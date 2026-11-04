extends Control

const UI = preload("res://scripts/MenuUI.gd")

var available_sets: Array[Dictionary] = []
var selected_path := "res://data/vocabulary.json"
var sidebar_list: VBoxContainer
var content: VBoxContainer
var list_panel: PanelContainer
var sidebar_scroll: ScrollContainer
var sets_toggle: Button
var level_label: Label
var level_bar: ProgressBar
var current_page := "home"

const ALL_SETS_KEY := "__all__"
const CAMPAIGN_FOLDER_KEY := "__campaign__"

func _ready() -> void:
	MusicPlayer.play("menu")
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
	if not found:
		selected_path = str(available_sets[0]["path"]) if not available_sets.is_empty() else ""
		SetSelection.selected_path = selected_path

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
	sidebar.add_child(_level_badge())
	list_panel = PanelContainer.new()
	var panel_style := UI.panel()
	panel_style.content_margin_left = 12
	panel_style.content_margin_right = 12
	panel_style.content_margin_top = 8
	panel_style.content_margin_bottom = 10
	list_panel.add_theme_stylebox_override("panel", panel_style)
	sidebar.add_child(list_panel)
	var panel_box := VBoxContainer.new()
	panel_box.add_theme_constant_override("separation", 6)
	list_panel.add_child(panel_box)
	# Kopf der Liste: Bild "SET-AUSWAHL", sonst Text-Überschrift
	if not UI.art_path("set_select").is_empty():
		sets_toggle = UI.art_button(UI.text("sets_heading"), "set_select", 48)
		sets_toggle.set_meta("art", true)
	else:
		sets_toggle = UI.header_button("", 16)
	sets_toggle.alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel_box.add_child(sets_toggle)
	sets_toggle.pressed.connect(func():
		_set_collapsed(ALL_SETS_KEY, not _is_collapsed(ALL_SETS_KEY))
		_refresh_sidebar()
	)
	sidebar_scroll = ScrollContainer.new()
	sidebar_scroll.custom_minimum_size.y = 180
	sidebar_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel_box.add_child(sidebar_scroll)
	sidebar_list = VBoxContainer.new()
	sidebar_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sidebar_list.add_theme_constant_override("separation", 8)
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
	UI.connect_animated(settings, _show_settings)
	var right_spacer := Control.new()
	right_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(right_spacer)
	var power := UI.art_button(UI.text("quit"), "power", 68)
	right.add_child(power)
	UI.connect_animated(power, _request_quit)
	_show_home()

func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()

# Level und XP oben links (Platzhalter, kann durch eigene Grafik ersetzt werden).
func _level_badge() -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size.y = 68
	box.add_theme_constant_override("separation", 4)
	level_label = UI.label("", 16)
	box.add_child(level_label)
	level_bar = UI.progress_bar(0, 1)
	box.add_child(level_bar)
	_update_level_badge()
	return box

func _update_level_badge() -> void:
	var info := PlayerProgress.level_info()
	level_label.text = UI.text("level_line") % [int(info["level"]), int(info["current"]), int(info["needed"])]
	level_bar.max_value = maxf(float(info["needed"]), 1.0)
	level_bar.value = float(info["current"])

# Sets in Gruppen: zuerst das Beispielset, dann eigene Kategorien
# (alphabetisch, "Eigene Sets" zuerst), am Schluss die Themen-Sets der Kampagne.
func _sets_by_topic() -> Array:
	var buckets := [[], [], []]
	for item in available_sets:
		var custom := bool(item.get("custom", false))
		var bucket := 1 if custom else 2
		if item["path"] == SetRepository.EXAMPLE_PATH:
			bucket = 0
		var topic := str(item.get("topic", ""))
		var key := ("custom:" if custom else "set:") + topic
		var group: Dictionary = {}
		for existing in buckets[bucket]:
			if existing["key"] == key:
				group = existing
				break
		if group.is_empty():
			# Themen der Kampagne sind am Anfang zugeklappt.
			group = {"key": key, "topic": topic, "custom": custom, "sets": [], "default_closed": bucket == 2, "campaign": bucket == 2}
			buckets[bucket].append(group)
		group["sets"].append(item)
	buckets[1].sort_custom(func(a, b):
		if a["topic"] == SetRepository.CUSTOM_TOPIC:
			return b["topic"] != SetRepository.CUSTOM_TOPIC
		if b["topic"] == SetRepository.CUSTOM_TOPIC:
			return false
		return str(a["topic"]).naturalnocasecmp_to(str(b["topic"])) < 0
	)
	for group in buckets[1]:
		group["sets"].sort_custom(func(a, b): return str(a["name"]).naturalnocasecmp_to(str(b["name"])) < 0)
	return buckets[0] + buckets[1] + buckets[2]

