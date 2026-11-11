extends Node
## Einstellungen, gespeichert in user://settings.json.
## Admin-Schalter (god_mode usw.) gelten nur bis das Spiel geschlossen wird.

const SAVE_PATH := "user://settings.json"
# SHA-256 des Admin-Codes, damit der Code nicht im Klartext im Projekt steht.
const ADMIN_HASH := "226e1c342e9b6d147efcd5f1b8a7a97e5e18c8fc78787cb58e1632c6768f384c"

const DEFAULTS := {
	"fullscreen": true,
	"master_volume": 80,
	"music_volume": 60,
	"sfx_volume": 80,
	"mismatch_delay": 0.6,
	"show_timer": true,
	"card_text_scale": 1.0,
	"button_animations": true,
	"pairs_per_round": 12,
	"confirm_quit": false,
	"graphics_quality": 1,   # 0 = Niedrig, 1 = Mittel, 2 = Hoch
	"particles": 1.0,        # 0 = aus, 0.4 = wenig, 1 = normal, 1.6 = viel
	"fps_limit": 60,         # 0 = unbegrenzt
	"vsync": true,
	"show_fps": false,
	"menu_music": "menu",     # menu, cafe, random, off
	"game_music": "game",     # game, promenade, valse, random, off
	"ui_sounds": true         # Klick, Hover, Seitenwechsel, Schalter …
}

var save_path := SAVE_PATH
var values: Dictionary = {}

# Nur für diese Sitzung
var admin_unlocked := false
var god_mode := false
var reveal_cards := false
var one_hit_boss := false

func _ready() -> void:
	load_settings()
	# Pixel-Theme für alle Menüs und Anzeigen (Schrift, Rahmen, Regler …)
	get_tree().root.theme = preload("res://scripts/MenuUI.gd").theme()
	_build_fps_label()
	get_tree().node_added.connect(_on_node_added)
	apply()

func load_settings() -> void:
	values = DEFAULTS.duplicate()
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for key in parsed:
			if DEFAULTS.has(key):
				values[key] = parsed[key]

func save_settings() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Einstellungen konnten nicht gespeichert werden.")
		return
	file.store_string(JSON.stringify(values, "  "))

func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))

func set_value(key: String, value: Variant) -> void:
	values[key] = value
	save_settings()
	apply()

func reset_settings() -> void:
	values = DEFAULTS.duplicate()
	save_settings()
	apply()

# Wendet Einstellungen an, die sofort wirken (Fenster, Lautstärke).
func apply() -> void:
	if DisplayServer.get_name() != "headless":
		var wanted := DisplayServer.WINDOW_MODE_FULLSCREEN if bool(get_value("fullscreen")) else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != wanted:
			DisplayServer.window_set_mode(wanted)
	var volume := clampf(float(get_value("master_volume")) / 100.0, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, volume <= 0.0)
	var music := get_node_or_null("/root/MusicPlayer")
	if music != null:
		music.apply_volume()
	_apply_performance()

func check_admin_code(code: String) -> bool:
	if code.strip_edges().sha256_text() == ADMIN_HASH:
		admin_unlocked = true
	return admin_unlocked

# --- Grafik, Partikel, FPS -------------------------------------------------------
# Niedrig: halbe Schattenauflösung, keine Schatten, kein Glühen und kein Volumen-Nebel,
#          3D wird mit 75 % gerendert und hochskaliert (FSR).
# Mittel:  ohne Umgebungsverdeckung (SSAO) und ohne Schatten von Fackeln/Kerzen.
# Hoch:    alles an.

const SHADOW_SIZES := [1024, 2048, 4096]
var fps_layer: CanvasLayer
var fps_label: Label

func quality() -> int:
	return clampi(int(get_value("graphics_quality")), 0, 2)

func _apply_performance() -> void:
	var q := quality()
	var vp := get_viewport()
	if vp != null:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if q == 0 else Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 0.75 if q == 0 else 1.0
		vp.positional_shadow_atlas_size = SHADOW_SIZES[q]
	RenderingServer.directional_shadow_atlas_set_size(SHADOW_SIZES[q], true)
	var soft: Array = [RenderingServer.SHADOW_QUALITY_HARD, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM]
	RenderingServer.directional_soft_shadow_filter_set_quality(soft[q])
	RenderingServer.positional_soft_shadow_filter_set_quality(soft[q])
	Engine.max_fps = maxi(0, int(get_value("fps_limit")))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(get_value("vsync")) else DisplayServer.VSYNC_DISABLED)
	if fps_layer != null:
		fps_layer.visible = bool(get_value("show_fps"))
	var scene := get_tree().current_scene if get_tree() != null else null
	if scene != null:
		apply_graphics(scene)
		for p in scene.find_children("*", "", true, false):
			if _is_particles(p):
				_scale_particles(p)

