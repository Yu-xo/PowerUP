extends CharacterBody2D

# --------------------------------------------------------------------------
# CONFIG
# --------------------------------------------------------------------------
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

# --------------------------------------------------------------------------
# NODES
# --------------------------------------------------------------------------
@onready var debug: Label = $CanvasLayer/Debug
@onready var tween := create_tween()
@onready var body_tween := create_tween()

# --------------------------------------------------------------------------
# STATE
# --------------------------------------------------------------------------
var health: float = max_health
var charge: float = 0.0
var is_charging: bool = false

var dash_direction: Vector2 = Vector2.ZERO
var is_dashing: bool = false

var overcharge_timer: float = 0.0
var is_overcharging: bool = false


# --------------------------------------------------------------------------
# MAIN LOOP
# --------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	rotate_towards_mouse()

	# Increase charge
	if is_charging:
		charge += charge_rate * delta
		charge = clamp(charge, 0.0, max_charge)

		# Slow motion at max charge
		if charge >= max_charge:
			Engine.time_scale = slowmo_factor
		else:
			Engine.time_scale = 1.0

		# Overcharge damage
		if charge >= overcharge_threshold:
			is_overcharging = true
			handle_overcharge(delta)
		else:
			is_overcharging = false
			overcharge_timer = 0.0

	# Dash movement
	if is_dashing:
		var speed = base_speed * (1.0 + charge)
		var motion = dash_direction * speed * delta

		var collision = move_and_collide(motion)
		if collision:
			handle_collision(collision)

	move_and_slide()
	update_debug_ui()
	update_player_visuals()


# --------------------------------------------------------------------------
# INPUT
# --------------------------------------------------------------------------
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("click"):
		charge = 0.0
		is_charging = true
		is_overcharging = false
		overcharge_timer = 0.0

		animate_debug_start()
		animate_player_charge_start()

	if event.is_action_released("click") and is_charging:
		is_charging = false
		is_overcharging = false
		overcharge_timer = 0.0

		Engine.time_scale = 1.0  # reset slowmo

		# Dash toward mouse
		dash_direction = global_position.direction_to(get_global_mouse_position())
		is_dashing = true

		animate_debug_release()
		animate_player_charge_end()


# --------------------------------------------------------------------------
# ROTATION
# --------------------------------------------------------------------------
func rotate_towards_mouse():
	var mouse_pos = get_global_mouse_position()
	rotation = (mouse_pos - global_position).angle()


# --------------------------------------------------------------------------
# COLLISION HANDLING
# --------------------------------------------------------------------------
func handle_collision(collision: KinematicCollision2D) -> void:
	var collider = collision.get_collider()

	# Hit wall
	if collider is StaticBody2D:
		is_dashing = false
		dash_direction = Vector2.ZERO
		velocity = Vector2.ZERO
		print("Hit wall & stopped")
		return

	# Hit enemy
	if collider is CharacterBody2D:
		var normal = collision.get_normal()

		# Bounce with charge multiplier
		dash_direction = dash_direction.bounce(normal).normalized() * bounce_multiplier

		# Knockback enemy
		StatsManager.apply_knockback(collider, -normal * knockback_force * (1.0 + charge))
		StatsManager.apply_damage(collider, round(charge))

		print("Bounced off enemy!")


# --------------------------------------------------------------------------
# OVERCHARGE DAMAGE
# --------------------------------------------------------------------------
func handle_overcharge(delta: float) -> void:
	overcharge_timer += delta
	if overcharge_timer >= overcharge_interval:
		overcharge_timer = 0.0
		apply_overcharge_damage()

func apply_overcharge_damage() -> void:
	health -= overcharge_damage
	print("Overload Damage! HP =", health)
	if health <= 0:
		die()

func die():
	print("Player Died")
	queue_free()


# --------------------------------------------------------------------------
# DEBUG UI
# --------------------------------------------------------------------------
func update_debug_ui():
	var over_text := "\nOVERCHARGING!" if is_overcharging else ""

	debug.text = "Charge: " + str(round(charge)) \
		+ "\nHP: " + str(round(health)) \
		+ over_text

	# Color transition
	var t := charge / max_charge
	var start_color := Color(0.2, 1.0, 0.2)
	var mid_color := Color(1.0, 1.0, 0.2)
	var end_color := Color(1.0, 0.2, 0.2)

	var new_color := (start_color.lerp(mid_color, t * 2.0)
		if t < 0.5
		else mid_color.lerp(end_color, (t - 0.5) * 2.0))

	debug.modulate = new_color


# --------------------------------------------------------------------------
# PLAYER VISUAL FEEDBACK
# --------------------------------------------------------------------------
func update_player_visuals():
	modulate = Color(1, 0.3, 0.3) if is_overcharging else Color(1, 1, 1)

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


# --------------------------------------------------------------------------
# DEBUG LABEL ANIMATION
# --------------------------------------------------------------------------
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
