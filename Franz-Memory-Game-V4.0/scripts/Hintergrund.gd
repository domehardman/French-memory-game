extends Node3D
## Hintergrund der normalen Runden (scenes/Hintergrund.tscn): ein "Raum" mit Tisch,
## Spielbrett-Rand, Licht und ein paar Deko-Gruppen links und rechts vom Brett.
##
## Es gibt vier Räume (ROOMS): cafe, nuit, jardin, riviera. Jeder hat eine feste
## Farbpalette, damit alles bunt, aber zusammenpassend aussieht. Main.gd ruft
## setup(raum) auf. Welcher Raum kommt: Einstellungen -> Raum (Automatisch = Kampagne
## nach Welt, freies Spiel nach Thema des Sets).
##
## Eigene 3D-Sachen in den Knoten "Deko3D" hängen, sie bleiben immer sichtbar.
## Die Deko des Raums landet im Knoten "Deko".
##
## Neue Deko-Form: in DESIGNS einen Eintrag dazuschreiben. Jedes Teil ist
##   [Form, Masse, Position, Drehung in Grad, Farbe]
## Formen: "box" [Grösse], "sphere" [Radius], "half" [Radius] (Halbkugel),
##   "cyl" [Radius oben, Radius unten, Höhe, Ecken] (4 Ecken = Pyramide, Radius oben 0 = Spitze),
##   "prism" [Grösse], "torus" [innen, aussen], "capsule" [Radius, Länge]
## Farben: "a", "b", "c" = Akzentfarben des Raums, "n" = helle Grundfarbe des Raums,
##   "glow" = leuchtende Farbe des Raums, oder ein fester Name aus PALETTE.
## Eine Deko-Gruppe (in ROOMS unter "groups") ist eine Liste von
##   [Form-Name, Versatz (x, z), Drehung, Grösse]

