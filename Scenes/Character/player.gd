extends CharacterBody2D

# ---------------------------------------------------------
# BASE VALUES
# ---------------------------------------------------------
@export var base_speed: float = 300.0
@export var max_charge: float = 3.0
@export var charge_rate: float = 3.0
@export var overcharge_threshold: float = 9.0
@export var overcharge_damage: float = 1.0
@export var overcharge_interval: float = 1.0
@export var max_health: float = 5.0
@export var bounce_multiplier: float = 1.3
@export var knockback_force: float = 200.0
@export var slowmo_factor: float = 0.3

@onready var tween := create_tween()
@onready var body_tween := create_tween()
@onready var player_sprite := $Sprite2D
@onready var hud: CanvasLayer = $HUD

@export var ghost_interval := 0.01
@export var ghost_scene = preload("res://Scenes/Character/ghost.tscn")
var ghost_timer := 0.0

# ---------------------------------------------------------
# RUNTIME
# ---------------------------------------------------------
var health: float = max_health
var charge: float = 0.0
var is_charging := false
var dash_direction := Vector2.ZERO
var is_dashing := false
var is_aiming := false
var is_overcharging := false
var overcharge_timer := 0.0

# Unsafe charge
var unsafe_charge_threshold := 6.0
var unsafe_damage_per_second := 1.0

# ---------------------------------------------------------
# HIT COOLDOWN + INVULNERABILITY
# ---------------------------------------------------------
var enemy_damage_cooldown := 0.0
var enemy_damage_cooldown_time := 1.0  # 1s invulnerability window
var is_invulnerable := false
var invuln_blink_timer := 0.0
var invuln_blink_speed := 0.08

# ---------------------------------------------------------
# UPGRADE SYSTEM VARIABLES
# ---------------------------------------------------------
var dash_damage_bonus := 0
var bounce_damage_multiplier := 1.0
var charge_damage_multiplier := 1.0
var first_hit_bonus := 0
var first_hit_active := false

var shield := 0.0
var shield_regen_rate := 0.0
var dash_invincible_time := 0.0
var dash_invincible_timer := 0.0
var shield_refill_on_hit := false

var regen_rate := 0.0
var max_overheal := 0.0
var overheal_bonus_damage := 0

var dash_distance_multiplier := 1.0
var dash_cooldown_multiplier := 1.0
var dash_contact_damage := 0
var dash_invincible := false
var dash_phase_through := false

var can_pierce_low_hp := false
var has_hp_regen_on_kill := false
var has_shield_after_regen := false
var kill_counter := 0

# ---------------------------------------------------------
func _ready():
	update_hud()

# ---------------------------------------------------------
# PHYSICS
# ---------------------------------------------------------
func _physics_process(delta):

	# Decrease damage cooldown
	if enemy_damage_cooldown > 0:
		enemy_damage_cooldown -= delta
	else:
		is_invulnerable = false

	# INVULNERABILITY BLINKING
	if is_invulnerable:
		invuln_blink_timer -= delta
		if invuln_blink_timer <= 0:
			invuln_blink_timer = invuln_blink_speed
			player_sprite.visible = !player_sprite.visible
	else:
		player_sprite.visible = true

	# Ghost Trail
	ghost_timer -= delta
	if is_dashing and ghost_timer <= 0:
		spawn_ghost()
		ghost_timer = ghost_interval

	if is_aiming or is_charging or is_dashing:
		look_at(get_global_mouse_position())

	# Charging
	if is_charging and !is_aiming:
		charge += charge_rate * delta
		charge = clamp(charge, 0.0, max_charge)

		Engine.time_scale = slowmo_factor if charge >= max_charge else 1.0

		if charge >= overcharge_threshold:
			is_overcharging = true
			handle_overcharge(delta)
		else:
			is_overcharging = false
			overcharge_timer = 0.0

	# Unsafe charge
	if charge > unsafe_charge_threshold:
		health -= unsafe_damage_per_second * delta
		hud.set_hp(health, max_health, true)
		if health <= 0:
			die()

	# Dash movement
	if is_dashing:
		dash_invincible_timer -= delta
		var dash_speed := base_speed * (1 + charge) * dash_distance_multiplier
		var motion = dash_direction * dash_speed * delta
		var collision := move_and_collide(motion, false, false, !dash_phase_through)
		if collision and !dash_phase_through:
			handle_collision(collision)

	# Regen
	if regen_rate > 0 and !is_dashing and !is_charging:
		health = min(health + regen_rate * delta, max_health + max_overheal)

	# Shield
	if shield_regen_rate > 0:
		shield = min(shield + shield_regen_rate * delta, 3.0)

	move_and_slide()

	update_player_visuals()
	update_hud()

# ---------------------------------------------------------
# HUD
# ---------------------------------------------------------
func update_hud():
	if hud:
		hud.set_hp(health, max_health)
		hud.set_charge(charge, max_charge, is_overcharging)

