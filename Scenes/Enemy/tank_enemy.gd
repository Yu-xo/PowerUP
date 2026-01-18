extends EnemyBase
class_name RotatingEnemy

@export var extra_health: int = 10

@export var rotation_speed: float = 90.0
@export var orbit_speed: float = 50.0
@export var orbit_radius: float = 150.0

var angle: float = 0.0
var mid_point: Node2D

func _ready():
	super._ready()

	max_health += extra_health
	health = max_health

	mid_point = get_tree().get_first_node_in_group("mid")
	if mid_point == null:
		push_error("RotatingEnemy: No 'mid' node found!")

	angle = randf() * TAU  # random offset for variety

func perform_movement(delta: float) -> void:

	if mid_point == null:
		return

	# Spin sprite
	rotation_degrees += rotation_speed * delta

	# Circle movement
	angle += orbit_speed * delta / orbit_radius
	var center = mid_point.global_position

	var orbit_target = center + Vector2(
		cos(angle) * orbit_radius,
		sin(angle) * orbit_radius
	)

	var base_move = global_position.direction_to(orbit_target) * speed * 0.6

	# Add avoidance
	var avoid = avoid_other_enemies() * 1.1 + avoid_walls() * 1.5

	velocity = base_move + avoid
	move_and_slide()
