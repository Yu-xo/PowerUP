extends CharacterBody2D

# ---------------------------------------------------------
# BASE VALUES (exported)
# ---------------------------------------------------------
@export var base_speed: float = 300.0
@export var max_charge: float = 10.0
@export var charge_rate: float = 3.0
@export var overcharge_threshold: float = 9.0
@export var overcharge_damage: float = 1.0
@export var overcharge_interval: float = 1.0
@export var max_health: int = 5
@export var bounce_multiplier: float = 1.3
@export var knockback_force: float = 200.0
@export var slowmo_factor: float = 0.3

@onready var debug: Label = $CanvasLayer/Debug
@onready var tween := create_tween()
@onready var body_tween := create_tween()

# ---------------------------------------------------------
# RUNTIME VALUES
# ---------------------------------------------------------
var health: float = max_health
var charge: float = 0.0
var is_charging: bool = false

var dash_direction: Vector2 = Vector2.ZERO
var is_dashing: bool = false

var overcharge_timer: float = 0.0
var is_overcharging: bool = false

# NEW — Aim Mode (Right-Click Slow Motion)
var is_aiming: bool = false

# ---------------------------------------------------------
# UPGRADE VARIABLES
# ---------------------------------------------------------
## Attack
var dash_damage_bonus: int = 0
var bounce_damage_multiplier: float = 1.0
var charge_damage_multiplier: float = 1.0
var first_hit_bonus: int = 0
var first_hit_active: bool = false

## Defense
var shield: float = 0.0
var shield_regen_rate: float = 0.0
var dash_invincible_time: float = 0.0
var shield_refill_on_hit: bool = false
var dash_invincible_timer: float = 0.0

## Health
var regen_rate: float = 0.0
var max_overheal: float = 0.0
var overheal_bonus_damage: int = 0

## Speed
var dash_distance_multiplier: float = 1.0
var dash_cooldown_multiplier: float = 1.0
var dash_contact_damage: int = 0
var dash_invincible: bool = false
var dash_phase_through: bool = false


# ---------------------------------------------------------
# PHYSICS PROCESS
# ---------------------------------------------------------
func _physics_process(delta: float) -> void:

	# Always rotate to mouse when aiming/charging/dashing
	if is_aiming or is_charging or is_dashing:
		look_at(get_global_mouse_position())

	# ------------------------------------------
	# Charging (Left-click held)
	# ------------------------------------------
	if is_charging and !is_aiming:
		charge += charge_rate * delta
		charge = clamp(charge, 0.0, max_charge)

		if charge >= max_charge:
			Engine.time_scale = slowmo_factor
		else:
			Engine.time_scale = 1.0

		if charge >= overcharge_threshold:
			is_overcharging = true
			handle_overcharge(delta)
		else:
			is_overcharging = false
			overcharge_timer = 0.0

	# ------------------------------------------
	# Dash movement
	# ------------------------------------------
	if is_dashing:
		dash_invincible_timer -= delta

		var speed = base_speed * (1.0 + charge) * dash_distance_multiplier
		var motion = dash_direction * speed * delta

		var collision = move_and_collide(motion, false, false, !dash_phase_through)
		if collision and !dash_phase_through:
			handle_collision(collision)

	# ------------------------------------------
	# Passive regen
	# ------------------------------------------
	if regen_rate > 0 and !is_dashing and !is_charging:
		health = min(health + regen_rate * delta, max_health + max_overheal)

	# ------------------------------------------
	# Shield regen
	# ------------------------------------------
	if shield_regen_rate > 0:
		shield = min(shield + shield_regen_rate * delta, 3.0)

	move_and_slide()
	update_debug_ui()
	update_player_visuals()


# ---------------------------------------------------------
# INPUT
# ---------------------------------------------------------
func _input(event: InputEvent) -> void:

	# -----------------------------------------------------
	# AIM MODE (RIGHT CLICK)
	# -----------------------------------------------------
	if event.is_action_pressed("aim_mode"):
		is_aiming = true
		Engine.time_scale = 0.25
		return

	if event.is_action_released("aim_mode"):
		is_aiming = false
		Engine.time_scale = 1.0
		return



	# -----------------------------------------------------
	# NORMAL DASH CHARGE (LEFT CLICK) — ONLY IF NOT AIMING
	# -----------------------------------------------------
	if event.is_action_pressed("click") and !is_aiming:
		charge = 0.0
		is_charging = true
		is_overcharging = false
		overcharge_timer = 0.0
		animate_debug_start()
		animate_player_charge_start()
		return


	# -----------------------------------------------------
	# RELEASE CHARGE → DASH
	# -----------------------------------------------------
	if event.is_action_released("click") and is_charging:
		is_charging = false
		is_overcharging = false
		overcharge_timer = 0.0
		Engine.time_scale = 1.0

		dash_direction = global_position.direction_to(get_global_mouse_position())
		is_dashing = true
		first_hit_active = true

		if dash_invincible:
			dash_invincible_timer = dash_invincible_time

		animate_debug_release()
		animate_player_charge_end()
		return



	# -----------------------------------------------------
	# MID-AIR REDIRECT DASH (LEFT CLICK DURING AIM MODE)
	# -----------------------------------------------------
	if event.is_action_pressed("click") and is_aiming:

		# override direction instantly
		dash_direction = global_position.direction_to(get_global_mouse_position())

		# ensure dash is active
		is_dashing = true

		# allow ONE more first-hit bonus for the redirect dash
		first_hit_active = true

		return

