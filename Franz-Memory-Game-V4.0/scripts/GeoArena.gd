@tool
extends Node3D
## Boss-Arena aus einfachen Formen mit Pixel-Texturen (wie die Bosse in GeoBosses.gd).
## Die Szene (z. B. scenes/arenen/geo_clocher.tscn) hat feste Knoten:
##   BossPunkt  hier steht der Boss (verschieben = Boss steht woanders)
##   Kamera     so schaut die Kamera im Spiel (in Godot auf "Vorschau" klicken)
## Alles andere baut dieses Skript beim Start, auch im Godot-Editor (@tool),
## damit man die Arena dort sieht. Eigene Sachen kann man einfach in die Szene hängen.
##
## arena_style wählt die Arena. Die Farben stehen in PALETTES.

@export var arena_style := "clocher":
	set(value):
		arena_style = value
		if is_inside_tree():
			rebuild()

const PALETTES := {
	"clocher": {
		"sky_top": "#ffb37a", "sky_horizon": "#ffd9a8", "ground": "#c97b5a",
		"floor": "#c4532f", "floor_alt": "#e4704a", "tile": "#fcf4e3",
		"stone": "#d9954a", "stone_dark": "#94552a", "accent": "#2a9d8f", "accent_dark": "#21786d",
		"bronze": "#8a5a24", "roof": "#b5452c", "glow": "#ffc23d",
		"light": "#ffe1b8", "city": ["#d98c5f", "#c26a4a", "#e8b07a", "#a85a48"],
		"lamp_post": "#8a5a24", "lamp_roof": "#b5452c",
	},
	"serre": {
		"sky_top": "#6a5cb8", "sky_horizon": "#f2a8c0", "ground": "#4a7a5a",
		"floor": "#5cae62", "floor_alt": "#4f9c56", "tile": "#efe6cf",
		"stone": "#f4f2ea", "stone_dark": "#c9c3ae", "accent": "#efe6cf", "accent_dark": "#d8cdb0",
		"bronze": "#2f6b4a", "roof": "#ff7a90", "glow": "#ffd166",
		"light": "#ffe9f0", "hedge": "#2f9e57", "flower": ["#ff7a90", "#ffd166", "#ffffff", "#c58cff"],
		"glass": ["#ff8fb0", "#7fd6a0", "#9fc4ff", "#ffd166"],
		"lamp_post": "#2f6b4a", "lamp_roof": "#ff7a90",
	},
	"grotte": {
		"sky_top": "#0c2a44", "sky_horizon": "#2a8a96", "ground": "#0a2233",
		"floor": "#e3c48a", "floor_alt": "#d4b277", "tile": "#2ec4b6",
		"stone": "#3d6478", "stone_dark": "#2a4556", "accent": "#2ec4b6", "accent_dark": "#239e93",
		"bronze": "#1f6fb8", "roof": "#ff6b5e", "glow": "#66f2b3",
		"light": "#d6ecff", "water": "#1f8fd1",
		"coral": ["#ff6b5e", "#ff9f80", "#ffd166", "#c58cff"],
		"lamp_post": "#1f6fb8", "lamp_roof": "#ff6b5e",
	},
	"clairiere": {
		"sky_top": "#21184f", "sky_horizon": "#3fa58f", "ground": "#123236",
		"floor": "#3f9b5a", "floor_alt": "#368a50", "tile": "#d9c79a",
		"stone": "#9a94c4", "stone_dark": "#6a6396", "accent": "#7d63c9", "accent_dark": "#6a52b4",
		"bronze": "#4a2f55", "roof": "#f4476b", "glow": "#b8ff5a",
		"light": "#e2f4e6", "bark": "#4a2f55", "bark_light": "#6a4470", "root": "#8a5636",
		"moss": "#58c936", "water": "#62ddd0", "pine": "#174a4c", "pine_light": "#1f5f5b",
		"cloud": "#8f8ccf",
		"lamp_post": "#4a2f55", "lamp_roof": "#f4476b",
	},
}

const BOSS_SPOT := Vector3(0, 0.9, -8.4)   # hinter der letzten Kartenreihe
var built: Node3D
var swingers: Array[Dictionary] = []
var time := 0.0

func _ready() -> void:
	rebuild()

func rebuild() -> void:
	if built != null and is_instance_valid(built):
		built.queue_free()
	# Umgebung und Kerzen hängen direkt an der Szene (BossArena sucht sie dort)
	for fixed in ["Umgebung", "Kerzen"]:
		var old := get_node_or_null(fixed)
		if old != null:
			remove_child(old)
			old.queue_free()
	built = Node3D.new()
	built.name = "Gebaut"
	add_child(built)
	swingers.clear()
	match arena_style:
		"serre":
			_build_serre(PALETTES["serre"])
		"grotte":
			_build_grotte(PALETTES["grotte"])
		"clairiere":
			_build_clairiere(PALETTES["clairiere"])
		_:
			_build_clocher(PALETTES["clocher"])

func _process(delta: float) -> void:
	time += delta
	for s in swingers:
		var node: Node3D = s["node"]
		if not is_instance_valid(node):
			continue
		match str(s["kind"]):
			"swing":
				node.rotation_degrees.z = sin(time * float(s["speed"]) + float(s["phase"])) * float(s["amount"])
			"drift":
				node.position.x = float(s["x"]) + sin(time * 0.08 + float(s["phase"])) * 4.0
			"water":
				var m: StandardMaterial3D = s["material"]
				m.uv1_offset = Vector3(time * 0.02, time * 0.013, 0)
			"spin":
				node.rotation_degrees.y += float(s["speed"]) * get_process_delta_time()

