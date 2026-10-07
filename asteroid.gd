extends StaticBody2D

var hp := 3

func hit_at(_global_pos: Vector2) -> void:
	hp -= 1
	scale *= 0.85
	if hp <= 0:
		queue_free()
