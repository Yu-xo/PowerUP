extends CharacterBody2D
class_name EnemyBase

@export var max_health: int = 3
@export var speed: float = 120.0
@export var friction: float = 8.0
@export var stun_time: float = 0.15

@onready var navigation_agent_2d: NavigationAgent2D = $NavigationAgent2D
@onready var player: Node2D = get_tree().get_first_node_in_group("player")

var health: int
var knockback_velocity: Vector2 = Vector2.ZERO
var stun_timer: float = 0.0


func _ready():
	health = max_health

	# Navigation setup
	navigation_agent_2d.target_desired_distance = 8.0
	navigation_agent_2d.path_desired_distance = 4.0



func _physics_process(delta: float) -> void:
	if stun_timer > 0:
		stun_timer -= delta
		_process_knockback(delta)
		return

	# Main AI movement
	perform_movement(delta)


### ----------------------------------------
### CHILD OVERRIDES DEFINE *HOW THEY MOVE*
### ----------------------------------------
func perform_movement(_delta: float) -> void:
	# Base class default: follow player
	if player:
		navigation_agent_2d.target_position = player.global_position

		var next_path_pos = navigation_agent_2d.get_next_path_position()
		var dir = global_position.direction_to(next_path_pos)

		velocity = dir * speed
		move_and_slide()


### ----------------------------------------
### Navigation callback (Godot 4 style)
### ----------------------------------------
func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity


### ----------------------------------------
### Knockback System
### ----------------------------------------
func apply_knockback(force: Vector2) -> void:
	knockback_velocity = force
	stun_timer = stun_time


func _process_knockback(delta: float) -> void:
	if knockback_velocity.length() > 1:
		var motion = knockback_velocity * delta
		var collision = move_and_collide(motion)

		if collision:
			knockback_velocity = Vector2.ZERO
		else:
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		knockback_velocity = Vector2.ZERO


### ----------------------------------------
### Damage System
### ----------------------------------------
func take_damage(amount: int = 1) -> void:
	StatsManager.apply_damage(self, amount)


func on_hit(amount: int):
	flash_hit()


func flash_hit():
	modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1, 1, 1)


func die():
	queue_free()
