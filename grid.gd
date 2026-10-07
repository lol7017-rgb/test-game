extends Node2D

var step := 100
var half_size := 5000

func _draw() -> void:
	var color := Color(0.2, 0.22, 0.28)
	for x in range(-half_size, half_size + 1, step):
		draw_line(Vector2(x, -half_size), Vector2(x, half_size), color, 1.0)
	for y in range(-half_size, half_size + 1, step):
		draw_line(Vector2(-half_size, y), Vector2(half_size, y), color, 1.0)
