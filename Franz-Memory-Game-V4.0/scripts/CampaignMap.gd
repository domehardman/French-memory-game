extends Node3D
## Kampagne als 3D-Weltkarte (scenes/Kampagne.tscn).
## Jede Welt ist eine kleine Insel im Stil ihres Raums (siehe scripts/Hintergrund.gd).
## Ein Pfad aus Steinen verbindet die Level-Marken, am Ende steht das Boss-Tor.
## Die Kamera gleitet von Insel zu Insel. Klick auf eine Marke öffnet die Level-Info.
##
## Namen und Räume der Welten: data/worlds.json. Welche Level zu welcher Welt gehören,
## ergibt sich aus data/campaign.json: jeder Boss schliesst eine Welt ab.

const UI = preload("res://scripts/MenuUI.gd")
const PixelFont = preload("res://scripts/PixelFont.gd")
const RoomScript = preload("res://scripts/Hintergrund.gd")
const WORLDS_PATH := "res://data/worlds.json"

const ISLAND_SPACING := 24.0      # Abstand der Inseln (Meter)
const ISLAND_RADIUS := Vector2(7.8, 5.0)   # Halbachsen der Insel (x, z)
# Farbe von Erde/Fels unter der Insel und Himmelsfarbe je Raum
const EARTH := {"cafe": "#8a5233", "jardin": "#6e4a33", "riviera": "#b98a52", "nuit": "#2c2a5e"}
const SKY := {"cafe": "#ffc896", "jardin": "#a6e3f7", "riviera": "#86d6ff", "nuit": "#151b42"}
# Farbe der Inseloberfläche, falls anders als der Tisch im Spiel
const ISLAND_TOP := {"riviera": "#e3bf7c"}
const CLOUD_TINT := {"cafe": "#fff4e6", "jardin": "#ffffff", "riviera": "#ffffff", "nuit": "#8790d0"}
# Plätze der 5 Level-Marken und des Boss-Tors auf jeder Insel (x, z)
const LEVEL_POINTS := [Vector2(-5.6, 2.2), Vector2(-3.2, 0.5), Vector2(-0.9, 2.1), Vector2(1.4, 0.4), Vector2(3.6, 2.0)]
const GATE_POINT := Vector2(5.4, -1.3)
# Plätze der Deko-Gruppen (hinten auf der Insel)
const DECO_POINTS := [Vector2(-5.6, -2.6), Vector2(-2.2, -2.9), Vector2(1.3, -2.7)]
const CAMERA_OFFSET := Vector3(0, 8.8, 13.5)
const LOCKED_COLOR := "#7d7a90"

var worlds: Array[Dictionary] = []     # title, name, room, levels (Indizes)
var current_world := 0
var camera: Camera3D
var environment: Environment
var tokens: Array[Dictionary] = []     # node, index, bounce
var spinners: Array[Node3D] = []
var helpers: Dictionary = {}           # Raum -> Hintergrund-Helfer (Formen, Materialien)
var time := 0.0
var sky_material: ProceduralSkyMaterial
var bobbers: Array[Dictionary] = []      # schwebende Felsen, Vögel, Vordergrund-Wolken
var waterfalls: Array[StandardMaterial3D] = []
static var _cloud_textures: Array[Texture2D] = []

var title_label: Label
var stars_label: Label
var lock_label: Label
var dots_label: Label
var info_panel: PanelContainer
var info_box: VBoxContainer
var banner: Label
var left_button: Button
var right_button: Button

func _ready() -> void:
	get_viewport().physics_object_picking = true
	MusicPlayer.play("menu")
	_load_worlds()
	_build_scene()
	for w in range(worlds.size()):
		_build_island(w)
	_build_ui()
	# Wo geht es weiter? Neue Welt frisch freigeschaltet -> hingleiten mit Banner
	var start := _world_of(_next_level())
	var seen := int(PlayerProgress.data.get("worlds_seen", 1))
	var open := _open_worlds()
	if open > seen and open - 1 < worlds.size():
		PlayerProgress.data["worlds_seen"] = open
		PlayerProgress.save_progress()
		_show_world(open - 2, false)
		await get_tree().create_timer(0.6).timeout
		_show_world(open - 1, true)
		_show_banner(UI.text("world_unlocked") % [str(worlds[open - 1]["name"])])
	else:
		if open > seen:
			PlayerProgress.data["worlds_seen"] = open
			PlayerProgress.save_progress()
		_show_world(start, false)

# --- Daten ---------------------------------------------------------------------------

func _load_worlds() -> void:
	var defs: Array = []
	var file := FileAccess.open(WORLDS_PATH, FileAccess.READ)
	if file != null:
		var parsed = JSON.parse_string(file.get_as_text())
		if parsed is Array:
			defs = parsed
	var count := PlayerProgress.campaign_world(PlayerProgress.campaign.size() - 1) + 1
	for w in range(count):
		var def: Dictionary = defs[w] if w < defs.size() and defs[w] is Dictionary else {}
		var room_names: Array = RoomScript.ROOM_ORDER
		worlds.append({
			"title": str(def.get("title", "Monde %d" % [w + 1])),
			"name": str(def.get("name", "")),
			"room": str(def.get("room", room_names[w % room_names.size()])),
			"levels": [],
		})
	for i in range(PlayerProgress.campaign.size()):
		var w := mini(PlayerProgress.campaign_world(i), worlds.size() - 1)
		worlds[w]["levels"].append(i)

func _world_of(index: int) -> int:
	for w in range(worlds.size()):
		if worlds[w]["levels"].has(index):
			return w
	return 0

