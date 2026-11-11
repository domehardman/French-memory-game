extends Node
## Spielt die Musik. Zwei Spieler wechseln sich ab, damit Stücke weich ineinander
## übergehen. Die Stücke liegen in assets/music/ und sind selbst komponiert
## (erzeugt mit einem kleinen Synthesizer, siehe data/README.md).

const TRACKS := {
	"menu": "res://assets/music/menu.wav",
	"game": "res://assets/music/game.wav",
	"sonneur": "res://assets/music/sonneur.wav",
	"veuve": "res://assets/music/veuve.wav",
	"prince": "res://assets/music/prince.wav",
	"patre": "res://assets/music/patre.wav",
	"cafe": "res://assets/music/cafe.wav",
	"promenade": "res://assets/music/promenade.wav",
	"valse": "res://assets/music/valse.wav"
}

# Auswahl in den Einstellungen ("random" = jedes Mal ein anderes, "off" = keine Musik)
const MENU_TRACKS := ["menu", "cafe"]
const GAME_TRACKS := ["game", "promenade", "valse"]

var players: Array[AudioStreamPlayer] = []
var active := 0
var current := ""
var fades: Array[Tween] = [null, null]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(2):
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		players.append(p)

# Lautstärke aus den Einstellungen (0–100). 0 = aus.
func target_db() -> float:
	var volume := float(GameSettings.get_value("music_volume")) / 100.0
	if volume <= 0.0:
		return -80.0
	return linear_to_db(volume)

func play(key: String, fade: float = 1.5) -> void:
	if key == current or not TRACKS.has(key):
		return
	var stream: AudioStream = load(TRACKS[key]) if ResourceLoader.exists(TRACKS[key]) else null
	if stream == null:
		return
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	current = key
	var old := active
	active = 1 - active
	var p := players[active]
	p.stream = stream
	p.volume_db = -60.0
	p.play()
	_fade(active, target_db(), fade)
	_fade(old, -80.0, fade, true)

func stop(fade: float = 1.5) -> void:
	current = ""
	_fade(active, -80.0, fade, true)

func _fade(index: int, db: float, duration: float, stop_after: bool = false) -> void:
	if fades[index] != null and fades[index].is_valid():
		fades[index].kill()
	var p := players[index]
	var tween := create_tween()
	tween.tween_property(p, "volume_db", db, maxf(duration, 0.01))
	if stop_after:
		tween.tween_callback(p.stop)
	fades[index] = tween

# Wird aufgerufen, wenn sich die Musik-Lautstärke in den Einstellungen ändert.
func apply_volume() -> void:
	if current.is_empty():
		return
	if fades[active] != null and fades[active].is_valid():
		fades[active].kill()
	players[active].volume_db = target_db()

# Musik im Menü bzw. in normalen Runden, so wie in den Einstellungen gewählt.
func play_menu() -> void:
	_play_choice(str(GameSettings.get_value("menu_music")), MENU_TRACKS)

func play_game() -> void:
	_play_choice(str(GameSettings.get_value("game_music")), GAME_TRACKS)

func _play_choice(choice: String, options: Array) -> void:
	if choice == "off":
		stop()
		return
	if choice == "random":
		# ein anderes Stück als das gerade laufende
		var pool := options.filter(func(t): return t != current)
		choice = str(pool.pick_random() if not pool.is_empty() else options[0])
	if not TRACKS.has(choice):
		choice = str(options[0])
	play(choice)
