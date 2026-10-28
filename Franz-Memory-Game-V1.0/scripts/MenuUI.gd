extends RefCounted

static var _texts: Dictionary = {}
static var _style: Dictionary = {}

static func _read_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

static func text(key: String) -> String:
	if _texts.is_empty():
		_texts = _read_dictionary("res://data/ui_text.json")
	return str(_texts.get(key, key))

static func color(key: String, fallback: String) -> Color:
	if _style.is_empty():
		_style = _read_dictionary("res://data/ui_style.json")
	return Color(str(_style.get(key, fallback)))

static func background() -> Color:
	return color("background", "#0b0d10d1")

static func panel() -> StyleBox:
	return _box(color("panel", "#191b20d9"), 18)

static func _box(fill: Color, radius: int = 16) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = color("border", "#888d9659")
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	return box

static func _button_style(state: String, base: Color) -> StyleBox:
	var path := str(_style.get("button_" + state + "_texture", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var texture = load(path)
		if texture is Texture2D:
			var box := StyleBoxTexture.new()
			box.texture = texture
			return box
	if state == "hover":
		return _box(base.lightened(0.12))
	if state == "pressed":
		return _box(base.darkened(0.12))
	return _box(base)

static func button(label: String, height: int = 72, accent: bool = false) -> Button:
	if _style.is_empty():
		_style = _read_dictionary("res://data/ui_style.json")
	var base := color("accent" if accent else "button", "#2a2d33dc")
	var control := Button.new()
	control.text = label
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.custom_minimum_size.y = height
	control.add_theme_font_size_override("font_size", 22)
	control.add_theme_color_override("font_color", color("text", "#f5f7f8"))
	control.add_theme_stylebox_override("normal", _button_style("normal", base))
	control.add_theme_stylebox_override("hover", _button_style("hover", base))
	control.add_theme_stylebox_override("pressed", _button_style("pressed", base))
	control.add_theme_stylebox_override("focus", _box(Color(1, 1, 1, 0.1)))
	return control

static func label(value: String, size: int = 20) -> Label:
	var control := Label.new()
	control.text = value
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", color("text", "#f5f7f8"))
	return control

static func art_button(label: String, art_key: String, height: int = 96) -> Button:
	if _style.is_empty():
		_style = _read_dictionary("res://data/ui_style.json")
	var art_paths = _style.get("art_buttons", {})
	var path := str(art_paths.get(art_key, "")) if art_paths is Dictionary else ""
	if path.is_empty() or not ResourceLoader.exists(path):
		return button(label, height)
	var texture = load(path)
	if not texture is Texture2D:
		return button(label, height)
	var control := button("", height)
	var intended_scale := maxi(1, floori(float(height) / float(texture.get_height())))
	control.custom_minimum_size.x = texture.get_width() * intended_scale
	control.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	control.tooltip_text = label
	for state in ["normal", "hover", "pressed"]:
		control.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(image)
	control.resized.connect(func(): _layout_art(control, image, texture))
	control.mouse_entered.connect(func(): image.modulate = Color(1.12, 1.12, 1.12))
	control.mouse_exited.connect(func(): image.modulate = Color.WHITE)
	return control

static func _layout_art(control: Button, image: TextureRect, texture: Texture2D) -> void:
	if control.size.x <= 0.0 or control.size.y <= 0.0:
		return
	var factor := maxi(1, floori(minf(control.size.x / texture.get_width(), control.size.y / texture.get_height())))
	image.size = Vector2(texture.get_width() * factor, texture.get_height() * factor)
	image.position = (control.size - image.size) / 2.0

static func connect_animated(control: Button, action: Callable) -> void:
	control.pressed.connect(func(): _animate_then_call(control, action))

static func _animate_then_call(control: Button, action: Callable) -> void:
	if control.get_meta("animating", false):
		return
	control.set_meta("animating", true)
	control.pivot_offset = control.size / 2.0
	var tween := control.create_tween()
	tween.tween_property(control, "scale", Vector2(0.90, 0.90), 0.08).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(control, "scale", Vector2(1.04, 1.04), 0.09).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(control, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_QUAD)
	await tween.finished
	if is_instance_valid(control) and control.is_inside_tree():
		control.set_meta("animating", false)
		action.call()