# --- Bausteine --------------------------------------------------------------------------

var _materials: Dictionary = {}

func mat(hex: String, scale_value: float = 1.0, emission: float = 0.0) -> StandardMaterial3D:
	var key := "%s_%s_%s" % [hex, scale_value, emission]
	if _materials.has(key):
		return _materials[key]
	var base := Color(hex)
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(base)
	for p in [Vector2i(1, 1), Vector2i(5, 2), Vector2i(3, 5), Vector2i(7, 6)]:
		img.set_pixelv(p, base.lightened(0.12))
	for p in [Vector2i(6, 0), Vector2i(2, 3), Vector2i(0, 6), Vector2i(5, 7)]:
		img.set_pixelv(p, base.darkened(0.12))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(scale_value, scale_value, scale_value)
	m.roughness = 0.8
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = base
		m.emission_energy_multiplier = emission
	_materials[key] = m
	return m

# Fliesen: zwei Farben im Schachbrett, 1 Fliese = 1 Meter
func tiles(a: String, b: String) -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var ca := Color(a)
	var cb := Color(b)
	for y in range(16):
		for x in range(16):
			var c := ca if (x < 8) == (y < 8) else cb
			if x % 8 == 0 or y % 8 == 0:
				c = c.darkened(0.12)
			img.set_pixel(x, y, c)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.5, 0.5, 0.5)
	m.roughness = 0.85
	return m

