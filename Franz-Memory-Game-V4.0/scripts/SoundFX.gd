extends Node
## Soundeffekte (selbst erzeugt, liegen in assets/sfx/). SoundFX.play("match")
## Mehrere Effekte können gleichzeitig klingen. Lautstärke in den Einstellungen:
## "Effekte" gilt für alle, dazu je ein Regler für Klicks, Karten und Boss.

const DIR := "res://assets/sfx/"
const UI_SOUNDS := ["click"]
const CARD_SOUNDS := ["flip", "match", "mismatch", "victory", "defeat", "level_up", "reward"]

var players: Array[AudioStreamPlayer] = []
var cache: Dictionary = {}
var next := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(10):
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

# Lautstärke (0 bis 1) für einen Sound: Effekte × seine Gruppe
func volume_of(sound: String) -> float:
	var group := "sfx_boss"
	if UI_SOUNDS.has(sound):
		group = "sfx_ui"
	elif CARD_SOUNDS.has(sound):
		group = "sfx_cards"
	return float(GameSettings.get_value("sfx_volume")) / 100.0 * float(GameSettings.get_value(group)) / 100.0

func play(sound: String, volume_db: float = 0.0, pitch_spread: float = 0.06) -> void:
	var volume := volume_of(sound)
	if volume <= 0.0:
		return
	if not cache.has(sound):
		var path := DIR + sound + ".wav"
		cache[sound] = load(path) if ResourceLoader.exists(path) else null
	var stream: AudioStream = cache[sound]
	if stream == null:
		return
	var p := players[next]
	next = (next + 1) % players.size()
	p.stream = stream
	p.volume_db = linear_to_db(volume) + volume_db
	p.pitch_scale = 1.0 + (randf_range(-pitch_spread, pitch_spread) if bool(GameSettings.get_value("sfx_variation")) else 0.0)
	p.play()
