extends Node3D

const UI = preload("res://scripts/MenuUI.gd")
const BossArenaScript = preload("res://scripts/BossArena.gd")
const BOSS_CARD_TILT := 34.0
# Welcher Sound zu welchem Angriff gehört
const STRIKE_SOUNDS := {"bell": "bell", "bells": "bell", "toll": "bell", "blades": "blade", "reap": "blade", "slash": "blade",
	"bone_spikes": "bones", "skulls": "bones", "bone_armor": "bones", "roots": "roots", "herd": "roots", "root_self": "roots",
	"stomp": "stomp", "slam": "stomp", "spores": "spores", "ash": "spores", "orb": "impact", "curse": "impact"}
const BOSS_CARD_LIFT := 0.24
const BOSS_ROW_STEP := 0.12       # so viel höher schwebt jede Reihe weiter hinten (ohne Rampe darunter)
const BOSS_ROW_GROWTH := 0.09     # jede Reihe weiter hinten bekommt so viel mehr Abstand (Perspektive)
const BOSS_BACK_TILT := 20.0      # hintere Reihen stehen so viel steiler zur Kamera (sonst sieht man sie zu flach)
const BOSS_ROW_SPREAD := 1.42     # Reihen im Bossfight weiter auseinander, damit der Text sichtbar bleibt

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
var stats_label: Label
var vocabulary: Array = []
var next_word_index := 0
var completed_pairs := 0
var round_number := 0
var round_count := 0
var round_marker: Label3D
var pairs_per_round := 12

# Modus, Zeit und Wertung
var mode := "free"
var campaign_index := -1
var level_data: Dictionary = {}
var set_info: Dictionary = {}
var time_limit := 0.0
var move_limit := 0
var elapsed := 0.0
var timer_running := false
var attempts := 0
var streak := 0
var best_streak := 0
var points := 0
var game_over := false

# Bossfight
var is_boss := false
var boss_cfg: Dictionary = {}
var boss_hp := 0
var boss_max_hp := 1
var player_hp := 0
var player_max_hp := 1
var attack_timer := 0.0
var raging := false
var effects_layer: CanvasLayer
var arena: Node3D
var attack_running := false
var attack_windup := false
var attack_interrupted := false
var heart_open := false
var boss_state := ""        # "ash" oder "armor" während einer Fähigkeit
var boss_bar: ProgressBar
var boss_hp_label: Label
var boss_status_label: Label
var player_bar: ProgressBar
var player_hp_label: Label
var message_label: Label
var hit_flash: ColorRect

func _ready() -> void:
	randomize()
	mode = SetSelection.mode
	campaign_index = SetSelection.campaign_index
	var paths: Array = []
	if mode == "campaign":
		level_data = PlayerProgress.campaign_level(campaign_index)
		if level_data.is_empty():
			mode = "free"
		else:
			is_boss = str(level_data.get("type", "")) == "boss"
			if level_data.has("sets"):
				paths = level_data["sets"]
			else:
				paths = [str(level_data.get("set", vocabulary_path))]
			time_limit = float(level_data.get("time_limit", 0))
			move_limit = int(level_data.get("move_limit", 0))
	if mode == "free":
		if not SetSelection.selected_path.is_empty():
			vocabulary_path = SetSelection.selected_path
		paths = [vocabulary_path]
		pairs_per_round = clampi(int(GameSettings.get_value("pairs_per_round")), 2, 12)
	vocabulary_path = str(paths[0])
	set_info = SetRepository.find_set(vocabulary_path)
	_build_overlay()
	if is_boss:
		_setup_boss()
	if not _load_vocabulary(paths):
		return
	vocabulary.shuffle()
	if mode == "campaign" and not is_boss:
		var wanted := int(level_data.get("pairs", 12))
		vocabulary = vocabulary.slice(0, mini(wanted, vocabulary.size()))
	round_count = ceili(float(vocabulary.size()) / float(pairs_per_round))
	_generate_grid()
	timer_running = true
	_update_stats()
	# Grafikqualität (Schatten, Nebel, Glühen) aus den Einstellungen anwenden
	GameSettings.apply_graphics(self)
	# Musik: jeder Boss hat sein eigenes Thema, sonst das Stück aus den Einstellungen
	if is_boss:
		MusicPlayer.play(str(boss_cfg.get("look", {}).get("music", "game")))
	else:
		MusicPlayer.play_game()

func _process(delta: float) -> void:
	if not timer_running or game_over:
		return
	var before := elapsed
	elapsed += delta
	# letzte 10 Sekunden: Ticken
	if time_limit > 0.0 and time_limit - elapsed <= 10.0 and floori(time_limit - before) != floori(time_limit - elapsed):
		SoundFX.play("tick", -2.0 if time_limit - elapsed <= 5.0 else -6.0, 0.0)
	if time_limit > 0.0 and elapsed >= time_limit:
		elapsed = time_limit
		_finish(false, "time")
	if is_boss and not game_over:
		if not attack_running:
			attack_timer -= delta
			if attack_timer <= 0.0:
				_boss_attack()
		_update_boss_ui()
	_update_stats()

func _load_vocabulary(paths: Array) -> bool:
	var combined: Array = []
	for path in paths:
		var file := FileAccess.open(str(path), FileAccess.READ)
		if file == null:
			push_error("Das Vokabelset konnte nicht geladen werden: " + str(path))
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
		combined.append_array(parsed)
	vocabulary = combined
	return true

