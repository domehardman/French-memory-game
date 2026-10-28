extends Node3D

const UI = preload("res://scripts/MenuUI.gd")

@export var card_scene: PackedScene
@export var grid_columns: int = 5
@export var grid_rows: int = 5
@export var card_spacing: float = 1.3
@export_file("*.json") var vocabulary_path := "res://data/vocabulary.json"
@export var symbol_materials: Array[Material] = []
@export var back_material: Material

var cards: Array[Card] = []
var first_card: Card = null
var second_card: Card = null
var can_click: bool = true
var matches_found: int = 0
var total_pairs: int = 0
var progress_label: Label
var vocabulary: Array = []
var next_word_index := 0
var completed_pairs := 0
var round_number := 0
var round_count := 0
var round_marker: Label3D

func _ready() -> void:
	randomize()
	_build_overlay()
	if not SetSelection.selected_path.is_empty():
		vocabulary_path = SetSelection.selected_path
	if not _load_vocabulary():
		return
	vocabulary.shuffle()
	round_count = ceili(float(vocabulary.size()) / 12.0)
	_generate_grid()

func _load_vocabulary() -> bool:
	var file := FileAccess.open(vocabulary_path, FileAccess.READ)
	if file == null:
		push_error("Das Vokabelset konnte nicht geladen werden: " + vocabulary_path)
		progress_label.text = "Vokabelset konnte nicht geladen werden."
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and parsed.has("entries"):
		parsed = parsed["entries"]
	if not parsed is Array or parsed.is_empty():
		push_error("Das Vokabelset ist leer oder ungültig.")
		progress_label.text = "Vokabelset ist leer oder ungültig."
		return false
	for entry in parsed:
		if not entry is Dictionary or not entry.has("de") or not entry.has("fr") or str(entry["de"]).strip_edges().is_empty() or str(entry["fr"]).strip_edges().is_empty():
			push_error("Jeder Eintrag braucht Text für de und fr.")
			progress_label.text = "Vokabelset hat ungültige Einträge."
			return false
	vocabulary = parsed
	return true

func _generate_grid() -> void:
	round_number += 1
	matches_found = 0
	first_card = null
	second_card = null
	can_click = true
	var remaining := vocabulary.size() - next_word_index
	total_pairs = mini(12, remaining)
	var entries: Array = []
	for i in range(total_pairs):
		var word: Dictionary = vocabulary[next_word_index + i]
		entries.append({"id": i, "text": str(word["de"])})
		entries.append({"id": i, "text": str(word["fr"])})
	next_word_index += total_pairs
	entries.shuffle()

	# Symmetric slot pairs keep the final, shorter round orderly.
	# The word cards themselves are shuffled separately above.
	var slot_pairs: Array[Vector2i] = [
		Vector2i(1, 1), Vector2i(3, 3),
		Vector2i(1, 2), Vector2i(3, 2),
		Vector2i(1, 3), Vector2i(3, 1),
		Vector2i(2, 1), Vector2i(2, 3),
		Vector2i(0, 2), Vector2i(4, 2),
		Vector2i(0, 1), Vector2i(4, 3),
		Vector2i(0, 3), Vector2i(4, 1),
		Vector2i(1, 0), Vector2i(3, 4),
		Vector2i(1, 4), Vector2i(3, 0),
		Vector2i(0, 0), Vector2i(4, 4),
		Vector2i(0, 4), Vector2i(4, 0),
		Vector2i(2, 0), Vector2i(2, 4)
	]
	if total_pairs == 1:
		slot_pairs = [Vector2i(1, 2), Vector2i(3, 2)]
	elif total_pairs == 2:
		slot_pairs = [Vector2i(1, 1), Vector2i(1, 3), Vector2i(3, 1), Vector2i(3, 3)]
	var positions: Array[Vector3] = []
	var offset_x := (grid_columns - 1) * card_spacing / 2.0
	var offset_z := (grid_rows - 1) * card_spacing / 2.0
	for slot in slot_pairs:
		positions.append(Vector3(slot.x * card_spacing - offset_x, 0, slot.y * card_spacing - offset_z))
	for i in range(entries.size()):
		var card: Card = card_scene.instantiate()
		card.card_id = entries[i]["id"]
		card.word_text = entries[i]["text"]
		card.back_material = back_material
		card.front_material = symbol_materials[0]
		card.position = positions[i]
		add_child(card)
		card.card_clicked.connect(_on_card_clicked)
		cards.append(card)
	_update_progress()
	round_marker.text = UI.text("game_round") % [round_number, round_count]

func _on_card_clicked(card: Card) -> void:
	if not can_click:
		return
	card.flip_up()
	if first_card == null:
		first_card = card
		return
	second_card = card
	can_click = false
	_check_match()

func _check_match() -> void:
	await get_tree().create_timer(0.6).timeout
	if first_card.card_id == second_card.card_id:
		first_card.set_matched()
		second_card.set_matched()
		matches_found += 1
		completed_pairs += 1
		_update_progress()
		if matches_found >= total_pairs:
			can_click = false
			first_card = null
			second_card = null
			if completed_pairs >= vocabulary.size():
				progress_label.text = UI.text("game_complete") % vocabulary.size()
				round_marker.text = "✓"
			else:
				progress_label.text = UI.text("game_next") % round_number
				await get_tree().create_timer(1.2).timeout
				_next_round()
			return
	else:
		first_card.flip_down()
		second_card.flip_down()
	first_card = null
	second_card = null
	can_click = true

func _next_round() -> void:
	for card in cards:
		remove_child(card)
		card.queue_free()
	cards.clear()
	_generate_grid()

func _update_progress() -> void:
	progress_label.text = UI.text("game_progress") % [round_number, round_count, matches_found, total_pairs, completed_pairs, vocabulary.size()]

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var bar := HBoxContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 20
	bar.offset_top = 12
	bar.offset_right = -20
	bar.add_theme_constant_override("separation", 20)
	layer.add_child(bar)
	var back := UI.button(UI.text("game_back"), 40)
	back.custom_minimum_size.x = 105
	bar.add_child(back)
	UI.connect_animated(back, func(): get_tree().change_scene_to_file("res://scenes/Menu.tscn"))
	progress_label = Label.new()
	progress_label.add_theme_font_size_override("font_size", 20)
	progress_label.add_theme_color_override("font_color", Color.WHITE)
	progress_label.add_theme_color_override("font_outline_color", Color.BLACK)
	progress_label.add_theme_constant_override("outline_size", 4)
	bar.add_child(progress_label)
	round_marker = Label3D.new()
	round_marker.position = Vector3(0, -0.40, 0)
	round_marker.rotation_degrees.x = -90
	round_marker.font_size = 28
	round_marker.pixel_size = 0.01
	round_marker.modulate = Color(0.9, 0.95, 1.0)
	add_child(round_marker)
