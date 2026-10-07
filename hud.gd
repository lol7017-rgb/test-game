extends CanvasLayer

signal palette_pressed(type)

var _bar: ProgressBar
var _energy_label: Label
var _build_banner: Label
var _buttons := {}

const NAMES := {
	1: "Корпус",
	2: "Двигатель",
	3: "Турель",
	4: "Реактор",
	5: "Батарея",
}

func _ready() -> void:
	_bar = ProgressBar.new()
	_bar.position = Vector2(12, 12)
	_bar.size = Vector2(260, 18)
	_bar.show_percentage = false
	add_child(_bar)

	_energy_label = Label.new()
	_energy_label.position = Vector2(14, 34)
	_energy_label.add_theme_font_size_override("font_size", 13)
	add_child(_energy_label)

	_build_banner = Label.new()
	_build_banner.text = ">> РЕЖИМ ПОСТРОЙКИ <<   ЛКМ - поставить, ПКМ - убрать"
	_build_banner.position = Vector2(12, 58)
	_build_banner.add_theme_font_size_override("font_size", 15)
	_build_banner.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	_build_banner.visible = false
	add_child(_build_banner)

	var types := [
		ShipGrid.BlockType.HULL, ShipGrid.BlockType.ENGINE, ShipGrid.BlockType.GUN,
		ShipGrid.BlockType.REACTOR, ShipGrid.BlockType.BATTERY
	]
	var keys := ["1", "2", "3", "4", "5"]
	var y := 96.0
	for i in types.size():
		var t = types[i]
		var btn := Button.new()
		btn.text = keys[i] + "  " + NAMES[t]
		btn.position = Vector2(12, y)
		btn.size = Vector2(150, 26)
		btn.self_modulate = ShipGrid.color_of(t).lerp(Color.WHITE, 0.2)
		btn.pressed.connect(_on_btn.bind(t))
		add_child(btn)
		_buttons[t] = btn
		y += 30.0

	var hint := Label.new()
	hint.text = "стрелки - полет   ПРОБЕЛ - залп   B - постройка   ЛКМ по врагу - фокус-огонь   колесо - зум"
	hint.position = Vector2(12, y + 12)
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(hint)

func _on_btn(t) -> void:
	palette_pressed.emit(t)

func set_energy(cur: float, maxv: float) -> void:
	if maxv <= 0.0:
		return
	_bar.value = cur / maxv * 100.0
	_energy_label.text = "Энергия: %d / %d" % [roundi(cur), roundi(maxv)]
	if cur / maxv < 0.25:
		_bar.modulate = Color(1.0, 0.4, 0.4)
	else:
		_bar.modulate = Color(0.4, 0.9, 1.0)

func set_build_mode(on: bool) -> void:
	_build_banner.visible = on

func set_selected(t) -> void:
	for key in _buttons:
		var btn: Button = _buttons[key]
		if key == t:
			btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
		else:
			btn.remove_theme_color_override("font_color")