# Auf-/Zugeklappt wird im Spielstand gemerkt.
func _is_collapsed(key: String, default_closed: bool = false) -> bool:
	return bool(PlayerProgress.data.get("menu_collapsed", {}).get(key, default_closed))

func _set_collapsed(key: String, value: bool) -> void:
	var state: Dictionary = PlayerProgress.data.get("menu_collapsed", {})
	state[key] = value
	PlayerProgress.data["menu_collapsed"] = state
	PlayerProgress.save_progress()

func _refresh_sidebar() -> void:
	_clear(sidebar_list)
	var all_closed := _is_collapsed(ALL_SETS_KEY)
	if not sets_toggle.has_meta("art"):
		sets_toggle.text = UI.text("sets_toggle_closed" if all_closed else "sets_toggle_open")
	sidebar_scroll.visible = not all_closed
	list_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN if all_closed else Control.SIZE_EXPAND_FILL
	if all_closed:
		return
	var groups := _sets_by_topic()
	# Überordner "Kampagne" für alle Themen-Sets der Kampagne
	var campaign_box: VBoxContainer = null
	var campaign_count := 0
	for group in groups:
		if group["campaign"]:
			campaign_count += group["sets"].size()
	for group in groups:
		var target: VBoxContainer = sidebar_list
		if group["campaign"]:
			if campaign_box == null:
				var folder_closed := _is_collapsed(CAMPAIGN_FOLDER_KEY)
				var folder_arrow := UI.text("group_closed") if folder_closed else UI.text("group_open")
				var folder := UI.header_button("%s  %s  (%d)" % [folder_arrow, UI.text("sidebar_campaign"), campaign_count], 15)
				sidebar_list.add_child(folder)
				folder.pressed.connect(func():
					_set_collapsed(CAMPAIGN_FOLDER_KEY, not _is_collapsed(CAMPAIGN_FOLDER_KEY))
					_refresh_sidebar()
				)
				if folder_closed:
					break
				var indent := MarginContainer.new()
				indent.add_theme_constant_override("margin_left", 14)
				sidebar_list.add_child(indent)
				campaign_box = VBoxContainer.new()
				campaign_box.add_theme_constant_override("separation", 8)
				indent.add_child(campaign_box)
			target = campaign_box
		var key := str(group["key"])
		var default_closed := bool(group["default_closed"])
		var closed := _is_collapsed(key, default_closed)
		var arrow := UI.text("group_closed") if closed else UI.text("group_open")
		var header := UI.header_button("%s  %s  (%d)" % [arrow, str(group["topic"]).to_upper(), group["sets"].size()], 13)
		header.modulate = Color(1, 1, 1, 0.7)
		target.add_child(header)
		header.pressed.connect(func():
			_set_collapsed(key, not _is_collapsed(key, default_closed))
			_refresh_sidebar()
		)
		if closed:
			continue
		for item in group["sets"]:
			var prefix := "✓  " if item["path"] == selected_path else "   "
			var button := UI.button(prefix + str(item["name"]), 48)
			button.add_theme_font_size_override("font_size", 16)
			target.add_child(button)
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
	UI.connect_animated(campaign, _show_campaign)
	var sets := UI.art_button(UI.text("your_sets"), "sets", 112)
	content.add_child(sets)
	UI.connect_animated(sets, _show_sets)
	var rewards := UI.art_button(UI.text("rewards"), "rewards", 112)
	content.add_child(rewards)
	UI.connect_animated(rewards, _show_rewards)

