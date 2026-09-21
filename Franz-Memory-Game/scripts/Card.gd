extends Node3D
class_name Card

signal card_clicked(card: Card)

@export var card_id: int = 0  # Zwei Karten mit gleicher ID = Match

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var area: Area3D = $Area3D

var is_flipped: bool = false
var is_matched: bool = false
var is_animating: bool = false

@export var front_material: Material
@export var back_material: Material

func _ready() -> void:
	area.input_event.connect(_on_input_event)
	_apply_back_material()

func _on_input_event(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_flipped and not is_matched and not is_animating:
			card_clicked.emit(self)

func flip_up() -> void:
	if is_animating or is_flipped:
		return
	is_flipped = true
	is_animating = true
	_apply_front_material()
	_play_flip_tween(180.0)

func flip_down() -> void:
	if is_animating or not is_flipped:
		return
	is_flipped = false
	is_animating = true
	_play_flip_tween(360.0)
	await get_tree().create_timer(0.15).timeout
	_apply_back_material()

func set_matched() -> void:
	is_matched = true
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y + 0.05, 0.2)

func _play_flip_tween(to_deg: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "rotation_degrees:y", to_deg, 0.3)
	tween.tween_callback(func():
		is_animating = false
		rotation_degrees.y = wrapf(to_deg, 0.0, 360.0)
	)

func _apply_front_material() -> void:
	if mesh_instance and front_material:
		mesh_instance.set_surface_override_material(0, front_material)

func _apply_back_material() -> void:
	if mesh_instance and back_material:
		mesh_instance.set_surface_override_material(0, back_material)