const ROOMS := {
	"cafe": {
		"title": "Café",
		"table": "#d9893a", "rim": "#a8452a", "rim_stripe": "", "corner": "#6e2c1a",
		"light": "#fff0d9",
		"a": "#e4572e", "b": "#2a9d8f", "c": "#f6d04d", "n": "#fcf4e3", "glow": "#ffe08a",
		"groups": [
			[["Flasche", Vector2(0, 0), 0, 1.0], ["Tasse", Vector2(0.8, 0.35), 0, 1.0]],
			[["Baguette", Vector2(0, 0), -20, 1.0], ["Käse", Vector2(0.35, 0.8), 15, 1.0]],
			[["Würfelstapel", Vector2(0, 0), 0, 1.0]],
			[["Eiffelturm", Vector2(0, 0), 0, 1.0]],
			[["Zylinder", Vector2(0, 0), 0, 0.9], ["Kugel", Vector2(0.75, 0.25), 0, 0.6]],
			[["Bücherstapel", Vector2(0, 0), 10, 1.0], ["Bleistift", Vector2(0.15, 0.85), -30, 1.0]],
			[["Baskenmütze", Vector2(0, 0), 0, 1.0]],
		],
	},
	"nuit": {
		"title": "Nuit",
		"table": "#232c66", "rim": "#36439a", "rim_stripe": "", "corner": "#5ee1ff",
		"light": "#c8d2ff",
		"a": "#7b5cff", "b": "#ff5c8a", "c": "#5ee1ff", "n": "#4a58b8", "glow": "#ffe9a8",
		"groups": [
			[["Mond", Vector2(0, 0), 0, 1.0]],
			[["Kristall", Vector2(0, 0), 0, 1.0], ["Kristall", Vector2(0.6, 0.45), 20, 0.7]],
			[["Pyramide", Vector2(0, 0), 0, 1.0], ["Pyramide", Vector2(0.9, 0.3), 0, 0.6]],
			[["Säule", Vector2(0, 0), 0, 1.0], ["Würfel", Vector2(0.75, 0.15), 0, 0.6]],
			[["Diamant", Vector2(0, 0), 0, 1.0]],
			[["Bogen", Vector2(0, 0), 0, 1.0]],
			[["Ring", Vector2(0, 0), 0, 1.0]],
		],
	},
	"jardin": {
		"title": "Jardin",
		"table": "#5cae62", "rim": "#e9e4d4", "rim_stripe": "", "corner": "#f2b632",
		"light": "#fffbe8",
		"a": "#2f9e57", "b": "#ff7a90", "c": "#ffd166", "n": "#ffffff", "glow": "#fff3b0",
		"groups": [
			[["Baum", Vector2(0, 0), 0, 1.0], ["Baum", Vector2(0.75, 0.45), 0, 0.75]],
			[["Busch", Vector2(0, 0), 0, 1.0], ["Blume", Vector2(0.75, 0.0), 0, 1.0]],
			[["Pilz", Vector2(0, 0), 0, 1.0], ["Pilz", Vector2(0.45, 0.35), 0, 0.7]],
			[["Haus", Vector2(0, 0), 0, 1.0]],
			[["Kegelpaar", Vector2(0, 0), 0, 1.0]],
			[["Blume", Vector2(0, 0), 0, 1.0], ["Blume", Vector2(0.4, 0.4), 0, 0.8], ["Blume", Vector2(-0.3, 0.5), 0, 0.9]],
			[["Kugel auf Würfel", Vector2(0, 0), 0, 1.0]],
		],
	},
	"riviera": {
		"title": "Riviera",
		"table": "#35a3b2", "rim": "#f1ece0", "rim_stripe": "", "corner": "#1f6fb8",
		"light": "#fff8ec",
		"a": "#1f6fb8", "b": "#f4d58d", "c": "#ff6b5e", "n": "#ffffff", "glow": "#fff3c4",
		"groups": [
			[["Leuchtturm", Vector2(0, 0), 0, 1.0]],
			[["Ring", Vector2(0, 0), 0, 1.0]],
			[["Kiesel", Vector2(0, 0), 0, 1.0]],
			[["Fahne", Vector2(0, 0), 0, 1.0], ["Prisma", Vector2(0.65, 0.55), 0, 0.6]],
			[["Halbkugel", Vector2(0, 0), 0, 1.0], ["Kugel", Vector2(0.75, 0.25), 0, 0.5]],
			[["Treppe", Vector2(0, 0), 0, 1.0]],
			[["Domino", Vector2(0, 0), 0, 1.0]],
		],
	},
}
const ROOM_ORDER := ["cafe", "nuit", "jardin", "riviera"]

@export var groups_per_side := 2     # Deko-Gruppen links und rechts
@export var floating := 1            # höchstens so viele Formen schweben langsam

const PALETTE := {
	"red": "#e63946", "blue": "#1f8fd1", "white": "#ffffff", "brown": "#8a5a3c", "bread": "#d9954a",
}