func _generate_grid() -> void:
	round_number += 1
	# Karten werden ausgeteilt
	SoundFX.play("deal", -4.0, 0.0)
	matches_found = 0
	first_card = null
	second_card = null
	can_click = true
	# Im Bossfight gehen die Wörter nie aus: neu mischen und von vorne.
	if is_boss and next_word_index >= vocabulary.size():
		vocabulary.shuffle()
		next_word_index = 0
	var remaining := vocabulary.size() - next_word_index
	total_pairs = mini(pairs_per_round, remaining)
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
	# Im Bossfight liegt das ganze Spielfeld auf einer schrägen Platte,
	# die Karten liegen flach darauf (gleicher Winkel wie die Platte).
	for slot in slot_pairs:
		var flat := Vector3(slot.x * card_spacing - offset_x, 0, slot.y * card_spacing - offset_z)
		if is_boss:
			# Jede Karte einzeln schräg zur Kamera, die Platte liegt flach
			# Hintere Reihen stufenweise höher (wie eine Tribüne), damit man ihren Text sieht
			var depth := (grid_rows - 1) - slot.y
			# Hinten wirken die Reihen durch die Perspektive enger, darum wächst der Abstand nach hinten
			var z := offset_z * BOSS_ROW_SPREAD
			for k in range(depth):
				z -= card_spacing * BOSS_ROW_SPREAD * (1.0 + BOSS_ROW_GROWTH * k)
			flat = Vector3(flat.x, BOSS_CARD_LIFT + depth * BOSS_ROW_STEP, z)
		positions.append(flat)
	var text_scale := float(GameSettings.get_value("card_text_scale"))
	for i in range(entries.size()):
		var card: Card = card_scene.instantiate()
		card.card_id = entries[i]["id"]
		card.word_text = entries[i]["text"]
		card.text_scale = text_scale
		# Normaler Modus: Karten drehen sich in 3D über die Kante um
		card.flip3d = not is_boss
		if is_boss:
			card.tilt_deg = _boss_tilt(positions[i])
			card.text_scale = text_scale * 1.2
			card.face_glow = 0.0
		card.back_material = back_material
		card.front_material = symbol_materials[0]
		card.position = positions[i]
		add_child(card)
		card.card_clicked.connect(_on_card_clicked)
		cards.append(card)
	_update_progress()
	if is_boss:
		round_marker.text = UI.text("game_round_boss") % [round_number]
	else:
		round_marker.text = UI.text("game_round") % [round_number, round_count]
	if GameSettings.reveal_cards:
		_reveal_preview()

# Admin: alle Karten kurz zeigen.
func _reveal_preview() -> void:
	can_click = false
	await get_tree().process_frame
	for card in cards:
		card.flip_up()
	await get_tree().create_timer(2.0).timeout
	if game_over or not is_inside_tree():
		return
	for card in cards:
		card.flip_down()
	await get_tree().create_timer(0.35).timeout
	can_click = true

func _on_card_clicked(card: Card) -> void:
	if not can_click or game_over:
		return
	card.flip_up()
	if first_card == null:
		first_card = card
		return
	second_card = card
	can_click = false
	_check_match()

func _check_match() -> void:
	await get_tree().create_timer(float(GameSettings.get_value("mismatch_delay"))).timeout
	if game_over:
		return
	attempts += 1
	if first_card.card_id == second_card.card_id:
		first_card.set_matched()
		second_card.set_matched()
		SoundFX.play("match")
		matches_found += 1
		completed_pairs += 1
		streak += 1
		best_streak = maxi(best_streak, streak)
		# Serie ohne Fehler: ab 3 Paaren ein aufsteigender Klang
		if streak >= 3 and streak % 2 == 1:
			SoundFX.play("streak", -3.0, 0.0)
		points += PlayerProgress.points_for_match(streak)
		_update_progress()
		_update_stats()
		if is_boss:
			_damage_boss(first_card, second_card)
			if game_over:
				return
		if matches_found >= total_pairs:
			first_card = null
			second_card = null
			if not is_boss and completed_pairs >= vocabulary.size():
				_finish(true, "done")
			else:
				progress_label.text = UI.text("game_next") % round_number
				timer_running = false
				await get_tree().create_timer(1.2).timeout
				if not is_inside_tree() or game_over:
					return
				_next_round()
				timer_running = true
			return
	else:
		streak = 0
		SoundFX.play("mismatch")
		first_card.flip_down()
		second_card.flip_down()
		if is_boss:
			var amount := int(boss_cfg.get("mismatch_damage", 2))
			var message := ""
			if first_card.cursed or second_card.cursed:
				amount *= int(boss_cfg.get("curse_multiplier", 3))
				message = UI.text("boss_curse_hit") % [amount]
			_damage_player(amount, message)
			if game_over:
				return
	_update_stats()
	first_card = null
	second_card = null
	if move_limit > 0 and attempts >= move_limit:
		_finish(false, "moves")
		return
	can_click = true

func _next_round() -> void:
	SoundFX.play("round", -2.0, 0.0)
	for card in cards:
		remove_child(card)
		card.queue_free()
	cards.clear()
	_generate_grid()