# Effekte der aktuellen Szene (Umgebung und Lichter) an die Qualität anpassen.
# Main.gd ruft das auf, nachdem die Arena gebaut ist.
func apply_graphics(node: Node) -> void:
	var q := quality()
	for world in node.find_children("*", "WorldEnvironment", true, false):
		var env: Environment = world.environment
		if env == null:
			continue
		if not env.has_meta("original"):
			env = env.duplicate()
			world.environment = env
			env.set_meta("original", {"ssao": env.ssao_enabled, "ssil": env.ssil_enabled, "ssr": env.ssr_enabled,
				"sdfgi": env.sdfgi_enabled, "volfog": env.volumetric_fog_enabled, "glow": env.glow_enabled})
		var o: Dictionary = env.get_meta("original")
		env.ssao_enabled = bool(o["ssao"]) and q >= 2
		env.ssil_enabled = bool(o["ssil"]) and q >= 2
		env.ssr_enabled = bool(o["ssr"]) and q >= 2
		env.sdfgi_enabled = bool(o["sdfgi"]) and q >= 2
		env.volumetric_fog_enabled = bool(o["volfog"]) and q >= 1
		env.glow_enabled = bool(o["glow"]) and q >= 1
	for light in node.find_children("*", "Light3D", true, false):
		if not light.has_meta("original_shadow"):
			light.set_meta("original_shadow", light.shadow_enabled)
		var wanted: bool = light.get_meta("original_shadow")
		if light is DirectionalLight3D:
			light.shadow_enabled = wanted and q >= 1
		else:
			light.shadow_enabled = wanted and q >= 2

func _is_particles(n: Node) -> bool:
	return n is CPUParticles3D or n is GPUParticles3D or n is CPUParticles2D or n is GPUParticles2D

func _on_node_added(n: Node) -> void:
	# Anzeigen in eigenen Ebenen (CanvasLayer) bekommen das Pixel-Theme auch
	if n is Control and not n.get_parent() is Control and n.theme == null:
		n.theme = get_tree().root.theme
		return
	if _is_particles(n):
		_scale_particles(n)
	elif n is Light3D and n.shadow_enabled and quality() < 2:
		# Lichter, die später dazukommen (z. B. Effekte), gleich anpassen
		n.set_meta("original_shadow", true)
		n.shadow_enabled = n is DirectionalLight3D and quality() >= 1

# Anzahl Partikel: Faktor aus den Einstellungen. Wichtige Partikel (z. B. Sporen,
# die Karten verdecken) haben die Markierung "wichtig" und verschwinden nie ganz.
func _scale_particles(p: Node) -> void:
	if not p.has_meta("base_amount"):
		p.set_meta("base_amount", p.amount)
	var factor := float(get_value("particles"))
	if p.has_meta("wichtig"):
		factor = maxf(factor, 0.5)
	if factor <= 0.0:
		p.visible = false
		p.set_meta("hidden_by_settings", true)
		return
	if p.has_meta("hidden_by_settings"):
		p.visible = true
		p.remove_meta("hidden_by_settings")
	var wanted := maxi(1, roundi(int(p.get_meta("base_amount")) * factor))
	if p.amount != wanted:
		p.amount = wanted

func _build_fps_label() -> void:
	fps_layer = CanvasLayer.new()
	fps_layer.layer = 120
	add_child(fps_layer)
	fps_label = Label.new()
	fps_label.anchor_top = 1.0
	fps_label.anchor_bottom = 1.0
	fps_label.offset_left = 10
	fps_label.offset_top = -32
	fps_label.offset_right = 140
	fps_label.offset_bottom = -8
	fps_label.add_theme_font_size_override("font_size", 16)
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.add_theme_constant_override("outline_size", 5)
	fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_layer.add_child(fps_label)
	fps_layer.visible = false

func _process(_delta: float) -> void:
	if fps_layer != null and fps_layer.visible:
		fps_label.text = "%d FPS" % Engine.get_frames_per_second()
