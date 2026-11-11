extends Node
## Soundeffekte (selbst erzeugt, liegen in assets/sfx/). SoundFX.play("match")
## Mehrere Effekte können gleichzeitig klingen. Lautstärke: Einstellungen → Effekte.
##
## UI-Sounds (Klick, Hover, Seitenwechsel, Schalter, Regler, Tippen) laufen über
## SoundFX.ui() und lassen sich in den Einstellungen ausschalten. Buttons, Schalter,
## Regler, Auswahl-Listen und Eingabefelder bekommen ihre Sounds automatisch.

const DIR := "res://assets/sfx/"
var players: Array[AudioStreamPlayer] = []
var cache: Dictionary = {}
var next := 0
var _last_played: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(12):
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	get_tree().node_added.connect(_on_node_added)

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

# Sound der Oberfläche. min_gap: so viele Sekunden muss derselbe Sound Pause haben
# (z. B. beim Ziehen eines Reglers, sonst rattert es).
func ui(sound: String, volume_db: float = 0.0, min_gap: float = 0.0) -> void:
	if not bool(GameSettings.get_value("ui_sounds")):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if min_gap > 0.0 and now - float(_last_played.get(sound, -10.0)) < min_gap:
		return
	_last_played[sound] = now
	play(sound, volume_db, 0.04)

func _on_node_added(n: Node) -> void:
	if n is CheckButton:
		n.toggled.connect(func(on: bool): ui("toggle_on" if on else "toggle_off"))
	elif n is OptionButton:
		n.pressed.connect(func(): ui("pop"))
		n.item_selected.connect(func(_i: int): ui("select", -4.0))
	elif n is BaseButton:
		n.mouse_entered.connect(func():
			if not n.disabled:
				ui("hover", 0.0, 0.05))
		# Buttons mit UI.connect_animated spielen ihren Klick selbst
		n.pressed.connect(func():
			if not n.has_meta("own_click"):
				ui("click", -4.0))
	elif n is HSlider:
		n.value_changed.connect(func(_v: float): ui("slider", 0.0, 0.06))
	elif n is LineEdit:
		n.text_changed.connect(func(_t: String): ui("type", 0.0, 0.03))