func _update_progress() -> void:
	var text := ""
	if is_boss:
		text = UI.text("game_boss_progress") % [str(level_data.get("name", "")), round_number, completed_pairs]
	else:
		text = UI.text("game_progress") % [round_number, round_count, matches_found, total_pairs, completed_pairs, vocabulary.size()]
		if mode == "campaign":
			text = UI.text("game_campaign_prefix") % [campaign_index + 1, str(level_data.get("name", ""))] + "  ·  " + text
	progress_label.text = text

func _update_stats() -> void:
	var parts: Array[String] = []
	if time_limit > 0.0:
		parts.append(UI.text("hud_time_limit") % [UI.time_text(time_limit - elapsed)])
	elif bool(GameSettings.get_value("show_timer")):
		parts.append(UI.text("hud_time") % [UI.time_text(elapsed)])
	if move_limit > 0:
		parts.append(UI.text("hud_attempts_limit") % [attempts, move_limit])
	else:
		parts.append(UI.text("hud_attempts") % [attempts])
	parts.append(UI.text("hud_hits") % [completed_pairs])
	parts.append(UI.text("hud_points") % [points])
	stats_label.text = "  ·  ".join(parts)

# --- Bossfight ---------------------------------------------------------------

func _setup_boss() -> void:
	boss_cfg = level_data.get("boss", {})
	boss_max_hp = maxi(1, int(boss_cfg.get("hp", 280)))
	if GameSettings.one_hit_boss:
		boss_max_hp = 1
	boss_hp = boss_max_hp
	player_max_hp = maxi(1, int(boss_cfg.get("player_hp", 100)))
	player_hp = player_max_hp
	attack_timer = float(boss_cfg.get("first_attack", 12))
	# Der Hintergrund der normalen Runden gehört nicht in die Boss-Arena
	var normal_bg := get_node_or_null("Hintergrund")
	if normal_bg != null:
		remove_child(normal_bg)
		normal_bg.free()
	# Gothic-Arena mit 3D-Boss
	arena = BossArenaScript.new()
	# Platte folgt der Tribüne: leicht nach hinten ansteigend
	var rise := BOSS_ROW_STEP * (grid_rows - 1)
	var run := card_spacing * BOSS_ROW_SPREAD * (grid_rows - 1)
	arena.board_tilt = rad_to_deg(atan(rise / run))
	arena.board_lift = BOSS_CARD_LIFT + rise / 2.0 - 0.42
	arena.board_depth = (grid_rows - 1) * card_spacing * BOSS_ROW_SPREAD + 1.8
	add_child(arena)
	arena.build(self, boss_cfg.get("look", {}))
	# Karten passend zur Arena: dunkle Rückseite mit rotem Schimmer
	var back := StandardMaterial3D.new()
	back.albedo_color = Color(0.16, 0.06, 0.07)
	back.emission_enabled = true
	back.emission = Color(0.5, 0.03, 0.03)
	back.emission_energy_multiplier = 0.35
	back.roughness = 0.4
	back.metallic = 0.3
	back_material = back
	var front := StandardMaterial3D.new()
	front.albedo_color = Color(0.92, 0.88, 0.8)
	front.emission_enabled = true
	front.emission = Color(0.92, 0.88, 0.8)
	front.emission_energy_multiplier = 0.35
	symbol_materials = [front]
	_build_boss_ui()
	_update_boss_ui()

func _damage_boss(card_a: Card, card_b: Card) -> void:
	var damage := int(boss_cfg.get("damage_per_pair", 10)) + int(boss_cfg.get("combo_bonus", 5)) * maxi(streak - 1, 0)
	var extra := ""
	if card_a.cursed or card_b.cursed:
		damage *= 2
		extra = UI.text("boss_curse_broken")
		for card in [card_a, card_b]:
			card.cursed = false
			arena.remove_curse_marker(card)
	if heart_open:
		damage *= 2
		extra = UI.text("boss_heart_hit")
	if boss_state == "armor":
		damage = ceili(damage * 0.5)
		extra = UI.text("boss_armor_hit")
	elif boss_state == "ash":
		# In Asche trifft man sie nicht, aber das Paar heilt dich.
		damage = 0
		player_hp = mini(player_max_hp, player_hp + int(boss_cfg.get("ash_heal", 4)))
		extra = UI.text("boss_ash_hit")
	# Ein Paar während des Ausholens unterbricht den Angriff.
	if attack_windup and not attack_interrupted:
		attack_interrupted = true
		damage += int(boss_cfg.get("interrupt_bonus", 10))
		extra = UI.text("boss_interrupted")
		SoundFX.play("interrupt")
		arena.stagger()
	boss_hp = maxi(0, boss_hp - damage)
	SoundFX.play("boss_hit", -2.0)
	player_hp = mini(player_max_hp, player_hp + int(boss_cfg.get("heal_per_pair", 0)))
	var popup := UI.text("boss_damage") % [damage]
	if streak > 1:
		popup += "  " + UI.text("boss_combo") % [streak]
	arena.fire_beam(card_a.position)
	arena.fire_beam(card_b.position)
	arena.damage_number(popup, Color(1.0, 0.85, 0.3))
	if not extra.is_empty():
		_show_message(extra, Color(1.0, 0.9, 0.5))
	if not raging and float(boss_hp) <= float(boss_max_hp) * float(boss_cfg.get("rage_at", 0.5)):
		raging = true
		SoundFX.play("roar")
		arena.set_rage(true)
		attack_timer = minf(attack_timer, float(boss_cfg.get("rage_interval", 16)))
		_show_message(UI.text("boss_rage") % [str(level_data.get("name", ""))], Color(1, 0.4, 0.3))
	_update_boss_ui()
	if boss_hp <= 0:
		_finish(true, "boss")

