extends CharacterBody2D
class_name EnemyBase

@export var max_health: int = 3
@export var speed: float = 120.0
@export var friction: float = 8.0
@export var stun_time: float = 0.15

# Avoidance settings
@export var avoidance_radius := 40.0
@export var avoidance_force := 180.0
@export var wall_avoid_distance := 60.0
@export var wall_avoid_strength := 200.0

@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D
@onready var player: Node2D = get_tree().get_first_node_in_group("player")

var health: int
var knockback_velocity: Vector2 = Vector2.ZERO
var stun_timer: float = 0.0

func _ready():
	health = max_health
	navigation_agent_2d.target_desired_distance = 8.0
	navigation_agent_2d.path_desired_distance = 4.0

func _physics_process(delta: float) -> void:

	if stun_timer > 0:
		stun_timer -= delta
		_process_knockback(delta)
		return

	perform_movement(delta)

### ---------------------------------------------------------
### SMART MOVEMENT SYSTEM
### ---------------------------------------------------------
func perform_movement(delta: float) -> void:

	if not player:
		return

	navigation_agent_2d.target_position = player.global_position
	var next_pos = navigation_agent_2d.get_next_path_position()
	var dir = global_position.direction_to(next_pos)

	var final_velocity = dir * speed
	final_velocity += avoid_other_enemies() * 1.2
	final_velocity += avoid_walls() * 2.0

	velocity = final_velocity
	move_and_slide()

### ---------------------------------------------------------
### ENEMY-ENEMY AVOIDANCE
### ---------------------------------------------------------
func avoid_other_enemies() -> Vector2:
	var push := Vector2.ZERO

	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self:
			continue
		if not e or not e.is_inside_tree():
			continue

		var dist := global_position.distance_to(e.global_position)
		if dist < avoidance_radius and dist > 0:
			var repulsion = (global_position - e.global_position).normalized()
			push += repulsion * (avoidance_radius - dist)

	return push.normalized() * avoidance_force


### ---------------------------------------------------------
### WALL AVOIDANCE
### ---------------------------------------------------------
func avoid_walls() -> Vector2:
	var space_state = get_world_2d().direct_space_state

	var q = PhysicsRayQueryParameters2D.new()
	q.from = global_position
	q.to = global_position + velocity.normalized() * wall_avoid_distance
	q.collide_with_areas = false
	q.collide_with_bodies = true

	var result = space_state.intersect_ray(q)

	if result and result.collider is StaticBody2D:
		return result.normal * wall_avoid_strength

	return Vector2.ZERO


### ---------------------------------------------------------
### NAVIGATION CALLBACK
### ---------------------------------------------------------
func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity


### ---------------------------------------------------------
### KNOCKBACK
### ---------------------------------------------------------
func apply_knockback(force: Vector2) -> void:
	knockback_velocity = force
	stun_timer = stun_time

func _process_knockback(delta: float) -> void:
	if knockback_velocity.length() > 1:
		var motion = knockback_velocity * delta
		var c = move_and_collide(motion)
		if c:
			knockback_velocity = Vector2.ZERO
		else:
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		knockback_velocity = Vector2.ZERO


### ---------------------------------------------------------
### DAMAGE + PLAYER-HIT KNOCKBACK
### ---------------------------------------------------------
func take_damage(amount: int = 1, attacker = null) -> void:

	# 1) If attacker is player
	if attacker != null and attacker.is_in_group("player"):

		# LOW CHARGE → reflect damage to player
		if attacker.charge < 3.0:
			StatsManager.apply_damage(attacker, 1)
			return

		# HIGH CHARGE → enemy takes damage AND gets knocked back
		var push_dir = (global_position - attacker.global_position).normalized()
		apply_knockback(push_dir * 600.0)

	# 2) Apply actual enemy damage
	StatsManager.apply_damage(self, amount)

func on_hit(amount: int):
	flash_hit()

func flash_hit():
	modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1, 1, 1)

func die():
	queue_free()
