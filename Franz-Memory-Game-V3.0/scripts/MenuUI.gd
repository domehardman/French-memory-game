extends RefCounted
## Alles, was das Menü und die Anzeige im Spiel gemeinsam brauchen: Texte aus
## data/ui_text.json, Bilder und Farben aus data/ui_style.json, die Pixel-Buttons
## und das Pixel-Theme (Schrift, Rahmen, Regler, Schalter, Eingabefelder).

const PixelFont = preload("res://scripts/PixelFont.gd")

static var _texts: Dictionary = {}
static var _style: Dictionary = {}
static var _theme: Theme

static func _read_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

static func _load_style() -> void:
	if _style.is_empty():
		_style = _read_dictionary("res://data/ui_style.json")

static func text(key: String) -> String:
	if _texts.is_empty():
		_texts = _read_dictionary("res://data/ui_text.json")
	return str(_texts.get(key, key))

static func color(key: String, fallback: String) -> Color:
	_load_style()
	return Color(str(_style.get(key, fallback)))

static func background() -> Color:
	return color("background", "#1d1740")

# --- Pixel-Theme ------------------------------------------------------------------
# Gilt für das ganze Spiel (wird in GameSettings auf das Fenster gesetzt).
# Rahmen, Regler und Schalter werden hier aus Pixeln gebaut. Wer eigene Bilder will:
# in ui_style.json unter "frames" eintragen, z. B. "panel": "res://assets/ui/rahmen.png"
# (Rahmenbild mit 3 Pixel Rand, wird 2× vergrössert).

const PX := 2   # jedes Pixel der Rahmen ist 2×2 Bildschirmpixel gross

static func font_size(requested: int) -> int:
	# Die Pixel-Schrift gibt es nur in ganzen Grössen: 18 (normal), 27 (Titel), 36 (gross)
	if requested >= 33:
		return PixelFont.size(4)
	if requested >= 23:
		return PixelFont.size(3)
	return PixelFont.size(2)

static func theme() -> Theme:
	if _theme != null:
		return _theme
	_load_style()
	var t := Theme.new()
	var ink := color("text", "#f5f7f8")
	var dim := Color(ink, 0.55)
	t.default_font = PixelFont.font()
	t.default_font_size = PixelFont.size(2)
	# Texte: heller Text mit Pixel-Schatten
	t.set_color("font_color", "Label", ink)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.85))
	t.set_constant("shadow_offset_x", "Label", PX)
	t.set_constant("shadow_offset_y", "Label", PX)
	t.set_constant("line_spacing", "Label", 4)
	# Rahmen
	t.set_stylebox("panel", "PanelContainer", frame("panel"))
	t.set_stylebox("panel", "Panel", frame("panel"))
	# Eingabefelder
	for state in ["normal", "focus", "read_only"]:
		t.set_stylebox(state, "LineEdit", frame("input_focus" if state == "focus" else "input"))
	t.set_color("font_color", "LineEdit", ink)
	t.set_color("font_placeholder_color", "LineEdit", dim)
	t.set_color("caret_color", "LineEdit", ink)
	t.set_color("selection_color", "LineEdit", Color(0.35, 0.6, 1.0, 0.45))
	t.set_constant("caret_width", "LineEdit", PX)
	# Schalter (Ein/Aus)
	t.set_icon("checked", "CheckButton", _icon("switch_on"))
	t.set_icon("unchecked", "CheckButton", _icon("switch_off"))
	t.set_icon("checked_disabled", "CheckButton", _icon("switch_on"))
	t.set_icon("unchecked_disabled", "CheckButton", _icon("switch_off"))
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		t.set_stylebox(state, "CheckButton", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		t.set_color(c, "CheckButton", ink)
	# Regler
	t.set_stylebox("slider", "HSlider", frame("track"))
	t.set_stylebox("grabber_area", "HSlider", frame("track_fill"))
	t.set_stylebox("grabber_area_highlight", "HSlider", frame("track_fill"))
	t.set_icon("grabber", "HSlider", _icon("knob"))
	t.set_icon("grabber_highlight", "HSlider", _icon("knob_hover"))
	t.set_icon("grabber_disabled", "HSlider", _icon("knob"))
	# Auswahl-Liste (OptionButton) und ihr Menü
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(state, "OptionButton", frame("option_hover" if state == "hover" else "option"))
	t.set_icon("arrow", "OptionButton", _icon("arrow"))
	t.set_constant("arrow_margin", "OptionButton", 4 * PX)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "OptionButton", ink)
	t.set_stylebox("panel", "PopupMenu", frame("panel"))
	t.set_stylebox("hover", "PopupMenu", frame("popup_hover"))
	t.set_color("font_color", "PopupMenu", ink)
	t.set_color("font_hover_color", "PopupMenu", Color("#240553"))
	t.set_icon("radio_checked", "PopupMenu", _icon("dot"))
	t.set_icon("radio_unchecked", "PopupMenu", _icon("empty"))
	# Fortschrittsbalken
	t.set_stylebox("background", "ProgressBar", frame("track"))
	t.set_stylebox("fill", "ProgressBar", frame("bar_fill"))
	# Bildlaufleisten
	for bar_type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar_type, frame("scroll"))
		t.set_stylebox("scroll_focus", bar_type, frame("scroll"))
		t.set_stylebox("grabber", bar_type, frame("grabber"))
		t.set_stylebox("grabber_highlight", bar_type, frame("grabber_hover"))
		t.set_stylebox("grabber_pressed", bar_type, frame("grabber_hover"))
	# Tooltips
	t.set_stylebox("panel", "TooltipPanel", frame("panel"))
	t.set_color("font_color", "TooltipLabel", ink)
	_theme = t
	return t