func _damage_player(amount: int, message: String) -> void:
	if GameSettings.god_mode:
		amount = 0
	player_hp = maxi(0, player_hp - amount)
	if amount > 0:
		SoundFX.play("player_hurt")
		_popup(UI.text("boss_damage") % [amount], Color(1, 0.35, 0.35), player_bar)
		_hit_flash()
	if not message.is_empty():
		_show_message(message, Color(1, 0.55, 0.45))
	_update_boss_ui()
	if player_hp <= 0:
		_finish(false, "defeated")

# --- Boss-Angriffe -------------------------------------------------------------
# Ablauf: Ausholen (Warnung auf den Zielkarten) -> Treffer -> Karten fliegen weg.
# Wer während des Ausholens ein Paar findet, unterbricht den Angriff.

func _boss_attack() -> void:
	if attack_running or game_over:
		return
	attack_running = true
	_run_attack()

func _hidden_cards() -> Array[Card]:
	var hidden: Array[Card] = []
	for card in cards:
		if is_instance_valid(card) and not card.is_matched and not card.is_flipped and card != first_card and card != second_card:
			hidden.append(card)
	return hidden

# Welche Angriffe ein Boss hat, steht in campaign.json ("attacks" / "rage_attacks").
# Mehrfach genannte Angriffe kommen öfter vor.
func _pick_attack() -> String:
	var normal: Array = boss_cfg.get("attacks", ["orb", "orb", "slash", "curse"])
	var rage: Array = boss_cfg.get("rage_attacks", ["slam", "orb", "slash", "curse"])
	var pool: Array = rage if raging else normal
	if pool.is_empty():
		return "orb"
	return str(pool.pick_random())

