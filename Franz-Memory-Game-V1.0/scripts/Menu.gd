extends Control

const UI = preload("res://scripts/MenuUI.gd")

var available_sets: Array[Dictionary] = []
var selected_path := "res://data/vocabulary.json"
var sidebar_list: VBoxContainer
var content: VBoxContainer
var list_panel: PanelContainer
var current_page := "home"

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reload_sets()
	_build_menu()

func _reload_sets() -> void:
	available_sets = SetRepository.list_sets()
	if not SetSelection.selected_path.is_empty():
		selected_path = SetSelection.selected_path
	var found := false
	for item in available_sets:
		if item["path"] == selected_path:
			found = true
			break
	if not found and not available_sets.is_empty():
		selected_path = str(available_sets[0]["path"])

func _build_menu() -> void:
	var background := ColorRect.new()
	background.color = UI.background()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 28)
	add_child(margin)
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 24)
	margin.add_child(layout)
	var sidebar := VBoxContainer.new()
	sidebar.custom_minimum_size.x = 220
	sidebar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar.size_flags_stretch_ratio = 0.8
	layout.add_child(sidebar)
	var future_button_space := Control.new()
	future_button_space.custom_minimum_size.y = 68
	sidebar.add_child(future_button_space)
	list_panel = PanelContainer.new()
	list_panel.add_theme_stylebox_override("panel", UI.panel())
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sidebar.add_child(list_panel)
	var sidebar_scroll := ScrollContainer.new()
	sidebar_scroll.custom_minimum_size.y = 180
	sidebar_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_child(sidebar_scroll)
	sidebar_list = VBoxContainer.new()
	sidebar_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_list.custom_minimum_size = Vector2(200, 180)
	sidebar_list.add_theme_constant_override("separation", 10)
	sidebar_scroll.add_child(sidebar_list)
	_refresh_sidebar()
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_stretch_ratio = 2.0
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(center)
	content = VBoxContainer.new()
	content.custom_minimum_size.x = 420
	content.add_theme_constant_override("separation", 16)
	center.add_child(content)
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 140
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 0.8
	layout.add_child(right)
	var settings := UI.art_button(UI.text("settings"), "settings", 68)
	right.add_child(settings)
	UI.connect_animated(settings, func(): _show_simple_page(UI.text("settings"), UI.text("settings_placeholder")))
	var right_spacer := Control.new()
	right_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(right_spacer)
	var power := UI.art_button(UI.text("quit"), "power", 68)
	right.add_child(power)
	UI.connect_animated(power, func(): get_tree().quit())
	_show_home()

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

func _refresh_sidebar() -> void:
	_clear(sidebar_list)
	var heading := UI.label(UI.text("sets_heading"), 16)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sidebar_list.add_child(heading)
	for item in available_sets:
		var prefix := "✓  " if item["path"] == selected_path else "   "
		var button := UI.button(prefix + str(item["name"]), 62)
		button.add_theme_font_size_override("font_size", 16)
		sidebar_list.add_child(button)
		UI.connect_animated(button, _select_set.bind(str(item["path"])))

func _select_set(path: String) -> void:
	selected_path = path
	SetSelection.selected_path = path
	_refresh_sidebar()
	if current_page == "sets":
		_show_sets()

func _show_home() -> void:
	current_page = "home"
	_clear(content)
	var play := UI.art_button(UI.text("play"), "play", 112)
	content.add_child(play)
	UI.connect_animated(play, _start_game)
	var campaign := UI.art_button(UI.text("campaign"), "campaign", 112)
	content.add_child(campaign)
	UI.connect_animated(campaign, func(): _show_simple_page(UI.text("campaign"), UI.text("campaign_placeholder")))
	var sets := UI.art_button(UI.text("your_sets"), "sets", 112)
	content.add_child(sets)
	UI.connect_animated(sets, _show_sets)

func _start_game() -> void:
	if available_sets.is_empty():
		return
	SetSelection.selected_path = selected_path
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _page(title: String, with_plus: bool = false) -> VBoxContainer:
	_clear(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var heading := UI.label(title, 28)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	if with_plus:
		var plus := UI.button(UI.text("add"), 48)
		plus.custom_minimum_size.x = 48
		header.add_child(plus)
		UI.connect_animated(plus, _show_add_options)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel())
	content.add_child(panel)
	var padding := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		padding.add_theme_constant_override(side, 20)
	panel.add_child(padding)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 14)
	padding.add_child(body)
	return body

func _back(action: Callable) -> void:
	var button := UI.button(UI.text("back"), 58)
	content.add_child(button)
	UI.connect_animated(button, action)