func _start_game() -> void:
	if available_sets.is_empty():
		return
	SetSelection.selected_path = selected_path
	SetSelection.mode = "free"
	SetSelection.campaign_index = -1
	Loader.go_to_main()

func _start_campaign_level(index: int) -> void:
	SetSelection.mode = "campaign"
	SetSelection.campaign_index = index
	Loader.go_to_main()

func _scroll_list(body: VBoxContainer, height: int = 260) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = height
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)
	return rows

# Kampagne: Level nacheinander freischalten (mind. 1 Stern im vorherigen Level).
func _show_campaign() -> void:
	current_page = "campaign"
	var body := _page(UI.text("campaign"))
	body.add_child(UI.label(UI.text("campaign_hint"), 16))
	var rows := _scroll_list(body, 300)
	for i in range(PlayerProgress.campaign.size()):
		var level_data: Dictionary = PlayerProgress.campaign[i]
		var unlocked := PlayerProgress.campaign_unlocked(i)
		var rules: Array[String] = [UI.text("campaign_pairs") % [int(level_data.get("pairs", 12))]]
		if int(level_data.get("time_limit", 0)) > 0:
			rules.append(UI.text("campaign_time") % [UI.time_text(float(level_data["time_limit"]))])
		if int(level_data.get("move_limit", 0)) > 0:
			rules.append(UI.text("campaign_moves") % [int(level_data["move_limit"])])
		var record := PlayerProgress.campaign_record(i)
		if record.has("best_time"):
			rules.append(UI.text("best_time") % [UI.time_text(float(record["best_time"]))])
		var title := "%d. %s" % [i + 1, str(level_data.get("name", ""))]
		if str(level_data.get("type", "")) == "boss":
			var is_final := bool(level_data.get("final", false))
			title = "%d. %s: %s" % [i + 1, UI.text("campaign_boss" if is_final else "campaign_miniboss"), str(level_data.get("name", ""))]
			rules = [UI.text("campaign_boss_rules" if is_final else "campaign_miniboss_rules") % [int(level_data.get("boss", {}).get("hp", 0))]]
			if record.has("best_time"):
				rules.append(UI.text("best_time") % [UI.time_text(float(record["best_time"]))])
		var status := UI.stars_text(PlayerProgress.campaign_stars(i)) if unlocked else UI.text("locked")
		var button := UI.button(title + "   " + status + "\n" + "  ·  ".join(rules), 66)
		button.add_theme_font_size_override("font_size", 17)
		button.disabled = not unlocked
		rows.add_child(button)
		if unlocked:
			UI.connect_animated(button, _start_campaign_level.bind(i))
	_back(_show_home)

# Belohnungen und Statistik.
func _show_rewards() -> void:
	current_page = "rewards"
	var body := _page(UI.text("rewards"))
	var info := PlayerProgress.level_info()
	body.add_child(UI.label(UI.text("level_line") % [int(info["level"]), int(info["current"]), int(info["needed"])], 20))
	body.add_child(UI.progress_bar(info["current"], info["needed"], 18))
	body.add_child(UI.label(UI.text("stats_line") % [
		PlayerProgress.stat("games_played"),
		PlayerProgress.stat("total_pairs"),
		UI.time_text(float(PlayerProgress.data.get("total_time", 0.0))),
		PlayerProgress.stat("best_streak"),
		PlayerProgress.campaign_completed_count(),
		PlayerProgress.campaign.size()
	], 16))
	var rows := _scroll_list(body, 240)
	for reward in PlayerProgress.rewards:
		var owned := PlayerProgress.has_reward(str(reward.get("id", "")))
		var mark := UI.text("reward_owned") if owned else UI.text("reward_locked")
		var line := UI.label(mark + "  " + str(reward.get("name", "")) + " – " + str(reward.get("description", "")), 17)
		if not owned:
			line.modulate = Color(1, 1, 1, 0.45)
		rows.add_child(line)
	_back(_show_home)