func _run_attack() -> void:
	var kind := _pick_attack()
	var hidden := _hidden_cards()
	if hidden.size() < 2:
		kind = "slam"
	var targets: Array[Card] = []
	var row_z := 0.0
	var row_y := 0.0
	match kind:
		"orb":
			hidden.shuffle()
			for i in range(mini(2 if raging else 1, hidden.size())):
				targets.append(hidden[i])
		"curse":
			hidden.shuffle()
			if not hidden.is_empty():
				targets.append(hidden[0])
		"slash":
			# Reihe mit den meisten verdeckten Karten
			var rows := {}
			for card in hidden:
				var key := snappedf(card.position.z, 0.01)
				rows[key] = int(rows.get(key, 0)) + 1
			var best := -1
			for key in rows:
				if rows[key] > best:
					best = rows[key]
					row_z = key
			for card in hidden:
				if is_equal_approx(snappedf(card.position.z, 0.01), row_z):
					targets.append(card)
					row_y = card.position.y
		"roots":
			# Eine ganze Reihe oder Spalte mit möglichst vielen verdeckten Karten
			var lines := {}
			for card in hidden:
				for key in ["z%.2f" % card.position.z, "x%.2f" % card.position.x]:
					if not lines.has(key):
						lines[key] = []
					lines[key].append(card)
			var best_line: Array = []
			for key in lines:
				if lines[key].size() > best_line.size() or (lines[key].size() == best_line.size() and randf() < 0.5):
					best_line = lines[key]
			for card in best_line:
				targets.append(card)
		"herd", "spores", "blades", "skulls", "bell", "bells":
			hidden.shuffle()
			var counts := {"herd": 3 if raging else 2, "spores": 3, "blades": 3, "skulls": 4, "bell": 1, "bells": 2}
			for i in range(mini(int(counts[kind]), hidden.size())):
				targets.append(hidden[i])
		"reap", "bone_spikes":
			# Sichelhieb: eine Reihe. Knochenspitzen: eine Spalte.
			var groups := {}
			for card in hidden:
				var key := snappedf(card.position.z if kind == "reap" else card.position.x, 0.01)
				if not groups.has(key):
					groups[key] = []
				groups[key].append(card)
			var best_group: Array = []
			for key in groups:
				if groups[key].size() > best_group.size():
					best_group = groups[key]
			for card in best_group:
				targets.append(card)
			if kind == "reap" and not targets.is_empty():
				row_z = targets[0].position.z
				row_y = targets[0].position.y
	var boss_title := str(level_data.get("name", ""))
	attack_windup = true
	attack_interrupted = false
	arena.windup(kind)
	SoundFX.play("windup", -3.0, 0.02)
	if kind == "slash" or kind == "reap":
		arena.add_row_warning(Vector3(0, row_y, row_z))
	elif kind not in ["slam", "stomp", "root_self", "toll", "ash", "bone_armor"]:
		for card in targets:
			arena.add_warning(card)
	_show_message(UI.text("boss_windup_" + kind) % [boss_title], Color(1, 0.75, 0.4))
	await get_tree().create_timer(float(boss_cfg.get("windup_time", 2.4))).timeout
	attack_windup = false
	arena.clear_warnings()
	if game_over or not is_inside_tree():
		return
	if attack_interrupted:
		_end_attack()
		return
	arena.strike()
	SoundFX.play(STRIKE_SOUNDS.get(kind, "impact"))
	var damage := int(boss_cfg.get("attack_damage", 6))
	match kind:
		"orb":
			for card in targets:
				if not _still_hidden(card):
					continue
				await arena.cast_orb(card.position + Vector3(0, -0.3, 0))
				if game_over:
					return
				_swap_with_random(card)
			_damage_player(damage, UI.text("boss_hit_orb") % [boss_title, damage])
		"slash":
			await arena.slash_row(Vector3(0, row_y, row_z))
			if game_over:
				return
			_scatter(targets.filter(func(c): return _still_hidden(c)))
			_damage_player(damage, UI.text("boss_hit_slash") % [boss_title, damage])
		"slam":
			await arena.slam()
			if game_over:
				return
			_scatter(_hidden_cards())
			var big := roundi(damage * 1.5)
			_damage_player(big, UI.text("boss_hit_slam") % [boss_title, big])
		"curse":
			for card in targets:
				if not _still_hidden(card):
					continue
				await arena.cast_curse(card.position + Vector3(0, -0.3, 0))
				if game_over:
					return
				if _still_hidden(card):
					card.cursed = true
					arena.add_curse_marker(card)
			_show_message(UI.text("boss_hit_curse") % [boss_title], Color(0.8, 0.55, 1.0))
		"roots":
			var hit := targets.filter(func(c): return _still_hidden(c))
			await arena.root_spikes(hit.map(func(c): return c.position + Vector3(0, -0.3, 0)))
			if game_over:
				return
			_scatter(hit.filter(func(c): return _still_hidden(c)))
			_damage_player(damage, UI.text("boss_hit_roots") % [boss_title, damage])
		"herd":
			var runners := targets.filter(func(c): return _still_hidden(c))
			await arena.herd_run(runners.map(func(c): return c.position + Vector3(0, 0.1, 0)))
			if game_over:
				return
			for card in runners:
				if _still_hidden(card):
					_swap_with_random(card)
			_damage_player(damage, UI.text("boss_hit_herd") % [boss_title, damage])
		"spores":
			for card in targets:
				if _still_hidden(card):
					card.cursed = true
					arena.add_spore_cloud(card)
			_show_message(UI.text("boss_hit_spores") % [boss_title], Color(0.7, 0.95, 0.45))
		"stomp":
			await arena.stomp_wave()
			if game_over:
				return
			_scatter(_hidden_cards())
			var heavy := roundi(damage * 1.5)
			_damage_player(heavy, UI.text("boss_hit_stomp") % [boss_title, heavy])
		"root_self":
			await _root_self(boss_title)
			if game_over:
				return
		"bell", "bells":
			for card in targets:
				if not _still_hidden(card):
					continue
				await arena.bell_drop(card.position)
				if game_over:
					return
				# Die Glocke wirft die Karte und ihre Nachbarn durcheinander
				var near := _hidden_cards().filter(func(c): return c.position.distance_to(card.position) < card_spacing * 1.5)
				_scatter(near)
			_damage_player(damage, UI.text("boss_hit_bell") % [boss_title, damage])
		"toll":
			await arena.stomp_wave()
			if game_over:
				return
			var shaken := _hidden_cards()
			shaken.shuffle()
			_scatter(shaken.slice(0, ceili(shaken.size() / 2.0)))
			_damage_player(damage, UI.text("boss_hit_toll") % [boss_title, damage])
		"blades":
			for card in targets:
				if not _still_hidden(card):
					continue
				await arena.throw_blade(card.position + Vector3(0, -0.2, 0))
				if game_over:
					return
				if _still_hidden(card):
					_swap_with_random(card)
			_damage_player(damage, UI.text("boss_hit_blades") % [boss_title, damage])
		"reap":
			await arena.slash_row(Vector3(0, row_y, row_z))
			if game_over:
				return
			_scatter(targets.filter(func(c): return _still_hidden(c)))
			_damage_player(damage, UI.text("boss_hit_reap") % [boss_title, damage])
		"ash":
			await _timed_state("ash", boss_title)
			if game_over:
				return
		"bone_spikes":
			var column := targets.filter(func(c): return _still_hidden(c))
			await arena.root_spikes(column.map(func(c): return c.position + Vector3(0, -0.3, 0)), true)
			if game_over:
				return
			_scatter(column.filter(func(c): return _still_hidden(c)))
			_damage_player(damage, UI.text("boss_hit_bone_spikes") % [boss_title, damage])
		"skulls":
			for card in targets:
				if not _still_hidden(card):
					continue
				await arena.skull_drop(card.position)
				if game_over:
					return
				if _still_hidden(card):
					_swap_with_random(card)
			_damage_player(damage, UI.text("boss_hit_skulls") % [boss_title, damage])
		"bone_armor":
			await _timed_state("armor", boss_title)
			if game_over:
				return
	_end_attack()

# Zustände, die eine Weile dauern: "ash" (unverwundbar, Paare heilen dich)
# und "armor" (Knochenpanzer, nur halber Schaden).
func _timed_state(state: String, boss_title: String) -> void:
	boss_state = state
	if state == "ash":
		arena.ash_vanish(true)
	else:
		arena.bone_armor(true)
	_show_message(UI.text("boss_state_" + state) % [boss_title], Color(0.85, 0.9, 1.0))
	await get_tree().create_timer(float(boss_cfg.get(state + "_duration", 5.0))).timeout
	if game_over or not is_inside_tree():
		return
	boss_state = ""
	if state == "ash":
		arena.ash_vanish(false)
	else:
		arena.bone_armor(false)
	_show_message(UI.text("boss_state_end_" + state) % [boss_title], Color(1, 0.75, 0.4))

