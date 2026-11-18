extends Node
## Spielt die Musik. Zwei Spieler wechseln sich ab, damit Stücke weich ineinander
## übergehen. Die Stücke liegen in assets/music/ und sind selbst komponiert
## (erzeugt mit einem kleinen Synthesizer, siehe data/README.md).
##
## Im Spiel laufen Wiedergabelisten aus data/music.json: 10 Stücke pro Insel und
## 3 pro Boss. Die Reihenfolge ist zufällig, erst wenn alle dran waren, geht es neu los.
## Im Menü läuft ein einzelnes Stück in Schleife.

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
const PLAYLISTS_PATH := "res://data/music.json"
const WORLDS_PATH := "res://data/worlds.json"
const CROSSFADE := 3.0

var players: Array[AudioStreamPlayer] = []
var active := 0
var current := ""
var fades: Array[Tween] = [null, null]

var world_tracks: Dictionary = {}   # Raum der Insel -> Liste von Stücken
var boss_tracks: Dictionary = {}    # look.music des Bosses -> Liste von Stücken
var track_titles: Dictionary = {}   # Pfad -> Name für die Einstellungen
var world_rooms: Array = []         # Raum jeder Insel, in der Reihenfolge der Kampagne
var playlist_id := ""
var playlist: Array = []
var bag: Array = []                 # Stücke, die in dieser Runde noch nicht dran waren
var switch_timer: Timer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(2):
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		players.append(p)
	switch_timer = Timer.new()
	switch_timer.one_shot = true
	switch_timer.timeout.connect(_next_track)
	add_child(switch_timer)
	_load_playlists()

func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(file.get_as_text()) if file != null else null

func _load_playlists() -> void:
	var data = _read_json(PLAYLISTS_PATH)
	if data is Dictionary:
		world_tracks = data.get("worlds", {})
		boss_tracks = data.get("bosses", {})
		track_titles = data.get("titles", {})
	var worlds = _read_json(WORLDS_PATH)
	if worlds is Array:
		for w in worlds:
			world_rooms.append(str(w.get("room", "")))

# Lautstärke aus den Einstellungen (0–100). 0 = aus.
func target_db() -> float:
	var volume := float(GameSettings.get_value("music_volume")) / 100.0
	if volume <= 0.0:
		return -80.0
	return linear_to_db(volume)

# Einzelnes Stück in Schleife (Menü und Kampagnen-Karte)
func play(key: String, fade: float = 1.5) -> void:
	if not TRACKS.has(key) or (key == current and playlist_id.is_empty()):
		return
	_clear_playlist()
	_start_stream(str(TRACKS[key]), key, fade)

# Menü und Kampagnen-Karte: Stück aus den Einstellungen (oder keine Musik)
func play_menu() -> void:
	var choice := str(GameSettings.get_value("menu_music"))
	if choice == "off":
		stop()
	else:
		play(choice if TRACKS.has(choice) else "menu")

# --- Wiedergabelisten im Spiel ----------------------------------------------------------
# Einstellung "Musik im Spiel" (music_mode):
#   auto    passend zur Insel, im normalen Modus zufällig von allen Inseln
#   style   nur die Stücke einer Insel (music_style)
#   single  nur ein einziges Lied (music_track)
#   off     keine Musik

# Kampagnen-Level: die Musik der Insel, zu der das Level gehört
func play_campaign_level(index: int) -> void:
	var world: int = PlayerProgress.campaign_world(index)
	var room := str(world_rooms[world]) if world >= 0 and world < world_rooms.size() else ""
	_play_game_music("world:" + room, world_tracks.get(room, []))

func play_world(room: String) -> void:
	_play_game_music("world:" + room, world_tracks.get(room, []))

# Boss: eigene Stücke, wie im normalen Spiel oder gar keine Musik (boss_music)
func play_boss(key: String, level_index: int = -1) -> void:
	match str(GameSettings.get_value("boss_music")):
		"off":
			stop()
		"game":
			if level_index >= 0:
				play_campaign_level(level_index)
			else:
				play_all_worlds()
		_:
			_start_playlist("boss:" + key, boss_tracks.get(key, [TRACKS.get(key, "")]))

# Normaler Modus: zufällig aus den Stücken aller Inseln
func play_all_worlds() -> void:
	_play_game_music("alle_inseln", all_world_tracks())

func all_world_tracks() -> Array:
	var all: Array = []
	for room in world_tracks:
		all.append_array(world_tracks[room])
	return all

func _play_game_music(auto_id: String, auto_tracks: Array) -> void:
	match str(GameSettings.get_value("music_mode")):
		"off":
			stop()
		"style":
			var room := str(GameSettings.get_value("music_style"))
			_start_playlist("style:" + room, world_tracks.get(room, auto_tracks))
		"single":
			var path := str(GameSettings.get_value("music_track"))
			if not ResourceLoader.exists(path):
				path = str(all_world_tracks()[0])
			_start_playlist("single:" + path, [path])
		_:
			_start_playlist(auto_id, auto_tracks)

# Probe hören in den Einstellungen: das, was gerade im Spiel laufen würde
func preview_game_music() -> void:
	playlist_id = ""
	match str(GameSettings.get_value("music_mode")):
		"off":
			stop()
		"auto":
			_start_playlist("alle_inseln", all_world_tracks())
		_:
			_play_game_music("alle_inseln", all_world_tracks())

func title_of(path: String) -> String:
	return str(track_titles.get(path, path.get_file().get_basename()))

func _start_playlist(id: String, tracks: Array) -> void:
	if id == playlist_id:
		return     # z. B. Neustart der Runde: die Musik läuft einfach weiter
	var usable := tracks.filter(func(t): return ResourceLoader.exists(str(t)))
	if usable.is_empty():
		return
	playlist_id = id
	playlist = usable
	bag.clear()
	_next_track()

func _next_track() -> void:
	if playlist.is_empty():
		return
	if bag.is_empty():
		bag = playlist.duplicate()
		bag.shuffle()
		# Nicht zweimal dasselbe Stück direkt hintereinander
		if bag.size() > 1 and str(bag.back()) == current:
			bag.reverse()
	var path := str(bag.pop_back())
	# Nur ein Lied in der Liste: einfach in Schleife weiterspielen
	if path == current and playlist.size() == 1:
		return
	var length := _start_stream(path, path, CROSSFADE)
	if length <= 0.0:
		switch_timer.start(1.0)
		return
	# music_change: so lange läuft ein Stück mindestens, 0 = nie von selbst wechseln
	var minimum := float(GameSettings.get_value("music_change"))
	if minimum > 0.0 and playlist.size() > 1:
		switch_timer.start(maxf(ceili(minimum / length) * length - CROSSFADE, 1.0))
	else:
		switch_timer.stop()

func _clear_playlist() -> void:
	playlist_id = ""
	playlist.clear()
	bag.clear()
	if switch_timer != null:
		switch_timer.stop()

# Startet ein Stück in Schleife und blendet über. Gibt seine Länge zurück.
func _start_stream(path: String, id: String, fade: float) -> float:
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
	if stream == null:
		return 0.0
	if stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	current = id
	var old := active
	active = 1 - active
	var p := players[active]
	p.stream = stream
	p.volume_db = -60.0
	p.play()
	_fade(active, target_db(), fade)
	_fade(old, -80.0, fade, true)
	return stream.get_length()

func stop(fade: float = 1.5) -> void:
	current = ""
	_clear_playlist()
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
