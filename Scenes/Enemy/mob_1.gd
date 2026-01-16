extends CharacterBody2D

@export var max_health: int = 3
@export var speed: float = 120.0
@export var friction: float = 8.0
@export var stun_time: float = 0.15

var health: int
var knockback_velocity: Vector2 = Vector2.ZERO
var stun_timer: float = 0.0

@onready var player: Node2D = get_tree().get_first_node_in_group("player")

func _ready():
	health = max_health

func _physics_process(delta: float) -> void:
	if stun_timer > 0:
		stun_timer -= delta
		_knockback_step(delta)
		return

	# Basic chase AI
	if player:
		var dir = global_position.direction_to(player.global_position)
		velocity = dir * speed

	move_and_slide()
	_knockback_step(delta)

func apply_knockback(force: Vector2) -> void:
	knockback_velocity = force
	stun_timer = stun_time

func _knockback_step(delta: float) -> void:
	if knockback_velocity.length() > 1:
		var motion = knockback_velocity * delta
		var collision = move_and_collide(motion)

		if collision:
			knockback_velocity = Vector2.ZERO
		else:
			knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, friction)
	else:
		knockback_velocity = Vector2.ZERO

func take_damage(amount: int = 1) -> void:
	StatsManager.apply_damage(self, amount)

func on_hit(amount):
	flash_hit()

func flash_hit():
	modulate = Color(1,0.4,0.4)
	await get_tree().create_timer(0.1).timeout
	modulate = Color(1,1,1)

func die():
	queue_free()
