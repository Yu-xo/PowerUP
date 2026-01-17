extends Node2D

@export var fade_time := 0.1

func start(sprite_texture, global_pos, global_rot):
	global_position = global_pos
	rotation = global_rot

	var s: Sprite2D = $Sprite2D
	s.texture = sprite_texture
	modulate = Color(1.0, 1.0, 1.0, 0.8)

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, fade_time)
	tween.tween_callback(Callable(self, "queue_free"))