const DESIGNS := [
	# --- Reine Formen -------------------------------------------------------------
	{"name": "Würfel", "float": true, "parts": [["box", [Vector3(0.9, 0.9, 0.9)], Vector3(0, 0.45, 0), Vector3(0, 20, 0), "a"]]},
	{"name": "Säule", "parts": [["box", [Vector3(0.55, 1.4, 0.55)], Vector3(0, 0.7, 0), Vector3(0, 10, 0), "a"]]},
	{"name": "Platte", "parts": [["box", [Vector3(1.3, 0.25, 1.0)], Vector3(0, 0.125, 0), Vector3(0, -15, 0), "a"]]},
	{"name": "Pyramide", "float": true, "parts": [["cyl", [0.0, 0.75, 1.0, 4], Vector3(0, 0.5, 0), Vector3(0, 45, 0), "a"]]},
	{"name": "Kugel", "float": true, "parts": [["sphere", [0.5], Vector3(0, 0.5, 0), Vector3.ZERO, "a"]]},
	{"name": "Zylinder", "parts": [["cyl", [0.45, 0.45, 1.0, 12], Vector3(0, 0.5, 0), Vector3.ZERO, "a"]]},
	{"name": "Kegel", "parts": [["cyl", [0.0, 0.5, 1.1, 12], Vector3(0, 0.55, 0), Vector3.ZERO, "a"]]},
	{"name": "Prisma", "parts": [["prism", [Vector3(1.2, 0.8, 0.7)], Vector3(0, 0.4, 0), Vector3(0, 25, 0), "a"]]},
	{"name": "Ring", "float": true, "parts": [["torus", [0.3, 0.55], Vector3(0, 0.13, 0), Vector3.ZERO, "a"]]},
	{"name": "Kapsel", "parts": [["capsule", [0.3, 1.2], Vector3(0, 0.3, 0), Vector3(0, 30, 90), "a"]]},
	{"name": "Diamant", "float": true, "parts": [
		["cyl", [0.5, 0.0, 0.5, 4], Vector3(0, 0.25, 0), Vector3(0, 45, 0), "a"],
		["cyl", [0.0, 0.5, 0.5, 4], Vector3(0, 0.75, 0), Vector3(0, 45, 0), "a"]]},
	{"name": "Würfelstapel", "parts": [
		["box", [Vector3(0.8, 0.8, 0.8)], Vector3(0, 0.4, 0), Vector3(0, 0, 0), "a"],
		["box", [Vector3(0.55, 0.55, 0.55)], Vector3(0, 1.075, 0), Vector3(0, 25, 0), "b"],
		["box", [Vector3(0.35, 0.35, 0.35)], Vector3(0, 1.525, 0), Vector3(0, 50, 0), "c"]]},
	{"name": "Sechseck", "parts": [["cyl", [0.5, 0.5, 0.6, 6], Vector3(0, 0.3, 0), Vector3.ZERO, "a"]]},
	{"name": "Treppe", "parts": [
		["box", [Vector3(0.4, 0.3, 0.9)], Vector3(-0.4, 0.15, 0), Vector3.ZERO, "a"],
		["box", [Vector3(0.4, 0.6, 0.9)], Vector3(0, 0.3, 0), Vector3.ZERO, "a"],
		["box", [Vector3(0.4, 0.9, 0.9)], Vector3(0.4, 0.45, 0), Vector3.ZERO, "a"]]},
	{"name": "Bogen", "parts": [
		["box", [Vector3(0.3, 0.9, 0.4)], Vector3(-0.45, 0.45, 0), Vector3.ZERO, "a"],
		["box", [Vector3(0.3, 0.9, 0.4)], Vector3(0.45, 0.45, 0), Vector3.ZERO, "a"],
		["box", [Vector3(1.2, 0.3, 0.4)], Vector3(0, 1.05, 0), Vector3.ZERO, "b"]]},
	{"name": "Kreuz", "parts": [
		["box", [Vector3(1.2, 0.3, 0.35)], Vector3(0, 0.15, 0), Vector3.ZERO, "a"],
		["box", [Vector3(0.35, 0.3, 1.2)], Vector3(0, 0.15, 0), Vector3.ZERO, "a"]]},
	{"name": "Kugel auf Würfel", "parts": [
		["box", [Vector3(0.7, 0.7, 0.7)], Vector3(0, 0.35, 0), Vector3(0, 15, 0), "a"],
		["sphere", [0.3], Vector3(0, 1.0, 0), Vector3.ZERO, "b"]]},
	{"name": "Halbkugel", "parts": [["half", [0.55], Vector3(0, 0.0, 0), Vector3.ZERO, "a"]]},
	{"name": "Kegelpaar", "parts": [
		["cyl", [0.0, 0.35, 0.9, 10], Vector3(-0.25, 0.45, 0), Vector3.ZERO, "a"],
		["cyl", [0.0, 0.28, 0.6, 10], Vector3(0.3, 0.3, 0.1), Vector3.ZERO, "b"]]},
	{"name": "Domino", "parts": [
		["box", [Vector3(0.25, 0.9, 0.5)], Vector3(-0.35, 0.45, 0), Vector3(0, 0, 0), "a"],
		["box", [Vector3(0.25, 0.9, 0.5)], Vector3(0.05, 0.45, 0), Vector3(0, 0, -20), "b"],
		["box", [Vector3(0.25, 0.9, 0.5)], Vector3(0.5, 0.3, 0), Vector3(0, 0, -55), "c"]]},
	# --- Gegenstände (nur aus einfachen Formen) ------------------------------------
	{"name": "Eiffelturm", "object": true, "parts": [
		["cyl", [0.3, 0.6, 0.7, 4], Vector3(0, 0.35, 0), Vector3(0, 45, 0), "n"],
		["cyl", [0.13, 0.28, 0.8, 4], Vector3(0, 1.1, 0), Vector3(0, 45, 0), "n"],
		["cyl", [0.0, 0.12, 0.7, 4], Vector3(0, 1.85, 0), Vector3(0, 45, 0), "a"]]},
	{"name": "Flasche", "object": true, "parts": [
		["box", [Vector3(0.5, 0.8, 0.5)], Vector3(0, 0.4, 0), Vector3.ZERO, "b"],
		["box", [Vector3(0.36, 0.18, 0.36)], Vector3(0, 0.89, 0), Vector3.ZERO, "b"],
		["box", [Vector3(0.18, 0.45, 0.18)], Vector3(0, 1.205, 0), Vector3.ZERO, "b"],
		["box", [Vector3(0.24, 0.12, 0.24)], Vector3(0, 1.49, 0), Vector3.ZERO, "a"]]},
	{"name": "Baguette", "object": true, "parts": [["capsule", [0.17, 1.5], Vector3(0, 0.17, 0), Vector3(0, -25, 90), "bread"]]},
	{"name": "Baskenmütze", "object": true, "parts": [
		["cyl", [0.5, 0.58, 0.18, 12], Vector3(0, 0.09, 0), Vector3.ZERO, "a"],
		["cyl", [0.05, 0.05, 0.14, 6], Vector3(0, 0.25, 0), Vector3.ZERO, "a"]]},
	{"name": "Käse", "object": true, "parts": [["prism", [Vector3(1.0, 0.5, 0.7)], Vector3(0, 0.25, 0), Vector3(0, 20, 0), "c"]]},
	{"name": "Bleistift", "object": true, "parts": [
		["cyl", [0.12, 0.12, 1.1, 6], Vector3(0, 0.12, 0), Vector3(0, 0, 90), "c"],
		["cyl", [0.0, 0.12, 0.25, 6], Vector3(-0.675, 0.12, 0), Vector3(0, 0, 90), "bread"]]},
	{"name": "Bücherstapel", "object": true, "parts": [
		["box", [Vector3(1.0, 0.18, 0.7)], Vector3(0, 0.09, 0), Vector3.ZERO, "a"],
		["box", [Vector3(0.9, 0.18, 0.65)], Vector3(0, 0.27, 0), Vector3(0, 8, 0), "b"],
		["box", [Vector3(0.95, 0.18, 0.6)], Vector3(0, 0.45, 0), Vector3(0, -6, 0), "c"]]},
	{"name": "Tasse", "object": true, "parts": [
		["cyl", [0.32, 0.28, 0.5, 12], Vector3(0, 0.25, 0), Vector3.ZERO, "n"],
		["torus", [0.08, 0.17], Vector3(0.36, 0.27, 0), Vector3(90, 0, 0), "n"]]},
	{"name": "Baum", "object": true, "parts": [
		["cyl", [0.1, 0.12, 0.5, 8], Vector3(0, 0.25, 0), Vector3.ZERO, "brown"],
		["cyl", [0.0, 0.5, 0.9, 8], Vector3(0, 0.95, 0), Vector3.ZERO, "a"]]},
	{"name": "Haus", "object": true, "parts": [
		["box", [Vector3(0.8, 0.6, 0.7)], Vector3(0, 0.3, 0), Vector3.ZERO, "n"],
		["prism", [Vector3(0.95, 0.45, 0.78)], Vector3(0, 0.825, 0), Vector3.ZERO, "a"]]},
	{"name": "Pilz", "object": true, "parts": [
		["cyl", [0.12, 0.15, 0.4, 8], Vector3(0, 0.2, 0), Vector3.ZERO, "n"],
		["half", [0.4], Vector3(0, 0.38, 0), Vector3.ZERO, "b"]]},
	{"name": "Fahne", "object": true, "parts": [
		["cyl", [0.04, 0.04, 1.3, 6], Vector3(0, 0.65, 0), Vector3.ZERO, "white"],
		["box", [Vector3(0.18, 0.32, 0.04)], Vector3(0.13, 1.12, 0), Vector3.ZERO, "blue"],
		["box", [Vector3(0.18, 0.32, 0.04)], Vector3(0.31, 1.12, 0), Vector3.ZERO, "white"],
		["box", [Vector3(0.18, 0.32, 0.04)], Vector3(0.49, 1.12, 0), Vector3.ZERO, "red"]]},
	# --- Für die Räume Nuit, Jardin und Riviera ------------------------------------
	{"name": "Mond", "float": true, "parts": [["sphere", [0.5], Vector3(0, 0.5, 0), Vector3.ZERO, "glow"]]},
	{"name": "Kristall", "parts": [
		["cyl", [0.3, 0.3, 0.6, 6], Vector3(0, 0.3, 0), Vector3.ZERO, "c"],
		["cyl", [0.0, 0.3, 0.45, 6], Vector3(0, 0.825, 0), Vector3.ZERO, "c"]]},
	{"name": "Busch", "parts": [
		["half", [0.5], Vector3(0, 0, 0), Vector3.ZERO, "a"],
		["half", [0.32], Vector3(0.45, 0, 0.25), Vector3.ZERO, "a"]]},
	{"name": "Blume", "parts": [
		["cyl", [0.04, 0.04, 0.6, 6], Vector3(0, 0.3, 0), Vector3.ZERO, "a"],
		["sphere", [0.16], Vector3(0, 0.66, 0), Vector3.ZERO, "b"]]},
	{"name": "Leuchtturm", "object": true, "parts": [
		["cyl", [0.33, 0.4, 0.5, 12], Vector3(0, 0.25, 0), Vector3.ZERO, "n"],
		["cyl", [0.28, 0.33, 0.5, 12], Vector3(0, 0.75, 0), Vector3.ZERO, "c"],
		["cyl", [0.24, 0.28, 0.5, 12], Vector3(0, 1.25, 0), Vector3.ZERO, "n"],
		["cyl", [0.0, 0.3, 0.35, 12], Vector3(0, 1.675, 0), Vector3.ZERO, "c"]]},
	{"name": "Kiesel", "parts": [
		["half", [0.4], Vector3(0, 0, 0), Vector3.ZERO, "n"],
		["half", [0.28], Vector3(0.55, 0, 0.2), Vector3.ZERO, "b"],
		["half", [0.2], Vector3(0.25, 0, 0.6), Vector3.ZERO, "a"]]},
]

