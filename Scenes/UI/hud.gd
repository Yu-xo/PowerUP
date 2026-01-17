extends CanvasLayer

var hp_display = 0.0:
	get(): return $Control/HP.value
	set(value): $Control/HP.value = value
var shield_display = 0.0:
	get(): return $Control/Shield.value
	set(value): $Control/Shield.value = value
var charge_display = 0.0:
	get(): return $Control/charge.value
	set(value): 
		$Control/charge.value = value
		$Control/charge.modulate = Color.GREEN.lerp(Color.RED, value / 10.0)
