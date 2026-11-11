extends Node3D
class_name Card

signal card_clicked(card: Card)

## Kartenbilder (Pixel-Art). Pfade stehen in data/ui_style.json unter "card_textures".
const DEFAULT_TEXTURES := {
	"back": "res://assets/cards/card_back.png",
	"front": "res://assets/cards/card_front.png",
	"matched": "res://assets/cards/card_matched.png"
}
const FACE_Y := -0.424
static var _texture_cache: Dictionary = {}

var word_text: String = ""
var text_scale: float = 1.0
var face_glow: float = 0.0      # Bossfight: Karten leuchten leicht, damit man sie im Dunkeln sieht

@export var card_id: int = 0  # Zwei Karten mit gleicher ID = Match

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var area: Area3D = $Area3D
@onready var word_label: Label3D = $WordLabel

var is_flipped: bool = false
var is_matched: bool = false
var is_animating: bool = false
var cursed: bool = false   # Bossfight: vom Boss verflucht

@export var front_material: Material
@export var back_material: Material

# Drehung der Karte: Neigung zur Kamera, Umdrehen und Wirbeln getrennt,
# damit sich eine geneigte Karte trotzdem sauber umdreht.
var tilt_deg := 0.0:
	set(value):
		tilt_deg = value
		_update_basis()
var flip_deg := 0.0:
	set(value):
		flip_deg = value
		_update_basis()
var spin_deg := 0.0:
	set(value):
		spin_deg = value
		_update_basis()
# Normaler Modus: echtes Umdrehen über die Kante (mit Anheben)
var flip3d := false
var turn_deg := 0.0:
	set(value):
		turn_deg = value
		_update_basis()
const CENTER := Vector3(0, -0.467, 0)   # Mitte der Karte (das Modell liegt unter dem Ursprung)
var _flip_swapped := false

var face: MeshInstance3D
var face_material: StandardMaterial3D

func _ready() -> void:
	# Die Karte wird nur per Skript bewegt; sonst überschreibt die Physik beim
	# Umdrehen die Drehung (Wurzelknoten ist ein AnimatableBody3D)
	if "sync_to_physics" in self:
		set("sync_to_physics", false)
	area.input_event.connect(_on_input_event)
	_build_face()
	_apply_back_material()
	word_label.text = word_text
	if word_text.length() > 45:
		word_label.font_size = 21
	elif word_text.length() > 28:
		word_label.font_size = 25
	word_label.font_size = roundi(word_label.font_size * text_scale)
	_fit_words()
	word_label.visible = false
	_update_basis()

func _update_basis() -> void:
	basis = Basis(Vector3.RIGHT, deg_to_rad(tilt_deg)) * Basis(Vector3.BACK, deg_to_rad(turn_deg)) * Basis(Vector3.UP, deg_to_rad(flip_deg)) * Basis(Vector3.BACK, deg_to_rad(spin_deg))

static func _texture(kind: String) -> Texture2D:
	if _texture_cache.has(kind):
		return _texture_cache[kind]
	var path := str(DEFAULT_TEXTURES.get(kind, ""))
	var background := Color.WHITE
	var file := FileAccess.open("res://data/ui_style.json", FileAccess.READ)
	if file != null:
		var style = JSON.parse_string(file.get_as_text())
		if style is Dictionary and style.get("card_textures") is Dictionary:
			path = str(style["card_textures"].get(kind, path))
			background = Color(str(style["card_textures"].get("background", "#ffffff")))
	var texture: Texture2D = null
	if not path.is_empty() and ResourceLoader.exists(path):
		texture = load(path)
		# Durchsichtige Stellen im Bild bekommen eine Hintergrundfarbe (Standard: weiss).
		var image := texture.get_image()
		if image != null:
			if image.is_compressed():
				image.decompress()
			if image.detect_alpha() != Image.ALPHA_NONE:
				image.convert(Image.FORMAT_RGBA8)
				var filled := Image.create(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
				filled.fill(background)
				filled.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i.ZERO)
				texture = ImageTexture.create_from_image(filled)
	_texture_cache[kind] = texture
	return texture

# Bildfläche oben auf der Karte
func _build_face() -> void:
	if _texture("back") == null:
		return
	var plane := PlaneMesh.new()
	plane.size = Vector2(1.12, 1.12)
	face_material = StandardMaterial3D.new()
	face_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	face_material.roughness = 0.75
	if face_glow > 0.0:
		face_material.emission_enabled = true
		face_material.emission_energy_multiplier = face_glow
		face_material.disable_fog = true
	face = MeshInstance3D.new()
	face.mesh = plane
	face.material_override = face_material
	face.position = Vector3(0, FACE_Y, 0)
	add_child(face)
	# Rand der Karte dunkelblau wie der Rahmen im Design
	var edge := StandardMaterial3D.new()
	edge.albedo_color = Color(0.13, 0.1, 0.35)
	edge.roughness = 0.6
	front_material = edge
	back_material = edge

