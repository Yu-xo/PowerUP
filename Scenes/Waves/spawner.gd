extends Node2D
class_name WaveSpawner

# ---------------------------------------------------
# Enemy Types
# ---------------------------------------------------
@export var enemy_type_1: PackedScene
@export var enemy_type_2: PackedScene
@export var enemy_type_3: PackedScene
@export var enemy_type_4: PackedScene
@export var enemy_type_5: PackedScene

# ---------------------------------------------------
# Waves
# ---------------------------------------------------
var waves = [
	[
		{"enemy": 1, "count": 2},
	],
	[
		{"enemy": 1, "count": 4},
		{"enemy": 3, "count": 2}
	],
	[
		{"enemy": 4, "count": 3},
		{"enemy": 2, "count": 2},
		{"enemy": 5, "count": 1}
	]
]

# ---------------------------------------------------
# Settings
# ---------------------------------------------------
var spawn_delay := 0.35
var wave_delay := 2.0
var spawn_area_half := 250.0
var post_wave_upgrade_delay := 2.0
var arena_bound := 1200.0

# ---------------------------------------------------
# Runtime References
# ---------------------------------------------------
@onready var mid = get_tree().get_first_node_in_group("mid")
@onready var player = get_tree().get_first_node_in_group("player")
@onready var upgrade_manager = get_tree().get_first_node_in_group("upgrade_manager")

# ---------------------------------------------------
# Internal
# ---------------------------------------------------
var enemy_list: Array = []
var alive_enemies: Array = []        # real enemy tracking
var current_wave: int = 0


# ---------------------------------------------------
# READY
# ---------------------------------------------------
func _ready():
	print("WaveSpawner: Initializing...")

	enemy_list = [
		enemy_type_1,
		enemy_type_2,
		enemy_type_3,
		enemy_type_4,
		enemy_type_5
	]

	if not player: push_error("Player not found in group 'player'!"); return
	if not mid: push_error("mid node not found in group 'mid'!"); return
	if not upgrade_manager: push_error("UpgradeManager not found in group 'upgrade_manager'!"); return

	start_wave(0)


# ---------------------------------------------------
# START WAVE
# ---------------------------------------------------
func start_wave(wave_index: int):
	if wave_index >= waves.size():
		print("ALL WAVES COMPLETED!")
		return

	current_wave = wave_index

	print("\n==============================")
	print("Starting Wave:", current_wave + 1)
	print("==============================\n")

	alive_enemies.clear()
	spawn_wave(waves[wave_index])


# ---------------------------------------------------
# SPAWN WAVE
# ---------------------------------------------------
func spawn_wave(wave_data: Array):
	spawn_wave_async(wave_data)


func spawn_wave_async(wave_data: Array) -> void:
	for entry in wave_data:
		var enemy_index = entry["enemy"] - 1
		var count = entry["count"]

		if enemy_index < 0 or enemy_index >= enemy_list.size(): continue
		var scene: PackedScene = enemy_list[enemy_index]
		if not scene: continue

		print("Spawning", count, "x Enemy Type", enemy_index + 1)

		for i in count:
			spawn_enemy(scene)
			await get_tree().create_timer(spawn_delay).timeout

	print("All enemies spawned. Waiting...")

	await wait_for_wave_to_finish()

	print("Wave", current_wave + 1, "cleared!")

	# Show upgrade UI
	if upgrade_manager:
		upgrade_manager.show_upgrades()

	print("Waiting", post_wave_upgrade_delay, "seconds before next wave...")
	await get_tree().create_timer(post_wave_upgrade_delay).timeout

	await get_tree().create_timer(wave_delay).timeout
	start_wave(current_wave + 1)


# ---------------------------------------------------
# SPAWN ENEMY SAFE
# ---------------------------------------------------
func spawn_enemy(scene: PackedScene):
	var enemy = scene.instantiate()
	get_parent().add_child(enemy)

	alive_enemies.append(enemy)
	enemy.tree_exited.connect(_on_enemy_exit.bind(enemy), Object.CONNECT_ONE_SHOT)

	var center = mid.global_position
	var spawn_pos := Vector2.ZERO
	var max_attempts := 25

	for i in max_attempts:
		var try_pos := Vector2(
			center.x + randf_range(-spawn_area_half, spawn_area_half),
			center.y + randf_range(-spawn_area_half, spawn_area_half)
		)

		var too_close := false

		for other in alive_enemies:
			if other != enemy and is_instance_valid(other):
				if try_pos.distance_to(other.global_position) < 48.0:
					too_close = true
					break

		if not too_close:
			spawn_pos = try_pos
			break

	if spawn_pos == Vector2.ZERO:
		spawn_pos = center

	enemy.global_position = spawn_pos

	print("Spawned SAFE enemy at:", spawn_pos)

	monitor_enemy_bounds(enemy)
	enemy_sanity_monitor(enemy)
	kill_after_time(enemy, 15.0)   # <-- new line, auto-kill after 15 seconds
func kill_after_time(enemy: Node2D, time: float) -> void:
	await get_tree().create_timer(time).timeout
	if is_instance_valid(enemy):
		print("Enemy auto-killed after", time, "seconds")



# ---------------------------------------------------
# ENEMY DEATH / REMOVAL HANDLER
# ---------------------------------------------------
func _on_enemy_exit(enemy):
	if alive_enemies.has(enemy):
		alive_enemies.erase(enemy)

	print("Enemy removed. Remaining:", alive_enemies.size())


# ---------------------------------------------------
# OUT OF BOUNDS CHECK
# ---------------------------------------------------
func monitor_enemy_bounds(enemy: Node2D) -> void:
	while true:
		if not is_instance_valid(enemy): return

		if enemy.global_position.distance_to(mid.global_position) > arena_bound:
			print("Enemy out of bounds → removed")
			alive_enemies.erase(enemy)
			enemy.queue_free()
			return

		await get_tree().process_frame


# ---------------------------------------------------
# WAIT FOR ALL ENEMIES
# ---------------------------------------------------
func wait_for_wave_to_finish() -> void:
	while alive_enemies.size() > 0:
		await get_tree().process_frame

	print("All enemies cleared!")


# ---------------------------------------------------
# DETECT STUCK ENEMIES
# ---------------------------------------------------
func enemy_sanity_monitor(enemy: Node2D) -> void:
	# Wait until enemy is fully added to scene
	await get_tree().process_frame

	if not is_instance_valid(enemy):
		return

	var stuck_time := 0.0
	var last_pos := enemy.global_position

	while true:

		if not is_instance_valid(enemy):
			return

		await get_tree().create_timer(0.3).timeout
		if not is_instance_valid(enemy):
			return

		var current_pos = enemy.global_position

		# If enemy didn't move AT ALL
		if current_pos == last_pos:
			stuck_time += 0.3
		else:
			stuck_time = 0.0   # reset if moving

		last_pos = current_pos

		# If stuck for more than 4 seconds → remove
		if stuck_time >= 4.0:
			print("Enemy frozen (Vector2.ZERO no movement) → removed")
			if alive_enemies.has(enemy):
				alive_enemies.erase(enemy)
			enemy.queue_free()
			return
