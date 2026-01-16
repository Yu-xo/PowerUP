extends Node
class_name DamageManager

signal damaged(target, amount)
signal died(target)
signal knocked_back(target, force)

func apply_damage(target: Node, amount: int):
	if target == null:
		return

	if target:
		target.health -= amount
		emit_signal("damaged", target, amount)

		if target.has_method("on_hit"):
			target.on_hit(amount)

		if target.health <= 0:
			if target.has_method("die"):
				target.die()
			emit_signal("died", target)

func apply_knockback(target: Node, force: Vector2):
	if target == null:
		return

	if target.has_method("apply_knockback"):
		target.apply_knockback(force)
		emit_signal("knocked_back", target, force)
