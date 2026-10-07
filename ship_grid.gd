class_name ShipGrid
extends Node2D

enum BlockType { CORE, HULL, ENGINE, GUN, REACTOR, BATTERY }

const CELL := 28.0
const BUILD_RANGE := 8
const SAVE_PATH := "user://ship.json"

const DebrisScript := preload("res://debris.gd")

var blocks := {}            # Vector2i -> BlockType
var hp := {}                # Vector2i -> int
var turret_angles := {}     # Vector2i -> float (мировой угол ствола)
var build_mode := false
var selected: BlockType = BlockType.HULL
var hover_cell := Vector2i.ZERO
var hover_valid := false
var is_player := true
var focus_cell := Vector2i.ZERO
var focus_enabled := false

signal blocks_changed

func _ready() -> void:
	_set_block(Vector2i.ZERO, BlockType.CORE)

func max_hp(t) -> int:
	match t:
		BlockType.CORE: return 6
		BlockType.HULL: return 3
		BlockType.ENGINE: return 2
		BlockType.GUN: return 2
		BlockType.REACTOR: return 2
		BlockType.BATTERY: return 2
	return 1

func _set_block(cell: Vector2i, t) -> void:
	blocks[cell] = t
	hp[cell] = max_hp(t)

func _process(_delta: float) -> void:
	if build_mode:
		var local := to_local(get_global_mouse_position())
		hover_cell = Vector2i(roundi(local.x / CELL), roundi(local.y / CELL))
		hover_valid = not blocks.has(hover_cell) and has_neighbor(hover_cell)
		queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if not is_player:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_B: toggle_build_mode()
			KEY_1: selected = BlockType.HULL
			KEY_2: selected = BlockType.ENGINE
			KEY_3: selected = BlockType.GUN
			KEY_4: selected = BlockType.REACTOR
			KEY_5: selected = BlockType.BATTERY

	if build_mode and event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT: try_place(hover_cell)
			MOUSE_BUTTON_RIGHT: try_remove(hover_cell)

func toggle_build_mode() -> void:
	build_mode = !build_mode
	var ship := get_parent() as RigidBody2D
	ship.freeze = build_mode
	if build_mode:
		ship.linear_velocity = Vector2.ZERO
		ship.angular_velocity = 0.0
	else:
		save_ship()
	queue_redraw()

func try_place(cell: Vector2i) -> void:
	if not hover_valid:
		return
	_set_block(cell, selected)
	blocks_changed.emit()
	queue_redraw()

func try_remove(cell: Vector2i) -> void:
	if not blocks.has(cell) or blocks[cell] == BlockType.CORE:
		return
	hp.erase(cell)
	blocks.erase(cell)
	_split_off_disconnected()
	blocks_changed.emit()
	queue_redraw()

func damage(cell: Vector2i) -> void:
	if not blocks.has(cell):
		return
	hp[cell] = hp.get(cell, 1) - 1
	if hp[cell] > 0:
		queue_redraw()
		return
	if blocks[cell] == BlockType.CORE:
		_destroy_ship()
	else:
		try_remove(cell)

func _destroy_ship() -> void:
	var ship := get_parent() as RigidBody2D
	for c in blocks.keys():
		_detach_group({c: blocks[c]}, c, 220.0)
	blocks.clear()
	hp.clear()
	ship.queue_free()

func has_neighbor(cell: Vector2i) -> bool:
	return (
		blocks.has(cell + Vector2i(1, 0))
		or blocks.has(cell + Vector2i(-1, 0))
		or blocks.has(cell + Vector2i(0, 1))
		or blocks.has(cell + Vector2i(0, -1))
	)

func build_demo_ship() -> void:
	blocks.clear()
	hp.clear()
	_set_block(Vector2i.ZERO, BlockType.CORE)
	_set_block(Vector2i(0, -1), BlockType.GUN)
	_set_block(Vector2i(-1, 0), BlockType.HULL)
	_set_block(Vector2i(1, 0), BlockType.HULL)
	_set_block(Vector2i(0, 1), BlockType.HULL)
	_set_block(Vector2i(-1, 1), BlockType.ENGINE)
	_set_block(Vector2i(1, 1), BlockType.ENGINE)
	_set_block(Vector2i(0, 2), BlockType.REACTOR)
	_set_block(Vector2i(0, 3), BlockType.BATTERY)
	blocks_changed.emit()
	queue_redraw()

func _split_off_disconnected() -> void:
	var connected := _flood(Vector2i.ZERO, blocks)
	var remaining := {}
	for c in blocks:
		if not connected.has(c):
			remaining[c] = true
	while not remaining.is_empty():
		var origin: Vector2i = remaining.keys()[0]
		var group := _flood(origin, remaining)
		for c in group:
			remaining.erase(c)
		_detach_group(group, origin)