func _request_quit() -> void:
	if not bool(GameSettings.get_value("confirm_quit")):
		get_tree().quit()
		return
	current_page = "quit"
	var body := _page(UI.text("quit"))
	var confirm := UI.button(UI.text("quit_confirm"), 58, true)
	body.add_child(confirm)
	confirm.pressed.connect(func(): get_tree().quit())
	_back(_show_home)

# --- Einstellungen -------------------------------------------------------------

func _show_settings() -> void:
	current_page = "settings"
	var body := _page(UI.text("settings"))
	var rows := _scroll_list(body, 340)

	rows.add_child(_section(UI.text("settings_display")))
	_setting_toggle(rows, "fullscreen", "setting_fullscreen")
	_setting_option(rows, "card_text_scale", "setting_card_text", [
		[UI.text("setting_card_text_small"), 0.8],
		[UI.text("setting_card_text_normal"), 1.0],
		[UI.text("setting_card_text_large"), 1.2]
	])
	_setting_toggle(rows, "button_animations", "setting_button_animations")

	rows.add_child(_section(UI.text("settings_gameplay")))
	_setting_slider(rows, "mismatch_delay", "setting_mismatch_delay", 0.3, 2.0, 0.1)
	_setting_slider(rows, "pairs_per_round", "setting_pairs_per_round", 4, 12, 1)
	_setting_toggle(rows, "show_timer", "setting_show_timer")
	_setting_toggle(rows, "confirm_quit", "setting_confirm_quit")

	rows.add_child(_section(UI.text("settings_sound")))
	_setting_slider(rows, "master_volume", "setting_volume", 0, 100, 5)
	_setting_slider(rows, "music_volume", "setting_music", 0, 100, 5)
	_setting_slider(rows, "sfx_volume", "setting_sfx", 0, 100, 5)

	rows.add_child(_section(UI.text("settings")))
	if SetRepository.has_hidden_sets():
		var restore := UI.button(UI.text("restore_example"), 50)
		rows.add_child(restore)
		UI.connect_animated(restore, func():
			SetRepository.restore_hidden_sets()
			_reload_sets()
			_refresh_sidebar()
			_show_settings()
		)
	var reset_settings := UI.button(UI.text("settings_reset"), 50)
	rows.add_child(reset_settings)
	UI.connect_animated(reset_settings, func():
		GameSettings.reset_settings()
		_show_settings()
	)
	var reset := UI.button(UI.text("reset_progress"), 50)
	rows.add_child(reset)
	var confirm_state := {"armed": false}
	UI.connect_animated(reset, func():
		if not confirm_state["armed"]:
			confirm_state["armed"] = true
			reset.text = UI.text("reset_confirm")
			return
		PlayerProgress.reset_progress()
		get_tree().reload_current_scene()
	)

	# Admin-Code
	rows.add_child(_section(UI.text("admin_code")))
	if GameSettings.admin_unlocked:
		var open := UI.button(UI.text("admin_open"), 50, true)
		rows.add_child(open)
		UI.connect_animated(open, _show_admin)
	else:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		rows.add_child(line)
		var code_field := LineEdit.new()
		code_field.placeholder_text = UI.text("admin_code_placeholder")
		code_field.secret = true
		code_field.custom_minimum_size.y = 46
		code_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(code_field)
		var go := UI.button("OK", 46)
		go.custom_minimum_size.x = 60
		line.add_child(go)
		var error_label := UI.label("", 15)
		rows.add_child(error_label)
		var submit := func():
			if GameSettings.check_admin_code(code_field.text):
				_show_admin()
			else:
				error_label.text = UI.text("admin_wrong")
				code_field.clear()
		code_field.text_submitted.connect(func(_text: String): submit.call())
		go.pressed.connect(submit)
	_back(_show_home)

func _section(title: String) -> Label:
	var label := UI.label(title.to_upper(), 14)
	label.modulate = Color(1, 1, 1, 0.6)
	return label