# ---------------------------------------------------------
# INPUT
# ---------------------------------------------------------
func _input(event):

	if event.is_action_pressed("aim_mode"):
		is_aiming = true
		Engine.time_scale = 0.25
		return

	if event.is_action_released("aim_mode"):
		is_aiming = false
		Engine.time_scale = 1.0
		return

	if event.is_action_pressed("click") and !is_aiming:
		charge = 0
		is_charging = true
		is_overcharging = false
		overcharge_timer = 0
		animate_player_charge_start()
		return

	if event.is_action_released("click") and is_charging:
		is_charging = false
		is_overcharging = false
		overcharge_timer = 0
		Engine.time_scale = 1.0

		dash_direction = global_position.direction_to(get_global_mouse_position())
		is_dashing = true
		first_hit_active = true

		if dash_invincible:
			dash_invincible_timer = dash_invincible_time

		animate_player_charge_end()
		return

	if event.is_action_pressed("click") and is_aiming:
		dash_direction = global_position.direction_to(get_global_mouse_position())
		is_dashing = true
		first_hit_active = true
		return

# ---------------------------------------------------------
# COLLISION
# ---------------------------------------------------------
func handle_collision(collision):

	var collider = collision.get_collider()

	# Wall
	if collider is StaticBody2D or collider is TileMap:
		return

	if collider is CharacterBody2D:

		var normal = collision.get_normal()
		dash_direction = dash_direction.bounce(normal).normalized() * bounce_multiplier

		# -----------------------------------------------------
		# LOW CHARGE DAMAGE WITH COOLDOWN + BLINK + KNOCKBACK
		# -----------------------------------------------------
		if charge < 3:

			if enemy_damage_cooldown <= 0:

				health -= 1
				hud.set_hp(health, max_health, true)

				enemy_damage_cooldown = enemy_damage_cooldown_time
				is_invulnerable = true
				invuln_blink_timer = invuln_blink_speed

				# Knockback player
				var knock_dir = -normal.normalized()
				velocity = knock_dir * 350

				if health <= 0:
					die()

			return

		# Pierce low-HP enemies
		if can_pierce_low_hp and collider.health < 2:
			collider.die()
			_reward_kill()
			return

		var total_damage = calculate_dash_damage()

		StatsManager.apply_knockback(collider, -normal * knockback_force * (1 + charge))
		collider.take_damage(total_damage, self)

		_reward_kill()

		if shield_refill_on_hit:
			shield = 1

# ---------------------------------------------------------
# KILL REWARD
# ---------------------------------------------------------
func _reward_kill():

	kill_counter += 1

	if has_hp_regen_on_kill and kill_counter >= 3:
		kill_counter = 0
		health = min(health + 1, max_health)

		if has_shield_after_regen:
			shield = 1

# ---------------------------------------------------------
# DAMAGE FORMULA
# ---------------------------------------------------------
func calculate_dash_damage():
	var dmg = round(charge) * charge_damage_multiplier
	dmg += dash_damage_bonus

	if first_hit_active and first_hit_bonus > 0:
		dmg += first_hit_bonus
		first_hit_active = false

	if health > max_health:
		dmg += overheal_bonus_damage

	return int(dmg)

# ---------------------------------------------------------
# OVERCHARGE DAMAGE
# ---------------------------------------------------------
func handle_overcharge(delta):
	overcharge_timer += delta
	if overcharge_timer >= overcharge_interval:
		overcharge_timer = 0
		apply_overcharge_damage()

func apply_overcharge_damage():
	if shield > 0:
		shield -= 1
		return

	health -= overcharge_damage
	hud.set_hp(health, max_health, true)
	if health <= 0:
		die()

# ---------------------------------------------------------
# DEATH
# ---------------------------------------------------------
func die():
	queue_free()

# ---------------------------------------------------------
# VISUAL STATES
# ---------------------------------------------------------
func update_player_visuals():

	if dash_invincible_timer > 0:
		modulate = Color(0.3, 0.3, 1)
	elif is_overcharging:
		modulate = Color(1, 0.3, 0.3)
	else:
		modulate = Color(1, 1, 1)

# ---------------------------------------------------------
# ANIMATIONS
# ---------------------------------------------------------
func animate_player_charge_start():
	if body_tween.is_running(): body_tween.kill()
	body_tween = create_tween()
	body_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.2)

func animate_player_charge_end():
	if body_tween.is_running(): body_tween.kill()
	body_tween = create_tween()
	body_tween.tween_property(self, "scale", Vector2(1, 1), 0.25)

# ---------------------------------------------------------
# GHOST
# ---------------------------------------------------------
func spawn_ghost():
	var g = ghost_scene.instantiate()
	g.z_index = 9999
	get_tree().current_scene.add_child(g)
	g.start(player_sprite.texture, global_position, rotation)