# Das Level, das als Nächstes dran ist (erstes offenes ohne Sterne)
func _next_level() -> int:
	for i in range(PlayerProgress.campaign.size()):
		if PlayerProgress.campaign_unlocked(i) and PlayerProgress.campaign_stars(i) == 0:
			return i
	return PlayerProgress.campaign.size() - 1

# Wie viele Welten offen sind (erstes Level der Welt freigeschaltet)
func _open_worlds() -> int:
	var open := 0
	for w in range(worlds.size()):
		if not worlds[w]["levels"].is_empty() and PlayerProgress.campaign_unlocked(int(worlds[w]["levels"][0])):
			open = w + 1
	return maxi(open, 1)

func _room(w: int) -> Dictionary:
	return RoomScript.ROOMS.get(str(worlds[w]["room"]), RoomScript.ROOMS["cafe"])

func _helper(room_name: String) -> Node3D:
	if not helpers.has(room_name):
		var helper: Node3D = RoomScript.new()
		helper.room = room_name
		helper.name = "Formen_" + room_name
		add_child(helper)
		helpers[room_name] = helper
	return helpers[room_name]

# --- 3D-Szene --------------------------------------------------------------------------

func _build_scene() -> void:
	var world_env := WorldEnvironment.new()
	environment = Environment.new()
	# Himmel als sanfter Verlauf (oben heller, unten dunkler), Farbe je Welt
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_material = ProceduralSkyMaterial.new()
	sky_material.sun_angle_max = 0.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.55, 0.62)
	environment.ambient_light_energy = 0.45
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = environment
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.shadow_opacity = 0.65
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 42
	add_child(camera)
	camera.current = true
	GameSettings.apply_graphics(self)
	# apply_graphics legt eine Kopie der Umgebung an: mit der weiterarbeiten
	environment = world_env.environment

func _build_island(w: int) -> void:
	var data := _room(w)
	var room_name := str(worlds[w]["room"])
	var helper := _helper(room_name)
	var island := Node3D.new()
	island.name = "Welt%d" % [w + 1]
	island.position = Vector3(w * ISLAND_SPACING, 0, 0)
	add_child(island)
	# Schwebende Insel: Wiese oben, Erde und Fels darunter, unten spitz zulaufend
	var outline := _island_outline(w)
	_build_island_body(island, outline, data, str(worlds[w]["room"]))
	_build_details(island, outline, data, helper, str(worlds[w]["room"]), w)
	_build_sky(island, w, data)
	# Deko des Raums hinten auf der Insel
	var groups: Array = data["groups"].duplicate()
	groups = groups.filter(func(g): return not _has_floater(g))
	for g in range(mini(DECO_POINTS.size(), groups.size())):
		var anchor: Vector2 = DECO_POINTS[g]
		for item in groups[g]:
			var design: Dictionary = helper._design(str(item[0]))
			if design.is_empty():
				continue
			var shape: Node3D = helper._build_design(design, data, {})
			var offset: Vector2 = item[1] * 1.3
			shape.position = Vector3(anchor.x + offset.x, 0, anchor.y + offset.y)
			shape.rotation_degrees.y = float(item[2])
			shape.scale = Vector3.ONE * float(item[3]) * 1.3
			island.add_child(shape)
	# Pfad aus Steinen
	var points: Array[Vector2] = []
	for p in LEVEL_POINTS:
		points.append(p)
	points.append(GATE_POINT)
	var stone_mat: Material = helper._material("n", data)
	for k in range(points.size() - 1):
		_build_path(island, points[k], points[k + 1], stone_mat)
	# Level-Marken
	var levels: Array = worlds[w]["levels"]
	var normal_levels := levels.filter(func(i): return str(PlayerProgress.campaign_level(int(i)).get("type", "")) != "boss")
	for k in range(mini(normal_levels.size(), LEVEL_POINTS.size())):
		_build_token(island, int(normal_levels[k]), LEVEL_POINTS[k], data, helper)
	for i in levels:
		if str(PlayerProgress.campaign_level(int(i)).get("type", "")) == "boss":
			_build_gate(island, int(i), data, helper)

func _has_floater(group: Array) -> bool:
	for item in group:
		if str(item[0]) == "Mond":
			return true
	return false

# Steine entlang einer leicht gebogenen Linie
func _build_path(island: Node3D, from: Vector2, to: Vector2, material: Material) -> void:
	var middle := (from + to) / 2.0
	var normal := (to - from).orthogonal().normalized()
	var control := middle + normal * 0.5
	var length := from.distance_to(to)
	var steps := maxi(2, floori(length / 0.5))
	for s in range(1, steps):
		var t := float(s) / steps
		var p := from.lerp(control, t).lerp(control.lerp(to, t), t)
		if p.distance_to(from) < 0.75 or p.distance_to(to) < 0.85:
			continue
		var stone := _box(Vector3(0.3, 0.08, 0.3), material)
		stone.position = Vector3(p.x, 0.04, p.y)
		stone.rotation_degrees.y = rad_to_deg((to - from).angle()) * -1.0 + 45.0
		stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		island.add_child(stone)