# Verwurzeln: Er steht still, sein Herz liegt offen (Paare machen doppelten Schaden),
# aber Wurzeln schlagen immer wieder unter einzelnen Karten aus.
func _root_self(boss_title: String) -> void:
	heart_open = true
	arena.set_rooted(true)
	_show_message(UI.text("boss_hit_root_self") % [boss_title], Color(0.75, 1.0, 0.45))
	var duration := float(boss_cfg.get("root_duration", 7.0))
	var lash_every := float(boss_cfg.get("root_lash_every", 1.6))
	var elapsed_root := 0.0
	while elapsed_root < duration:
		await get_tree().create_timer(lash_every).timeout
		elapsed_root += lash_every
		if game_over or not is_inside_tree():
			return
		var hidden := _hidden_cards()
		if hidden.size() >= 2:
			var victim: Card = hidden.pick_random()
			await arena.root_lash(victim.position + Vector3(0, -0.3, 0))
			if game_over:
				return
			if _still_hidden(victim):
				_swap_with_random(victim)
	heart_open = false
	arena.set_rooted(false)
	_show_message(UI.text("boss_root_end") % [boss_title], Color(1, 0.75, 0.4))

func _end_attack() -> void:
	if arena != null:
		arena.finish_attack()
	attack_running = false
	attack_timer = float(boss_cfg.get("rage_interval" if raging else "attack_interval", 25))

func _still_hidden(card: Card) -> bool:
	return is_instance_valid(card) and cards.has(card) and not card.is_matched and not card.is_flipped and card != first_card and card != second_card

# Getroffene Karte tauscht den Platz mit einer anderen verdeckten Karte.
func _swap_with_random(card: Card) -> void:
	var others := _hidden_cards().filter(func(c): return c != card)
	if others.is_empty():
		return
	var other: Card = others.pick_random()
	var a := card.position
	_hop_card(card, other.position)
	_hop_card(other, a)

# Mehrere Karten werden untereinander durcheinandergewirbelt.
func _scatter(list: Array) -> void:
	if list.size() < 2:
		var all := _hidden_cards()
		if list.size() == 1 and all.size() > 1:
			_swap_with_random(list[0])
		return
	var positions: Array[Vector3] = []
	for card in list:
		positions.append(card.position)
	var shuffled := positions.duplicate()
	for attempt in range(5):
		shuffled.shuffle()
		if shuffled != positions:
			break
	for i in range(list.size()):
		_hop_card(list[i], shuffled[i])

# Karte fliegt im Bogen an eine neue Stelle (dreht sich dabei, bleibt verdeckt).
func _hop_card(card: Card, to: Vector3) -> void:
	var from := card.position
	var height := randf_range(1.2, 2.0)
	var spin := randf_range(-25.0, 25.0)
	var tilt_from := card.tilt_deg
	var tilt_to := _boss_tilt(to) if is_boss else tilt_from
	var tween := card.create_tween()
	tween.tween_method(func(t: float):
		if is_instance_valid(card):
			card.position = from.lerp(to, t) + Vector3(0, sin(t * PI) * height, 0)
			card.spin_deg = sin(t * PI) * spin
			card.tilt_deg = lerpf(tilt_from, tilt_to, t)
	, 0.0, 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		if is_instance_valid(card):
			card.position = to
			card.spin_deg = 0.0
			card.tilt_deg = tilt_to
	)

func _update_boss_ui() -> void:
	if boss_bar == null:
		return
	boss_bar.max_value = boss_max_hp
	boss_bar.value = boss_hp
	boss_hp_label.text = UI.text("boss_hp") % [boss_hp, boss_max_hp]
	player_bar.max_value = player_max_hp
	player_bar.value = player_hp
	player_hp_label.text = UI.text("player_hp") % [player_hp, player_max_hp]
	if attack_windup:
		boss_status_label.text = UI.text("boss_status_windup")
	elif attack_running:
		boss_status_label.text = ""
	else:
		boss_status_label.text = UI.text("boss_next_attack") % [ceili(maxf(attack_timer, 0.0))]
	if raging:
		boss_status_label.text = UI.text("boss_raging") + "  ·  " + boss_status_label.text

