extends Node
## Soundeffekte (selbst erzeugt, liegen in assets/sfx/). SoundFX.play("match")
## Mehrere Effekte können gleichzeitig klingen. Lautstärke: Einstellungen → Effekte.

const DIR := "res://assets/sfx/"
var players: Array[AudioStreamPlayer] = []
var cache: Dictionary = {}
var next := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(10):
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)

func play(sound: String, volume_db: float = 0.0, pitch_spread: float = 0.06) -> void:
	var volume := float(GameSettings.get_value("sfx_volume")) / 100.0
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
	p.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
	p.play()
