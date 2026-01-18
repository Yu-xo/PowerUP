extends Node
class_name UpgradeManager

@onready var player = get_tree().get_first_node_in_group("player")

@onready var ui = $VBoxContainer
@onready var panel = $VBoxContainer/Panel
@onready var title = $VBoxContainer/Label
@onready var btn1 = $VBoxContainer/option1
@onready var btn2 = $VBoxContainer/option2
@onready var btn3 = $VBoxContainer/option3

var pending_choice_1: String
var pending_choice_2: String
var pending_choice_3: String

# Tier selection
var has_speed_upgrade := false
var has_hp_upgrade := false

func _ready():
	ui.visible = false

	btn1.pressed.connect(_on_button_pressed.bind(btn1, 1))
	btn2.pressed.connect(_on_button_pressed.bind(btn2, 2))
	btn3.pressed.connect(_on_button_pressed.bind(btn3, 3))

# -----------------------------------------------------------------------------------
# MAIN TIER 1
# -----------------------------------------------------------------------------------
var UPGRADE_POOL = {
	"Speed Boost": func(p):
	p.base_speed += 20
	has_speed_upgrade = true
	,
	"Shrink Body": func(p):
	p.scale -= Vector2(0.5, 0.5)
	,
	"Max HP +1": func(p):
	p.max_health += 1
	p.health = p.max_health
	has_hp_upgrade = true
	,
	"Max Charge +1": func(p):
		p.max_charge += 1
}

# -----------------------------------------------------------------------------------
# TIER 2 SPEED
# -----------------------------------------------------------------------------------
func speed_secondary_upgrades():
	var list = {}
	if has_speed_upgrade:
		list["Bounce +1 From Walls"] = func(p):
			p.bounce_multiplier += 1

		list["Pierce Enemies (HP < 2)"] = func(p):
			p.can_pierce_low_hp = true
	return list

# -----------------------------------------------------------------------------------
# TIER 2 HP
# -----------------------------------------------------------------------------------
func hp_secondary_upgrades():
	var list = {}
	if has_hp_upgrade:
		list["Regain HP Every 3 Kills"] = func(p):
			p.has_hp_regen_on_kill = true

		list["Gain Shield After HP Regen"] = func(p):
			p.has_shield_after_regen = true
	return list

# -----------------------------------------------------------------------------------
# SHOW UPGRADES
# -----------------------------------------------------------------------------------
func show_upgrades():

	var choices = []

	if not has_speed_upgrade:
		choices.append("Speed Boost")
	if not has_hp_upgrade:
		choices.append("Max HP +1")

	choices.append("Shrink Body")
	choices.append("Max Charge +1")

	for key in speed_secondary_upgrades().keys():
		choices.append(key)
	for key in hp_secondary_upgrades().keys():
		choices.append(key)

	choices.shuffle()

	pending_choice_1 = choices[0]
	pending_choice_2 = choices[1]
	pending_choice_3 = choices[2]

	btn1.text = pending_choice_1
	btn2.text = pending_choice_2
	btn3.text = pending_choice_3

	# ---------------------------------------
	# CENTER THE UI PERFECTLY
	# ---------------------------------------
	var screen = get_viewport().get_visible_rect().size

	ui.visible = true

	ui.position = screen * 0.5 - ui.size * 0.5   # exact center
	ui.position.y -= 200  # start slightly ABOVE center

	# ---------------------------------------
	# BOUNCE TO FINAL CENTER POSITION
	# ---------------------------------------
	var target_pos = screen * 0.5 - ui.size * 0.5

	var tw = create_tween()
	tw.tween_property(ui, "position", target_pos, 0.45)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	get_tree().paused = true
	title.text = "Choose Your Upgrade"


# -----------------------------------------------------------------------------------
# BUTTON PRESS ANIMATION + Apply Upgrade
# -----------------------------------------------------------------------------------
func _on_button_pressed(button: Button, index: int):

	# Button scale animation
	var t = create_tween()
	t.tween_property(button, "scale", Vector2(0.85, 0.85), 0.08)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(button, "scale", Vector2(1, 1), 0.12)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	await t.finished

	# Apply selected upgrade
	if index == 1:
		apply_upgrade(pending_choice_1)
	elif index == 2:
		apply_upgrade(pending_choice_2)
	elif index == 3:
		apply_upgrade(pending_choice_3)

# -----------------------------------------------------------------------------------
# APPLY + EXIT UI WITH BOUNCE
# -----------------------------------------------------------------------------------
func apply_upgrade(name: String):

	if name in UPGRADE_POOL:
		UPGRADE_POOL[name].call(player)
	elif name in speed_secondary_upgrades():
		speed_secondary_upgrades()[name].call(player)
	elif name in hp_secondary_upgrades():
		hp_secondary_upgrades()[name].call(player)

	# Bounce UI upward to hide
	var t = create_tween()
	t.tween_property(ui, "position:y", -400, 0.45)\
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)

	await t.finished

	ui.visible = false
	get_tree().paused = false
