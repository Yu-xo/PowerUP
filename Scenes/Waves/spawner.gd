extends Node2D
class_name WaveSpawner

# ---------------------------------------------------
# ENEMY SCENES
# ---------------------------------------------------
@export var enemy_type_1: PackedScene
@export var enemy_type_2: PackedScene
@export var enemy_type_3: PackedScene
@export var enemy_type_4: PackedScene
@export var enemy_type_5: PackedScene

# UI References
@onready var wave_number: Label = $wave_banner/Wave_Number
@onready var wave_banner: Control = $wave_banner
@onready var wave_banner_label: Label =$wave_banner/wave_banner_label

# Runtime refs
@onready var mid = get_tree().get_first_node_in_group("mid")
@onready var upgrade_manager = get_tree().get_first_node_in_group("upgrade_manager")

# ---------------------------------------------------
# WAVES
# ---------------------------------------------------
var waves = [
	[ {"enemy": 1, "count": 2} ],
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
# SETTINGS
# ---------------------------------------------------
var spawn_delay := 0.35
var wave_delay := 2.0
var spawn_area_half := 250.0
var post_wave_upgrade_delay := 2.0
var arena_bound := 1200.0

# Internal
var enemy_list: Array = []
var alive_enemies: Array = []
var current_wave: int = 0

# ---------------------------------------------------
# READY
# ---------------------------------------------------
func _ready():
	enemy_list = [
		enemy_type_1,
		enemy_type_2,
		enemy_type_3,
		enemy_type_4,
		enemy_type_5
	]

	wave_number.visible = true
	update_wave_text(0)

	start_wave(0)

# ---------------------------------------------------
# UI BANNER ANIMATION
# ---------------------------------------------------
func show_wave_banner(text: String):
	wave_banner_label.text = text

	# Reset start state
	wave_banner.position.y = -150
	wave_banner_label.modulate.a = 0

	var tw = create_tween()

	# Slide down
	tw.tween_property(wave_banner, "position:y", 40, 0.4)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tw.tween_property(wave_banner_label, "modulate:a", 1.0, 0.4)

	# Hold
	tw.tween_interval(1.0)

	# Fade out + slide up
	tw.tween_property(wave_banner_label, "modulate:a", 0.0, 0.3)
	tw.tween_property(wave_banner, "position:y", -150, 0.4)

# ---------------------------------------------------
func update_wave_text(idx: int):
	wave_number.text = "Wave: " + str(idx + 1)

# ---------------------------------------------------
# START WAVE
# ---------------------------------------------------
func start_wave(wave_index: int):

	if wave_index >= waves.size():
		wave_number.text = "ALL WAVES CLEARED!"
		show_wave_banner("ALL WAVES COMPLETE")
		return

	current_wave = wave_index
	update_wave_text(current_wave)

	show_wave_banner("Wave " + str(current_wave + 1) + " Starting")

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

		if enemy_index < 0 or enemy_index >= enemy_list.size():
			continue

		var scene = enemy_list[enemy_index]
		if not scene:
			continue

		for i in count:
			spawn_enemy(scene)
			await get_tree().create_timer(spawn_delay).timeout

	await wait_for_wave_to_finish()

	wave_number.text = "UPGRADE TIME!"
	show_wave_banner("UPGRADE TIME!")

	if upgrade_manager:
		upgrade_manager.show_upgrades()

	await get_tree().create_timer(post_wave_upgrade_delay).timeout

	show_wave_banner("Wave " + str(current_wave + 2) + " Incoming")
	await get_tree().create_timer(wave_delay).timeout

	start_wave(current_wave + 1)

# ---------------------------------------------------
# SAFE SPAWN
# ---------------------------------------------------
func spawn_enemy(scene: PackedScene):
	var enemy = scene.instantiate()
	get_parent().call_deferred("add_child", enemy)

	alive_enemies.append(enemy)
	enemy.tree_exited.connect(_on_enemy_exit.bind(enemy), Object.CONNECT_ONE_SHOT)

	var center = mid.global_position
	var spawn_pos := Vector2.ZERO

	for i in 25:
		var try_pos = Vector2(
			center.x + randf_range(-spawn_area_half, spawn_area_half),
			center.y + randf_range(-spawn_area_half, spawn_area_half)
		)

		var ok := true
		for other in alive_enemies:
			if other != enemy and is_instance_valid(other):
				if try_pos.distance_to(other.global_position) < 48:
					ok = false
					break
		if ok:
			spawn_pos = try_pos
			break

	if spawn_pos == Vector2.ZERO:
		spawn_pos = center

	enemy.global_position = spawn_pos

	monitor_enemy_bounds(enemy)
	enemy_sanity_monitor(enemy)

# ---------------------------------------------------
# ENEMY EXIT
# ---------------------------------------------------
func _on_enemy_exit(enemy):
	if alive_enemies.has(enemy):
		alive_enemies.erase(enemy)

# ---------------------------------------------------
# WAIT FOR WAVE FINISH
# ---------------------------------------------------
func wait_for_wave_to_finish():
	while true:
		for e in alive_enemies.duplicate():
			if e == null or not is_instance_valid(e):
				alive_enemies.erase(e)

		if alive_enemies.size() <= 0:
			return

		await get_tree().process_frame

# ---------------------------------------------------
# BOUNDS CHECK
# ---------------------------------------------------
func monitor_enemy_bounds(enemy: Node2D):
	while true:

		if enemy == null or not is_instance_valid(enemy):
			return

		var dist_ok = abs(enemy.global_position.x - mid.global_position.x) <= arena_bound \
					  and abs(enemy.global_position.y - mid.global_position.y) <= arena_bound

		if not dist_ok:
			if alive_enemies.has(enemy):
				alive_enemies.erase(enemy)
			if is_instance_valid(enemy):
				enemy.queue_free()
			return

		await get_tree().process_frame

# ---------------------------------------------------
# STUCK ENEMY CLEANER
# ---------------------------------------------------
func enemy_sanity_monitor(enemy: Node2D):

	await get_tree().process_frame
	if enemy == null or not is_instance_valid(enemy):
		return

	var stuck_time := 0.0
	var last_pos = enemy.global_position

	while true:

		if enemy == null or not is_instance_valid(enemy):
			return

		await get_tree().create_timer(0.3).timeout
		if enemy == null or not is_instance_valid(enemy):
			return

		var current_pos = enemy.global_position

		if current_pos == last_pos:
			stuck_time += 0.3
		else:
			stuck_time = 0.0

		last_pos = current_pos

		if stuck_time >= 4.0:
			if alive_enemies.has(enemy):
				alive_enemies.erase(enemy)
			if is_instance_valid(enemy):
				enemy.queue_free()
			return