# Farben der Rahmen: [Füllung, Licht (oben/links), Schatten (unten/rechts), Umriss]
const FRAMES := {
	"panel": ["#2b2560f0", "#8b7bff", "#1a1545", "#07051a"],
	"input": ["#140f33", "#0b0822", "#5d50d6", "#07051a"],
	"input_focus": ["#140f33", "#0b0822", "#4dd1dd", "#07051a"],
	"track": ["#140f33", "#0b0822", "#4a3fb8", "#07051a"],
	"track_fill": ["#4caf6a", "#8fe0a0", "#2e7a45", "#07051a"],
	"bar_fill": ["#4caf6a", "#8fe0a0", "#2e7a45", "#07051a"],
	"option": ["#3b3290", "#8b7bff", "#211b5c", "#07051a"],
	"option_hover": ["#4a3fb8", "#a99bff", "#2a2370", "#07051a"],
	"popup_hover": ["#4dd1dd", "#d2f9fa", "#28adcf", "#07051a"],
	"scroll": ["#140f33", "#0b0822", "#3b3290", "#07051a"],
	"grabber": ["#f48d8a", "#ffb6a5", "#c4398b", "#07051a"],
	"grabber_hover": ["#ffb6a5", "#ffe0d8", "#dc5d86", "#07051a"],
}

# Farben für Titel, Abschnitte und Kategorien (aus den Button-Bildern)
const TITLE_COLOR := Color("#ffd75e")
const SECTION_COLOR := Color("#f7ac38")
const BUTTON_COLORS := {"red": "#ff8a8f", "blue": "#7ee6ef", "orange": "#ffc45e", "pink": "#ffb0ad", "green": "#9be86b"}

static func accent(color_name: String) -> Color:
	return Color(str(BUTTON_COLORS.get(color_name, "#f5f7f8")))

