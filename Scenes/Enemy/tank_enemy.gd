extends EnemyBase
class_name RotatingEnemy

@export var extra_health: int = 10
@export var rotation_speed: float = 90.0          # visual rotation speed
@export var orbit_speed: float = 50.0             # how fast it moves around circle
@export var orbit_radius: float = 150.0           # distance from mid center

# Internal
var angle: float = 0.0
var mid_point: Node2D

func _ready():
	super._ready()

	max_health += extra_health
	health = max_health

	# Get the mid node
	mid_point = get_tree().get_first_node_in_group("mid")

	if mid_point == null:
		push_error("RotatingEnemy: No node in group 'mid' found!")

	# Randomize starting angle so all tanks don't align
	angle = randf() * TAU


func perform_movement(delta: float) -> void:

	# ----------------------------------------
	# VISUAL ROTATION
	# ----------------------------------------
	rotation_degrees += rotation_speed * delta

	if mid_point == null:
		return

	# ----------------------------------------
	# ORBIT AROUND MID
	# ----------------------------------------
	angle += orbit_speed * delta / orbit_radius

	var center := mid_point.global_position

	# perfect circle path around mid
	var target_pos = center + Vector2(
		cos(angle) * orbit_radius,
		sin(angle) * orbit_radius
	)

	# move toward target point
	velocity = global_position.direction_to(target_pos) * speed * 0.6
	move_and_slide()