# Boss-Leiste unten in der Mitte, eigene Lebensleiste oben links.
func _build_boss_ui() -> void:
	effects_layer = CanvasLayer.new()
	effects_layer.layer = 5
	add_child(effects_layer)
	hit_flash = ColorRect.new()
	hit_flash.color = Color(0.6, 0, 0, 0)
	hit_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hit_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effects_layer.add_child(hit_flash)

	var boss_box := VBoxContainer.new()
	boss_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	boss_box.offset_left = -380
	boss_box.offset_right = 380
	boss_box.offset_top = -56
	boss_box.offset_bottom = -10
	boss_box.add_theme_constant_override("separation", 4)
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_layer.add_child(boss_box)
	var name_row := HBoxContainer.new()
	boss_box.add_child(name_row)
	var boss_name := _outlined(str(level_data.get("name", "")), 24, Color(0.95, 0.88, 0.78))
	# Schrift Cinzel (aus "Claude 1", OFL-Lizenz) für den Boss-Namen
	if ResourceLoader.exists("res://assets/hain/fonts/Cinzel-Bold.ttf"):
		boss_name.add_theme_font_override("font", load("res://assets/hain/fonts/Cinzel-Bold.ttf"))
	name_row.add_child(boss_name)
	boss_status_label = _outlined("", 15, Color(1, 0.75, 0.6))
	boss_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_row.add_child(boss_status_label)
	boss_hp_label = _outlined("", 16, Color(0.95, 0.85, 0.75))
	name_row.add_child(boss_hp_label)
	boss_bar = _hp_bar(Color("#a01818"), 12)
	boss_box.add_child(boss_bar)

	var player_box := VBoxContainer.new()
	player_box.position = Vector2(22, 96)
	player_box.custom_minimum_size = Vector2(300, 0)
	player_box.add_theme_constant_override("separation", 4)
	player_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_layer.add_child(player_box)
	player_hp_label = _outlined("", 17, Color(0.85, 1, 0.85))
	player_box.add_child(player_hp_label)
	player_bar = _hp_bar(Color("#3f9c5a"), 14)
	player_box.add_child(player_bar)

	message_label = _outlined("", 22, Color.WHITE)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	message_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	message_label.offset_left = -420
	message_label.offset_right = 420
	message_label.offset_top = -170
	message_label.offset_bottom = -100
	effects_layer.add_child(message_label)

func _outlined(text: String, size: int, color: Color) -> Label:
	var label := UI.label(text, size)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _hp_bar(fill: Color, height: int = 20) -> ProgressBar:
	var bar := UI.progress_bar(1, 1, height, fill)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar

func _popup(text: String, tint: Color, anchor: Control) -> void:
	if effects_layer == null or anchor == null:
		return
	var label := UI.label(text, 28)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.add_theme_color_override("font_color", tint)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_layer.add_child(label)
	var width := label.get_minimum_size().x
	var screen_width := get_viewport().get_visible_rect().size.x
	var x := clampf(anchor.global_position.x + (anchor.size.x - width) / 2.0, 8.0, screen_width - width - 8.0)
	label.position = Vector2(x, anchor.global_position.y + 10)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 60, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.chain().tween_callback(label.queue_free)

func _flash(control: Control, tint: Color) -> void:
	if control == null:
		return
	var tween := control.create_tween()
	tween.tween_property(control, "modulate", tint, 0.08)
	tween.tween_property(control, "modulate", Color.WHITE, 0.25)

func _hit_flash() -> void:
	var tween := hit_flash.create_tween()
	tween.tween_property(hit_flash, "color:a", 0.28, 0.06)
	tween.tween_property(hit_flash, "color:a", 0.0, 0.35)

func _show_message(text: String, tint: Color) -> void:
	if message_label == null:
		return
	message_label.text = text
	message_label.add_theme_color_override("font_color", tint)
	message_label.modulate.a = 1.0
	var tween := message_label.create_tween()
	tween.tween_interval(1.6)
	tween.tween_property(message_label, "modulate:a", 0.0, 0.6)

# --- Spielende ---------------------------------------------------------------

func _finish(won: bool, reason: String) -> void:
	if game_over:
		return
	game_over = true
	timer_running = false
	can_click = false
	var all_pairs := completed_pairs if is_boss else vocabulary.size()
	var stars := PlayerProgress.stars_for(won, attempts, all_pairs)
	var hp_ratio := float(player_hp) / float(player_max_hp) if is_boss else 0.0
	if is_boss:
		stars = 0
		if won:
			stars = 3 if hp_ratio > 0.66 else (2 if hp_ratio > 0.33 else 1)
	var bonus := 0
	if won:
		if is_boss:
			bonus += int(boss_cfg.get("reward_points", 250))
		else:
			bonus += PlayerProgress.time_bonus(all_pairs, elapsed)
		if mode == "campaign":
			bonus += stars * int(PlayerProgress.rule("star_bonus", 20))
	points += bonus
	_update_stats()
	if message_label != null:
		message_label.text = ""
	var result := {
		"set_path": vocabulary_path,
		"topic": str(set_info.get("topic", "")),
		"custom": bool(set_info.get("custom", false)),
		"mode": mode,
		"campaign_index": campaign_index,
		"won": won,
		"reason": reason,
		"pairs_found": completed_pairs,
		"total_pairs": all_pairs,
		"attempts": attempts,
		"time": elapsed,
		"best_streak": best_streak,
		"points": points,
		"bonus": bonus,
		"stars": stars,
		"boss": is_boss,
		"final_boss": is_boss and bool(level_data.get("final", false)),
		"player_hp_ratio": hp_ratio
	}
	var summary := PlayerProgress.record_game(result)
	SoundFX.play("victory" if won else "defeat")
	if int(summary["level_after"]) > int(summary["level_before"]):
		get_tree().create_timer(1.6).timeout.connect(func(): SoundFX.play("level_up"))
	elif not summary["new_rewards"].is_empty():
		get_tree().create_timer(1.6).timeout.connect(func(): SoundFX.play("reward"))
	if is_boss and arena != null:
		arena.clear_warnings()
		if won:
			_show_message(UI.text("boss_dies") % [str(level_data.get("name", ""))], Color(1, 0.85, 0.5))
			await arena.die()
		else:
			await get_tree().create_timer(0.8).timeout
		if not is_inside_tree():
			return
	_show_end_screen(result, summary)

