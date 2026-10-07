extends RigidBody2D

const BULLET_SPEED := 700.0

@export var engine_power := 400.0
@export var turn_power := 3000.0
@export var block_mass := 1.0
@export var is_player := true
@export var fire_rate := 2.0
@export var turret_turn_speed := 3.0
@export var turret_range := 900.0

@export var base_capacity := 10.0
@export var battery_capacity := 25.0
@export var reactor_rate := 12.0
@export var engine_drain := 8.0
@export var gun_shot_cost := 6.0

@onready var grid: ShipGrid = $BlockGrid

var _block_shape: RectangleShape2D
var _fire_cooldown := 0.0
var _ai_cooldown := 0.0
var _bullet_scene := preload("res://bullet.tscn")

var energy := 10.0
var max_energy := 10.0
var energy_regen := 0.0
var _engines := 0
var _guns := 0

var focus_target: Node2D = null
var focus_cell := Vector2i.ZERO

func _ready() -> void:
	_block_shape = RectangleShape2D.new()
	_block_shape.size = Vector2(ShipGrid.CELL, ShipGrid.CELL)
	grid.is_player = is_player
	grid.blocks_changed.connect(_on_blocks_changed)
	$HUD.palette_pressed.connect(_on_palette)
	if is_player:
		add_to_group("player")
		grid.load_ship()
	else:
		add_to_group("enemy")
		$HUD.visible = false
	$Camera2D.enabled = is_player
	_on_blocks_changed()

func _on_palette(t) -> void:
	grid.selected = t
	if not grid.build_mode:
		grid.toggle_build_mode()

func _on_blocks_changed() -> void:
	_recalc_stats()
	_rebuild_collision.call_deferred()

func _recalc_stats() -> void:
	mass = maxf(grid.blocks.size() * block_mass, 0.1)
	_engines = 0
	_guns = 0
	var reactors := 0
	var batteries := 0
	for cell in grid.blocks:
		match grid.blocks[cell]:
			ShipGrid.BlockType.ENGINE: _engines += 1
			ShipGrid.BlockType.GUN: _guns += 1
			ShipGrid.BlockType.REACTOR: reactors += 1
			ShipGrid.BlockType.BATTERY: batteries += 1
	max_energy = base_capacity + batteries * battery_capacity
	energy_regen = reactors * reactor_rate
	energy = minf(energy, max_energy)

func _rebuild_collision() -> void:
	var old := []
	for child in get_children():
		if child is CollisionShape2D and child.name.begins_with("BlockCol_"):
			old.append(child)
	for node in old:
		node.free()
	for cell in grid.blocks:
		var col := CollisionShape2D.new()
		col.shape = _block_shape
		col.position = Vector2(cell) * ShipGrid.CELL
		col.name = "BlockCol_%d_%d" % [cell.x, cell.y]
		add_child(col)

func _unhandled_input(event: InputEvent) -> void:
	if not is_player or grid.build_mode:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click := get_global_mouse_position()
		for n in get_tree().get_nodes_in_group("enemy"):
			var enemy: Node2D = n
			var tgrid := enemy.get_node("BlockGrid") as ShipGrid
			var local := enemy.to_local(click)
			var cell := Vector2i(roundi(local.x / ShipGrid.CELL), roundi(local.y / ShipGrid.CELL))
			if tgrid.blocks.has(cell):
				_set_focus(enemy, cell)
				return
		_clear_focus()

func _physics_process(delta: float) -> void:
	if is_player:
		$HUD.set_energy(energy, max_energy)
		$HUD.set_build_mode(grid.build_mode)
		$HUD.set_selected(grid.selected)
	if grid.build_mode:
		return

	energy = minf(energy + energy_regen * delta, max_energy)
	_check_focus()
	var target := _find_target()
	var aim_target: Node2D = focus_target if focus_target != null else target
	_update_turrets(delta, aim_target)
	if is_player:
		_player_control(delta, aim_target)
	else:
		_ai_control(delta, aim_target)

func _find_target() -> Node2D:
	var group := "enemy" if is_player else "player"
	var best: Node2D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(group):
		var node: Node2D = n
		var d := node.global_position.distance_squared_to(global_position)
		if d < best_d:
			best_d = d
			best = node
	return best

# ===== Фокус-огонь =====

func _set_focus(enemy: Node2D, cell: Vector2i) -> void:
	_clear_focus()
	focus_target = enemy
	focus_cell = cell
	var tgrid := enemy.get_node("BlockGrid") as ShipGrid
	tgrid.focus_enabled = true
	tgrid.focus_cell = cell
	tgrid.queue_redraw()

func _clear_focus() -> void:
	if is_instance_valid(focus_target):
		var tgrid := focus_target.get_node_or_null("BlockGrid") as ShipGrid
		if tgrid:
			tgrid.focus_enabled = false
			tgrid.queue_redraw()
	focus_target = null

func _check_focus() -> void:
	if focus_target == null:
		return
	if not is_instance_valid(focus_target):
		focus_target = null
		return
	var tgrid := focus_target.get_node("BlockGrid") as ShipGrid
	if not tgrid.blocks.has(focus_cell):
		_clear_focus()

# ===== Упреждение =====

func _aim_point(target: Node2D) -> Vector2:
	if focus_target == target:
		var tgrid := target.get_node("BlockGrid") as ShipGrid
		if tgrid.blocks.has(focus_cell):
			return target.to_global(Vector2(focus_cell) * ShipGrid.CELL)
	return target.global_position