# Ankerpunkte der Gruppen: links/rechts, oben/unten (x, z ab Brettmitte)
const ANCHORS := [Vector2(-5.7, -2.2), Vector2(-5.9, 2.1), Vector2(5.7, -2.1), Vector2(5.9, 2.2)]
const DECO_SCALE := 1.35   # alle Deko-Formen so viel grösser
const TABLE_Y := -0.95

var room := "cafe"
var _floaters: Array[Dictionary] = []
var _time := 0.0
var _materials: Dictionary = {}

func setup(room_name: String) -> void:
	room = room_name if ROOMS.has(room_name) else "cafe"
	var data: Dictionary = ROOMS[room]
	_apply_table(data)
	_apply_rim(data)
	_apply_light(data)
	_build_deco(data)

# Farben fürs Konfetti (Main.gd)
func confetti_colors() -> Array:
	var data: Dictionary = ROOMS.get(room, ROOMS["cafe"])
	return [data["a"], data["b"], data["c"], data["n"], data["corner"]]

# --- Tisch, Rand, Licht ------------------------------------------------------------

func _apply_table(data: Dictionary) -> void:
	var table := get_node_or_null("Tisch") as MeshInstance3D
	if table == null:
		return
	# Eine ruhige Farbe mit ganz feinen Pixel-Tupfen
	var base := Color(str(data["table"]))
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(base)
	for p in [Vector2i(2, 3), Vector2i(12, 6), Vector2i(6, 12), Vector2i(10, 14), Vector2i(14, 1)]:
		img.set_pixelv(p, base.lightened(0.05))
	for p in [Vector2i(8, 2), Vector2i(3, 9), Vector2i(13, 11)]:
		img.set_pixelv(p, base.darkened(0.05))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(img)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.95
	material.uv1_scale = Vector3(30, 20, 1)
	table.material_override = material

