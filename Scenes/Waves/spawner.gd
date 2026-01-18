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

# ---------------------------------------------------
# UI References
# ---------------------------------------------------
@onready var wave_banner: Control = $wave_banner
@onready var wave_number: Label = $wave_banner/Wave_Number
@onready var wave_banner_label: Label = $wave_banner/wave_banner_label

@onready var mid = get_tree().get_first_node_in_group("mid")
@onready var upgrade_manager = get_tree().get_first_node_in_group("upgrade_manager")

# ---------------------------------------------------
# WAVES (Corrected)
# ---------------------------------------------------
var waves = [
	[{"enemy": 1, "count": 2}],
	[
		{"enemy": 1, "count": 4},
		{"enemy": 2, "count": 2}
	],
	[
		{"enemy": 2, "count": 2},
		{"enemy": 1, "count": 2},
		{"enemy": 3, "count": 1}
	],
	[
		{"enemy": 2, "count": 2},
		{"enemy": 1, "count": 2},
		{"enemy": 3, "count": 1}
	],
	[
		{"enemy": 2, "count": 2},
		{"enemy": 1, "count": 2},
		{"enemy": 3, "count": 1}
	],
]

# ---------------------------------------------------
# SETTINGS
# ---------------------------------------------------
var spawn_delay := 0.3
var wave_delay := 1.4
var spawn_area_half := 260.0
var arena_bound := 1200.0

var enemy_list: Array = []
var alive_enemies: Array = []
var current_wave := 0

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

	show_wave_banner("WAVE 1 START")
	update_wave_text(0)
	start_wave(0)

# ---------------------------------------------------
# UI BANNER (INTENSITY BOOSTED)
# ---------------------------------------------------
func show_wave_banner(text: String) -> Tween:
	wave_banner_label.text = text

	# Reset
	wave_banner.position.y = -200
	wave_banner_label.modulate.a = 0

	var t = create_tween()

	# Drop fast + overshoot
	t.tween_property(wave_banner, "position:y", 40, 0.33)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Fade text
	t.parallel().tween_property(wave_banner_label, "modulate:a", 1.0, 0.25)

	# Hold
	t.tween_interval(1.15)

	# Fade + slide up harder
	t.tween_property(wave_banner_label, "modulate:a", 0.0, 0.25)
	t.tween_property(wave_banner, "position:y", -200, 0.35)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	return t  # important (we wait for this)

# ---------------------------------------------------
func update_wave_text(idx: int):
	wave_number.text = "Wave: " + str(idx + 1)

# ---------------------------------------------------
# START WAVE
# ---------------------------------------------------
func start_wave(wave_index: int):
	if wave_index >= waves.size():
		show_wave_banner("ALL WAVES CLEARED!")
		return

	current_wave = wave_index
	update_wave_text(current_wave)

	await show_wave_banner("WAVE " + str(current_wave + 1) + " START").finished

	alive_enemies.clear()
	spawn_wave(waves[current_wave])

# ---------------------------------------------------
# SPAWN WAVE
# ---------------------------------------------------
func spawn_wave(wave_data: Array):
	spawn_wave_async(wave_data)

func spawn_wave_async(wave_data: Array) -> void:
	for entry in wave_data:
		for i in entry["count"]:
			spawn_enemy(enemy_list[entry["enemy"] - 1])
			await get_tree().create_timer(spawn_delay).timeout

	await wait_for_wave_to_finish()

	# WAVE OVER TEXT
	await show_wave_banner("WAVE " + str(current_wave + 1) + " COMPLETE").finished
	await show_wave_banner("CHOOSE YOUR POWER UP").finished

	# Drop Upgrade UI (Bounce)
	if upgrade_manager:
		upgrade_manager.show_upgrades()

	await get_tree().create_timer(1.0).timeout

	show_wave_banner("NEXT WAVE INCOMING")
	await get_tree().create_timer(wave_delay).timeout

	start_wave(current_wave + 1)

# ---------------------------------------------------
# SAFE SPAWNING
# ---------------------------------------------------
func spawn_enemy(scene: PackedScene):
	var enemy = scene.instantiate()
	get_parent().call_deferred("add_child", enemy)

	alive_enemies.append(enemy)
	enemy.tree_exited.connect(_on_enemy_exit.bind(enemy), Object.CONNECT_ONE_SHOT)

	var center = mid.global_position
	var pos = center

	for i in 25:
		var try_pos = center + Vector2(randf_range(-spawn_area_half, spawn_area_half), randf_range(-spawn_area_half, spawn_area_half))
		var ok := true

		for other in alive_enemies:
			if other != enemy and is_instance_valid(other):
				if try_pos.distance_to(other.global_position) < 48:
					ok = false
					break

		if ok:
			pos = try_pos
			break

	enemy.global_position = pos

	monitor_enemy_bounds(enemy)
	enemy_sanity_monitor(enemy)

# ---------------------------------------------------
func _on_enemy_exit(enemy):
	alive_enemies.erase(enemy)

# ---------------------------------------------------
func wait_for_wave_to_finish():
	while true:
		if !get_tree(): continue
		for e in alive_enemies.duplicate():
			if not is_instance_valid(e):
				alive_enemies.erase(e)

		if alive_enemies.size() == 0:
			return

		await get_tree().process_frame

# ---------------------------------------------------
func monitor_enemy_bounds(enemy):
	while is_instance_valid(enemy):
		if !get_tree(): continue
		var d = enemy.global_position.distance_to(mid.global_position)
		if d > arena_bound:
			alive_enemies.erase(enemy)
			enemy.queue_free()
			return
		await get_tree().process_frame

# ---------------------------------------------------
func enemy_sanity_monitor(enemy):
	await get_tree().process_frame
	if not is_instance_valid(enemy):
		return

	var last_pos = enemy.global_position
	var stuck_time := 0.0

	while true:

		# Wait some time
		await get_tree().create_timer(0.3).timeout

		# Enemy may have been destroyed while waiting
		if enemy == null or not is_instance_valid(enemy):
			return

		var current_pos = enemy.global_position

		# Compare positions
		if current_pos == last_pos:
			stuck_time += 0.3
		else:
			stuck_time = 0.0

		last_pos = current_pos

		# Stuck too long → remove
		if stuck_time >= 4.0:
			if alive_enemies.has(enemy):
				alive_enemies.erase(enemy)
			if is_instance_valid(enemy):
				enemy.queue_free()
			return