func _build_token(island: Node3D, index: int, at: Vector2, data: Dictionary, helper: Node3D) -> void:
	var unlocked := PlayerProgress.campaign_unlocked(index)
	var stars := PlayerProgress.campaign_stars(index)
	var root := Node3D.new()
	root.position = Vector3(at.x, 0, at.y)
	island.add_child(root)
	var base_mat: Material = helper._material("a", data) if unlocked else _speck_material(Color(LOCKED_COLOR))
	var base := _cylinder(0.62, 0.62, 0.3, base_mat)
	base.position.y = 0.15
	root.add_child(base)
	var top := _cylinder(0.5, 0.5, 0.06, helper._material("n", data) if unlocked else _speck_material(Color(LOCKED_COLOR).lightened(0.25)))
	top.position.y = 0.33
	root.add_child(top)
	var number := _label3d(str(index + 1), 5, Color(str(data["a"])) if unlocked else Color(LOCKED_COLOR).darkened(0.3))
	number.position.y = 0.9
	root.add_child(number)
	if unlocked:
		var star_line := _label3d(UI.stars_text(stars), 3, Color("#ffc93c"))
		star_line.position.y = 1.45
		root.add_child(star_line)
	else:
		root.add_child(_lock(Vector3(0, 1.45, 0)))
	_make_clickable(root, index, Vector3(1.3, 1.8, 1.3))
	tokens.append({"node": root, "index": index, "bounce": unlocked and stars == 0 and index == _next_level()})

func _build_gate(island: Node3D, index: int, data: Dictionary, helper: Node3D) -> void:
	var unlocked := PlayerProgress.campaign_unlocked(index)
	var level := PlayerProgress.campaign_level(index)
	var root := Node3D.new()
	root.position = Vector3(GATE_POINT.x, 0, GATE_POINT.y)
	island.add_child(root)
	var stone: Material = _speck_material(Color(str(data["corner"])), 2.0) if unlocked else _speck_material(Color(LOCKED_COLOR))
	for side in [-1.0, 1.0]:
		var pillar := _box(Vector3(0.5, 2.3, 0.5), stone)
		pillar.position = Vector3(side * 0.95, 1.15, 0)
		root.add_child(pillar)
	var lintel := _box(Vector3(2.6, 0.5, 0.65), stone)
	lintel.position = Vector3(0, 2.55, 0)
	root.add_child(lintel)
	if unlocked:
		# Leuchtende Form im Tor in der Farbe des Bosses
		var accent := Color(str(level.get("boss", {}).get("look", {}).get("accent", data["glow"])))
		var glow := StandardMaterial3D.new()
		glow.albedo_color = accent
		glow.emission_enabled = true
		glow.emission = accent
		glow.emission_energy_multiplier = 1.6
		var crystal := Node3D.new()
		crystal.position = Vector3(0, 1.2, 0)
		var upper := _cylinder(0.0, 0.45, 0.6, glow, 4)
		upper.position.y = 0.3
		crystal.add_child(upper)
		var lower := _cylinder(0.45, 0.0, 0.6, glow, 4)
		lower.position.y = -0.3
		crystal.add_child(lower)
		root.add_child(crystal)
		spinners.append(crystal)
		var stars := PlayerProgress.campaign_stars(index)
		if stars > 0:
			var star_line := _label3d(UI.stars_text(stars), 3, Color("#ffc93c"))
			star_line.position.y = 3.9
			root.add_child(star_line)
	else:
		root.add_child(_lock(Vector3(0, 1.2, 0), 1.6))
	var title := _label3d(str(level.get("name", "")), 3, Color(str(data["a"])) if unlocked else Color(LOCKED_COLOR).darkened(0.3))
	title.position.y = 3.35
	root.add_child(title)
	_make_clickable(root, index, Vector3(2.8, 3.2, 1.2), Vector3(0, 1.4, 0))
	tokens.append({"node": root, "index": index, "bounce": false})

# Kleines Schloss aus einem Quader und einem Bügel
func _lock(at: Vector3, size: float = 1.0) -> Node3D:
	var lock := Node3D.new()
	lock.position = at
	lock.scale = Vector3.ONE * size
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("#f2c14e")
	metal.roughness = 0.4
	metal.metallic = 0.3
	var body := _box(Vector3(0.42, 0.34, 0.16), metal)
	lock.add_child(body)
	var shackle := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.1
	ring.outer_radius = 0.16
	shackle.mesh = ring
	shackle.material_override = metal
	shackle.rotation_degrees.x = 90
	shackle.position.y = 0.2
	lock.add_child(shackle)
	return lock

func _make_clickable(root: Node3D, index: int, size: Vector3, center: Vector3 = Vector3(0, 0.6, 0)) -> void:
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = center
	area.add_child(shape)
	root.add_child(area)
	area.input_event.connect(func(_cam, event: InputEvent, _pos, _normal, _shape):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			SoundFX.play("click", -4.0)
			_show_info(index)
	)
	area.mouse_entered.connect(func():
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		create_tween().tween_property(root, "scale", Vector3.ONE * 1.08, 0.12))
	area.mouse_exited.connect(func():
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
		create_tween().tween_property(root, "scale", Vector3.ONE, 0.12))