# Hintergrund des Menüs: Indigo mit feinem Pixel-Muster (kachelt)
static func background_texture() -> Texture2D:
	var base := background()
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(base)
	var dot := base.lightened(0.07)
	for p in [Vector2i(1, 1), Vector2i(5, 5)]:
		img.set_pixelv(p, dot)
	img.set_pixelv(Vector2i(5, 1), base.darkened(0.15))
	img.set_pixelv(Vector2i(1, 5), base.darkened(0.15))
	img.resize(16, 16, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

# Pixel-Rahmen als StyleBox (3 Pixel Rand, Ecken abgeschnitten)
static func frame(kind: String, fill_override: Color = Color(0, 0, 0, 0)) -> StyleBox:
	_load_style()
	var custom = _style.get("frames", {})
	if custom is Dictionary and custom.has(kind) and ResourceLoader.exists(str(custom[kind])):
		var tex: Texture2D = load(str(custom[kind]))
		var img := tex.get_image()
		img.decompress()
		img.resize(img.get_width() * PX, img.get_height() * PX, Image.INTERPOLATE_NEAREST)
		return _texture_box(ImageTexture.create_from_image(img), 3)
	var c: Array = FRAMES.get(kind, FRAMES["panel"])
	var fill := Color(c[0]) if fill_override.a == 0.0 else fill_override
	return _frame_box(fill, Color(c[1]), Color(c[2]), Color(c[3]))

static func _frame_box(fill: Color, light: Color, shade: Color, outline: Color) -> StyleBoxTexture:
	var n := 8
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in range(n):
		for x in range(n):
			var edge := mini(mini(x, y), mini(n - 1 - x, n - 1 - y))
			var col := fill
			if edge == 0:
				col = outline
			elif edge == 1:
				col = light if (x == 1 or y == 1) and x < n - 2 and y < n - 2 else shade
			img.set_pixel(x, y, col)
	# abgeschnittene Ecken wie bei den Button-Bildern
	for p in [Vector2i(0, 0), Vector2i(n - 1, 0), Vector2i(0, n - 1), Vector2i(n - 1, n - 1)]:
		img.set_pixelv(p, Color(0, 0, 0, 0))
	img.resize(n * PX, n * PX, Image.INTERPOLATE_NEAREST)
	return _texture_box(ImageTexture.create_from_image(img), 3)

static func _texture_box(tex: Texture2D, margin_px: int) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = tex
	var m := margin_px * PX
	box.texture_margin_left = m
	box.texture_margin_right = m
	box.texture_margin_top = m
	box.texture_margin_bottom = m
	box.content_margin_left = m + 4
	box.content_margin_right = m + 4
	box.content_margin_top = m + 2
	box.content_margin_bottom = m + 2
	return box

# Kleine Pixel-Bilder: Schalter, Reglerknopf, Pfeil
const ICONS := {
	"switch_off": [".############.", "#rrrrrrrrrrrr#", "#rWWrrrrrrrrr#", "#rWWrrrrrrrrr#", "#rWWrrrrrrrrr#", "#rWWrrrrrrrrr#", "#rrrrrrrrrrrr#", ".############."],
	"switch_on": [".############.", "#gggggggggggg#", "#gggggggggWWg#", "#gggggggggWWg#", "#gggggggggWWg#", "#gggggggggWWg#", "#gggggggggggg#", ".############."],
	"knob": [".####.", "#WWWW#", "#Wwww#", "#Wwww#", "#Wwww#", "#wwww#", ".####."],
	"knob_hover": [".####.", "#WWWW#", "#WWWW#", "#WWWW#", "#WWWW#", "#wwww#", ".####."],
	"arrow": ["#####", ".###.", "..#.."],
	"dot": ["....", ".WW.", ".WW.", "...."],
	"empty": ["....", "....", "....", "...."],
}
const ICON_COLORS := {"#": "#000000", "0": "#3a1530", "r": "#c4394b", "w": "#9aa3b2", "W": "#f5f7f8", "g": "#4caf6a"}

static func _icon(kind: String, tint: Color = Color("#f5f7f8")) -> Texture2D:
	var rows: Array = ICONS[kind]
	var img := Image.create(str(rows[0]).length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y in range(rows.size()):
		var row := str(rows[y])
		for x in range(row.length()):
			var ch := row[x]
			if ch == "#" and kind == "arrow":
				img.set_pixel(x, y, tint)
			elif ICON_COLORS.has(ch):
				img.set_pixel(x, y, Color(ICON_COLORS[ch]))
	img.resize(img.get_width() * PX, img.get_height() * PX, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

static func panel() -> StyleBox:
	return frame("panel")

# Flacher Button ohne Rahmen, z. B. für aufklappbare Überschriften.
static func header_button(label: String, size: int = 18) -> Button:
	var control := Button.new()
	control.text = label
	control.flat = true
	control.alignment = HORIZONTAL_ALIGNMENT_LEFT
	control.add_theme_font_size_override("font_size", font_size(size))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		control.add_theme_color_override(state, color("text", "#f5f7f8"))
	control.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return control

static func label(value: String, size: int = 18) -> Label:
	var control := Label.new()
	control.text = value
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.add_theme_font_size_override("font_size", font_size(size))
	return control

# Zeit als m:ss, z. B. 83.4 -> "1:23"
static func time_text(seconds: float) -> String:
	var total := maxi(0, floori(seconds))
	return "%d:%02d" % [floori(total / 60.0), total % 60]

# Sterne als Text, z. B. 2 von 3 -> "★★☆". Zeichen in ui_text.json änderbar.
static func stars_text(stars: int, max_stars: int = 3) -> String:
	var result := ""
	for i in range(max_stars):
		result += text("star_full") if i < stars else text("star_empty")
	return result

# Fortschrittsbalken im Pixel-Stil (z. B. für XP und Leben).
static func progress_bar(value: float, max_value: float, height: int = 18, fill: Color = Color(0, 0, 0, 0)) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = maxf(max_value, 1.0)
	bar.value = value
	bar.show_percentage = false
	bar.custom_minimum_size.y = maxi(height, 7 * PX)
	if fill.a > 0.0:
		bar.add_theme_stylebox_override("fill", tinted_fill(fill))
	return bar

# Füllung in einer eigenen Farbe (Licht und Schatten werden daraus berechnet)
static func tinted_fill(fill: Color) -> StyleBox:
	return _frame_box(fill, fill.lightened(0.35), fill.darkened(0.35), Color.BLACK)

# Normaler Button: Pixel-Hintergrund in der Farbe seines Textes (siehe unten).
static func button(label: String, height: int = 72, _accent: bool = false, color_name: String = "") -> Button:
	return pixel_text_button(label, height, color_name)

# Bild für einen Button aus ui_style.json. Ein Eintrag kann auch eine Liste sein:
# dann wird die erste Datei genommen, die es gibt.
static func art_path(art_key: String) -> String:
	if _style.is_empty():
		_style = _read_dictionary("res://data/ui_style.json")
	var art_paths = _style.get("art_buttons", {})
	if not art_paths is Dictionary:
		return ""
	var entry = art_paths.get(art_key, "")
	var options: Array = entry if entry is Array else [entry]
	for option in options:
		if not str(option).is_empty() and ResourceLoader.exists(str(option)):
			return str(option)
	return ""

static func art_button(label: String, art_key: String, height: int = 96) -> Button:
	if _style.is_empty():
		_style = _read_dictionary("res://data/ui_style.json")
	var path := art_path(art_key)
	if path.is_empty():
		return button(label, height)
	var texture = load(path)
	if not texture is Texture2D:
		return button(label, height)
	var control := Button.new()
	control.custom_minimum_size.y = height
	control.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	control.add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
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
	control.pressed.connect(func():
		SoundFX.play("click", -4.0)
		_animate_then_call(control, action))

static func _animate_then_call(control: Button, action: Callable) -> void:
	if control.get_meta("animating", false):
		return
	if not bool(GameSettings.get_value("button_animations")):
		action.call()
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

# --- Pixel-Buttons der Set-Auswahl ----------------------------------------------
# Hintergrundbilder (50×25) aus data/ui_style.json "set_backgrounds". Die Schrift ist
# die Pixel-Schrift der Button-Bilder (scripts/PixelFont.gd); ihre Farbe ist die
# dunkle Randfarbe des jeweiligen Bildes, so wie bei PLAY, SETS usw.

const SET_COLOR_DEFAULTS := {
	"red": "res://assets/ui/blank_backgrounds/wide_red.png",
	"blue": "res://assets/ui/blank_backgrounds/wide_blue.png",
	"orange": "res://assets/ui/blank_backgrounds/wide_orange.png",
	"pink": "res://assets/ui/blank_backgrounds/wide_pink.png",
}
static var _pixel_cache: Dictionary = {}

static func set_colors() -> Array:
	if _style.is_empty():
		_style = _read_dictionary("res://data/ui_style.json")
	var custom = _style.get("set_backgrounds", {})
	if custom is Dictionary and not custom.is_empty():
		return custom.keys()
	return SET_COLOR_DEFAULTS.keys()

static func _set_background_path(color_name: String) -> String:
	if _style.is_empty():
		_style = _read_dictionary("res://data/ui_style.json")
	# "square:rot" = quadratische Variante (square_red.png neben wide_red.png)
	if color_name.begins_with("square:"):
		var wide := _set_background_path(color_name.substr(7))
		var square := wide.replace("wide_", "square_")
		return square if square != wide and ResourceLoader.exists(square) else wide
	if EXTRA_BACKGROUNDS.has(color_name) and not (_style.get("set_backgrounds", {}) as Dictionary).has(color_name):
		return str(EXTRA_BACKGROUNDS[color_name])
	var custom = _style.get("set_backgrounds", {})
	if custom is Dictionary and custom.has(color_name):
		return str(custom[color_name])
	return str(SET_COLOR_DEFAULTS.get(color_name, SET_COLOR_DEFAULTS["red"]))

# Bild in ganzen Faktoren vergrössert (bleibt pixelscharf) und die Schriftfarbe dazu.
static func pixel_background(color_name: String, factor: int) -> Dictionary:
	var key := "%s@%d" % [color_name, factor]
	if _pixel_cache.has(key):
		return _pixel_cache[key]
	var path := _set_background_path(color_name)
	var source = load(path) if ResourceLoader.exists(path) else null
	if not source is Texture2D:
		return {}
	var image: Image = source.get_image()
	image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	var base_size := image.get_size()
	# Dunkelste Farbe = Randfarbe = Schriftfarbe
	var ink := Color(0.1, 0.1, 0.1)
	var darkest := 9.0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var c := image.get_pixel(x, y)
			if c.a > 0.8 and c.get_luminance() < darkest:
				darkest = c.get_luminance()
				ink = c
	image.resize(base_size.x * factor, base_size.y * factor, Image.INTERPOLATE_NEAREST)
	var result := {"texture": ImageTexture.create_from_image(image), "ink": ink, "base": base_size}
	_pixel_cache[key] = result
	return result

static func pixel_button(label: String, color_name: String, factor: int = 2, text_factor: int = 2) -> Button:
	var control := Button.new()
	var bg := pixel_background(color_name, factor)
	if bg.is_empty():
		# Hintergrundbild fehlt: einfacher Button mit Pixel-Schrift
		control.text = PixelFont.prepare(label)
		control.custom_minimum_size.y = 25 * factor
		return control
	var base: Vector2i = bg["base"]
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box := StyleBoxTexture.new()
		box.texture = bg["texture"]
		# Ränder bleiben wie im Bild, nur die Mitte wird breiter gezogen
		box.texture_margin_left = 8 * factor
		box.texture_margin_right = 8 * factor
		box.texture_margin_top = 7 * factor
		box.texture_margin_bottom = 7 * factor
		box.content_margin_left = 9 * factor
		box.content_margin_right = 9 * factor
		box.content_margin_top = 0
		box.content_margin_bottom = 2 * factor
		if state == "hover":
			box.modulate_color = Color(1.12, 1.12, 1.12)
		elif state == "pressed":
			box.modulate_color = Color(0.88, 0.88, 0.88)
		elif state == "disabled":
			box.modulate_color = Color(0.5, 0.5, 0.55, 0.8)
		control.add_theme_stylebox_override(state, box)
	control.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	control.custom_minimum_size = Vector2(base.x * factor, base.y * factor)
	control.text = PixelFont.prepare(label)
	control.tooltip_text = label
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	control.clip_text = true
	control.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	control.alignment = HORIZONTAL_ALIGNMENT_CENTER
	control.add_theme_font_override("font", PixelFont.font())
	control.add_theme_font_size_override("font_size", PixelFont.size(text_factor))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		control.add_theme_color_override(state, bg["ink"])
	control.add_theme_color_override("font_disabled_color", Color(bg["ink"], 0.7))
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return control

# Überschrift (Kategorie) in der Pixel-Schrift
static func pixel_header(label: String, text_factor: int = 2, tint: Color = Color(0, 0, 0, 0)) -> Button:
	var control := header_button(PixelFont.prepare(label))
	control.clip_text = true
	control.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	control.add_theme_font_override("font", PixelFont.font())
	control.add_theme_font_size_override("font_size", PixelFont.size(text_factor))
	control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if tint.a > 0.0:
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			control.add_theme_color_override(state, tint)
	return control

# --- Alle anderen Buttons im Pixel-Stil -------------------------------------------
# Jeder Button bekommt einen der Hintergründe und die Pixel-Schrift. Die Farbe hängt
# nur vom Text ab: gleicher Text = gleiche Farbe. Heisst ein Button wie eines der
# Button-Bilder (z. B. "Zurück", "Einstellungen"), bekommt er dessen Farbe.
# Eigene Zuordnungen: "text_colors" in data/ui_style.json, z. B. {"Löschen": "red"}.

const ART_TEXT_COLORS := {
	"zurück": "green", "play": "green", "erfolge": "green", "fortschritt zurücksetzen": "green",
	"einstellungen": "blue", "kampagne": "orange", "sets": "pink", "deine sets": "pink",
	"einstellungen zurücksetzen": "red",
}
const EXTRA_BACKGROUNDS := {"green": "res://assets/ui/blank_backgrounds/wide_green.png"}

static func _text_key(label: String) -> String:
	var key := label.split("\n")[0].strip_edges().to_lower()
	for symbol in ["✓", "←", "→", "↻", "+", "×"]:
		key = key.replace(symbol, "")
	return key.strip_edges()

static func color_for_text(label: String) -> String:
	if _style.is_empty():
		_style = _read_dictionary("res://data/ui_style.json")
	var key := _text_key(label)
	var custom = _style.get("text_colors", {})
	if custom is Dictionary:
		for k in custom:
			if str(k).to_lower() == key:
				return str(custom[k])
	if ART_TEXT_COLORS.has(key):
		return ART_TEXT_COLORS[key]
	var colors := set_colors()
	# Fester Wert aus dem Text (md5), damit gleiche Texte immer dieselbe Farbe haben
	return str(colors[key.md5_text().substr(0, 6).hex_to_int() % colors.size()])


static func pixel_text_button(label: String, height: int = 72, color_name: String = "") -> Button:
	var wanted := color_name if not color_name.is_empty() else color_for_text(label)
	if not set_colors().has(wanted) and not EXTRA_BACKGROUNDS.has(wanted):
		wanted = color_for_text(label)
	var factor := maxi(2, roundi(height / 25.0))
	# Ganz kurze Texte ("+", "×", "OK") bekommen den quadratischen Hintergrund
	var short := PixelFont.prepare(label).strip_edges().length() <= 2
	var control := pixel_button(label, ("square:" + wanted) if short else wanted, factor, 2)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box = control.get_theme_stylebox(state)
		if box is StyleBoxTexture:
			box.content_margin_left = 6 * factor
			box.content_margin_right = 6 * factor
	control.custom_minimum_size = Vector2(27 * factor if short else 0, 25 * factor)
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Alle Texte gleich gross (Pixel 2×2), auch wenn später eine andere Grösse gesetzt wird
	control.theme_changed.connect(func(): _keep_pixel_size(control))
	return control

static func _keep_pixel_size(control: Button) -> void:
	if control.get_theme_font_size("font_size") != PixelFont.size(2):
		control.add_theme_font_size_override("font_size", PixelFont.size(2))

# Bild ohne Klick (z. B. Seitentitel)
static func art_image(art_key: String, height: int) -> TextureRect:
	var path := art_path(art_key)
	if path.is_empty() or not load(path) is Texture2D:
		return null
	var texture: Texture2D = load(path)
	var scale_factor := maxi(1, floori(float(height) / float(texture.get_height())))
	# Leeren (durchsichtigen) Rand weglassen, damit das Bild keinen Platz verschwendet
	var used := texture.get_image().get_used_rect()
	if used.size.x > 0 and used.size != Vector2i(texture.get_width(), texture.get_height()):
		var cropped := AtlasTexture.new()
		cropped.atlas = texture
		cropped.region = Rect2(used)
		texture = cropped
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	image.custom_minimum_size = Vector2(texture.get_width() * scale_factor, texture.get_height() * scale_factor)
	image.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return image
