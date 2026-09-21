extends Node3D

@export var card_scene: PackedScene
@export var grid_columns: int = 4
@export var grid_rows: int = 4
@export var card_spacing: float = 1.3

@export var symbol_materials: Array[Material] = []
@export var back_material: Material

var cards: Array[Card] = []
var first_card: Card = null
var second_card: Card = null
var can_click: bool = true
var matches_found: int = 0
var total_pairs: int = 0

func _ready() -> void:
	randomize()
	_generate_grid()

func _generate_grid() -> void:
	var total_cards := grid_columns * grid_rows
	total_pairs = total_cards / 2

	var ids: Array[int] = []
	for i in range(total_pairs):
		ids.append(i)
		ids.append(i)
	ids.shuffle()

	var offset_x := (grid_columns - 1) * card_spacing / 2.0
	var offset_z := (grid_rows - 1) * card_spacing / 2.0

	var index := 0
	for row in range(grid_rows):
		for col in range(grid_columns):
			var card: Card = card_scene.instantiate()
			add_child(card)

			card.position = Vector3(col * card_spacing - offset_x, 0, row * card_spacing - offset_z)
			card.card_id = ids[index]
			card.back_material = back_material
			card.front_material = symbol_materials[ids[index] % symbol_materials.size()]
			card.card_clicked.connect(_on_card_clicked)

			cards.append(card)
			index += 1

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
		if matches_found >= total_pairs:
			print("Gewonnen!")
	else:
		first_card.flip_down()
		second_card.flip_down()

	first_card = null
	second_card = null
	can_click = true