func _apply_rim(data: Dictionary) -> void:
	var rim_color := Color(str(data["rim"]))
	var stripe := str(data.get("rim_stripe", ""))
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(rim_color)
	for x in range(16):
		img.set_pixel(x, 0, rim_color.lightened(0.18))
		img.set_pixel(x, 15, rim_color.darkened(0.18))
		if not stripe.is_empty():
			img.set_pixel(x, 7, Color(stripe))
			img.set_pixel(x, 8, Color(stripe))
	var rim_material := _pixel_material(img, 1.6)
	for node in find_children("*", "MeshInstance3D", true, false):
		var path := str(get_path_to(node))
		if path.begins_with("Spielbrett/Rand"):
			node.material_override = rim_material
	var corner_color := Color(str(data["corner"]))
	var corner_img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	corner_img.fill(corner_color)
	for x in range(16):
		corner_img.set_pixel(x, 0, corner_color.lightened(0.2))
		corner_img.set_pixel(x, 15, corner_color.darkened(0.2))
	var corner_material := _pixel_material(corner_img, 2.0)
	for node in find_children("*", "MeshInstance3D", true, false):
		if str(get_path_to(node)).begins_with("Spielbrett/Ecken"):
			node.material_override = corner_material

func _apply_light(data: Dictionary) -> void:
	if get_parent() == null:
		return
	var light := get_parent().get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	if light != null:
		light.light_color = Color(str(data["light"]))

