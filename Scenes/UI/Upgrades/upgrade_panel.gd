extends Node
class_name UpgradeManager

@onready var player = get_tree().get_first_node_in_group("player")

# The ENTIRE upgrade UI container
@onready var ui = $VBoxContainer

# Upgrade UI References INSIDE ui
@onready var panel = $VBoxContainer/Panel
@onready var title = $VBoxContainer/Label
@onready var btn1 = $VBoxContainer/option1
@onready var btn2 = $VBoxContainer/option2
@onready var btn3 = $VBoxContainer/option3

# Stores the upgrade choices
var pending_choice_1: String
var pending_choice_2: String
var pending_choice_3: String


# ---------------------------------------------------------
# READY → HIDE WHOLE UI ALWAYS
# ---------------------------------------------------------
func _ready():
	ui.visible = false     # Hide everything on game start

	btn1.pressed.connect(_on_option1)
	btn2.pressed.connect(_on_option2)
	btn3.pressed.connect(_on_option3)


# ---------------------------------------------------------
# UPGRADE DATASET
# ---------------------------------------------------------
var UPGRADES = {
	"Impact Boost": {
		"apply": func(p):
	p.knockback_force += 40
	p.dash_damage_bonus += 1
	},
	"Kinetic Surge": {
		"apply": func(p):
	p.bounce_multiplier += 0.15
	p.charge_damage_multiplier = 1.2
	},
	"Hyper Collision Core": {
		"apply": func(p):
	p.first_hit_bonus = 5
	p.bounce_damage_multiplier = 2.0
	},
	"Reactive Shielding": {
		"apply": func(p):
	p.shield_regen_rate = 0.1
	},
	"Overcharge Dampener": {
		"apply": func(p):
	p.overcharge_damage *= 0.5
	},
	"Phase Barrier": {
		"apply": func(p):
	p.dash_invincible_time = 0.2
	p.shield_refill_on_hit = true
	},
	"Vital Booster": {
		"apply": func(p):
	p.max_health += 2
	p.health = p.max_health
	},
	"Nanite Regeneration": {
		"apply": func(p):
	p.regen_rate = 0.25
	},
	"Bio-Overheal Engine": {
		"apply": func(p):
	p.max_overheal = 3
	p.overheal_bonus_damage = 2
	},
	"Velocity Tuner": {
		"apply": func(p):
	p.base_speed *= 1.2
	p.charge_rate *= 1.2
	},
	"Dash Streamlining": {
		"apply": func(p):
	p.dash_distance_multiplier = 1.1
	p.dash_cooldown_multiplier = 0.6
	},
	"Phantom Dash": {
		"apply": func(p):
	p.dash_invincible = true
	p.dash_phase_through = true
	p.dash_contact_damage = 1
	},
}


# ---------------------------------------------------------
# SHOW PANEL WHEN WAVE ENDS
# ---------------------------------------------------------
func show_upgrades():
	var keys = UPGRADES.keys()
	keys.shuffle()

	pending_choice_1 = keys[0]
	pending_choice_2 = keys[1]
	pending_choice_3 = keys[2]

	btn1.text = pending_choice_1
	btn2.text = pending_choice_2
	btn3.text = pending_choice_3

	ui.visible = true          # Show ENTIRE UI
	get_tree().paused = true   # Pause game

	title.text = "Choose Your Upgrade"


# ---------------------------------------------------------
# BUTTON CALLBACKS
# ---------------------------------------------------------
func _on_option1():
	apply_upgrade(pending_choice_1)

func _on_option2():
	apply_upgrade(pending_choice_2)

func _on_option3():
	apply_upgrade(pending_choice_3)


# ---------------------------------------------------------
# APPLY UPGRADE + HIDE UI + UNPAUSE
# ---------------------------------------------------------
func apply_upgrade(name: String):
	var data = UPGRADES[name]
	data["apply"].call(player)

	ui.visible = false         # Hide entire UI again
	get_tree().paused = false