func _setting_toggle(parent: Control, key: String, label_key: String) -> void:
	var toggle := CheckButton.new()
	toggle.text = UI.text(label_key)
	toggle.button_pressed = bool(GameSettings.get_value(key))
	toggle.add_theme_font_size_override("font_size", 17)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		toggle.add_theme_color_override(state, UI.color("text", "#f5f7f8"))
	parent.add_child(toggle)
	toggle.toggled.connect(func(on: bool): GameSettings.set_value(key, on))

func _setting_slider(parent: Control, key: String, label_key: String, min_value: float, max_value: float, step: float) -> void:
	var label := UI.label("", 17)
	parent.add_child(label)
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = float(GameSettings.get_value(key))
	slider.custom_minimum_size.y = 24
	parent.add_child(slider)
	var whole := step >= 1.0
	var update_label := func(value: float):
		if whole:
			label.text = UI.text(label_key) % [roundi(value)]
		else:
			label.text = UI.text(label_key) % [value]
	update_label.call(slider.value)
	slider.value_changed.connect(func(value: float):
		update_label.call(value)
		if whole:
			GameSettings.set_value(key, roundi(value))
		else:
			GameSettings.set_value(key, snappedf(value, step))
	)

func _setting_option(parent: Control, key: String, label_key: String, choices: Array) -> void:
	var line := HBoxContainer.new()
	parent.add_child(line)
	var label := UI.label(UI.text(label_key), 17)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size.x = 140
	var current := float(GameSettings.get_value(key))
	for i in range(choices.size()):
		option.add_item(str(choices[i][0]), i)
		if is_equal_approx(float(choices[i][1]), current):
			option.select(i)
	line.add_child(option)
	option.item_selected.connect(func(index: int): GameSettings.set_value(key, choices[index][1]))

# --- Admin-Panel ---------------------------------------------------------------