func _label3d(text: String, factor: int, tint: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = PixelFont.font()
	label.font_size = PixelFont.size(factor)
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	label.modulate = tint
	label.outline_size = 8
	label.outline_modulate = Color.WHITE
	return label

func _box(size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	return instance

func _cylinder(top: float, bottom: float, height: float, material: Material, segments: int = 16) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	return instance

# Fläche mit ganz feinen Pixel-Tupfen (wie der Tisch im Spiel)
func _speck_material(base: Color, scale_value: float = 0.6) -> StandardMaterial3D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(base)
	for p in [Vector2i(2, 3), Vector2i(12, 6), Vector2i(6, 12), Vector2i(10, 14), Vector2i(14, 1)]:
		img.set_pixelv(p, base.lightened(0.05))
	for p in [Vector2i(8, 2), Vector2i(3, 9), Vector2i(13, 11)]:
		img.set_pixelv(p, base.darkened(0.05))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(img)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.uv1_triplanar = true
	material.uv1_scale = Vector3(scale_value, scale_value, scale_value)
	material.roughness = 0.9
	return material

# --- Schwebende Insel ------------------------------------------------------------------

# Umriss: Ellipse mit welligem Rand (immer gleich für dieselbe Welt)
func _island_outline(w: int) -> PackedVector2Array:
	var noise := FastNoiseLite.new()
	noise.seed = 17 + w * 31
	noise.frequency = 0.9
	var points := PackedVector2Array()
	var count := 56
	for i in range(count):
		var a := TAU * i / count
		var wobble := 1.0 + noise.get_noise_2d(cos(a) * 2.0, sin(a) * 2.0) * 0.16
		points.append(Vector2(cos(a) * ISLAND_RADIUS.x, sin(a) * ISLAND_RADIUS.y) * wobble)
	return points

func _build_island_body(island: Node3D, outline: PackedVector2Array, data: Dictionary, room_name: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(room_name)
	var top_color := Color(str(ISLAND_TOP.get(room_name, data["table"])))
	var earth := Color(str(EARTH.get(room_name, "#7a4a2c")))
	# Oberfläche (Wiese)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	for i in range(outline.size()):
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(Vector3(a.x, 0, a.y))
		st.add_vertex(Vector3(b.x, 0, b.y))
	st.generate_normals()
	var top := MeshInstance3D.new()
	top.mesh = st.commit()
	top.material_override = _speck_material(top_color)
	island.add_child(top)
	# Ringe nach unten: Grasrand, dann Erde und Fels, die immer schmaler werden
	var rings := [[0.0, 1.0], [-0.45, 1.01], [-0.55, 0.97], [-1.5, 0.86], [-2.7, 0.66], [-3.9, 0.42], [-5.0, 0.2], [-5.9, 0.04]]
	var shapes: Array = []
	for r in range(rings.size()):
		var ring := PackedVector3Array()
		for i in range(outline.size()):
			var jitter := 1.0 if r < 2 else rng.randf_range(0.9, 1.08)
			var p: Vector2 = outline[i] * float(rings[r][1]) * jitter
			var y: float = float(rings[r][0]) + (0.0 if r < 2 else rng.randf_range(-0.2, 0.2))
			ring.append(Vector3(p.x, y, p.y))
		shapes.append(ring)
	var edge_mat := _speck_material(top_color.darkened(0.18), 1.4)
	var earth_mat := _speck_material(earth, 1.2)
	var dark_mat := _speck_material(earth.darkened(0.25), 1.2)
	for r in range(rings.size() - 1):
		var skirt := SurfaceTool.new()
		skirt.begin(Mesh.PRIMITIVE_TRIANGLES)
		skirt.set_smooth_group(-1)
		var upper: PackedVector3Array = shapes[r]
		var lower: PackedVector3Array = shapes[r + 1]
		for i in range(outline.size()):
			var j := (i + 1) % outline.size()
			skirt.add_vertex(upper[i])
			skirt.add_vertex(lower[i])
			skirt.add_vertex(upper[j])
			skirt.add_vertex(upper[j])
			skirt.add_vertex(lower[i])
			skirt.add_vertex(lower[j])
		skirt.generate_normals()
		var part := MeshInstance3D.new()
		part.mesh = skirt.commit()
		part.material_override = edge_mat if r == 0 else (earth_mat if r < 4 else dark_mat)
		island.add_child(part)

# Ist ein Punkt frei (nicht auf Pfad, Marken, Tor oder Deko)?
func _free_spot(p: Vector2, outline: PackedVector2Array) -> bool:
	if not Geometry2D.is_point_in_polygon(p / 0.88, outline):
		return false
	for q in LEVEL_POINTS:
		if p.distance_to(q) < 1.1:
			return false
	if p.distance_to(GATE_POINT) < 1.8:
		return false
	for q in DECO_POINTS:
		if p.distance_to(q) < 1.6:
			return false
	var points: Array = LEVEL_POINTS + [GATE_POINT]
	for k in range(points.size() - 1):
		var a: Vector2 = points[k]
		var b: Vector2 = points[k + 1]
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < 0.7:
			return false
	return true

func _random_spot(rng: RandomNumberGenerator, outline: PackedVector2Array) -> Vector2:
	for attempt in range(60):
		var p := Vector2(rng.randf_range(-ISLAND_RADIUS.x, ISLAND_RADIUS.x), rng.randf_range(-ISLAND_RADIUS.y, ISLAND_RADIUS.y))
		if _free_spot(p, outline):
			return p
	return Vector2.INF

func _build_details(island: Node3D, outline: PackedVector2Array, data: Dictionary, helper: Node3D, room_name: String, w: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99 + w * 7
	var top_color := Color(str(ISLAND_TOP.get(room_name, data["table"])))
	var tuft_mat := _speck_material(top_color.darkened(0.22), 3.0)
	var tuft_light := _speck_material(top_color.lightened(0.12), 3.0)
	# Grasbüschel (kleine Kegel)
	for i in range(46):
		var p := _random_spot(rng, outline)
		if p == Vector2.INF:
			continue
		var tuft := _cylinder(0.0, rng.randf_range(0.07, 0.13), rng.randf_range(0.18, 0.32), tuft_mat if i % 3 else tuft_light, 5)
		tuft.position = Vector3(p.x, 0.1, p.y)
		tuft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		island.add_child(tuft)
	# Kieselsteine und Blümchen in den Raumfarben
	for i in range(18):
		var p := _random_spot(rng, outline)
		if p == Vector2.INF:
			continue
		var key: String = ["n", "b", "c"][i % 3]
		var bit := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = rng.randf_range(0.07, 0.13)
		mesh.height = mesh.radius
		mesh.is_hemisphere = true
		mesh.radial_segments = 6
		mesh.rings = 2
		bit.mesh = mesh
		bit.material_override = helper._material(key, data)
		bit.position = Vector3(p.x, 0, p.y)
		island.add_child(bit)
	# Felsbrocken am Rand
	var rock_mat := _speck_material(Color(str(EARTH.get(room_name, "#7a4a2c"))).lightened(0.1), 1.5)
	for i in range(7):
		var k := rng.randi_range(0, outline.size() - 1)
		var p: Vector2 = outline[k] * 0.93
		if p.distance_to(GATE_POINT) < 2.2:
			continue
		var rock := _cylinder(rng.randf_range(0.15, 0.25), rng.randf_range(0.3, 0.45), rng.randf_range(0.3, 0.55), rock_mat, 5)
		rock.position = Vector3(p.x, 0.15, p.y)
		rock.rotation_degrees.y = rng.randf_range(0, 360)
		island.add_child(rock)
	# Laternen entlang des Pfads
	var glow: Material = helper._material("glow", data)
	var post_mat := _speck_material(Color(str(data["corner"])), 3.0)
	for k in range(LEVEL_POINTS.size() - 1):
		var a: Vector2 = LEVEL_POINTS[k]
		var b: Vector2 = LEVEL_POINTS[k + 1]
		var side := (b - a).orthogonal().normalized() * (0.75 if k % 2 == 0 else -0.75)
		var spot := (a + b) / 2.0 + side
		var post := _cylinder(0.05, 0.06, 0.8, post_mat, 6)
		post.position = Vector3(spot.x, 0.4, spot.y)
		island.add_child(post)
		var lamp := MeshInstance3D.new()
		var bulb := SphereMesh.new()
		bulb.radius = 0.14
		bulb.height = 0.28
		bulb.radial_segments = 8
		bulb.rings = 4
		lamp.mesh = bulb
		lamp.material_override = glow
		lamp.position = Vector3(spot.x, 0.88, spot.y)
		island.add_child(lamp)
	# Schwebende Felsen rund um die Insel
	var float_mat := _speck_material(Color(str(EARTH.get(room_name, "#7a4a2c"))), 1.5)
	var grass_mat := _speck_material(top_color, 1.5)
	for i in range(5):
		var a := TAU * (i + rng.randf()) / 5.0
		var pos := Vector3(cos(a) * (ISLAND_RADIUS.x + rng.randf_range(1.2, 2.4)), rng.randf_range(-2.0, 0.5), sin(a) * (ISLAND_RADIUS.y + rng.randf_range(0.8, 1.6)))
		var chunk := Node3D.new()
		chunk.position = pos
		var size := rng.randf_range(0.35, 0.7)
		var cap := _cylinder(size, size * 0.9, size * 0.35, grass_mat, 6)
		chunk.add_child(cap)
		var body := _cylinder(size * 0.9, 0.0, size * 1.5, float_mat, 6)
		body.position.y = -size * 0.92
		chunk.add_child(body)
		island.add_child(chunk)
		bobbers.append({"node": chunk, "kind": "rock", "y": pos.y, "phase": rng.randf() * TAU})
	# Besonderheiten je Raum
	match room_name:
		"jardin", "riviera":
			_build_waterfall(island, outline, data, room_name)
		"nuit":
			_build_hanging_crystals(island, helper, data, rng)
		"cafe":
			_build_bunting(island, data, helper)

# Teich und Wasserfall über die Kante
func _build_waterfall(island: Node3D, outline: PackedVector2Array, data: Dictionary, room_name: String) -> void:
	var water_color := Color("#4fc3f7") if room_name == "jardin" else Color("#2fa6e8")
	var k := int(outline.size() * 0.31)   # vorne links
	var edge: Vector2 = outline[k]
	var pond_center := edge * 0.8
	var pond := _cylinder(0.85, 0.85, 0.04, _water_material(water_color, false), 16)
	pond.position = Vector3(pond_center.x, 0.02, pond_center.y)
	pond.scale = Vector3(1.0, 1.0, 0.7)
	island.add_child(pond)
	var fall_mat := _water_material(water_color, true)
	var fall := _box(Vector3(0.7, 5.2, 0.12), fall_mat)
	var dir := edge.normalized()
	fall.position = Vector3(edge.x + dir.x * 0.1, -2.5, edge.y + dir.y * 0.1)
	fall.rotation.y = -dir.angle() + PI / 2.0
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	island.add_child(fall)
	waterfalls.append(fall_mat)

func _water_material(color: Color, stripes: bool) -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(color)
	for y in range(8):
		for x in range(8):
			if stripes and (x + y * 3) % 7 == 0:
				img.set_pixel(x, y, color.lightened(0.45))
			elif not stripes and (x * 5 + y * 3) % 11 == 0:
				img.set_pixel(x, y, color.lightened(0.3))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(img)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.uv1_scale = Vector3(1.0, 6.0, 1.0) if stripes else Vector3(2, 2, 2)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.35
	material.roughness = 0.2
	return material

# Nuit: leuchtende Kristalle hängen unter der Insel
func _build_hanging_crystals(island: Node3D, helper: Node3D, data: Dictionary, rng: RandomNumberGenerator) -> void:
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(str(data["c"]))
	glow.emission_enabled = true
	glow.emission = Color(str(data["c"]))
	glow.emission_energy_multiplier = 1.3
	for i in range(9):
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.3, 0.75)
		var p := Vector2(cos(a) * ISLAND_RADIUS.x * r, sin(a) * ISLAND_RADIUS.y * r)
		var depth := lerpf(-1.6, -4.2, 1.0 - r)
		var length := rng.randf_range(0.6, 1.3)
		var crystal := _cylinder(0.18, 0.0, length, glow, 5)
		crystal.position = Vector3(p.x, depth - length / 2.0, p.y)
		island.add_child(crystal)

# Café: kleine Wimpelkette zwischen zwei Masten
func _build_bunting(island: Node3D, data: Dictionary, helper: Node3D) -> void:
	var a := Vector3(-7.0, 0, 0.6)
	var b := Vector3(-6.2, 0, 3.6)
	var post_mat := _speck_material(Color(str(data["corner"])), 3.0)
	for p in [a, b]:
		var post := _cylinder(0.05, 0.06, 1.5, post_mat, 6)
		post.position = p + Vector3(0, 0.75, 0)
		island.add_child(post)
	var keys := ["a", "b", "c"]
	for i in range(7):
		var t := (i + 0.5) / 7.0
		var p := a.lerp(b, t) + Vector3(0, 1.42 - sin(t * PI) * 0.35, 0)
		var flag := _cylinder(0.0, 0.13, 0.26, helper._material(keys[i % 3], data), 3)
		flag.position = p
		flag.rotation_degrees.x = 180
		island.add_child(flag)

# --- Pixel-Wolken und Vögel ------------------------------------------------------------

# Wolke als Pixel-Bild: Kreise zusammengesetzt, unten schattiert, mit Umriss
static func _cloud_texture(seed_value: int, width: int, height: int) -> Texture2D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var mask := []
	for y in range(height):
		var row := []
		row.resize(width)
		row.fill(false)
		mask.append(row)
	var blobs := rng.randi_range(4, 6)
	for b in range(blobs):
		var cx := rng.randf_range(width * 0.2, width * 0.8)
		var radius := rng.randf_range(height * 0.25, height * 0.45)
		var cy := height - radius - 1.0 - rng.randf_range(0.0, height * 0.2)
		for y in range(height):
			for x in range(width):
				if Vector2(x - cx, (y - cy) * 1.1).length() <= radius:
					mask[y][x] = true
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var light := Color("#ffffff")
	var mid := Color("#e6ecf7")
	var shade := Color("#c3cde4")
	var edge := Color("#a5b0cf")
	for y in range(height):
		for x in range(width):
			if not mask[y][x]:
				continue
			var border := false
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx < 0 or ny < 0 or nx >= width or ny >= height or not mask[ny][nx]:
					border = true
			var below_free: bool = y + 2 >= height or not mask[mini(y + 2, height - 1)][x]
			var color := light
			if border:
				color = edge
			elif below_free:
				color = shade
			elif y > height * 0.6:
				color = mid
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)

func _cloud_sprites() -> Array[Texture2D]:
	if _cloud_textures.is_empty():
		for i in range(6):
			_cloud_textures.append(_cloud_texture(1234 + i * 77, 48 + (i % 3) * 16, 20 + (i % 2) * 6))
	return _cloud_textures

func _build_sky(island: Node3D, w: int, data: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 555 + w
	var textures := _cloud_sprites()
	var tint := Color(str(CLOUD_TINT.get(str(worlds[w]["room"]), "#ffffff")))
	# Wolkenmeer unter der Insel und Wolken weit hinten
	for i in range(14):
		var cloud := _cloud(textures[i % textures.size()], tint, rng.randf_range(0.16, 0.24))
		if i < 9:
			cloud.position = Vector3(rng.randf_range(-16, 16), rng.randf_range(-11, -7), rng.randf_range(-8, 9))
		else:
			cloud.position = Vector3(rng.randf_range(-16, 16), rng.randf_range(-3, 1), rng.randf_range(-16, -12))
		island.add_child(cloud)
		bobbers.append({"node": cloud, "kind": "cloud", "x": cloud.position.x, "speed": rng.randf_range(0.25, 0.6) * (1 if i % 2 else -1)})
	# Wolken ganz vorne in den unteren Ecken (zwischen Kamera und Insel), halb durchsichtig
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var cloud := _cloud(textures[(i + 2) % textures.size()], tint, 0.11)
		cloud.modulate.a = 0.85
		cloud.position = Vector3(side * rng.randf_range(8.5, 10.0), 5.5, 8.5)
		island.add_child(cloud)
		bobbers.append({"node": cloud, "kind": "drift", "x": cloud.position.x, "phase": rng.randf() * TAU})
	# Vögel (nicht in der Nacht)
	if str(worlds[w]["room"]) != "nuit":
		var bird_tex := _bird_texture(Color(str(data["corner"])).darkened(0.3))
		for i in range(3):
			var bird := Sprite3D.new()
			bird.texture = bird_tex
			bird.hframes = 2
			bird.pixel_size = 0.07
			bird.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			bird.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			bird.shaded = false
			island.add_child(bird)
			bobbers.append({"node": bird, "kind": "bird", "y": rng.randf_range(3.0, 4.5), "radius": rng.randf_range(5.0, 8.0), "speed": rng.randf_range(0.12, 0.2), "phase": rng.randf() * TAU})

func _cloud(texture: Texture2D, tint: Color, size: float) -> Sprite3D:
	var cloud := Sprite3D.new()
	cloud.texture = texture
	cloud.pixel_size = size
	cloud.modulate = tint
	cloud.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	cloud.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	cloud.shaded = false
	cloud.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	return cloud

# Vogel: 2 Bilder (Flügel oben / unten), je 7×4 Pixel
static func _bird_texture(color: Color) -> Texture2D:
	var frames := [
		["#.....#", ".#...#.", "..#.#..", "...#..."],
		[".......", "###.###", "...#...", "......."],
	]
	var img := Image.create(14, 4, false, Image.FORMAT_RGBA8)
	for f in range(2):
		for y in range(4):
			var row: String = frames[f][y]
			for x in range(7):
				if row[x] == "#":
					img.set_pixel(f * 7 + x, y, color)
	return ImageTexture.create_from_image(img)

# --- Oberfläche ------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	# Zurück (oben links)
	var back_box := HBoxContainer.new()
	back_box.position = Vector2(28, 24)
	root.add_child(back_box)
	var back := UI.art_button(UI.text("back"), "back", 60)
	back_box.add_child(back)
	UI.connect_animated(back, _leave)
	# Titel und Sterne (oben Mitte)
	var head := VBoxContainer.new()
	head.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	head.offset_left = -400
	head.offset_right = 400
	head.offset_top = 22
	head.alignment = BoxContainer.ALIGNMENT_BEGIN
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(head)
	title_label = UI.label("", 36)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(title_label)
	stars_label = UI.label("", 27)
	stars_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(stars_label)
	lock_label = UI.label("", 18)
	lock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(lock_label)
	# Welt wechseln (unten Mitte)
	var nav := HBoxContainer.new()
	nav.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	nav.offset_left = -220
	nav.offset_right = 220
	nav.offset_top = -86
	nav.offset_bottom = -24
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 24)
	root.add_child(nav)
	left_button = UI.button("←", 58)
	left_button.custom_minimum_size.x = 64
	nav.add_child(left_button)
	left_button.pressed.connect(func(): _show_world(current_world - 1, true))
	dots_label = UI.label("", 27)
	dots_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	nav.add_child(dots_label)
	right_button = UI.button("→", 58)
	right_button.custom_minimum_size.x = 64
	nav.add_child(right_button)
	right_button.pressed.connect(func(): _show_world(current_world + 1, true))
	# Level-Info (rechts)
	info_panel = PanelContainer.new()
	var style := UI.panel()
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 16
	info_panel.add_theme_stylebox_override("panel", style)
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	info_panel.offset_left = -420
	info_panel.offset_right = -28
	info_panel.offset_top = -170
	info_panel.offset_bottom = 170
	info_panel.visible = false
	root.add_child(info_panel)
	info_box = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 10)
	info_panel.add_child(info_box)
	# Banner für neue Welten
	banner = UI.label("", 36)
	banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	banner.offset_left = -500
	banner.offset_right = 500
	banner.offset_top = -40
	banner.offset_bottom = 40
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.autowrap_mode = TextServer.AUTOWRAP_OFF
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.outlined(banner, Color("#ffc93c"))
	root.add_child(banner)

func _show_world(w: int, animate: bool) -> void:
	w = clampi(w, 0, worlds.size() - 1)
	current_world = w
	info_panel.visible = false
	var data := _room(w)
	var target := Vector3(w * ISLAND_SPACING, -0.8, 0.6)
	var from := target + CAMERA_OFFSET
	if animate:
		var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tween.tween_method(func(p: Vector3): camera.look_at_from_position(p, p - CAMERA_OFFSET), camera.position, from, 0.8)
		tween.tween_method(_set_sky, _sky_color_now(), Color(str(SKY.get(str(worlds[w]["room"]), "#86d6ff"))), 0.8)
	else:
		camera.look_at_from_position(from, target)
		_set_sky(Color(str(SKY.get(str(worlds[w]["room"]), "#86d6ff"))))
	# Kopfzeile
	title_label.text = "%s · %s" % [str(worlds[w]["title"]), str(worlds[w]["name"])]
	UI.outlined(title_label, Color(str(data["a"])))
	var earned := 0
	var possible := 0
	for i in worlds[w]["levels"]:
		earned += PlayerProgress.campaign_stars(int(i))
		possible += 3
	stars_label.text = UI.text("world_stars") % [earned, possible]
	UI.outlined(stars_label, Color("#ffc93c"))
	var open := PlayerProgress.campaign_unlocked(int(worlds[w]["levels"][0]))
	lock_label.text = "" if open else UI.text("world_locked") % [_boss_name(w - 1)]
	UI.outlined(lock_label, Color.WHITE)
	var dots := ""
	for k in range(worlds.size()):
		dots += ("●" if k == w else "○") + (" " if k < worlds.size() - 1 else "")
	dots_label.text = dots
	left_button.disabled = w == 0
	right_button.disabled = w == worlds.size() - 1
	left_button.modulate.a = 0.35 if w == 0 else 1.0
	right_button.modulate.a = 0.35 if w == worlds.size() - 1 else 1.0

func _boss_name(w: int) -> String:
	if w < 0 or w >= worlds.size():
		return ""
	for i in worlds[w]["levels"]:
		var level := PlayerProgress.campaign_level(int(i))
		if str(level.get("type", "")) == "boss":
			return str(level.get("name", ""))
	return ""

func _show_info(index: int) -> void:
	for child in info_box.get_children():
		child.queue_free()
	var level := PlayerProgress.campaign_level(index)
	var unlocked := PlayerProgress.campaign_unlocked(index)
	var is_boss := str(level.get("type", "")) == "boss"
	var top := HBoxContainer.new()
	info_box.add_child(top)
	var heading := UI.label(("%s" if is_boss else "%d. " % [index + 1] + "%s") % [str(level.get("name", ""))], 27)
	heading.add_theme_color_override("font_color", UI.TITLE_COLOR)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	var close := UI.button("×", 42)
	close.custom_minimum_size.x = 42
	top.add_child(close)
	close.pressed.connect(func(): info_panel.visible = false)
	var rules: Array[String] = []
	if is_boss:
		var is_final := bool(level.get("final", false))
		info_box.add_child(UI.label(UI.text("campaign_boss" if is_final else "campaign_miniboss"), 18))
		var description := str(level.get("description", ""))
		if not description.is_empty():
			var text := UI.label(description, 18)
			text.add_theme_color_override("font_color", UI.DIM_COLOR)
			info_box.add_child(text)
		rules.append(UI.text("campaign_boss_rules" if is_final else "campaign_miniboss_rules") % [int(level.get("boss", {}).get("hp", 0))])
	else:
		rules.append(UI.text("campaign_pairs") % [int(level.get("pairs", 12))])
		if int(level.get("time_limit", 0)) > 0:
			rules.append(UI.text("campaign_time") % [UI.time_text(float(level["time_limit"]))])
		if int(level.get("move_limit", 0)) > 0:
			rules.append(UI.text("campaign_moves") % [int(level["move_limit"])])
	for rule in rules:
		info_box.add_child(UI.label("· " + rule, 18))
	var record := PlayerProgress.campaign_record(index)
	var stars_line := UI.label(UI.stars_text(PlayerProgress.campaign_stars(index)), 27)
	stars_line.add_theme_color_override("font_color", Color("#ffc93c"))
	info_box.add_child(stars_line)
	if record.has("best_time"):
		info_box.add_child(UI.label(UI.text("best_time") % [UI.time_text(float(record["best_time"]))], 18))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_box.add_child(spacer)
	if unlocked:
		var play := UI.art_button(UI.text("play"), "play", 75)
		info_box.add_child(play)
		UI.connect_animated(play, _start_level.bind(index))
	else:
		var locked := UI.label(UI.text("locked"), 18)
		locked.add_theme_color_override("font_color", UI.DIM_COLOR)
		info_box.add_child(locked)
	# Info auf der Seite, wo die angeklickte Marke nicht ist
	var on_left := _token_x(index) > 0.0
	info_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT if on_left else Control.PRESET_CENTER_RIGHT)
	info_panel.offset_left = 28 if on_left else -420
	info_panel.offset_right = 420 if on_left else -28
	info_panel.offset_top = -170
	info_panel.offset_bottom = 170
	info_panel.visible = true