func _show_end_screen(result: Dictionary, summary: Dictionary) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.panel())
	panel.custom_minimum_size.x = 600
	center.add_child(panel)
	var padding := MarginContainer.new()
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		padding.add_theme_constant_override(side, 28)
	panel.add_child(padding)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	padding.add_child(box)

	var won := bool(result["won"])
	var title_key := "end_won"
	match str(result["reason"]):
		"boss":
			title_key = "end_boss_won"
		"defeated":
			title_key = "end_defeated"
		"time":
			title_key = "end_time_up"
		"moves":
			title_key = "end_moves_up"
	var title := UI.label(UI.text(title_key), 34)
	title.add_theme_color_override("font_color", UI.TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	if won:
		var stars := UI.label(UI.stars_text(int(result["stars"])), 36)
		stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(stars)
		# für jeden Stern ein Klang, kurz nacheinander
		for k in range(int(result["stars"])):
			get_tree().create_timer(0.5 + k * 0.28).timeout.connect(func(): SoundFX.play("star", -2.0, 0.0))

	if is_boss:
		box.add_child(UI.label(UI.text("end_boss_stats") % [UI.time_text(float(result["time"])), int(result["attempts"]), int(result["pairs_found"]), player_hp, player_max_hp], 20))
	else:
		box.add_child(UI.label(UI.text("end_stats") % [UI.time_text(float(result["time"])), int(result["attempts"]), int(result["pairs_found"]), int(result["total_pairs"])], 20))
	var points_line := UI.text("end_points") % [int(result["points"])]
	if int(result["bonus"]) > 0:
		points_line += "  " + UI.text("end_bonus") % [int(result["bonus"])]
	box.add_child(UI.label(points_line, 20))
	if bool(summary["new_best_time"]):
		box.add_child(UI.label(UI.text("end_best_time"), 20))

	var info := PlayerProgress.level_info()
	if int(summary["level_after"]) > int(summary["level_before"]):
		box.add_child(UI.label(UI.text("end_level_up") % [int(summary["level_after"])], 22))
	box.add_child(UI.label(UI.text("level_line") % [int(info["level"]), int(info["current"]), int(info["needed"])], 18))
	box.add_child(UI.progress_bar(info["current"], info["needed"]))

	if bool(summary["unlocked_next"]):
		get_tree().create_timer(1.5).timeout.connect(func(): SoundFX.play("unlock", -3.0, 0.0))
		var next_level := PlayerProgress.campaign_level(campaign_index + 1)
		if str(next_level.get("type", "")) == "boss":
			box.add_child(UI.label(UI.text("end_unlocked_boss"), 20))
		else:
			box.add_child(UI.label(UI.text("end_unlocked") % [campaign_index + 2], 20))
	var reward_names: Array[String] = []
	for reward in summary["new_rewards"]:
		reward_names.append(str(reward.get("name", "")))
	if not reward_names.is_empty():
		box.add_child(UI.label(UI.text("end_reward") % [", ".join(reward_names)], 18))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	var retry := UI.art_button(UI.text("end_retry"), "retry", 58)
	retry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(retry)
	UI.connect_animated(retry, _restart)
	var has_next := mode == "campaign" and won and campaign_index + 1 < PlayerProgress.campaign.size() and PlayerProgress.campaign_unlocked(campaign_index + 1)
	if has_next:
		var next := UI.art_button(UI.text("end_next"), "next", 58)
		next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(next)
		UI.connect_animated(next, func():
			SetSelection.campaign_index = campaign_index + 1
			_restart()
		)
	var menu := UI.art_button(UI.text("end_menu"), "menu", 58)
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(menu)
	UI.connect_animated(menu, _go_to_menu)

func _restart() -> void:
	Loader.go_to_main(true)

func _go_to_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")

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
	var back := UI.art_button(UI.text("game_back"), "game_menu", 40)
	back.custom_minimum_size.x = 120
	bar.add_child(back)
	UI.connect_animated(back, _go_to_menu)
	var restart := UI.art_button(UI.text("game_restart"), "game_restart", 40)
	restart.custom_minimum_size.x = 165
	bar.add_child(restart)
	UI.connect_animated(restart, _restart)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(info)
	progress_label = _hud_label()
	info.add_child(progress_label)
	stats_label = _hud_label()
	info.add_child(stats_label)
	round_marker = Label3D.new()
	round_marker.position = Vector3(0, -0.40, 0)
	round_marker.rotation_degrees.x = -90
	round_marker.font_size = 28
	round_marker.pixel_size = 0.01
	round_marker.modulate = Color(0.9, 0.95, 1.0)
	add_child(round_marker)

func _hud_label() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", UI.font_size(20))
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	return label

# Neigung einer Karte im Bossfight: vorne BOSS_CARD_TILT, ganz hinten steiler.
func _boss_tilt(pos: Vector3) -> float:
	var front := (grid_rows - 1) * card_spacing / 2.0 * BOSS_ROW_SPREAD
	var depth := 0.0
	for k in range(grid_rows - 1):
		depth += card_spacing * BOSS_ROW_SPREAD * (1.0 + BOSS_ROW_GROWTH * k)
	var t := clampf((front - pos.z) / depth, 0.0, 1.0)
	return BOSS_CARD_TILT + t * BOSS_BACK_TILT
