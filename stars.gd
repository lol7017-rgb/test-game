extends Node2D

func _draw() -> void:
	for i in 80:
		var pos := Vector2(randf_range(0, 1000), randf_range(0, 1000))
		var r := randf_range(0.5, 1.8)
		draw_circle(pos, r, Color(1, 1, 1, randf_range(0.3, 1.0)))
