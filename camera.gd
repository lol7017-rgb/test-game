extends Camera2D

@export var zoom_min := 0.4
@export var zoom_max := 2.5
@export var zoom_smooth := 10.0

var target_zoom := 1.0

func _ready() -> void:
	target_zoom = zoom.x

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom *= 1.1
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom /= 1.1
		target_zoom = clampf(target_zoom, zoom_min, zoom_max)

func _process(delta: float) -> void:
	var z := lerpf(zoom.x, target_zoom, clampf(zoom_smooth * delta, 0.0, 1.0))
	zoom = Vector2(z, z)