func part(mesh: Mesh, material: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = pos
	instance.rotation_degrees = rot
	(parent if parent != null else built).add_child(instance)
	return instance

static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

static func cyl(bottom: float, top: float, height: float, segments: int = 8) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = bottom
	m.top_radius = top
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m

static func prism(size: Vector3) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = size
	return m

static func torus(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 48
	m.ring_segments = 6
	return m

# --- Le Clocher: Glockenturm über den Dächern von Paris (Le Sonneur) ----------------------

func _build_clocher(p: Dictionary) -> void:
	_environment(p)
	# Achteckige Turmplattform mit Fliesen, darunter der Turm
	part(cyl(17.0, 17.0, 1.0, 8), tiles(p["floor"], p["floor_alt"]), Vector3(0, -1.1, -3.0), Vector3(0, 22.5, 0))
	part(cyl(16.0, 17.0, 14.0, 8), mat(p["stone_dark"], 0.6), Vector3(0, -8.6, -3.0), Vector3(0, 22.5, 0))
	part(cyl(17.4, 17.4, 0.4, 8), mat(p["stone"], 0.8), Vector3(0, -0.75, -3.0), Vector3(0, 22.5, 0))
	_build_stage(p)
	# Glockenstuhl hinter dem Boss: zwei Pfeiler, Balken, drei Glocken
	var frame_z := BOSS_SPOT.z - 3.8
	for side in [-1.0, 1.0]:
		part(box(Vector3(1.2, 11.0, 1.2)), mat(p["floor"], 0.8), Vector3(side * 6.0, 4.4, frame_z))
		part(cyl(0.95, 0.0, 1.6, 4), mat(p["roof"], 1.0), Vector3(side * 6.0, 10.7, frame_z), Vector3(0, 45, 0))
	part(box(Vector3(13.4, 0.9, 1.0)), mat(p["stone_dark"], 1.0), Vector3(0, 9.4, frame_z))
	for i in range(3):
		var bell := Node3D.new()
		bell.position = Vector3((i - 1) * 4.2, 9.0, frame_z + 0.2)
		built.add_child(bell)
		var size := 1.0 if i != 1 else 1.35
		part(cyl(0.08, 0.08, 0.8, 6), mat(p["bronze"]), Vector3(0, -0.4, 0), Vector3.ZERO, bell)
		part(cyl(1.1 * size, 0.65 * size, 1.3 * size, 8), mat(p["accent"], 1.0), Vector3(0, -0.8 - 0.65 * size, 0), Vector3.ZERO, bell)
		part(cyl(0.6 * size, 0.3 * size, 0.5 * size, 8), mat(p["bronze"], 1.0), Vector3(0, -0.8 + 0.1 * size, 0), Vector3.ZERO, bell)
		part(torus(1.0 * size, 1.2 * size), mat(p["bronze"]), Vector3(0, -0.8 - 1.3 * size, 0), Vector3.ZERO, bell)
		swingers.append({"node": bell, "kind": "swing", "amount": 6.0 + i * 2.0, "speed": 0.8 + i * 0.15, "phase": i * 1.3})
	# Bögen rundherum (nur hinten und an den Seiten, vorne bleibt frei für die Kamera)
	var pillar_mat := mat(p["stone"], 0.8)
	var arch_mat := mat(p["floor"], 0.8)
	var radius := 16.0
	for i in range(9):
		var a := deg_to_rad(180.0 + i * 22.5)
		var pos := Vector3(cos(a) * radius, 0, sin(a) * radius - 3.0)
		part(box(Vector3(1.0, 7.0, 1.0)), pillar_mat, pos + Vector3(0, 2.5, 0), Vector3(0, -rad_to_deg(a), 0))
		if i < 8:
			var b := deg_to_rad(180.0 + (i + 1) * 22.5)
			var next := Vector3(cos(b) * radius, 0, sin(b) * radius - 3.0)
			var middle := (pos + next) / 2.0
			var length := pos.distance_to(next)
			var angle := -rad_to_deg(atan2(next.z - pos.z, next.x - pos.x))
			part(box(Vector3(length + 1.0, 0.9, 1.1)), arch_mat, middle + Vector3(0, 6.4, 0), Vector3(0, angle, 0))
			part(box(Vector3(length - 1.0, 1.1, 0.8)), mat(p["stone_dark"], 0.8), middle + Vector3(0, -0.05, 0), Vector3(0, angle, 0))
			# Dreieckiger Giebel auf jedem Bogen
			part(prism(Vector3(length + 0.6, 1.2, 0.9)), mat(p["roof"], 1.0), middle + Vector3(0, 7.45, 0), Vector3(0, angle, 0))
	# Paris unten: kleine Häuser mit Dächern, in der Ferne der Eiffelturm
	_build_city(p)
	_build_clouds(p)
	_build_motes(p)

# Gemeinsam für alle Arenen: Stufen unter den Karten, Leuchtring, Sockel für den Boss,
# Laternen am Spielfeldrand und das Licht über dem Spielfeld.
func _build_stage(p: Dictionary) -> void:
	# Stufen unter den Kartenreihen (jede Reihe etwas höher, hinten breiter)
	var rows := [3.69, 1.84, -0.17, -2.35, -4.69]
	for k in range(rows.size()):
		var top := 0.24 + 0.12 * k - 0.62
		var depth := 2.2
		var step := part(box(Vector3(7.4, top + 1.0, depth)), tiles(p["accent"], p["accent_dark"]), Vector3(0, -1.0 + (top + 1.0) / 2.0, rows[k]))
		step.name = "Stufe%d" % [k + 1]
	# Leuchtender Ring um das Spielfeld
	var glow := mat(p["glow"], 1.0, 1.8)
	var ring_node := part(torus(5.6, 5.85), glow, Vector3(0, -0.55, -0.4))
	ring_node.scale = Vector3(1.0, 1.0, 1.25)
	ring_node.name = "LeuchtKreis"
	# Sockel für den Boss
	part(cyl(2.6, 2.45, 1.5, 8), mat(p["stone"], 0.8), BOSS_SPOT + Vector3(0, -0.75, 0), Vector3(0, 22.5, 0))
	part(cyl(2.75, 2.75, 0.25, 8), mat(p["accent"], 1.2), BOSS_SPOT + Vector3(0, -0.12, 0), Vector3(0, 22.5, 0))
	# Laternen am Spielfeldrand (Lichter darin flackern im Spiel)
	var lights := Node3D.new()
	lights.name = "Kerzen"
	add_child(lights)
	for side in [-1.0, 1.0]:
		for z in [3.0, -1.0, -5.0]:
			var post_pos := Vector3(side * 4.6, -0.6, z)
			part(cyl(0.09, 0.09, 1.6, 6), mat(p["lamp_post"]), post_pos + Vector3(0, 0.8, 0))
			part(box(Vector3(0.38, 0.45, 0.38)), mat(p["glow"], 1.0, 2.5), post_pos + Vector3(0, 1.8, 0))
			part(cyl(0.3, 0.0, 0.3, 4), mat(p["lamp_roof"]), post_pos + Vector3(0, 2.18, 0), Vector3(0, 45, 0))
			var lamp := OmniLight3D.new()
			lamp.position = post_pos + Vector3(0, 1.8, 0)
			lamp.light_color = Color(p["glow"])
			lamp.light_energy = 0.8
			lamp.omni_range = 4.5
			lights.add_child(lamp)
	# Licht über dem Spielfeld
	var board_light := OmniLight3D.new()
	board_light.name = "Spielfeldlicht"
	board_light.position = Vector3(0, 6, 1)
	board_light.light_color = Color(p["light"])
	board_light.light_energy = 0.7
	board_light.omni_range = 14
	built.add_child(board_light)

func _environment(p: Dictionary) -> void:
	var env_node := WorldEnvironment.new()
	env_node.name = "Umgebung"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(p["sky_top"])
	sky_mat.sky_horizon_color = Color(p["sky_horizon"])
	sky_mat.ground_horizon_color = Color(p["sky_horizon"])
	sky_mat.ground_bottom_color = Color(p["ground"])
	sky_mat.sun_angle_max = 0.0
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(p["light"])
	env.ambient_light_energy = 0.22
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.05
	env.fog_enabled = true
	env.fog_light_color = Color(p["sky_horizon"])
	env.fog_density = 0.004
	env_node.environment = env
	add_child(env_node)
	# Abendsonne von der Seite
	var sun := DirectionalLight3D.new()
	sun.name = "Sonne"
	sun.rotation_degrees = Vector3(-35, -50, 0)
	sun.light_color = Color(p["light"])
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.6
	built.add_child(sun)

func _build_city(p: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var colors: Array = p["city"]
	for i in range(70):
		var a := rng.randf_range(PI * 0.95, TAU * 1.02)
		var dist := rng.randf_range(24.0, 48.0)
		var pos := Vector3(cos(a) * dist, 0, sin(a) * dist - 3.0)
		var height := rng.randf_range(2.0, 5.5)
		var width := rng.randf_range(1.8, 3.5)
		var ground := -16.0 + rng.randf_range(-1.0, 2.0)
		var color: String = colors[i % colors.size()]
		part(box(Vector3(width, height, width)), mat(color, 0.5), Vector3(pos.x, ground + height / 2.0, pos.z), Vector3(0, rng.randf_range(0, 90), 0))
		part(cyl(width * 0.75, 0.0, 1.4, 4), mat(p["roof"] if i % 3 else p["accent"], 0.8), Vector3(pos.x, ground + height + 0.7, pos.z), Vector3(0, 45 + rng.randf_range(0, 90), 0))
	# Eiffelturm in der Ferne
	var tower := Vector3(-34, -16, -40)
	part(cyl(4.5, 2.2, 7.0, 4), mat(p["stone_dark"], 0.5), tower + Vector3(0, 3.5, 0), Vector3(0, 45, 0))
	part(cyl(2.0, 0.9, 8.0, 4), mat(p["stone_dark"], 0.5), tower + Vector3(0, 11.0, 0), Vector3(0, 45, 0))
	part(cyl(0.85, 0.0, 9.0, 4), mat(p["stone_dark"], 0.5), tower + Vector3(0, 19.5, 0), Vector3(0, 45, 0))

func _build_clouds(p: Dictionary) -> void:
	var map_script := preload("res://scripts/CampaignMap.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(12):
		var sprite := Sprite3D.new()
		sprite.texture = map_script._cloud_texture(900 + i * 31, 48 + (i % 3) * 16, 20 + (i % 2) * 6)
		sprite.pixel_size = rng.randf_range(0.3, 0.5)
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.shaded = false
		sprite.modulate = Color(str(p.get("cloud", "#fff2e6")))
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.position = Vector3(rng.randf_range(-45, 45), rng.randf_range(4, 16), rng.randf_range(-60, -40))
		built.add_child(sprite)
		swingers.append({"node": sprite, "kind": "drift", "x": sprite.position.x, "phase": rng.randf() * TAU})

# Warme Staubkörnchen in der Abendluft
func _build_motes(p: Dictionary) -> void:
	var motes := CPUParticles3D.new()
	motes.name = "Asche"
	motes.amount = 60
	motes.lifetime = 7.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(10, 4, 8)
	motes.position = Vector3(0, 3, -3)
	motes.direction = Vector3(0.3, 1, 0)
	motes.spread = 30
	motes.gravity = Vector3(0, 0.05, 0)
	motes.initial_velocity_min = 0.1
	motes.initial_velocity_max = 0.35
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(p["glow"])
	quad.material = m
	motes.mesh = quad
	built.add_child(motes)

# --- La Serre: Wintergarten in der Abenddämmerung (La Veuve de Cendre) --------------------

func _build_serre(p: Dictionary) -> void:
	_environment(p)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	# Runder Rasen mit einem hellen Steinweg
	part(cyl(22.0, 22.0, 1.0, 24), tiles(p["floor"], p["floor_alt"]), Vector3(0, -1.1, -3.0))
	var path := part(torus(6.6, 8.2), mat(p["tile"], 1.0), Vector3(0, -0.6, -1.5))
	path.scale = Vector3(1.0, 0.25, 1.15)
	_build_stage(p)
	# Glashaus hinter der Witwe: weisse Pfeiler, hohe Fenster mit Spitzbogen aus farbigem Glas
	var frame_mat := mat(p["stone"], 1.0)
	var glass_colors: Array = p["glass"]
	var center := Vector3(0, 0, -9.0)
	var count := 9
	for i in range(count):
		var a := deg_to_rad(200.0 + i * (140.0 / (count - 1)))
		var pos := center + Vector3(cos(a) * 9.5, 0, sin(a) * 6.0)
		var facing := -rad_to_deg(atan2(center.z - pos.z, center.x - pos.x)) + 90.0
		part(box(Vector3(0.5, 9.0, 0.5)), frame_mat, pos + Vector3(0, 3.9, 0), Vector3(0, facing, 0))
		if i < count - 1:
			var b := deg_to_rad(200.0 + (i + 1) * (140.0 / (count - 1)))
			var next := center + Vector3(cos(b) * 9.5, 0, sin(b) * 6.0)
			var middle := (pos + next) / 2.0
			var width := pos.distance_to(next) - 0.5
			var angle := -rad_to_deg(atan2(next.z - pos.z, next.x - pos.x))
			var color: String = glass_colors[i % glass_colors.size()]
			var glass := mat(color, 1.6, 0.9)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.albedo_color = Color(1, 1, 1, 0.75)
			part(box(Vector3(width, 6.0, 0.1)), glass, middle + Vector3(0, 3.6, 0), Vector3(0, angle, 0))
			part(prism(Vector3(width, 1.8, 0.1)), glass, middle + Vector3(0, 7.5, 0), Vector3(0, angle, 0))
			# Sprossen im Fenster
			part(box(Vector3(0.12, 7.6, 0.16)), frame_mat, middle + Vector3(0, 4.3, 0), Vector3(0, angle, 0))
			part(box(Vector3(width, 0.14, 0.16)), frame_mat, middle + Vector3(0, 3.0, 0), Vector3(0, angle, 0))
			part(box(Vector3(width + 0.5, 0.35, 0.4)), frame_mat, middle + Vector3(0, 0.45, 0), Vector3(0, angle, 0))
	# Dachrippen laufen oben zur Mitte zusammen
	for i in range(count):
		var a := deg_to_rad(200.0 + i * (140.0 / (count - 1)))
		var top := center + Vector3(cos(a) * 9.5, 8.4, sin(a) * 6.0)
		var peak := center + Vector3(0, 12.5, 0)
		var rib := part(box(Vector3(0.25, 0.25, top.distance_to(peak))), frame_mat, (top + peak) / 2.0)
		rib.look_at_from_position((top + peak) / 2.0, peak, Vector3.UP)
	part(cyl(0.6, 0.0, 1.4, 6), mat(p["roof"]), center + Vector3(0, 13.1, 0))
	# Hecken links und rechts, Formschnitt-Bäume und Blumenbeete
	var hedge := mat(p["hedge"], 1.0)
	for side in [-1.0, 1.0]:
		part(box(Vector3(1.4, 1.6, 12.0)), hedge, Vector3(side * 8.5, 0.0, -1.0))
		for z in [-6.5, -1.0, 4.5]:
			part(cyl(0.18, 0.2, 1.2, 6), mat("#7a5236"), Vector3(side * 10.8, 0.0, z))
			part(cyl(1.1, 0.0, 3.0, 8), hedge, Vector3(side * 10.8, 2.0, z))
			part(GeoArenaBall(0.75), mat(p["floor_alt"], 1.2), Vector3(side * 6.8, -0.1, z + 1.8))
	var flowers: Array = p["flower"]
	for i in range(80):
		var side := -1.0 if i % 2 == 0 else 1.0
		var pos := Vector3(side * rng.randf_range(5.4, 7.8), -0.45, rng.randf_range(-7.5, 5.0))
		part(GeoArenaBall(rng.randf_range(0.12, 0.2)), mat(flowers[i % flowers.size()], 2.0), pos)
	# Rosenbögen vorne an den Seiten
	for side in [-1.0, 1.0]:
		var arch_pos := Vector3(side * 6.2, -0.6, 6.0)
		for dx in [-0.9, 0.9]:
			part(box(Vector3(0.2, 3.2, 0.2)), frame_mat, arch_pos + Vector3(dx, 1.6, 0))
		part(torus(0.8, 1.0), frame_mat, arch_pos + Vector3(0, 3.2, 0), Vector3(90, 0, 0))
		for k in range(6):
			var a := PI * k / 5.0
			part(GeoArenaBall(0.16), mat(flowers[k % 2], 2.0), arch_pos + Vector3(cos(a) * 0.9, 3.2 + sin(a) * 0.9, 0.1))
	_build_clouds(p)
	_build_petals(p)

static func GeoArenaBall(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 8
	m.rings = 4
	return m

# Fallende Blütenblätter und ein wenig Asche
func _build_petals(p: Dictionary) -> void:
	var petals := CPUParticles3D.new()
	petals.name = "Asche"
	petals.amount = 70
	petals.lifetime = 8.0
	petals.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	petals.emission_box_extents = Vector3(12, 0.5, 9)
	petals.position = Vector3(0, 10, -3)
	petals.direction = Vector3(0.4, -1, 0)
	petals.spread = 25
	petals.gravity = Vector3(0.15, -0.35, 0)
	petals.initial_velocity_min = 0.2
	petals.initial_velocity_max = 0.5
	petals.angular_velocity_min = -90
	petals.angular_velocity_max = 90
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.08)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	quad.material = m
	petals.mesh = quad
	var colors := Gradient.new()
	colors.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	colors.set_color(0, Color(p["roof"]))
	colors.set_color(1, Color("#ffffff"))
	colors.add_point(0.5, Color("#9aa0bd"))
	petals.color_initial_ramp = colors
	built.add_child(petals)

# --- La Clairière: Lichtung im toten Hain bei Nacht (Le Pâtre des Racines) -----------------

# Ast aus Blöcken, der sich verzweigt. tips sammelt die Astspitzen.
func _branch(parent: Node3D, start: Vector3, angle: float, length: float, thick: float, depth: int, material: Material, rng: RandomNumberGenerator, tips: Array) -> void:
	var end := start + Vector3(-sin(angle), cos(angle), 0) * length
	var bar := part(box(Vector3(thick, length + thick * 0.4, thick)), material, (start + end) / 2.0, Vector3.ZERO, parent)
	bar.rotation.z = angle
	if depth <= 0:
		tips.append(end)
		return
	for side in [-1.0, 1.0]:
		_branch(parent, end, angle + side * rng.randf_range(0.35, 0.7), length * rng.randf_range(0.66, 0.8), thick * 0.68, depth - 1, material, rng, tips)

# Kahler Baum: Stamm und zwei Astebenen über Kreuz
func _bare_tree(base: Vector3, height: float, thick: float, material: Material, rng: RandomNumberGenerator) -> void:
	var holder := Node3D.new()
	holder.position = base
	holder.rotation_degrees.y = rng.randf_range(0, 180)
	built.add_child(holder)
	part(cyl(thick * 1.35, thick * 0.72, height * 0.5, 6), material, Vector3(0, height * 0.25, 0), Vector3.ZERO, holder)
	var tips: Array = []
	for k in range(2):
		var plane := Node3D.new()
		plane.rotation_degrees.y = k * 90.0
		holder.add_child(plane)
		_branch(plane, Vector3(0, height * 0.48, 0), rng.randf_range(-0.2, 0.2), height * 0.24, thick * 0.9, 2 + (1 - k), material, rng, tips)

func _mushroom(pos: Vector3, size: float, cap_color: String, stem_color: String) -> void:
	part(cyl(0.1 * size, 0.08 * size, 0.4 * size, 6), mat(stem_color, 2.0), pos + Vector3(0, 0.2 * size, 0))
	part(cyl(0.38 * size, 0.08 * size, 0.28 * size, 8), mat(cap_color, 2.0, 0.2), pos + Vector3(0, 0.52 * size, 0))

func _build_clairiere(p: Dictionary) -> void:
	_environment(p)
	var rng := RandomNumberGenerator.new()
	rng.seed = 58
	# Dunkler Waldboden bis zum Horizont, darauf die runde Lichtung
	part(cyl(110.0, 110.0, 1.0, 24), mat(p["ground"], 0.3), Vector3(0, -2.0, -3.0))
	part(cyl(22.0, 22.5, 1.0, 24), tiles(p["floor"], p["floor_alt"]), Vector3(0, -1.1, -3.0))
	_build_stage(p)
	var bark := mat(p["bark"], 0.8)
	var bark_light := mat(p["bark_light"], 0.8)
	var root_mat := mat(p["root"], 1.0)
	var moss := mat(p["moss"], 1.2, 0.08)
	var glow := mat(p["glow"], 1.0, 1.7)
	# Riesiger toter Baum hinter dem Boss, seine Äste bilden ein Tor
	var tree := Node3D.new()
	tree.position = Vector3(0, -0.6, BOSS_SPOT.z - 7.5)
	built.add_child(tree)
	part(cyl(4.2, 2.7, 3.0, 8), bark, Vector3(0, 1.5, 0), Vector3.ZERO, tree)
	part(cyl(2.7, 2.1, 5.0, 8), bark_light, Vector3(0, 5.5, 0), Vector3.ZERO, tree)
	part(cyl(2.1, 1.5, 3.2, 8), bark, Vector3(0, 9.6, 0), Vector3.ZERO, tree)
	var tips: Array = []
	for side in [-1.0, 1.0]:
		_branch(tree, Vector3(side * 1.1, 8.0, 0), -side * 1.05, 4.8, 0.95, 3, bark, rng, tips)
		_branch(tree, Vector3(side * 0.7, 10.6, 0), -side * 0.45, 3.8, 0.75, 3, bark_light, rng, tips)
	# Leuchtende Samen hängen an den Astspitzen und pendeln
	for i in range(0, tips.size(), 3):
		var lantern := Node3D.new()
		lantern.position = tips[i]
		tree.add_child(lantern)
		var drop := 0.55 + (i % 4) * 0.2
		part(cyl(0.03, 0.03, drop, 4), bark, Vector3(0, -drop / 2.0, 0), Vector3.ZERO, lantern)
		part(cyl(0.0, 0.26, 0.3, 4), glow, Vector3(0, -drop - 0.15, 0), Vector3(0, 45, 0), lantern)
		part(cyl(0.26, 0.0, 0.3, 4), glow, Vector3(0, -drop - 0.45, 0), Vector3(0, 45, 0), lantern)
		swingers.append({"node": lantern, "kind": "swing", "amount": 7.0, "speed": 0.8 + (i % 5) * 0.12, "phase": i * 0.7})
	# Steinkreis mit leuchtenden Zeichen und Moos-Kappen
	for i in range(11):
		var a := deg_to_rad(188.0 + i * 16.4)
		var pos := Vector3(cos(a) * 17.5, -0.6, sin(a) * 13.0 - 3.0)
		var height := rng.randf_range(3.6, 6.2)
		var yaw := -rad_to_deg(a) + 90.0
		var stone := Node3D.new()
		stone.position = pos
		stone.rotation_degrees = Vector3(rng.randf_range(-3, 3), yaw, rng.randf_range(-5, 5))
		built.add_child(stone)
		part(box(Vector3(1.9, height, 1.2)), mat(p["stone"] if i % 2 else p["stone_dark"], 0.8), Vector3(0, height / 2.0, 0), Vector3.ZERO, stone)
		part(cyl(1.0, 0.0, 0.9, 4), mat(p["stone_dark"] if i % 2 else p["stone"], 0.8), Vector3(0, height + 0.45, 0), Vector3(0, 45, 0), stone)
		part(box(Vector3(2.05, 0.35, 1.35)), moss, Vector3(0, height * 0.62, 0), Vector3.ZERO, stone)
		part(box(Vector3(0.34, 0.34, 0.08)), glow, Vector3(0, height * 0.4, 0.62), Vector3(0, 0, 45), stone)
	# Kahle Bäume links und rechts auf der Lichtung
	for side in [-1.0, 1.0]:
		for i in range(5):
			var pos := Vector3(side * rng.randf_range(11.5, 15.5), -0.6, -8.5 + i * 3.8 + rng.randf_range(-0.8, 0.8))
			_bare_tree(pos, rng.randf_range(6.5, 9.5), rng.randf_range(0.34, 0.5), bark if i % 2 else bark_light, rng)
	# Grosse Wurzelbögen wachsen aus dem Boden
	for side in [-1.0, 1.0]:
		for r in range(4):
			var radius := 2.3 - r * 0.22
			var arch := part(torus(radius - 0.38, radius), root_mat, Vector3(side * (8.7 + r % 2 * 0.6), -0.72, 3.8 - r * 2.8), Vector3(90, side * 12.0, 0))
			arch.name = "Wurzelbogen"
			part(box(Vector3(0.8, 0.14, 0.72)), moss, Vector3(side * (8.7 + r % 2 * 0.6), radius - 0.67, 3.8 - r * 2.8))
	# Pfützen, in denen sich der Mond spiegelt
	var water := mat(p["water"], 1.5, 0.45)
	water.roughness = 0.12
	for pos in [Vector3(-6.4, -0.58, 4.8), Vector3(6.2, -0.58, 1.8), Vector3(-7.2, -0.58, -3.8), Vector3(7.0, -0.58, -6.0)]:
		var puddle := part(cyl(1.25, 1.25, 0.05, 10), water, pos)
		puddle.scale = Vector3(1.0, 1.0, 0.62)
	# Pilze, Farne und Hexenring
	for i in range(34):
		var side := -1.0 if i % 2 == 0 else 1.0
		var pos := Vector3(side * rng.randf_range(5.2, 10.5), -0.6, rng.randf_range(-9.0, 7.0))
		if i % 3 == 0:
			for k in range(4):
				var leaf := part(prism(Vector3(0.34, 0.95, 0.08)), mat(p["moss"], 2.0), pos + Vector3(0, 0.45, 0), Vector3(rng.randf_range(-25, 25), k * 45.0, rng.randf_range(-22, 22)))
				leaf.name = "Farn"
		else:
			_mushroom(pos, rng.randf_range(0.9, 1.6), p["roof"] if i % 2 else p["glow"], p["tile"])
	# Tannen als dunkle Waldwand in der Ferne
	for i in range(58):
		var a := rng.randf_range(PI * 0.93, TAU * 1.035)
		var dist := rng.randf_range(27.0, 62.0)
		var pos := Vector3(cos(a) * dist, -1.5, sin(a) * dist - 3.0)
		var height := rng.randf_range(7.0, 15.0)
		var pine := mat(p["pine"] if i % 2 else p["pine_light"], 0.5)
		part(cyl(height * 0.27, height * 0.12, height * 0.55, 6), pine, pos + Vector3(0, height * 0.28, 0))
		part(cyl(height * 0.2, 0.0, height * 0.6, 6), pine, pos + Vector3(0, height * 0.72, 0))
	# Mond, Sterne, Wolken und Glühwürmchen
	var moon := part(GeoArenaBall(6.0), mat("#fff1bd", 1.0, 1.5), Vector3(-30, 27, -78))
	moon.name = "Mond"
	var star := mat("#ffffff", 1.0, 2.0)
	for i in range(55):
		var a := rng.randf_range(PI * 1.02, TAU * 0.98)
		var size := rng.randf_range(0.14, 0.32)
		part(box(Vector3.ONE * size), star, Vector3(cos(a) * 82.0, rng.randf_range(15.0, 54.0), sin(a) * 82.0), Vector3(0, 0, 45))
	_build_clouds(p)
	_build_motes(p)

# --- La Grotte: Meeresgrotte zur blauen Stunde (Le Prince des Os) -------------------------

func _build_grotte(p: Dictionary) -> void:
	_environment(p)
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	# Meer bis zum Horizont, leicht leuchtend, Wellenmuster wandert
	var water := StandardMaterial3D.new()
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var sea := Color(p["water"])
	img.fill(sea)
	for k in range(14):
		img.set_pixel((k * 7) % 16, (k * 5) % 16, sea.lightened(0.35))
		img.set_pixel((k * 7 + 1) % 16, (k * 5) % 16, sea.lightened(0.2))
	water.albedo_texture = ImageTexture.create_from_image(img)
	water.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	water.uv1_scale = Vector3(60, 60, 1)
	water.emission_enabled = true
	water.emission = sea
	water.emission_energy_multiplier = 0.25
	water.roughness = 0.15
	var plane := PlaneMesh.new()
	plane.size = Vector2(240, 240)
	part(plane, water, Vector3(0, -1.3, 0))
	swingers.append({"node": built, "kind": "water", "material": water})
	# Sandinsel mit Schaumrand
	part(cyl(18.0, 19.5, 1.2, 20), tiles(p["floor"], p["floor_alt"]), Vector3(0, -1.2, -3.0))
	var foam := part(torus(18.8, 20.2), mat("#e9f7ff", 1.0, 0.4), Vector3(0, -1.25, -3.0))
	foam.scale = Vector3(1.0, 0.15, 1.0)
	_build_stage(p)
	# Felsbogen hinter dem Prinzen
	var rock := mat(p["stone"], 0.7)
	var rock_dark := mat(p["stone_dark"], 0.7)
	var arch_z := BOSS_SPOT.z - 4.0
	for side in [-1.0, 1.0]:
		for k in range(5):
			var size := Vector3(2.4 - k * 0.2, 2.2, 2.2 - k * 0.15)
			part(box(size), rock if k % 2 == 0 else rock_dark, Vector3(side * (6.0 - k * 0.25), -0.2 + k * 2.0, arch_z + rng.randf_range(-0.3, 0.3)), Vector3(rng.randf_range(-6, 6), rng.randf_range(-20, 20), rng.randf_range(-5, 5)))
	for k in range(6):
		var x := -5.5 + k * 2.2
		part(box(Vector3(2.6, 1.8, 2.2)), rock_dark if k % 2 == 0 else rock, Vector3(x, 10.0 + sin(k * 0.9) * 0.5, arch_z), Vector3(rng.randf_range(-8, 8), rng.randf_range(-15, 15), rng.randf_range(-10, 10)))
	# Grottenwand im Halbkreis dahinter, mit leuchtenden Kristallen
	var glow := mat(p["glow"], 1.0, 1.6)
	for i in range(16):
		var a := deg_to_rad(190.0 + i * 10.5)
		var pos := Vector3(cos(a) * 17.0, 0, sin(a) * 14.0 - 3.0)
		var height := rng.randf_range(5.0, 11.0)
		part(box(Vector3(rng.randf_range(3.0, 4.5), height, 3.0)), rock if i % 2 else rock_dark, pos + Vector3(0, height / 2.0 - 1.0, 0), Vector3(0, -rad_to_deg(a) + 90 + rng.randf_range(-15, 15), rng.randf_range(-6, 6)))
		if i % 3 == 0:
			for c in range(3):
				var crystal := part(cyl(0.25, 0.0, rng.randf_range(1.0, 1.8), 5), glow, pos + Vector3(rng.randf_range(-1, 1), rng.randf_range(0.0, height * 0.6), 1.5))
				crystal.rotation_degrees = Vector3(rng.randf_range(-30, 30), 0, rng.randf_range(-30, 30))
	# Riesiges Rippenskelett eines Meeresungeheuers links und rechts:
	# Knochenringe, halb im Sand, ragen als Bögen heraus
	var bone := mat("#efe6cf", 1.0)
	for side in [-1.0, 1.0]:
		for r in range(4):
			var radius := 2.7 - r * 0.3
			var rib := part(torus(radius - 0.28, radius), bone, Vector3(side * 10.2, -0.7, 3.0 - r * 2.5), Vector3(90, 0, 0))
			rib.name = "Rippe"
		part(box(Vector3(0.5, 0.5, 9.5)), bone, Vector3(side * 10.2, 1.85, -0.8), Vector3(-3.0, 0, 0))
		part(box(Vector3(1.4, 1.1, 1.3)), bone, Vector3(side * 10.2, 1.7, 4.4))
	# Korallen, Muscheln und Seesterne im Sand
	var corals: Array = p["coral"]
	for i in range(40):
		var side := -1.0 if i % 2 == 0 else 1.0
		var pos := Vector3(side * rng.randf_range(5.2, 9.5), -0.6, rng.randf_range(-8.0, 6.5))
		var color: String = corals[i % corals.size()]
		match i % 4:
			0:
				for b in range(3):
					var branch := part(cyl(0.08, 0.04, rng.randf_range(0.6, 1.1), 5), mat(color, 2.0), pos + Vector3(rng.randf_range(-0.2, 0.2), 0.4, rng.randf_range(-0.2, 0.2)))
					branch.rotation_degrees = Vector3(rng.randf_range(-35, 35), 0, rng.randf_range(-35, 35))
			1:
				part(GeoArenaBall(rng.randf_range(0.2, 0.35)), mat(color, 2.0), pos + Vector3(0, 0.1, 0))
			2:
				for arm in range(5):
					part(box(Vector3(0.36, 0.06, 0.1)), mat(color, 2.0), pos + Vector3(cos(arm * TAU / 5.0) * 0.18, 0.03, sin(arm * TAU / 5.0) * 0.18), Vector3(0, -arm * 72.0, 0))
			3:
				part(cyl(0.25, 0.0, 0.3, 6), mat("#ffe7d1", 2.0), pos + Vector3(0, 0.1, 0), Vector3(-70, rng.randf_range(0, 360), 0))
	# Leuchtturm weit draussen auf einem Felsen, das Licht dreht sich
	var lighthouse := Vector3(30, -1.3, -45)
	part(cyl(4.0, 3.0, 3.0, 7), rock_dark, lighthouse + Vector3(0, 1.0, 0))
	for k in range(4):
		part(cyl(1.3 - k * 0.12, 1.2 - k * 0.12, 2.0, 10), mat("#ffffff" if k % 2 == 0 else p["roof"], 1.0), lighthouse + Vector3(0, 3.5 + k * 2.0, 0))
	part(cyl(0.9, 0.9, 1.0, 10), mat(p["glow"], 1.0, 3.0), lighthouse + Vector3(0, 11.0, 0))
	part(cyl(1.1, 0.0, 1.2, 10), mat(p["roof"], 1.0), lighthouse + Vector3(0, 12.1, 0))
	var beam_holder := Node3D.new()
	beam_holder.position = lighthouse + Vector3(0, 11.0, 0)
	built.add_child(beam_holder)
	var beam_mat := StandardMaterial3D.new()
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam_mat.albedo_color = Color(1.0, 0.95, 0.7, 0.18)
	beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var beam := part(cyl(0.3, 2.2, 22.0, 10), beam_mat, Vector3(0, 0, 11.0), Vector3(90, 0, 0), beam_holder)
	swingers.append({"node": beam_holder, "kind": "spin", "speed": 30.0})
	# Mond und Wolken
	var moon := part(GeoArenaBall(4.0), mat("#fff3c4", 1.0, 1.4), Vector3(-26, 24, -70))
	moon.name = "Mond"
	_build_clouds(p)
	# Aufsteigende Lichtpunkte (Plankton)
	var motes := CPUParticles3D.new()
	motes.name = "Asche"
	motes.amount = 60
	motes.lifetime = 6.0
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	motes.emission_box_extents = Vector3(11, 1, 9)
	motes.position = Vector3(0, 0, -3)
	motes.direction = Vector3(0, 1, 0)
	motes.spread = 20
	motes.gravity = Vector3(0, 0.1, 0)
	motes.initial_velocity_min = 0.2
	motes.initial_velocity_max = 0.5
	var quad := QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(p["glow"])
	quad.material = m
	motes.mesh = quad
	built.add_child(motes)
