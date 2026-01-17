extends EnemyBase
class_name ExploderEnemy

@export var follow_speed: float = 110.0      # Movement speed
@export var explode_distance: float = 40.0   # Distance from player to trigger explosion
@export var explosion_radius: float = 70.0   # Area of effect
@export var explosion_damage: int = 2        # Damage applied
@export var fuse_time: float = 0.35          # Delay before explosion after triggering

var exploding: bool = false


func _ready():
	super._ready()
	speed = follow_speed


func _physics_process(delta: float) -> void:
	if exploding:
		return

	# If stunned → base handles it
	if stun_timer > 0:
		stun_timer -= delta
		_process_knockback(delta)
		return

	# Normal movement toward player (via base)
	perform_movement(delta)

	# Check explosion range
	if player and global_position.distance_to(player.global_position) <= explode_distance:
		start_explosion()


# ---------------------------------------------------
# Explosion Logic
# ---------------------------------------------------
func start_explosion() -> void:
	exploding = true
	velocity = Vector2.ZERO

	explode_async()


func explode_async() -> void:
	await get_tree().create_timer(fuse_time).timeout

	# Deal damage inside explosion radius
	apply_explosion_damage()

	# Play animation or flash (optional)
	modulate = Color(1, 0.3, 0.3)

	# Destroy this enemy
	queue_free()


func apply_explosion_damage():
	if player == null:
		return

	if global_position.distance_to(player.global_position) <= explosion_radius:
		StatsManager.apply_damage(player, explosion_damage)