func _flood(start: Vector2i, source: Dictionary) -> Dictionary:
	var result := {}
	var stack := [start]
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if result.has(c) or not source.has(c):
			continue
		result[c] = true
		stack.append(c + Vector2i(1, 0))
		stack.append(c + Vector2i(-1, 0))
		stack.append(c + Vector2i(0, 1))
		stack.append(c + Vector2i(0, -1))
	return result

func _detach_group(group: Dictionary, origin: Vector2i, scatter := 0.0) -> void:
	var rel := {}
	for c in group:
		rel[c - origin] = blocks[c]
		blocks.erase(c)
		hp.erase(c)

	var ship := get_parent() as RigidBody2D
	if ship.get_parent() == null:
		return

	var d := RigidBody2D.new()
	d.set_script(DebrisScript)
	ship.get_parent().add_child(d)
	d.global_position = ship.to_global(Vector2(origin) * CELL)
	d.global_rotation = ship.global_rotation
	d.gravity_scale = 0.0

	var r := d.global_position - ship.global_position
	d.linear_velocity = ship.linear_velocity + Vector2(-r.y, r.x) * ship.angular_velocity
	d.angular_velocity = ship.angular_velocity
	if scatter > 0.0:
		d.linear_velocity += Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * randf_range(0.3, 1.0) * scatter
		d.angular_velocity += randf_range(-3.0, 3.0)
	d.init_blocks(rel)

func save_ship() -> void:
	var data := {}
	for cell in blocks:
		data["%d,%d" % [cell.x, cell.y]] = int(blocks[cell])
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))

func load_ship() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json: Variant = JSON.parse_string(f.get_as_text())
	if json == null:
		return false
	blocks.clear()
	hp.clear()
	for key in json:
		var parts := (key as String).split(",")
		_set_block(Vector2i(int(parts[0]), int(parts[1])), int(json[key]))
	blocks_changed.emit()
	queue_redraw()
	return true

func _draw() -> void:
	for cell in blocks:
		var rect := cell_rect(cell)
		var t = blocks[cell]
		var ratio := clampf(float(hp.get(cell, 1)) / float(max_hp(t)), 0.0, 1.0)
		draw_rect(rect, color_of(t).lerp(Color.BLACK, (1.0 - ratio) * 0.7))
		draw_rect(rect, Color(0, 0, 0, 0.55), false, 2.0)

	# стволы турелей
	var ship_rot: float = (get_parent() as Node2D).global_rotation
	for cell in blocks:
		if blocks[cell] == BlockType.GUN:
			var c := Vector2(cell) * CELL
			var a: float = turret_angles.get(cell, 0.0) - ship_rot
			var dir := Vector2.from_angle(a)
			draw_circle(c, CELL * 0.22, Color(0.55, 0.15, 0.15))
			draw_line(c, c + dir * CELL * 0.65, Color(0.15, 0.15, 0.15), 3.0)
	if focus_enabled:
		var c := Vector2(focus_cell) * CELL
		var col := Color(1.0, 0.2, 0.2)
		draw_arc(c, 10.0, 0.0, TAU, 16, col, 2.0)
		draw_line(c - Vector2(14, 0), c + Vector2(14, 0), col, 1.5)
		draw_line(c - Vector2(0, 14), c + Vector2(0, 14), col, 1.5)
	if build_mode:
		_draw_overlay()

func _draw_overlay() -> void:
	var c := Color(1, 1, 1, 0.10)
	for i in range(-BUILD_RANGE, BUILD_RANGE + 2):
		var p := i * CELL - CELL / 2
		draw_line(Vector2(p, -BUILD_RANGE * CELL), Vector2(p, BUILD_RANGE * CELL), c, 1.0)
		draw_line(Vector2(-BUILD_RANGE * CELL, p), Vector2(BUILD_RANGE * CELL, p), c, 1.0)
	var hr := cell_rect(hover_cell)
	if hover_valid:
		draw_rect(hr, Color(0.3, 1, 0.4, 0.25))
		draw_rect(hr, Color(0.3, 1, 0.4, 0.9), false, 2.0)
	else:
		draw_rect(hr, Color(1, 0.3, 0.3, 0.25))
		draw_rect(hr, Color(1, 0.3, 0.3, 0.9), false, 2.0)

func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(cell.x * CELL - CELL / 2, cell.y * CELL - CELL / 2, CELL, CELL)

static func color_of(t: BlockType) -> Color:
	match t:
		BlockType.CORE: return Color(0.95, 0.75, 0.2)
		BlockType.HULL: return Color(0.55, 0.58, 0.65)
		BlockType.ENGINE: return Color(0.25, 0.5, 1.0)
		BlockType.GUN: return Color(0.9, 0.3, 0.25)
		BlockType.REACTOR: return Color(0.4, 0.9, 0.4)
		BlockType.BATTERY: return Color(0.7, 0.4, 0.9)
	return Color.WHITE