func _show_face(kind: String) -> void:
	if face == null:
		return
	var texture := _texture(kind)
	face_material.albedo_texture = texture
	if face_material.emission_enabled:
		face_material.emission_texture = texture
		face_material.emission = Color.WHITE
	# Aufgedeckte Karten sind um 180° gedreht, das Bild soll trotzdem gerade stehen.
	face.rotation_degrees.y = 0.0 if kind == "back" else 180.0

func _on_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_flipped and not is_matched and not is_animating:
			card_clicked.emit(self)

func flip_up() -> void:
	if is_animating or is_flipped:
		return
	is_flipped = true
	is_animating = true
	_sound("flip", 0.0)
	if flip3d:
		_flip_over(true)
		return
	_apply_front_material()
	word_label.visible = true
	_play_flip_tween(180.0)

func flip_down() -> void:
	if is_animating or not is_flipped:
		return
	is_flipped = false
	if flip3d:
		is_animating = true
		_sound("flip", -6.0)
		_flip_over(false)
		return
	word_label.visible = false
	is_animating = true
	_sound("flip", -6.0)
	_play_flip_tween(360.0)
	await get_tree().create_timer(0.15).timeout
	_apply_back_material()

func set_matched() -> void:
	is_matched = true
	while is_animating:
		await get_tree().process_frame
	_show_face("matched")
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y + 0.05, 0.2)

func _play_flip_tween(to_deg: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "flip_deg", to_deg, 0.3)
	tween.tween_callback(func():
		is_animating = false
		flip_deg = wrapf(to_deg, 0.0, 360.0)
	)

func _apply_front_material() -> void:
	if mesh_instance and front_material:
		mesh_instance.set_surface_override_material(0, front_material)
	_show_face("front")

func _apply_back_material() -> void:
	if mesh_instance and back_material:
		mesh_instance.set_surface_override_material(0, back_material)
	if not is_matched:
		_show_face("back")

func _sound(name: String, volume_db: float) -> void:
	var sfx := get_node_or_null("/root/SoundFX")
	if sfx != null:
		sfx.play(name, volume_db)

# Lange Wörter nicht mitten im Wort umbrechen: Schrift verkleinern, bis jedes
# einzelne Wort in eine Zeile passt (höchstens 3 Zeilen).
func _fit_words() -> void:
	var font: Font = word_label.font if word_label.font != null else ThemeDB.fallback_font
	# Nach Leerzeichen und nach Bindestrichen darf umgebrochen werden ("belle-/mère")
	var words: Array = []
	for w in word_text.split(" ", false):
		var parts := w.split("-")
		for p in range(parts.size()):
			if not parts[p].is_empty():
				words.append(parts[p] + ("-" if p < parts.size() - 1 else ""))
	var size := word_label.font_size
	while size > 12:
		var widest := 0.0
		var line_count := 1
		var line_width := 0.0
		var space := font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		for w in words:
			var ww := font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + word_label.outline_size * 2
			widest = maxf(widest, ww)
			if line_width > 0.0 and line_width + space + ww > word_label.width:
				line_count += 1
				line_width = ww
			else:
				line_width += (space if line_width > 0.0 else 0.0) + ww
		if widest <= word_label.width and line_count <= 3:
			break
		size -= 1
	word_label.font_size = size

# Umdrehen in 3D: Karte hebt ab, kippt über die Kante, in der Mitte (hochkant)
# wird die Seite gewechselt, dann landet sie wieder flach.
func _flip_over(face_up: bool) -> void:
	var base := position
	_flip_swapped = false
	var tween := create_tween()
	tween.tween_method(func(t: float): _flip_step(base, t, face_up), 0.0, 1.0, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func():
		turn_deg = 0.0
		position = base
		is_animating = false
		_sound("card_land", -6.0)
	)

func _flip_step(base: Vector3, t: float, face_up: bool) -> void:
	if t < 0.5:
		turn_deg = t * 2.0 * 90.0
	else:
		if not _flip_swapped:
			_flip_swapped = true
			if face_up:
				flip_deg = 180.0
				_apply_front_material()
				word_label.visible = true
			else:
				flip_deg = 0.0
				word_label.visible = false
				_apply_back_material()
		turn_deg = -90.0 + (t - 0.5) * 2.0 * 90.0
	position = base + Vector3(0, sin(t * PI) * 0.8, 0) + (CENTER - basis * CENTER)