func _token_x(index: int) -> float:
	for token in tokens:
		if int(token["index"]) == index:
			var node: Node3D = token["node"]
			return node.position.x
	return 0.0

func _show_banner(text: String) -> void:
	banner.text = text
	var tween := create_tween()
	banner.scale = Vector2(0.8, 0.8)
	banner.pivot_offset = banner.size / 2.0
	tween.set_parallel(true)
	tween.tween_property(banner, "modulate:a", 1.0, 0.3)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_interval(2.2)
	tween.chain().tween_property(banner, "modulate:a", 0.0, 0.6)
	SoundFX.play("level_up", -4.0)

func _start_level(index: int) -> void:
	SetSelection.mode = "campaign"
	SetSelection.campaign_index = index
	Loader.go_to_main()

func _leave() -> void:
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_show_world(current_world - 1, true)
	elif event.is_action_pressed("ui_right"):
		_show_world(current_world + 1, true)
	elif event.is_action_pressed("ui_cancel"):
		if info_panel.visible:
			info_panel.visible = false
		else:
			_leave()

func _process(delta: float) -> void:
	time += delta
	for token in tokens:
		var node: Node3D = token["node"]
		if token["bounce"]:
			node.position.y = absf(sin(time * 3.0)) * 0.35
	for spinner in spinners:
		spinner.rotation_degrees.y += 40.0 * delta
		spinner.position.y = 1.2 + sin(time * 1.5) * 0.12
	for b in bobbers:
		var node: Node3D = b["node"]
		match str(b["kind"]):
			"rock":
				node.position.y = float(b["y"]) + sin(time * 0.8 + float(b["phase"])) * 0.25
				node.rotation_degrees.y += 6.0 * delta
			"drift":
				node.position.x = float(b["x"]) + sin(time * 0.25 + float(b["phase"])) * 0.8
			"cloud":
				# Wolken ziehen langsam seitwärts und kommen auf der anderen Seite wieder
				var x := fposmod(float(b["x"]) + time * float(b["speed"]) + 20.0, 40.0) - 20.0
				node.position.x = x
			"bird":
				var t := time * float(b["speed"]) + float(b["phase"])
				node.position = Vector3(cos(t) * float(b["radius"]), float(b["y"]) + sin(t * 2.0) * 0.3, sin(t) * float(b["radius"]) * 0.5 - 1.0)
				var sprite: Sprite3D = node
				sprite.frame = int(time * 5.0 + float(b["phase"]) * 3.0) % 2
				sprite.flip_h = sin(t) > 0.0
	for material in waterfalls:
		material.uv1_offset.y -= delta * 1.2

func _sky_color_now() -> Color:
	return sky_material.sky_horizon_color

func _set_sky(color: Color) -> void:
	sky_material.sky_top_color = color.lightened(0.15)
	sky_material.sky_horizon_color = color
	sky_material.ground_horizon_color = color
	sky_material.ground_bottom_color = color.darkened(0.35)