func _show_admin() -> void:
	if not GameSettings.admin_unlocked:
		_show_settings()
		return
	current_page = "admin"
	var body := _page(UI.text("admin_title"))
	body.add_child(UI.label(UI.text("admin_hint"), 15))
	var status := UI.label("", 15)
	var rows := _scroll_list(body, 300)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	rows.add_child(grid)
	var actions := [
		[UI.text("admin_unlock_campaign"), func(): PlayerProgress.admin_unlock_campaign()],
		[UI.text("admin_max_stars"), func(): PlayerProgress.admin_max_stars()],
		[UI.text("admin_reset_campaign"), func(): PlayerProgress.admin_reset_campaign()],
		[UI.text("admin_goto_boss"), func(): _start_campaign_level(PlayerProgress.boss_index())],
		[UI.text("admin_xp_plus") % [100], func(): PlayerProgress.admin_add_xp(100)],
		[UI.text("admin_xp_plus") % [1000], func(): PlayerProgress.admin_add_xp(1000)],
		[UI.text("admin_xp_minus") % [100], func(): PlayerProgress.admin_add_xp(-100)],
		[UI.text("reset_progress"), func(): PlayerProgress.reset_progress()],
		[UI.text("admin_unlock_rewards"), func(): PlayerProgress.admin_unlock_rewards()],
		[UI.text("admin_lock_rewards"), func(): PlayerProgress.admin_lock_rewards()]
	]
	for action in actions:
		var button := UI.button(str(action[0]), 46)
		button.add_theme_font_size_override("font_size", 16)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(button)
		var callback: Callable = action[1]
		button.pressed.connect(func():
			callback.call()
			_update_level_badge()
			status.text = UI.text("admin_done")
		)
	for toggle_data in [["god_mode", "admin_god_mode"], ["one_hit_boss", "admin_one_hit"], ["reveal_cards", "admin_reveal"]]:
		var toggle := CheckButton.new()
		toggle.text = UI.text(toggle_data[1])
		toggle.button_pressed = bool(GameSettings.get(toggle_data[0]))
		toggle.add_theme_font_size_override("font_size", 16)
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			toggle.add_theme_color_override(state, UI.color("text", "#f5f7f8"))
		rows.add_child(toggle)
		var property: String = toggle_data[0]
		toggle.toggled.connect(func(on: bool): GameSettings.set(property, on))
	var path_label := UI.label(UI.text("admin_save_path") % [ProjectSettings.globalize_path("user://")], 13)
	path_label.modulate = Color(1, 1, 1, 0.6)
	rows.add_child(path_label)
	body.add_child(status)
	_back(_show_settings)

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
	var button := UI.art_button(UI.text("back"), "back", 58)
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
	var status := UI.label(UI.text("select_hint"), 16)
	for item in available_sets:
		var path := str(item["path"])
		if not SetRepository.can_delete(path):
			continue
		if item["custom"]:
			custom_count += 1
		var prefix := "✓  " if path == selected_path else ""
		var label := prefix + str(item["name"]) + "  ·  " + str(item["count"]) + " " + UI.text("pairs_suffix")
		if item["custom"] and str(item["topic"]) != SetRepository.CUSTOM_TOPIC:
			label += "  ·  " + str(item["topic"])
		var record := PlayerProgress.set_record(path)
		if record.has("best_time"):
			label += "  ·  " + UI.text("best_time") % [UI.time_text(float(record["best_time"]))]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 8)
		set_rows.add_child(line)
		var button := UI.button(label, 62)
		button.add_theme_font_size_override("font_size", 18)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(button)
		UI.connect_animated(button, _select_set.bind(path))
		# Löschen mit Nachfrage: erster Klick fragt, zweiter löscht.
		var delete := UI.button(UI.text("delete"), 62)
		delete.custom_minimum_size.x = 104
		delete.add_theme_font_size_override("font_size", 16)
		line.add_child(delete)
		var armed := {"value": false}
		delete.pressed.connect(func():
			if not armed["value"]:
				armed["value"] = true
				delete.text = UI.text("delete_confirm")
				delete.modulate = Color(1.3, 0.6, 0.6)
				return
			var result := SetRepository.delete_set(path)
			if result.has("error"):
				delete.text = UI.text("delete")
				delete.modulate = Color.WHITE
				armed["value"] = false
				status.text = str(result["error"])
				return
			_show_sets()
		)
	if custom_count == 0:
		set_rows.add_child(UI.label(UI.text("empty_sets"), 18))
	body.add_child(status)
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
	# Kategorie ist freiwillig. Leer = "Eigene Sets".
	body.add_child(UI.label(UI.text("category_label"), 16))
	var category_field := LineEdit.new()
	category_field.placeholder_text = UI.text("category_placeholder")
	category_field.custom_minimum_size.y = 46
	body.add_child(category_field)
	var existing := _custom_categories()
	if not existing.is_empty():
		var chips := HFlowContainer.new()
		chips.add_theme_constant_override("h_separation", 8)
		chips.add_theme_constant_override("v_separation", 8)
		body.add_child(chips)
		for category in existing:
			var chip := UI.button(category, 36)
			chip.autowrap_mode = TextServer.AUTOWRAP_OFF
			chip.custom_minimum_size.x = 0
			chip.add_theme_font_size_override("font_size", 15)
			chips.add_child(chip)
			chip.pressed.connect(func(): category_field.text = category)
	var error_label := UI.label("", 16)
	body.add_child(error_label)
	var next := UI.button(UI.text("continue"), 60)
	body.add_child(next)
	UI.connect_animated(next, func():
		var name := name_field.text.strip_edges()
		if name.is_empty():
			error_label.text = UI.text("error_name")
		else:
			_show_editor(name, category_field.text.strip_edges())
	)
	_back(_show_add_options)

# Alle Kategorien, die eigene Sets schon haben (ohne "Eigene Sets").
func _custom_categories() -> Array[String]:
	var result: Array[String] = []
	for item in available_sets:
		var topic := str(item.get("topic", ""))
		if bool(item.get("custom", false)) and topic != SetRepository.CUSTOM_TOPIC and not result.has(topic):
			result.append(topic)
	result.sort()
	return result

func _show_editor(set_name: String, category: String = "") -> void:
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
	UI.connect_animated(save, func(): _save_entries(set_name, category, rows, error_label))
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

func _save_entries(set_name: String, category: String, rows: Array[Dictionary], error_label: Label) -> void:
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
	var result: Dictionary = SetRepository.save_set(set_name, entries, category)
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