func _show_sets() -> void:
	current_page = "sets"
	_reload_sets()
	_refresh_sidebar()
	var body := _page(UI.text("your_sets"), true)
	var custom_count := 0
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 210
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var set_rows := VBoxContainer.new()
	set_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_rows.add_theme_constant_override("separation", 8)
	scroll.add_child(set_rows)
	for item in available_sets:
		if item["path"] == SetRepository.EXAMPLE_PATH:
			continue
		custom_count += 1
		var prefix := "✓  " if item["path"] == selected_path else ""
		var label := prefix + str(item["name"]) + "  ·  " + str(item["count"]) + " " + UI.text("pairs_suffix")
		var button := UI.button(label, 62)
		button.add_theme_font_size_override("font_size", 18)
		set_rows.add_child(button)
		UI.connect_animated(button, _select_set.bind(str(item["path"])))
	if custom_count == 0:
		set_rows.add_child(UI.label(UI.text("empty_sets"), 18))
	body.add_child(UI.label(UI.text("select_hint"), 16))
	_back(_show_home)

func _show_add_options() -> void:
	current_page = "add_options"
	var body := _page(UI.text("add"))
	var manual := UI.button(UI.text("manual"), 76)
	body.add_child(manual)
	UI.connect_animated(manual, _show_name_step)
	var other := UI.button(UI.text("other"), 76)
	body.add_child(other)
	UI.connect_animated(other, _show_other)
	_back(_show_sets)

func _show_other() -> void:
	current_page = "other"
	var body := _page(UI.text("other"))
	var empty_space := Control.new()
	empty_space.custom_minimum_size.y = 180
	body.add_child(empty_space)
	_back(_show_add_options)

func _show_name_step() -> void:
	current_page = "name"
	var body := _page(UI.text("set_name"))
	var name_field := LineEdit.new()
	name_field.placeholder_text = UI.text("set_name")
	name_field.custom_minimum_size.y = 50
	body.add_child(name_field)
	var error_label := UI.label("", 16)
	body.add_child(error_label)
	var next := UI.button(UI.text("continue"), 60)
	body.add_child(next)
	UI.connect_animated(next, func():
		var name := name_field.text.strip_edges()
		if name.is_empty():
			error_label.text = UI.text("error_name")
		else:
			_show_editor(name)
	)
	_back(_show_add_options)

func _show_editor(set_name: String) -> void:
	current_page = "editor"
	var body := _page(set_name)
	var columns := HBoxContainer.new()
	body.add_child(columns)
	var german := UI.label(UI.text("german"), 16)
	german.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(german)
	var french := UI.label(UI.text("french"), 16)
	french.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(french)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 210
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var rows_container := VBoxContainer.new()
	rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows_container.add_theme_constant_override("separation", 8)
	scroll.add_child(rows_container)
	var rows: Array[Dictionary] = []
	_add_word_row(rows_container, rows)
	var add_row := UI.button(UI.text("add_pair"), 54)
	body.add_child(add_row)
	UI.connect_animated(add_row, func(): _add_word_row(rows_container, rows))
	var error_label := UI.label("", 16)
	body.add_child(error_label)
	var save := UI.button(UI.text("save"), 62, true)
	body.add_child(save)
	UI.connect_animated(save, func(): _save_entries(set_name, rows, error_label))
	_back(func(): _show_name_step())

func _add_word_row(container: VBoxContainer, rows: Array[Dictionary]) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	container.add_child(line)
	var de := LineEdit.new()
	de.placeholder_text = UI.text("german")
	de.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	de.custom_minimum_size.y = 48
	line.add_child(de)
	var fr := LineEdit.new()
	fr.placeholder_text = UI.text("french")
	fr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(fr)
	var remove := UI.button("×", 46)
	remove.custom_minimum_size.x = 42
	line.add_child(remove)
	var record := {"de": de, "fr": fr}
	rows.append(record)
	UI.connect_animated(remove, func():
		rows.erase(record)
		line.queue_free()
	)

func _save_entries(set_name: String, rows: Array[Dictionary], error_label: Label) -> void:
	var entries: Array[Dictionary] = []
	for row in rows:
		var de := str(row["de"].text).strip_edges()
		var fr := str(row["fr"].text).strip_edges()
		if de.is_empty() and fr.is_empty():
			continue
		if de.is_empty() or fr.is_empty():
			error_label.text = UI.text("error_pair")
			return
		entries.append({"de": de, "fr": fr})
	if entries.is_empty():
		error_label.text = UI.text("error_empty")
		return
	var result: Dictionary = SetRepository.save_set(set_name, entries)
	if result.has("error"):
		error_label.text = str(result["error"])
		return
	selected_path = str(result["path"])
	SetSelection.selected_path = selected_path
	_show_sets()

func _show_simple_page(title: String, message: String) -> void:
	current_page = "simple"
	var body := _page(title)
	body.add_child(UI.label(message, 18))
	_back(_show_home)
