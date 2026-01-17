extends EnemyBase
class_name FollowerEnemy

@export var follow_speed: float = 140.0

@export var rest_duration: float = 2.0        # Enemy stops moving
@export var follow_duration: float = 1.8      # Enemy moves

var state_timer: float = 0.0
var is_resting: bool = true                   # Start in rest mode

func _ready():
	super._ready()
	speed = follow_speed
	state_timer = rest_duration               # Start resting


func _physics_process(delta: float) -> void:
	# If stunned, let base handle it
	if stun_timer > 0:
		stun_timer -= delta
		_process_knockback(delta)
		return

	# Handle the rest/follow timer
	state_timer -= delta
	if state_timer <= 0.0:
		is_resting = !is_resting
		state_timer = (rest_duration if is_resting else follow_duration)

	# If resting → no movement
	if is_resting:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# If following → use normal base movement
	perform_movement(delta)
