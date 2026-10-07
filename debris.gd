extends RigidBody2D

var blocks := {}
var life := 10.0
var _shape: RectangleShape2D

func init_blocks(data: Dictionary) -> void:
	blocks = data
	_shape = RectangleShape2D.new()
	_shape.size = Vector2(ShipGrid.CELL, ShipGrid.CELL)
	for cell in blocks:
		var col := CollisionShape2D.new()
		col.shape = _shape
		col.position = Vector2(cell) * ShipGrid.CELL
		add_child(col)
	mass = maxf(blocks.size() * 0.5, 0.1)
	queue_redraw()

func _physics_process(delta: float) -> void:
	life -= delta
	if life < 1.0:
		modulate.a = clampf(life, 0.0, 1.0)
	if life <= 0.0:
		queue_free()

func _draw() -> void:
	for cell in blocks:
		var rect := Rect2(
			Vector2(cell) * ShipGrid.CELL - Vector2(ShipGrid.CELL, ShipGrid.CELL) / 2.0,
			Vector2(ShipGrid.CELL, ShipGrid.CELL)
		)
		draw_rect(rect, _color_of(blocks[cell]))
		draw_rect(rect, Color(0, 0, 0, 0.55), false, 2.0)

func _color_of(t) -> Color:
	match t:
		ShipGrid.BlockType.CORE: return Color(0.95, 0.75, 0.2)
		ShipGrid.BlockType.HULL: return Color(0.55, 0.58, 0.65)
		ShipGrid.BlockType.ENGINE: return Color(0.25, 0.5, 1.0)
		ShipGrid.BlockType.GUN: return Color(0.9, 0.3, 0.25)
	return Color.WHITE
