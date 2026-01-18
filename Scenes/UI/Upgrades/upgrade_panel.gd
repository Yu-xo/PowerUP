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

# Tier selection tracking
var has_speed_upgrade := false
var has_hp_upgrade := false

func _ready():
	ui.visible = false
	btn1.pressed.connect(_on_option1)
	btn2.pressed.connect(_on_option2)
	btn3.pressed.connect(_on_option3)

# -----------------------------------------------------------------------------------
# MAIN TIER 1 UPGRADES (always appear until chosen)
# -----------------------------------------------------------------------------------
var UPGRADE_POOL = {
	"Speed Boost": func(p):
	p.base_speed += 20
	has_speed_upgrade = true
,
	"Shrink Body": func(p):
	p.scale -= Vector2(0.5,0.5)
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
# TIER 2 SPEED BRANCH
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
# TIER 2 HP BRANCH
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
# SHOW UPGRADE PANEL
# -----------------------------------------------------------------------------------
func show_upgrades():

	var choices = []

	# TIER 1 choices (if not taken)
	if not has_speed_upgrade:
		choices.append("Speed Boost")
	if not has_hp_upgrade:
		choices.append("Max HP +1")

	choices.append("Shrink Body")
	choices.append("Max Charge +1")

	# TIER 2 unlocks
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

	ui.visible = true
	get_tree().paused = true
	title.text = "Choose Your Upgrade"

# -----------------------------------------------------------------------------------
# APPLY UPGRADE
# -----------------------------------------------------------------------------------
func apply_upgrade(name: String):

	if name in UPGRADE_POOL:
		UPGRADE_POOL[name].call(player)

	elif name in speed_secondary_upgrades():
		speed_secondary_upgrades()[name].call(player)

	elif name in hp_secondary_upgrades():
		hp_secondary_upgrades()[name].call(player)

	ui.visible = false
	get_tree().paused = false

func _on_option1(): apply_upgrade(pending_choice_1)
func _on_option2(): apply_upgrade(pending_choice_2)
func _on_option3(): apply_upgrade(pending_choice_3)