func _point_velocity(target: Node2D, point: Vector2) -> Vector2:
	var r := point - target.global_position
	return target.linear_velocity + Vector2(-r.y, r.x) * target.angular_velocity

func _predict(pos: Vector2, vel: Vector2, from: Vector2, from_vel: Vector2) -> Vector2:
	var aim := pos
	for i in 3:
		var to := aim - from
		var bv := to.normalized() * BULLET_SPEED + from_vel
		var s := bv.length()
		if s <= 1.0:
			break
		aim = pos + vel * (to.length() / s)
	return aim

# ===== Турели =====

func _update_turrets(delta: float, target: Node2D) -> void:
	var guns := []
	for cell in grid.blocks:
		if grid.blocks[cell] == ShipGrid.BlockType.GUN:
			guns.append(cell)
			if not grid.turret_angles.has(cell):
				grid.turret_angles[cell] = global_rotation
	for key in grid.turret_angles.keys():
		if not guns.has(key):
			grid.turret_angles.erase(key)
	if target == null:
		return
	var aim_base := _aim_point(target)
	var aim_vel := _point_velocity(target, aim_base)
	for cell in guns:
		var world_pos := to_global(Vector2(cell) * ShipGrid.CELL)
		var predicted := _predict(aim_base, aim_vel, world_pos, linear_velocity)
		var desired := (predicted - world_pos).angle()
		var diff := wrapf(desired - grid.turret_angles[cell], -PI, PI)
		grid.turret_angles[cell] += clampf(diff, -turret_turn_speed * delta, turret_turn_speed * delta)
	grid.queue_redraw()

# ===== Управление =====

func _player_control(delta: float, target: Node2D) -> void:
	var turn := Input.get_axis("ui_left", "ui_right")
	apply_torque(turn * turn_power * mass)

	if Input.is_action_pressed("ui_up"):
		var cost := _engines * engine_drain * delta
		if _engines > 0 and energy >= cost:
			energy -= cost
			_apply_engines(1.0)

	_fire_cooldown -= delta
	var want_fire := Input.is_action_pressed("ui_accept") or focus_target != null
	if want_fire and _fire_cooldown <= 0.0:
		if _try_fire(target):
			_fire_cooldown = 1.0 / fire_rate

func _try_fire(target: Node2D) -> bool:
	if target == null:
		return false
	var aim_base := _aim_point(target)
	var aim_vel := _point_velocity(target, aim_base)
	var fired := false
	for cell in grid.blocks:
		if grid.blocks[cell] != ShipGrid.BlockType.GUN:
			continue
		if energy < gun_shot_cost:
			break
		var world_pos := to_global(Vector2(cell) * ShipGrid.CELL)
		var predicted := _predict(aim_base, aim_vel, world_pos, linear_velocity)
		if (predicted - world_pos).length() > turret_range:
			continue
		var a: float = grid.turret_angles.get(cell, global_rotation)
		var desired := (predicted - world_pos).angle()
		if abs(wrapf(desired - a, -PI, PI)) > 0.1:
			continue
		energy -= gun_shot_cost
		var dir := Vector2.from_angle(a)
		var b := _bullet_scene.instantiate()
		get_parent().add_child(b)
		b.global_position = world_pos + dir * ShipGrid.CELL
		b.velocity = dir * BULLET_SPEED + linear_velocity
		b.shooter = self
		if not is_player:
			b.modulate = Color(1.0, 0.4, 0.4)
		fired = true
	return fired

func _apply_engines(throttle: float) -> void:
	var forward := Vector2.UP.rotated(rotation)
	var total_force := Vector2.ZERO
	var total_torque := 0.0
	for cell in grid.blocks:
		if grid.blocks[cell] == ShipGrid.BlockType.ENGINE:
			var r := (Vector2(cell) * ShipGrid.CELL).rotated(rotation)
			var f := forward * engine_power * throttle
			total_force += f
			total_torque += r.cross(f)
	apply_central_force(total_force)
	apply_torque(total_torque)

func _ai_control(delta: float, target: Node2D) -> void:
	if target == null:
		return
	var tgrid := target.get_node("BlockGrid") as ShipGrid
	if tgrid.build_mode:
		return

	var to_target := target.global_position - global_position
	var dist := to_target.length()
	var dir := to_target.normalized()

	var target_angle := dir.angle() + PI / 2.0
	var angle_diff := wrapf(target_angle - rotation, -PI, PI)
	var control := clampf(angle_diff * 3.0 - angular_velocity * 1.0, -1.0, 1.0)
	apply_torque(control * turn_power * mass)

	var desired_vel := Vector2.ZERO
	if dist > 500.0:
		desired_vel = dir * 220.0
	elif dist < 250.0:
		desired_vel = -dir * 180.0
	else:
		desired_vel = dir.rotated(PI / 2.0) * 150.0
	apply_central_force((desired_vel - linear_velocity) * mass * 2.0)

	_ai_cooldown -= delta
	if _ai_cooldown <= 0.0:
		if _try_fire(target):
			_ai_cooldown = 1.0 / fire_rate
		else:
			_ai_cooldown = 0.1

# ===== Урон =====

func hit_at(global_pos: Vector2) -> void:
	var local := to_local(global_pos)
	var center := local / ShipGrid.CELL
	var base := Vector2i(roundi(center.x), roundi(center.y))
	var best := Vector2i.ZERO
	var best_d := INF
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var c := base + Vector2i(dx, dy)
			if grid.blocks.has(c):
				var d := (Vector2(c) - center).length_squared()
				if d < best_d:
					best_d = d
					best = c
	if best_d <= 0.5:
		grid.damage.call_deferred(best)
