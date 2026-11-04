extends CanvasLayer

# =====================================================================
# LADEBILD
# Führt den Wechsel von einem Level zum nächsten durch:
#   1. Der Bildschirm blendet in eine Farbe über (Licht vom Tor oder Stein).
#   2. Das Ladebild erscheint, das Level lädt im Hintergrund.
#   3. Das neue Level startet unsichtbar hinter dem Bild.
#   4. Das Bild blendet aus, der Name des Ortes bleibt kurz stehen.
#
# Dieses Bild hängt nicht im Level, sondern direkt am Spiel. Darum
# überlebt es den Wechsel und verschwindet erst ganz am Ende von selbst.
# =====================================================================

# Hier stehen die Texte und Bilder der Orte.
const ORTE = {
	"res://claude1/scenes/main.tscn": {
		"titel": "Domplatz",
		"zeile": "Die Scheiterhaufen brennen noch immer.",
		"bild": "res://claude1/textures/lade1.png",
	},
	"res://claude1/scenes/level2.tscn": {
		"titel": "Kathedrale",
		"zeile": "Die Glocke hat seit Jahren nicht geläutet.",
		"bild": "res://claude1/textures/lade2.png",
	},
	"res://claude1/scenes/level3.tscn": {
		"titel": "Beinhaus",
		"zeile": "Hier unten zählt man die Toten nicht mehr.",
		"bild": "res://claude1/textures/lade3.png",
	},
	"res://claude1/scenes/level4.tscn": {
		"titel": "Mondterrasse",
		"zeile": "Über dem Abgrund blüht, was nachts erwacht.",
		"bild": "res://claude1/textures/lade4.png",
	},
	"res://claude1/scenes/level5.tscn": {
		"titel": "Thronsaal",
		"zeile": "Der König wartet in seiner Asche.",
		"bild": "res://claude1/textures/lade5.png",
	},
	"res://claude1/scenes/level6.tscn": {
		"titel": "Glockenturm",
		"zeile": "Wer hier oben läutet, hört nichts mehr.",
		"bild": "res://claude1/textures/lade6.png",
	},
	"res://claude1/scenes/level7.tscn": {
		"titel": "Flutgruft",
		"zeile": "Das Wasser steigt, seit sie unten ist.",
		"bild": "res://claude1/textures/lade7.png",
	},
	"res://claude1/scenes/level8.tscn": {
		"titel": "Toter Hain",
		"zeile": "Die Wurzeln kennen deinen Namen.",
		"bild": "res://claude1/textures/lade8.png",
	},
}

const TIPPS = [
	"Findest du ein Paar, während der Boss ausholt, unterbrichst du seinen Angriff.",
	"Beobachte die Augen des Gegners: Sie leuchten auf, kurz bevor er zuschlägt.",
	"Merke dir, wohin getroffene Karten fliegen.",
	"Paare hintereinander machen mehr Schaden.",
	"Rot markierte Karten werden gleich getroffen.",
]

# So lange bleibt das Ladebild mindestens stehen.
const MINDEST_DAUER = 2.0
const MINDEST_DAUER_KURZ = 0.6            # Beim Neustart mit R soll es schnell gehen

var mindest_dauer = MINDEST_DAUER

# Memory-Spiel: Ort des Bosses (Schlüssel in ORTE), wenn das Ziel kein Level aus "Claude 1" ist
var ort_schluessel = ""

@onready var blende = $Blende
@onready var hintergrund = $Hintergrund
@onready var bild = $Hintergrund/Bild
@onready var tipp = $Hintergrund/Tipp
@onready var balken = $Hintergrund/Balken
@onready var ortsname = $Ortsname
@onready var titel = $Ortsname/Titel
@onready var zeile = $Ortsname/Zeile
@onready var linie = $Ortsname/Linie


func _ready():
	# Das Bild läuft weiter, auch wenn das alte Level angehalten ist.
	process_mode = Node.PROCESS_MODE_ALWAYS
	hintergrund.modulate.a = 0.0
	ortsname.modulate.a = 0.0
	blende.color.a = 0.0
	balken.scale.x = 0.0


# pfad: das neue Level. farbe: in diese Farbe blendet das Bild zuerst über.
# untertitel: ersetzt die Zeile unter dem Ortsnamen, zum Beispiel beim Stein.
# kurz: für den Neustart mit R. Alles läuft schneller ab.
func wechseln(pfad, farbe, untertitel, kurz = false):
	texte_setzen(pfad, untertitel)

	var tempo = 1.0
	if kurz:
		tempo = 0.45
		mindest_dauer = MINDEST_DAUER_KURZ

	# 1. In die Farbe überblenden.
	blende.color = Color(farbe.r, farbe.g, farbe.b, 0.0)
	var tween = create_tween()
	tween.tween_property(blende, "color:a", 1.0, 0.7 * tempo)
	await tween.finished

	# Das alte Level hält an, damit es beim Laden nichts mehr bremst.
	get_tree().paused = true

	# 2. Das Ladebild erscheint hinter der Farbe.
	hintergrund.modulate.a = 1.0
	ortsname.modulate.a = 1.0
	tween = create_tween()
	tween.tween_property(blende, "color:a", 0.0, 0.8 * tempo)

	var szene = await im_hintergrund_laden(pfad)

	# 3. Das neue Level startet, noch verdeckt.
	get_tree().paused = false
	if szene == null:
		get_tree().change_scene_to_file(pfad)
	else:
		get_tree().change_scene_to_packed(szene)

	# Einige Bilder warten: So ruckelt der erste Anblick nicht.
	for i in range(8):
		await get_tree().process_frame

	# 4. Das Bild blendet aus, der Name des Ortes bleibt noch stehen.
	tween = create_tween()
	tween.tween_property(hintergrund, "modulate:a", 0.0, 1.1 * tempo)
	await tween.finished
	await get_tree().create_timer(1.1 * tempo).timeout

	tween = create_tween()
	tween.tween_property(ortsname, "modulate:a", 0.0, 1.0 * tempo)
	await tween.finished
	queue_free()


func texte_setzen(pfad, untertitel):
	var ort = ORTE[ort_schluessel if ort_schluessel != "" else pfad]
	titel.text = ort["titel"]
	zeile.text = ort["zeile"]
	if untertitel != "":
		zeile.text = untertitel
	bild.texture = load(ort["bild"])
	tipp.text = TIPPS[randi() % TIPPS.size()]


# Lädt das Level, ohne dass das Spiel stehen bleibt. Der Balken zeigt den Stand.
func im_hintergrund_laden(pfad):
	var start = Time.get_ticks_msec()
	ResourceLoader.load_threaded_request(pfad)

	while true:
		var stand = []
		var status = ResourceLoader.load_threaded_get_status(pfad, stand)
		var vergangen = (Time.get_ticks_msec() - start) / 1000.0

		# Der Balken läuft nie schneller als die Mindestdauer.
		var ziel = min(stand[0], vergangen / mindest_dauer)
		balken.scale.x = lerp(balken.scale.x, ziel, 0.15)

		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			return null
		if status == ResourceLoader.THREAD_LOAD_LOADED and vergangen >= mindest_dauer:
			balken.scale.x = 1.0
			return ResourceLoader.load_threaded_get(pfad)

		await get_tree().process_frame
