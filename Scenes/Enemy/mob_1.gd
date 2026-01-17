extends EnemyBase
class_name EnemyRandomMove

@export var change_dir_interval: float = 1.2  
@export var randomness: float = 1.0            # 1.0 = fully random, 0.3 = slight jitter

var dir: Vector2 = Vector2.ZERO
var change_timer: float = 0.0


func _ready():
	super._ready()
	pick_random_direction()


func perform_movement(delta: float) -> void:
	# Countdown to next direction change
	change_timer -= delta
	if change_timer <= 0.0:
		pick_random_direction()


	velocity = dir * speed
	move_and_slide()


func pick_random_direction() -> void:
	change_timer = change_dir_interval
	

	var angle = randf() * TAU
	var base_dir = Vector2(cos(angle), sin(angle))


	var noisy = base_dir.lerp(Vector2(randf() - 0.5, randf() - 0.5).normalized(), randomness)

	dir = noisy.normalized()
