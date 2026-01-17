extends CanvasLayer

var hp_display = 0.0:
	get(): return $Control/HP.value
	set(value): $Control/HP.value = value
var charge_display = 0.0:
	get(): return $Control/charge.value
	set(value): $Control/charge.value = value