# ---------------------------------------------------------
# COLLISION
# ---------------------------------------------------------
func handle_collision(collision: KinematicCollision2D) -> void:
	var collider = collision.get_collider()

	if collider is StaticBody2D:
		is_dashing = false
		dash_direction = Vector2.ZERO
		velocity = Vector2.ZERO
		return

	if collider is CharacterBody2D:
		var normal = collision.get_normal()

		dash_direction = dash_direction.bounce(normal).normalized() * bounce_multiplier

		var total_damage = calculate_dash_damage()

		StatsManager.apply_knockback(collider, -normal * knockback_force * (1.0 + charge))
		StatsManager.apply_damage(collider, total_damage)

		if shield_refill_on_hit:
			shield = 1.0

		if dash_phase_through and dash_contact_damage > 0:
			StatsManager.apply_damage(collider, dash_contact_damage)


# ---------------------------------------------------------
# DAMAGE FORMULA
# ---------------------------------------------------------
func calculate_dash_damage() -> int:
	var dmg = round(charge) * charge_damage_multiplier
	dmg += dash_damage_bonus

	if first_hit_active and first_hit_bonus > 0:
		dmg += first_hit_bonus
		first_hit_active = false

	if health > max_health:
		dmg += overheal_bonus_damage

	return int(dmg)


# ---------------------------------------------------------
# OVERCHARGE
# ---------------------------------------------------------
func handle_overcharge(delta: float) -> void:
	overcharge_timer += delta
	if overcharge_timer >= overcharge_interval:
		overcharge_timer = 0.0
		apply_overcharge_damage()


func apply_overcharge_damage() -> void:
	if shield > 0:
		shield -= 1
		return

	health -= overcharge_damage
	if health <= 0:
		die()


# ---------------------------------------------------------
# DEATH
# ---------------------------------------------------------
func die():
	queue_free()


# ---------------------------------------------------------
# DEBUG UI
# ---------------------------------------------------------
func update_debug_ui():
	var over_text := "\nOVERCHARGING!" if is_overcharging else ""
	debug.text = "Charge: " + str(round(charge)) \
		+ "\nHP: " + str(round(health)) \
		+ "\nShield: " + str(round(shield)) \
		+ over_text

	var t := charge / max_charge
	var start_color := Color(0.2, 1.0, 0.2)
	var mid_color := Color(1.0, 1.0, 0.2)
	var end_color := Color(1.0, 0.2, 0.2)
	var new_color := (start_color.lerp(mid_color, t * 2.0)
		if t < 0.5
		else mid_color.lerp(end_color, (t - 0.5) * 2.0))
	debug.modulate = new_color


# ---------------------------------------------------------
# VISUALS
# ---------------------------------------------------------
func update_player_visuals():
	if dash_invincible_timer > 0:
		modulate = Color(0.3, 0.3, 1.0)
	elif is_overcharging:
		modulate = Color(1, 0.3, 0.3)
	else:
		modulate = Color(1, 1, 1)


# ---------------------------------------------------------
# ANIMATION TWEENS
# ---------------------------------------------------------
func animate_player_charge_start():
	if body_tween.is_running(): body_tween.kill()
	body_tween = create_tween()
	body_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.2)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func animate_player_charge_end():
	if body_tween.is_running(): body_tween.kill()
	body_tween = create_tween()
	body_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.25)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func animate_debug_start():
	if tween.is_running(): tween.kill()
	tween = create_tween()
	tween.tween_property(debug, "scale", Vector2(1.3, 1.3), 0.15)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func animate_debug_release():
	if tween.is_running(): tween.kill()
	tween = create_tween()
	tween.tween_property(debug, "scale", Vector2(1.0, 1.0), 0.2)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
