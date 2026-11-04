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
	"confirm_quit": false
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

func check_admin_code(code: String) -> bool:
	if code.strip_edges().sha256_text() == ADMIN_HASH:
		admin_unlocked = true
	return admin_unlocked
