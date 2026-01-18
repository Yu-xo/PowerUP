extends CanvasLayer

@onready var hp: ProgressBar = $Control/HP
@onready var hp_label: Label = $Control/HP/Label
@onready var charge: ProgressBar = $Control/charge
@onready var root: Control = $Control        # for shake
@onready var flash: ColorRect = $Control/ColorRect    # white flash overlay

var hp_tween: Tween
var shake_tween: Tween
var flash_tween: Tween

# ---------------------------------------------------------
# PUBLIC API (called from Player)
# ---------------------------------------------------------

func set_hp(value: float, max_hp: float, damaged: bool = false):
	hp.max_value = max_hp

	# Smooth bar animation
	if hp_tween:
		hp_tween.kill()
	hp_tween = create_tween()
	hp_tween.tween_property(hp, "value", value, 0.15)\
		.set_trans(Tween.TRANS_SINE)

	hp_label.text = str(int(value)) + "/" + str(int(max_hp))

	if damaged:
		shake_hp_bar()
		hit_flash()

func set_charge(value: float, max_charge: float, is_overcharging: bool = false):
	charge.max_value = max_charge
	charge.value = value

	if is_overcharging:
		charge.modulate = Color(1.0, 0.5, 0.5)     # reddish tint
	else:
		charge.modulate = Color(1.0, 1.0, 1.0)     # normal


# ---------------------------------------------------------
# SCREEN SHAKE FOR HP DAMAGE
# ---------------------------------------------------------
func shake_hp_bar():
	if shake_tween:
		shake_tween.kill()

	shake_tween = create_tween()

	# quick shake left-right
	shake_tween.tween_property(root, "position", Vector2(6, 0), 0.05)
	shake_tween.tween_property(root, "position", Vector2(-4, 0), 0.05)
	shake_tween.tween_property(root, "position", Vector2(0, 0), 0.05)


# ---------------------------------------------------------
# WHITE FLASH HIT EFFECT
# ---------------------------------------------------------
func hit_flash():
	flash.visible = true
	flash.modulate.a = 0.6

	if flash_tween:
		flash_tween.kill()

	flash_tween = create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.20)\
		.set_trans(Tween.TRANS_SINE)
	flash_tween.tween_callback(func(): flash.visible = false)