func _pixel_material(img: Image, scale_value: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(img)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(scale_value, scale_value, scale_value)
	material.roughness = 0.75
	return material

# --- Deko --------------------------------------------------------------------------

func _build_deco(data: Dictionary) -> void:
	var holder := get_node_or_null("Deko")
	if holder == null:
		holder = Node3D.new()
		holder.name = "Deko"
		add_child(holder)
	for child in holder.get_children():
		child.queue_free()
	_floaters.clear()
	var groups: Array = data["groups"].duplicate()
	groups.shuffle()
	var anchors: Array = ANCHORS.duplicate()
	var float_left := floating
	for i in range(mini(groups_per_side * 2, mini(groups.size(), anchors.size()))):
		var anchor: Vector2 = anchors[i]
		# Farben je Gruppe etwas vertauschen, damit nicht alles gleich aussieht
		var keys := ["a", "b", "c"]
		keys.shuffle()
		var swap := {"a": keys[0], "b": keys[1], "c": keys[2]}
		# Rechts gespiegelt, damit die Gruppen zur Brettmitte hin offen sind
		var mirror := -1.0 if anchor.x > 0 else 1.0
		for item in groups[i]:
			var design := _design(str(item[0]))
			if design.is_empty():
				continue
			var node := _build_design(design, data, swap)
			var offset: Vector2 = item[1] * DECO_SCALE
			node.position = Vector3(anchor.x + offset.x * mirror, TABLE_Y, anchor.y + offset.y)
			node.rotation_degrees.y = float(item[2]) * mirror
			node.scale = Vector3.ONE * float(item[3]) * DECO_SCALE
			holder.add_child(node)
			if float_left > 0 and design.get("float", false):
				float_left -= 1
				_floaters.append({"node": node, "y": TABLE_Y + 0.45, "phase": randf() * TAU, "spin": 8.0})

func _design(design_name: String) -> Dictionary:
	for design in DESIGNS:
		if str(design["name"]) == design_name:
			return design
	return {}

func _build_design(design: Dictionary, data: Dictionary = {}, swap: Dictionary = {}) -> Node3D:
	if data.is_empty():
		data = ROOMS[room]
	var root := Node3D.new()
	root.name = str(design["name"])
	for part in design["parts"]:
		var mesh := _mesh(str(part[0]), part[1])
		if mesh == null:
			continue
		var key := str(part[4])
		key = str(swap.get(key, key))
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = _material(key, data)
		instance.position = part[2]
		instance.rotation_degrees = part[3]
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(instance)
	return root

func _mesh(kind: String, p: Array) -> Mesh:
	match kind:
		"box":
			var m := BoxMesh.new()
			m.size = p[0]
			return m
		"sphere", "half":
			var m := SphereMesh.new()
			m.radius = p[0]
			m.height = p[0] * (1.0 if kind == "half" else 2.0)
			m.is_hemisphere = kind == "half"
			m.radial_segments = 12
			m.rings = 6
			return m
		"cyl":
			var m := CylinderMesh.new()
			m.top_radius = p[0]
			m.bottom_radius = p[1]
			m.height = p[2]
			m.radial_segments = int(p[3])
			m.rings = 1
			return m
		"prism":
			var m := PrismMesh.new()
			m.size = p[0]
			return m
		"torus":
			var m := TorusMesh.new()
			m.inner_radius = p[0]
			m.outer_radius = p[1]
			m.rings = 16
			m.ring_segments = 8
			return m
		"capsule":
			var m := CapsuleMesh.new()
			m.radius = p[0]
			m.height = p[1]
			m.radial_segments = 10
			m.rings = 3
			return m
	return null

# Farbe des Raums mit kleiner Pixeltextur (4×4, hell/dunkel getupft)
func _material(key: String, data: Dictionary) -> StandardMaterial3D:
	var cache_key := room + ":" + key
	if _materials.has(cache_key):
		return _materials[cache_key]
	var hex := str(data.get(key, PALETTE.get(key, "#ffffff")))
	var base := Color(hex)
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(base)
	img.set_pixel(0, 0, base.lightened(0.1))
	img.set_pixel(2, 2, base.lightened(0.1))
	img.set_pixel(2, 0, base.darkened(0.08))
	img.set_pixel(0, 2, base.darkened(0.08))
	var material := _pixel_material(img, 2.5)
	material.roughness = 0.8
	if key == "glow":
		material.emission_enabled = true
		material.emission = base
		material.emission_energy_multiplier = 1.4
	_materials[cache_key] = material
	return material

func _process(delta: float) -> void:
	_time += delta
	for f in _floaters:
		var node: Node3D = f["node"]
		if not is_instance_valid(node):
			continue
		node.position.y = float(f["y"]) + sin(_time * 0.9 + float(f["phase"])) * 0.1
		node.rotation_degrees.y += float(f["spin"]) * delta
