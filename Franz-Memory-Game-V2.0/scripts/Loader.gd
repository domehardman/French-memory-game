extends Node
## Startet das Spielfeld. Vor einem Bossfight erscheint der Ladebildschirm des Ortes.

const SCREEN := "res://claude1/scenes/ladebild.tscn"
const MAIN := "res://scenes/Main.tscn"

# Orte der Boss-Arenen (Texte und Bilder aus "Claude 1")
const PLACES := {
	"level2": {"title": "Kathedrale", "image": "res://claude1/textures/lade2.png"},
	"level3": {"title": "Beinhaus", "image": "res://claude1/textures/lade3.png"},
	"level6": {"title": "Glockenturm", "image": "res://claude1/textures/lade6.png"},
	"level8": {"title": "Toter Hain", "image": "res://claude1/textures/lade8.png"},
}

const TIPS := [
	"Findest du ein Paar, während der Boss ausholt, unterbrichst du seinen Angriff.",
	"Beobachte seine Augen: Sie leuchten auf, kurz bevor er zuschlägt.",
	"Merke dir, wohin getroffene Karten fliegen. Sie bleiben verdeckt, aber nicht vergessen.",
	"Paare hintereinander machen mehr Schaden. Eine Serie lohnt sich.",
	"Karten unter Sporen oder Fluch: Ein Fehler tut weh, ein Paar damit trifft doppelt.",
	"Ist sein Herz offen, zählt jedes Paar doppelt. Jetzt nicht zögern.",
	"Wird der Boss wütend, greift er öfter an. Bleib ruhig und spiel sicher.",
]

func go_to_main(short: bool = false) -> void:
	var level: Dictionary = {}
	if SetSelection.mode == "campaign":
		level = PlayerProgress.campaign_level(SetSelection.campaign_index)
	var look: Dictionary = level.get("boss", {}).get("look", {})
	if str(level.get("type", "")) != "boss" or not ResourceLoader.exists(SCREEN) or not PLACES.has(str(look.get("level", ""))):
		get_tree().change_scene_to_file(MAIN)
		return
	var screen = load(SCREEN).instantiate()
	get_tree().root.add_child(screen)
	# Das Original-Ladebild aus "Claude 1": Ort, Bild und Zeile kommen aus seiner Tabelle ORTE
	screen.ort_schluessel = "res://claude1/scenes/%s.tscn" % str(look["level"])
	var color := Color(str(look.get("accent", "#ffffff"))).darkened(0.5)
	screen.wechseln(MAIN, color, str(level.get("name", "")) + " erwartet dich", short)