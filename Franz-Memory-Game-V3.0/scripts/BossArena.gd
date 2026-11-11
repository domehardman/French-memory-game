extends Node3D
## Gothic-Arena für den Bossfight: Blutmond, Nebel, Türme, Kerzen, Asche
## und der 3D-Boss "Le Grand Oubli" mit Animationen und Angriffs-Effekten.
## Alles wird aus Grundformen gebaut. Main.gd steuert die Spiellogik,
## dieses Skript nur das, was man sieht.

var boss_pos := Vector3(0, 0.9, -6.6)   # wo der Boss steht (in einer Level-Arena auf dem Boden)

var camera: Camera3D
var boss_root: Node3D
var boss_body: Node3D
var head: Node3D
var left_arm: Node3D
var right_arm: Node3D
var eye_light: OmniLight3D
var aura: CPUParticles3D
var halo: MeshInstance3D
var moon_material: StandardMaterial3D
var eye_material: StandardMaterial3D
var flash_materials: Array[StandardMaterial3D] = []
var candles: Array[OmniLight3D] = []
var warnings: Array[Node3D] = []
var time := 0.0
var raging := false
var busy := false        # true während einer Angriffs-/Treffer-Animation
var dead := false
# Schräge Spielplatte (von Main.gd gesetzt): Winkel in Grad und Höhe der Mitte
var board_tilt := 0.0
var board_lift := 0.0
var board_depth := 7.2
var use_steps := false

# Punkt in Koordinaten der schrägen Platte -> Weltposition
func board_point(local: Vector3) -> Vector3:
	return local.rotated(Vector3.RIGHT, deg_to_rad(board_tilt)) + Vector3(0, board_lift, 0)

# --- Aufbau --------------------------------------------------------------------

# Arten von Arenen (look.arena in campaign.json):
#   "hain"   Toter Hain: fahles grünes Mondlicht, Moos, Wurzeln, tote Bäume, Knochen
#   "mond"   Mondnacht: kaltes, silbernes Licht über einer gotischen Stadt
#   sonst    die rote Blutmond-Arena
# Himmel, Steinoberflächen, Wurzelhirt und Knochen stammen aus dem Projekt "Claude 1"
# (assets/hain/).
const HAIN := "res://assets/hain/"
var arena_kind := "gothic"
var flame_color := Color(1, 0.55, 0.15)
var ring_color := Color(0.9, 0.05, 0.05)

func build(main: Node3D, look: Dictionary = {}) -> void:
	arena_kind = str(look.get("arena", "gothic"))
	camera = main.get_node("Camera3D")
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 52
	var world: WorldEnvironment = main.get_node("WorldEnvironment")
	var sun: DirectionalLight3D = main.get_node("DirectionalLight3D")
	# Arena als eigene Szene (look.scene, z. B. res://scenes/arenen/hain.tscn):
	# kann direkt in Godot bearbeitet werden. Dann wird hier nichts mehr gebaut.
	var scene_path := str(look.get("scene", ""))
	var from_scene := not scene_path.is_empty() and ResourceLoader.exists(scene_path)
	var custom := from_scene or look.has("level")
	match arena_kind:
		"hain":
			flame_color = Color(0.6, 0.95, 0.3)
			ring_color = Color(0.5, 0.9, 0.2)
			camera.look_at_from_position(Vector3(0, 5.8, 12.6), Vector3(0, 2.7, -3.0))
			world.environment = _environment_hain()
			_moon_light(sun, Vector3(-0.32, 0.17, -0.93), Color(0.72, 0.86, 0.66), 1.3)
			if not custom:
				_build_hain()
		"mond", "turm", "kathedrale", "beinhaus":
			var p: Dictionary = PALETTES.get(arena_kind, PALETTES["mond"])
			flame_color = p["flame"]
			ring_color = p["ring"]
			camera.look_at_from_position(Vector3(0, 5.8, 12.6), Vector3(0, 2.7, -3.0))
			world.environment = _environment_palette(p)
			_moon_light(sun, p["moon_dir"], p["light"], p["light_energy"])
			if not custom:
				_build_ruins(p)
			match arena_kind if not custom else "":
				"turm":
					_build_bell_tower()
				"kathedrale":
					_build_cathedral()
				"beinhaus":
					_build_ossuary()
		_:
			camera.look_at_from_position(Vector3(0, 8.8, 11.8), Vector3(0, 2.5, -2.4))
			world.environment = _environment()
			sun.light_color = Color(0.75, 0.7, 0.9)
			sun.light_energy = 0.35
			if not custom:
				_build_sky_objects(true)
	if from_scene:
		_build_from_scene(scene_path, world, sun)
	else:
		# Echte Level-Arena aus "Claude 1" (Bauwerk, Licht, Nebel, Fackeln, Bildfilter)
		if look.has("level"):
			_build_level(look, world, sun)
		_build_floor()
		_build_candles()
		_build_ash()
	_build_boss(look)
	if arena_kind == "hain" and level_root == null:
		_build_remains()

var level_root: Node3D

# Lädt eine Arena-Szene aus scenes/arenen/. Feste Namen in der Szene:
#   Umgebung     WorldEnvironment (Himmel, Nebel, Farben)
#   BossPunkt    Marker3D: hier steht der Boss
#   Kamera       Camera3D: so schaut die Kamera im Spiel
#   Kerzen       Lichter darin flackern
#   Vorschau     nur für den Editor (Boss-Modell und Karten), wird im Spiel entfernt
# Alles andere (Level, Leuchtkreis, Asche, eigene Sachen) wird einfach angezeigt.
func _build_from_scene(path: String, world: WorldEnvironment, sun: DirectionalLight3D) -> void:
	var scene: Node3D = load(path).instantiate()
	add_child(scene)
	level_root = scene
	sun.visible = false
	var env_node := scene.get_node_or_null("Umgebung")
	if env_node is WorldEnvironment:
		if env_node.environment != null:
			world.environment = env_node.environment
		scene.remove_child(env_node)
		env_node.free()
	var marker := scene.get_node_or_null("BossPunkt")
	if marker is Node3D:
		boss_pos = to_local(marker.global_position)
	var cam := scene.get_node_or_null("Kamera")
	if cam is Camera3D:
		camera.global_transform = cam.global_transform
		camera.fov = cam.fov
		scene.remove_child(cam)
		cam.free()
	var preview := scene.get_node_or_null("Vorschau")
	if preview != null:
		scene.remove_child(preview)
		preview.free()
	var candle_root := scene.get_node_or_null("Kerzen")
	if candle_root != null:
		for light in candle_root.find_children("*", "OmniLight3D", true, false):
			candles.append(light)

# Stufen unter den Kartenreihen (statt einer schrägen Rampe). Jede Reihe liegt auf
# ihrer eigenen Stufe. Material = Boden der Arena, damit der Untergrund dazu passt.
# rows: Array aus {"z": Mitte der Reihe, "top": Oberkante der Stufe}
var step_nodes: Array[Node3D] = []

func arena_floor_material() -> Material:
	if level_root != null:
		for name in ["Boden", "Platz", "Beinhausboden"]:
			for mi in level_root.find_children(name, "MeshInstance3D", true, false):
				var m: Material = mi.material_override if mi.material_override != null else mi.get_surface_override_material(0)
				if m == null and mi.mesh != null and mi.mesh.get_surface_count() > 0:
					m = mi.mesh.surface_get_material(0)
				if m != null:
					return m
	return _mat(Color(0.16, 0.13, 0.13), Color.BLACK, 0.0, 0.65)

func build_steps(rows: Array, width: float, row_depth: float) -> void:
	for n in step_nodes:
		n.queue_free()
	step_nodes.clear()
	var floor_mat := arena_floor_material()
	var edge := _mat(ring_color * 0.4, ring_color, 1.4)
	var floor_y := -0.6
	for r in rows:
		var top: float = r["top"]
		var height := top - floor_y
		var box := BoxMesh.new()
		box.size = Vector3(width, height, row_depth)
		step_nodes.append(_part(box, floor_mat, self, Vector3(0, floor_y + height / 2.0, r["z"])))
		# schmale leuchtende Kante vorne an jeder Stufe
		var lip := BoxMesh.new()
		lip.size = Vector3(width, 0.03, 0.04)
		step_nodes.append(_part(lip, edge, self, Vector3(0, top - 0.01, r["z"] + row_depth / 2.0)))
# Lädt die Arena-Szene, nimmt ihre Umgebung (Himmel, Nebel, Farben) und setzt sie so,
# dass der Boss genau dort steht, wo er in "Claude 1" steht. Grössen im selben
# Verhältnis wie dort: Arena-Massstab = Modell-Massstab / Boss-Grösse in "Claude 1".
func _build_level(look: Dictionary, world: WorldEnvironment, sun: DirectionalLight3D) -> void:
	var path := "res://claude1/arenas/%s.tscn" % str(look["level"])
	if not ResourceLoader.exists(path):
		return
	var level: Node3D = load(path).instantiate()
	var s := float(look.get("arena_scale", 1.75))
	var their_boss_z := float(look.get("level_boss_z", -24.0))
	var env_node := level.get_node_or_null("Umgebung")
	if env_node is WorldEnvironment and env_node.environment != null:
		var env: Environment = env_node.environment.duplicate()
		# Die Arena ist grösser skaliert, darum ist der Nebel pro Meter dünner zu machen
		env.fog_density /= s
		env.volumetric_fog_density /= s
		env.volumetric_fog_length *= s
		world.environment = env
		level.remove_child(env_node)
		env_node.free()
	sun.visible = false
	level.scale = Vector3.ONE * s
	boss_pos.y = -0.6
	level.position = Vector3(0, -0.6, boss_pos.z) - Vector3(0, 0, their_boss_z * s)
	add_child(level)
	level_root = level
	for fog in level.find_children("*", "FogVolume", true, false):
		if fog.material is FogMaterial:
			var fog_mat: FogMaterial = fog.material.duplicate()
			fog_mat.density /= s * 1.6
			fog.material = fog_mat
	# Lichtweiten mitskalieren, damit Fackeln und Mond gleich wirken
	for light in level.find_children("*", "OmniLight3D", true, false):
		light.omni_range *= s
	for light in level.find_children("*", "SpotLight3D", true, false):
		light.spot_range *= s

# Mond als gerichtetes Licht: kommt von hinten (hinter dem Boss) und wirft Schatten.
func _moon_light(sun: DirectionalLight3D, toward_moon: Vector3, color: Color, energy: float) -> void:
	sun.look_at_from_position(Vector3.ZERO, -toward_moon.normalized(), Vector3.UP)
	sun.light_color = color
	sun.light_energy = energy
	sun.light_volumetric_fog_energy = 1.2
	sun.shadow_enabled = true

func _sky_shader(top: Color, bottom: Color, moon: Color, shimmer: Color, moon_size: float, craters: float) -> Sky:
	var m := ShaderMaterial.new()
	m.shader = load(HAIN + "shaders/himmel.gdshader")
	m.set_shader_parameter("himmel_oben", top)
	m.set_shader_parameter("himmel_unten", bottom)
	m.set_shader_parameter("mond_farbe", moon)
	m.set_shader_parameter("schimmer_farbe", shimmer)
	m.set_shader_parameter("mond_groesse", moon_size)
	m.set_shader_parameter("mond_krater", craters)
	var sky := Sky.new()
	sky.sky_material = m
	return sky

# Stimmung wie im Level "Toter Hain"
func _environment_hain() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = _sky_shader(Color(0.012, 0.022, 0.024), Color(0.1, 0.14, 0.11), Color(0.86, 0.9, 0.72), Color(0.1, 0.14, 0.08), 0.2, 0.7)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.38, 0.46, 0.38)
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.3
	env.ssao_enabled = true
	env.ssao_intensity = 2.6
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.1, 0.14, 0.11)
	env.fog_density = 0.01
	env.fog_sky_affect = 0.3
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.012
	env.volumetric_fog_albedo = Color(0.8, 0.9, 0.8)
	env.volumetric_fog_emission = Color(0.07, 0.11, 0.07)
	env.volumetric_fog_emission_energy = 0.05
	env.volumetric_fog_ambient_inject = 0.3
	env.volumetric_fog_length = 64.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.3
	env.adjustment_saturation = 0.62
	return env

# Stimmung wie auf dem Domplatz: kalt, silbern, wenig Farbe
func _environment_moon() -> Environment:
	var env := _environment_hain()
	env.sky = _sky_shader(Color(0.06, 0.07, 0.09), Color(0.36, 0.4, 0.45), Color(0.86, 0.9, 1.0), Color(0.32, 0.2, 0.46), 0.09, 0.5)
	env.ambient_light_color = Color(0.44, 0.49, 0.56)
	env.tonemap_exposure = 1.38
	env.glow_intensity = 0.55
	env.fog_light_color = Color(0.46, 0.5, 0.56)
	env.fog_density = 0.0085
	env.fog_sky_affect = 0.5
	env.volumetric_fog_density = 0.011
	env.volumetric_fog_albedo = Color(0.86, 0.89, 0.93)
	env.volumetric_fog_emission = Color(0.3, 0.33, 0.38)
	env.volumetric_fog_emission_energy = 0.09
	env.volumetric_fog_ambient_inject = 0.6
	env.adjustment_contrast = 1.28
	env.adjustment_saturation = 0.5
	return env

# Farbstimmungen der Arenen, angelehnt an die Level von "Claude 1"
const PALETTES := {
	"mond": {"top": Color(0.06, 0.07, 0.09), "bottom": Color(0.36, 0.4, 0.45), "moon": Color(0.86, 0.9, 1.0), "shimmer": Color(0.32, 0.2, 0.46), "moon_size": 0.09, "craters": 0.5,
		"ambient": Color(0.44, 0.49, 0.56), "fog": Color(0.46, 0.5, 0.56), "vol": Color(0.86, 0.89, 0.93), "vol_emission": Color(0.3, 0.33, 0.38), "saturation": 0.5,
		"flame": Color(1.0, 0.6, 0.25), "ring": Color(0.85, 0.12, 0.1), "light": Color(0.72, 0.78, 0.88), "light_energy": 0.95, "moon_dir": Vector3(0.36, 0.2, -0.91)},
	# Glockenturm: warmes Bernstein, Staub in der Luft
	"turm": {"top": Color(0.05, 0.04, 0.03), "bottom": Color(0.42, 0.3, 0.18), "moon": Color(1.0, 0.86, 0.62), "shimmer": Color(0.45, 0.25, 0.1), "moon_size": 0.12, "craters": 0.6,
		"ambient": Color(0.52, 0.44, 0.34), "fog": Color(0.42, 0.33, 0.22), "vol": Color(0.95, 0.85, 0.7), "vol_emission": Color(0.25, 0.17, 0.08), "saturation": 0.6,
		"flame": Color(1.0, 0.62, 0.22), "ring": Color(0.95, 0.6, 0.2), "light": Color(1.0, 0.85, 0.62), "light_energy": 1.0, "moon_dir": Vector3(0.4, 0.18, -0.9)},
	# Kathedrale: kaltes Blau, violetter Schimmer
	"kathedrale": {"top": Color(0.03, 0.04, 0.08), "bottom": Color(0.24, 0.3, 0.46), "moon": Color(0.78, 0.86, 1.0), "shimmer": Color(0.35, 0.25, 0.6), "moon_size": 0.1, "craters": 0.4,
		"ambient": Color(0.4, 0.46, 0.62), "fog": Color(0.3, 0.36, 0.52), "vol": Color(0.78, 0.84, 1.0), "vol_emission": Color(0.14, 0.18, 0.32), "saturation": 0.55,
		"flame": Color(0.5, 0.66, 1.0), "ring": Color(0.45, 0.6, 1.0), "light": Color(0.7, 0.8, 1.0), "light_energy": 1.0, "moon_dir": Vector3(-0.38, 0.2, -0.9)},
	# Beinhaus: fahles Türkis, sehr dunkel
	"beinhaus": {"top": Color(0.01, 0.025, 0.025), "bottom": Color(0.1, 0.2, 0.18), "moon": Color(0.75, 0.95, 0.88), "shimmer": Color(0.1, 0.3, 0.25), "moon_size": 0.14, "craters": 0.8,
		"ambient": Color(0.34, 0.46, 0.44), "fog": Color(0.12, 0.2, 0.18), "vol": Color(0.75, 0.95, 0.9), "vol_emission": Color(0.06, 0.14, 0.12), "saturation": 0.55,
		"flame": Color(0.4, 0.95, 0.7), "ring": Color(0.35, 0.9, 0.65), "light": Color(0.66, 0.9, 0.84), "light_energy": 1.1, "moon_dir": Vector3(0.0, 0.17, -0.98)},
}

func _environment_palette(p: Dictionary) -> Environment:
	var env := _environment_moon()
	env.sky = _sky_shader(p["top"], p["bottom"], p["moon"], p["shimmer"], p["moon_size"], p["craters"])
	env.ambient_light_color = p["ambient"]
	env.fog_light_color = p["fog"]
	env.volumetric_fog_albedo = p["vol"]
	env.volumetric_fog_emission = p["vol_emission"]
	env.adjustment_saturation = p["saturation"]
	return env

func _bronze() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.42, 0.3, 0.16)
	m.metallic = 0.9
	m.roughness = 0.38
	m.normal_enabled = true
	m.normal_texture = load(HAIN + "textures/metall_n.png")
	m.uv1_triplanar = true
	return m

# Steinruinen aus dem Level von "Claude 1" als Kulisse, in der Farbe der Arena
func _build_ruins(p: Dictionary) -> void:
	var level := Node3D.new()
	level.scale = Vector3(1.75, 1.15, 1.75)
	level.position = Vector3(0, -0.6, 38.0)
	add_child(level)
	var walls := MeshInstance3D.new()
	walls.mesh = load(HAIN + "models/level8/stein.obj")
	var tint: Color = p["ambient"].lerp(Color(0.55, 0.55, 0.55), 0.4)
	walls.material_override = _stone("quader", 0.42, tint, 0.25 if arena_kind == "beinhaus" else 0.1, 0.15)
	level.add_child(walls)
# Glockenturm: Glocken hängen an Ketten über und neben der Arena
func _build_bell_tower() -> void:
	var bell_mesh: Mesh = load(HAIN + "models/gloeckner/fallglocke.obj")
	var bronze := _bronze()
	var chain := _mat(Color(0.1, 0.09, 0.08), Color.BLACK, 0.0, 0.5)
	chain.metallic = 0.8
	var beam_mat := _stone("schiefer", 0.9, Color(0.3, 0.22, 0.15), 0.0)
	for spot in [Vector3(-9, 6.5, -10), Vector3(9, 7.5, -11), Vector3(-12, 9, -18), Vector3(12, 8, -17), Vector3(0, 12.5, -16), Vector3(-5, 10, -22), Vector3(6, 11, -23)]:
		var bell := _part(bell_mesh, bronze, self, spot, Vector3(0, randf() * 360, randf_range(-6, 6)), Vector3.ONE * randf_range(1.2, 2.0))
		var rope := CylinderMesh.new()
		rope.top_radius = 0.05
		rope.bottom_radius = 0.05
		rope.height = 20.0
		_part(rope, chain, self, spot + Vector3(0, 11.5, 0))
		bell.set_meta("swing", randf() * TAU)
		orbiters_scene.append(bell)
	# Holzbalken des Turms
	for z in [-12.0, -20.0]:
		var beam := BoxMesh.new()
		beam.size = Vector3(34, 0.8, 0.8)
		_part(beam, beam_mat, self, Vector3(0, 17, z))

# Kathedrale: hohe Pfeiler und leuchtende Kirchenfenster
func _build_cathedral() -> void:
	var stone := _stone("quader", 0.4, Color(0.55, 0.6, 0.7), 0.15, 0.2)
	var glass_colors := [Color(0.3, 0.45, 1.0), Color(0.6, 0.3, 0.9), Color(0.3, 0.8, 0.9), Color(0.9, 0.3, 0.4)]
	for i in range(7):
		var x := -15.0 + i * 5.0
		var pillar := CylinderMesh.new()
		pillar.top_radius = 0.7
		pillar.bottom_radius = 0.9
		pillar.height = 22
		_part(pillar, stone, self, Vector3(x, 10.4, -20))
		var window := BoxMesh.new()
		window.size = Vector3(2.4, 7.0, 0.1)
		var glass := _mat(glass_colors[i % glass_colors.size()] * 0.5, glass_colors[i % glass_colors.size()], 1.8)
		glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glass.disable_fog = true
		if i < 6:
			_part(window, glass, self, Vector3(x + 2.5, 9.0, -21))
			_part(_cone(1.2, 2.0, 0.0, 3), glass, self, Vector3(x + 2.5, 13.4, -21), Vector3(0, 0, 0), Vector3(1, 1, 0.05))
	var rose := TorusMesh.new()
	rose.inner_radius = 2.2
	rose.outer_radius = 2.8
	var rose_mat := _mat(Color(0.4, 0.3, 0.8), Color(0.5, 0.4, 1.0), 2.0)
	rose_mat.disable_fog = true
	_part(rose, rose_mat, self, Vector3(0, 16.5, -20.5), Vector3(90, 0, 0))
	# Lange Bänke als Schatten im Hintergrund
	for side in [-1, 1]:
		for k in range(4):
			var bench := BoxMesh.new()
			bench.size = Vector3(4.0, 0.9, 0.6)
			_part(bench, stone, self, Vector3(side * 10.0, -0.15, -2.0 - k * 2.5))

# Beinhaus: Wände aus Schädeln, Knochenberge
func _build_ossuary() -> void:
	var bone := _bestie_material("knochen")
	bone.vertex_color_use_as_albedo = false
	bone.albedo_color = Color(0.72, 0.7, 0.62)
	var skull: Mesh = load(HAIN + "models/level3/schaedel.obj")
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	# Schädelwand hinter dem Boss
	for row in range(9):
		for col in range(26):
			var p := Vector3(-13.0 + col * 1.0 + (row % 2) * 0.5, -0.2 + row * 0.85, -14.0 + rng.randf_range(-0.15, 0.15))
			_part(skull, bone, self, p, Vector3(rng.randf_range(-10, 10), rng.randf_range(-20, 20), rng.randf_range(-10, 10)), Vector3.ONE * 4.2)
	var pile_mesh: Mesh = load(HAIN + "models/level3/knochen.obj")
	var center := pile_mesh.get_aabb().get_center()
	for spot in [Vector3(-9.5, -1.0, -6.0), Vector3(9.5, -1.0, -7.0), Vector3(-11, -1.0, 1.0), Vector3(11, -1.0, 0.0)]:
		var pile := MeshInstance3D.new()
		pile.mesh = pile_mesh
		pile.material_override = bone
		pile.scale = Vector3(0.6, 0.5, 0.3)
		pile.rotation.y = PI / 2.0 + rng.randf_range(-0.4, 0.4)
		add_child(pile)
		pile.position = spot - pile.basis * center
	for i in range(30):
		var a := rng.randf() * TAU
		var r := rng.randf_range(5.0, 11.0)
		var p := Vector3(cos(a) * r, -0.52, sin(a) * r * 0.7 - 3.0)
		if abs(p.x) < 4.2 and p.z > -4.5:
			continue
		_part(skull, bone, self, p, Vector3(rng.randf_range(-30, 30), rng.randf() * 360, rng.randf_range(-40, 40)), Vector3.ONE * rng.randf_range(2.5, 4.0))

var orbiters_scene: Array[Node3D] = []

# Stein-Shader aus "Claude 1" mit Moos, Schmutz, Nässe und Glutrissen
func _stone(color_tex: String, scale_value: float, tint: Color, moss: float, wet: float = 0.0, ember: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(HAIN + "shaders/arena_stein.gdshader")
	m.set_shader_parameter("farbe_bild", load(HAIN + "textures/%s.png" % color_tex))
	m.set_shader_parameter("normal_bild", load(HAIN + "textures/%s_n.png" % color_tex))
	m.set_shader_parameter("rauh_bild", load(HAIN + "textures/%s_r.png" % color_tex))
	m.set_shader_parameter("rausch_bild", load(HAIN + "textures/rausch.png"))
	m.set_shader_parameter("massstab", scale_value)
	m.set_shader_parameter("toenung", tint)
	m.set_shader_parameter("schmutz_farbe", Color(0.02, 0.03, 0.015))
	m.set_shader_parameter("schmutz_hoehe", 3.4)
	m.set_shader_parameter("schmutz_staerke", 0.7)
	m.set_shader_parameter("moos", moss)
	m.set_shader_parameter("moos_farbe", Color(0.07, 0.13, 0.05))
	m.set_shader_parameter("naesse", wet)
	m.set_shader_parameter("glut", ember)
	m.set_shader_parameter("glut_farbe", ring_color)
	return m

# Toter Hain: Wände und Wurzeln aus dem Level, Schlammboden, tote Bäume, grüne Feuer
func _build_hain() -> void:
	var level := Node3D.new()
	# Die Arena aus "Claude 1" ist kleiner gebaut: vergrössern und so setzen,
	# dass die Spielplatte in ihrer Mitte liegt.
	level.scale = Vector3(1.75, 1.15, 1.75)
	level.position = Vector3(0, -0.6, 38.0)
	add_child(level)
	var walls := MeshInstance3D.new()
	walls.mesh = load(HAIN + "models/level8/stein.obj")
	walls.material_override = _stone("quader", 0.42, Color(0.5, 0.54, 0.46), 0.75)
	level.add_child(walls)
	var roots := MeshInstance3D.new()
	roots.mesh = load(HAIN + "models/level8/wurzel.obj")
	roots.material_override = _stone("schiefer", 0.8, Color(0.26, 0.2, 0.14), 0.5)
	level.add_child(roots)
	# Tote Bäume rund um die Arena
	var tree_mesh: Mesh = load(HAIN + "models/level8/baum.obj")
	var bark := _stone("schiefer", 0.9, Color(0.22, 0.18, 0.13), 0.55)
	var rng := RandomNumberGenerator.new()
	rng.seed = 808
	for i in range(12):
		var a := lerpf(-2.6, 2.6, i / 11.0) + rng.randf_range(-0.12, 0.12)
		var r := rng.randf_range(15.0, 24.0)
		var tree := MeshInstance3D.new()
		tree.mesh = tree_mesh
		tree.material_override = bark
		tree.position = Vector3(sin(a) * r, -0.6, -cos(a) * r - 2.0)
		tree.rotation.y = rng.randf() * TAU
		var s := rng.randf_range(1.3, 2.0)
		tree.scale = Vector3(s, s, s)
		add_child(tree)
	# Grüne Feuer in Eisenschalen rund um die Platte
	var iron := _mat(Color(0.08, 0.08, 0.08), Color.BLACK, 0.0, 0.45)
	iron.metallic = 0.85
	for spot in [Vector3(-7.2, 0, -5.0), Vector3(7.2, 0, -5.0), Vector3(-8.0, 0, 1.5), Vector3(8.0, 0, 1.5)]:
		var bowl := CylinderMesh.new()
		bowl.top_radius = 0.6
		bowl.bottom_radius = 0.25
		bowl.height = 0.4
		var stand := CylinderMesh.new()
		stand.top_radius = 0.08
		stand.bottom_radius = 0.18
		stand.height = 1.6
		_part(stand, iron, self, spot + Vector3(0, 0.2, 0))
		_part(bowl, iron, self, spot + Vector3(0, 1.1, 0))
		_fire(spot + Vector3(0, 1.3, 0), 1.0)

# Flackernde Flamme aus der Flammen-Textur von "Claude 1"
func _fire(at: Vector3, size: float) -> void:
	var fire := CPUParticles3D.new()
	fire.position = at
	fire.amount = 26
	fire.lifetime = 0.8
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.25 * size
	fire.direction = Vector3(0, 1, 0)
	fire.spread = 12
	fire.gravity = Vector3(0, 2.2, 0)
	fire.initial_velocity_min = 0.3
	fire.initial_velocity_max = 0.8
	fire.scale_amount_min = 0.6 * size
	fire.scale_amount_max = 1.3 * size
	var quad := QuadMesh.new()
	quad.size = Vector2(0.7, 0.9)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(HAIN + "textures/flamme.png")
	m.albedo_color = flame_color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.disable_fog = true
	quad.material = m
	fire.mesh = quad
	add_child(fire)
	var light := OmniLight3D.new()
	light.position = at + Vector3(0, 0.4, 0)
	light.light_color = flame_color
	light.light_energy = 3.0
	light.omni_range = 9.0
	light.light_volumetric_fog_energy = 0.6
	add_child(light)
	candles.append(light)

# Überreste: Schädel und Geweihe früherer Wurzelhirten, Knochenberge, kleine Schädel
func _build_remains() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var bone := _bestie_material("knochen")
	var scene: PackedScene = load(HAIN + "models/hirt/hirt.glb")
	var probe := scene.instantiate()
	var skull_mesh: Mesh = null
	var antler_mesh: Mesh = null
	for mi in probe.find_children("*", "MeshInstance3D", true, false):
		if mi.name == "knochen_schaedel":
			skull_mesh = mi.mesh
		elif mi.name == "knochen_geweih":
			antler_mesh = mi.mesh
	probe.free()
	var spots := [Vector3(-6.0, -0.6, -2.0), Vector3(6.3, -0.6, -3.2), Vector3(-4.6, 0.9, -8.6), Vector3(4.2, 0.9, -8.9), Vector3(-9.5, -0.6, -8.0), Vector3(9.8, -0.6, -6.5)]
	for spot in spots:
		var remains := Node3D.new()
		remains.position = spot
		remains.rotation = Vector3(rng.randf_range(-0.6, 0.6), rng.randf() * TAU, rng.randf_range(1.0, 1.5) * (1 if rng.randf() < 0.5 else -1))
		var s := rng.randf_range(1.6, 2.3)
		remains.scale = Vector3(s, s, s)
		add_child(remains)
		for mesh in [skull_mesh, antler_mesh]:
			if mesh != null:
				var part := MeshInstance3D.new()
				part.mesh = mesh
				part.material_override = bone
				part.position = Vector3(0, -1.2, 0)
				remains.add_child(part)
	# Kleine Schädel verstreut
	var small_skull: Mesh = load(HAIN + "models/level3/schaedel.obj")
	for i in range(26):
		var a := rng.randf() * TAU
		var r := rng.randf_range(5.0, 11.0)
		var p := Vector3(cos(a) * r, -0.52, sin(a) * r * 0.7 - 3.0)
		if abs(p.x) < 4.2 and p.z > -4.5:
			continue
		var skull := _part(small_skull, bone, self, p, Vector3(rng.randf_range(-30, 30), rng.randf() * 360, rng.randf_range(-40, 40)))
		var ss := rng.randf_range(2.5, 4.0)
		skull.scale = Vector3(ss, ss, ss)
	# Knochenberge neben dem Felsvorsprung
	var pile_mesh: Mesh = load(HAIN + "models/level3/knochen.obj")
	var center := pile_mesh.get_aabb().get_center()
	for side in [-1, 1]:
		var pile := MeshInstance3D.new()
		pile.mesh = pile_mesh
		pile.material_override = bone
		pile.scale = Vector3(0.55, 0.55, 0.3)
		pile.rotation.y = PI / 2.0
		add_child(pile)
		pile.position = Vector3(side * 9.0, -1.2, -9.0) - pile.basis * center


func _environment() -> Environment:
	var env := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.02, 0.01, 0.03)
	sky_mat.sky_horizon_color = Color(0.55, 0.1, 0.06)
	sky_mat.ground_horizon_color = Color(0.2, 0.04, 0.03)
	sky_mat.ground_bottom_color = Color(0.0, 0.0, 0.0)
	sky_mat.sun_angle_max = 1.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.36, 0.42)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.glow_enabled = true
	env.glow_intensity = 1.1
	env.glow_bloom = 0.15
	env.glow_hdr_threshold = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.22, 0.05, 0.05)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.35
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.014
	env.volumetric_fog_albedo = Color(0.6, 0.25, 0.25)
	env.volumetric_fog_emission = Color(0.06, 0.0, 0.01)
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.15
	env.adjustment_saturation = 0.9
	return env

func _mat(color: Color, emission: Color = Color.BLACK, energy: float = 0.0, roughness: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m

func _part(mesh: Mesh, material: Material, parent: Node3D, pos: Vector3, rot: Vector3 = Vector3.ZERO, scale_v: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = pos
	node.rotation_degrees = rot
	node.scale = scale_v
	parent.add_child(node)
	return node

func _cone(bottom: float, height: float, top: float = 0.0, segments: int = 12) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh

func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh

func _build_sky_objects(with_moon: bool = true) -> void:
	# Blutmond (in der Mondnacht kommt der Mond aus dem Himmel-Shader)
	moon_material = _mat(Color(0.95, 0.6, 0.45), Color(1.0, 0.45, 0.3), 1.15)
	moon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_material.disable_fog = true
	if with_moon:
		_part(_sphere(7.0), moon_material, self, Vector3(-15, 6.5, -46))
	# Schein um den Mond
	var glow_mat := _mat(Color(0.9, 0.3, 0.2, 0.18), Color(1, 0.3, 0.2), 1.0)
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.disable_fog = true
	_part(_sphere(10.5), glow_mat, self, Vector3(-15, 6.5, -48))
	# Silhouette einer gotischen Stadt
	var stone := _mat(Color(0.05, 0.03, 0.04))
	stone.disable_fog = true
	var rng := RandomNumberGenerator.new()
	rng.seed = 1347
	for i in range(26):
		var x := -34.0 + i * 2.7 + rng.randf_range(-0.8, 0.8)
		var z := -30.0 - rng.randf_range(0, 14)
		var h := rng.randf_range(5, 16)
		var w := rng.randf_range(1.2, 2.6)
		var box := BoxMesh.new()
		box.size = Vector3(w, h, w)
		_part(box, stone, self, Vector3(x, h / 2.0 - 2, z))
		_part(_cone(w * 0.62, rng.randf_range(3, 8), 0.0, 4), stone, self, Vector3(x, h - 2 + 2.5, z), Vector3(0, 45, 0))
		# kleine Türmchen
		for side in [-1, 1]:
			if rng.randf() < 0.6:
				_part(_cone(0.25, 3.0, 0.0, 4), stone, self, Vector3(x + side * w * 0.45, h - 2 + 1.2, z + w * 0.45), Vector3(0, 45, 0))
		# erleuchtete Fenster
		if rng.randf() < 0.5:
			var window := _mat(Color(1, 0.6, 0.3), Color(1, 0.5, 0.2), 3.0)
			window.disable_fog = true
			var quad := BoxMesh.new()
			quad.size = Vector3(0.25, 0.5, 0.05)
			_part(quad, window, self, Vector3(x, rng.randf_range(2, h - 3), z + w / 2.0 + 0.03))
	# Grosse Säulen links und rechts vom Spielfeld
	for side in [-1, 1]:
		for j in range(3):
			var pillar := CylinderMesh.new()
			pillar.top_radius = 0.45
			pillar.bottom_radius = 0.55
			pillar.height = 12
			_part(pillar, stone, self, Vector3(side * 7.5, 4, -6 + j * 5.5))
			_part(_cone(0.7, 2.5, 0.0, 6), stone, self, Vector3(side * 7.5, 11.2, -6 + j * 5.5))

func _build_floor() -> void:
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(80, 80)
	var floor_mat: Material
	var stone_top: Material
	var stone_base: Material
	match arena_kind:
		"hain":
			floor_mesh.size = Vector2(140, 140)
			floor_mat = _stone("matsch", 0.22, Color(0.5, 0.5, 0.4), 0.6, 0.15)
			stone_top = _stone("quader", 0.55, Color(0.55, 0.58, 0.5), 0.45, 0.25, 0.6)
			stone_base = _stone("quader", 0.42, Color(0.42, 0.45, 0.38), 0.8)
		"mond", "turm", "kathedrale", "beinhaus":
			floor_mat = _stone("quader", 0.25, Color(0.62, 0.65, 0.72), 0.15, 0.35)
			stone_top = _stone("quader", 0.55, Color(0.7, 0.72, 0.78), 0.1, 0.2, 0.5)
			stone_base = _stone("quader", 0.42, Color(0.5, 0.52, 0.58), 0.2)
		_:
			var plain := _mat(Color(0.09, 0.07, 0.07), Color.BLACK, 0.0, 0.6)
			plain.metallic = 0.2
			floor_mat = plain
			stone_top = _mat(Color(0.16, 0.13, 0.13), Color.BLACK, 0.0, 0.65)
			stone_base = _mat(Color(0.08, 0.06, 0.06), Color.BLACK, 0.0, 0.8)
	if level_root == null:
		_part(floor_mesh, floor_mat, self, Vector3(0, -0.6, 0))
	# Ritualkreis unter den Karten
	var ring_mat := _mat(ring_color * 0.55, ring_color, 2.2)
	var ring_root := Node3D.new()
	ring_root.name = "LeuchtKreis"
	add_child(ring_root)
	for r in [4.3, 4.6]:
		var torus := TorusMesh.new()
		torus.inner_radius = r - 0.05
		torus.outer_radius = r
		torus.rings = 64
		_part(torus, ring_mat, ring_root, Vector3(0, -0.58, 0), Vector3.ZERO, Vector3(1, 1, maxf(1.0, board_depth / 8.0)))
	# Schräge Steinplatte im gleichen Winkel wie die Karten, darunter ein massiver Sockel

	var slab := BoxMesh.new()
	slab.size = Vector3(7.2, 0.12, board_depth)
	var board_stone: Material = _stone("quader", 0.55, Color(0.46, 0.46, 0.48), 0.0, 0.1) if arena_kind != "gothic" else stone_top
	if level_root == null:
		_part(slab, board_stone, self, board_point(Vector3(0, -0.57, 0)), Vector3(board_tilt, 0, 0))
	var trim := BoxMesh.new()
	trim.size = Vector3(7.5, 0.1, board_depth + 0.3)
	if level_root == null:
		_part(trim, ring_mat, self, board_point(Vector3(0, -0.66, 0)), Vector3(board_tilt, 0, 0))
	var pedestal := BoxMesh.new()
	pedestal.size = Vector3(7.0, 6.0, board_depth - 0.2)
	if level_root == null:
		_part(pedestal, stone_base, self, board_point(Vector3(0, -3.7, 0)), Vector3(board_tilt, 0, 0))
	# Felsvorsprung, auf dem der Boss steht (nicht in Level-Arenen)
	var ledge := BoxMesh.new()
	ledge.size = Vector3(7.5, 2.0, 4.5)
	if level_root != null:
		ledge.size = Vector3.ZERO
	ledge.size = Vector3(7.5, 2.0, 4.5)
	if level_root == null:
		_part(ledge, stone_base, self, Vector3(0, boss_pos.y - 1.0, boss_pos.z - 0.3))
	var ledge_top := BoxMesh.new()
	ledge_top.size = Vector3(7.7, 0.12, 4.7)
	if level_root == null:
		_part(ledge_top, stone_top, self, Vector3(0, boss_pos.y - 0.02, boss_pos.z - 0.3))
	# Licht über dem Spielfeld
	var board_light := OmniLight3D.new()
	board_light.name = "Spielfeldlicht"
	board_light.position = Vector3(0, 6, 1)
	board_light.light_color = Color(1.0, 0.88, 0.8)
	board_light.light_energy = 2.2
	board_light.omni_range = 14
	add_child(board_light)

func _build_candles() -> void:
	var candle_root := Node3D.new()
	candle_root.name = "Kerzen"
	add_child(candle_root)
	var wax := _mat(Color(0.85, 0.8, 0.7))
	var flame := _mat(flame_color.lightened(0.3), flame_color, 6.0)
	flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var spots := [Vector3(-4.6, 0, -4.2), Vector3(4.6, 0, -4.2), Vector3(-4.9, 0, 0.8), Vector3(4.9, 0, 0.8), Vector3(-4.2, 0, 4.4), Vector3(4.2, 0, 4.4)]
	for spot in spots:
		for k in range(3):
			var height := 0.4 + k * 0.25
			var offset := Vector3((k - 1) * 0.22, 0, (k % 2) * 0.18)
			var stick := CylinderMesh.new()
			stick.top_radius = 0.07
			stick.bottom_radius = 0.08
			stick.height = height
			_part(stick, wax, candle_root, spot + offset + Vector3(0, -0.58 + height / 2.0, 0))
			_part(_sphere(0.05), flame, candle_root, spot + offset + Vector3(0, -0.58 + height + 0.06, 0), Vector3.ZERO, Vector3(1, 1.8, 1))
		var light := OmniLight3D.new()
		light.position = spot + Vector3(0, 0.6, 0)
		light.light_color = flame_color
		light.light_energy = 1.4
		light.omni_range = 4.5
		candle_root.add_child(light)
		candles.append(light)

func _build_ash() -> void:
	var ash := CPUParticles3D.new()
	ash.name = "Asche"
	ash.amount = 140
	ash.lifetime = 9.0
	ash.preprocess = 9.0
	ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ash.emission_box_extents = Vector3(14, 1, 12)
	ash.position = Vector3(0, 9, -3)
	ash.direction = Vector3(0.3, -1, 0)
	ash.spread = 25
	ash.gravity = Vector3(0.15, -0.4, 0)
	ash.initial_velocity_min = 0.2
	ash.initial_velocity_max = 0.6
	ash.scale_amount_min = 0.5
	ash.scale_amount_max = 1.3
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var ash_color := Color(1, 0.45, 0.25)
	if arena_kind == "hain":
		ash_color = Color(0.7, 0.9, 0.45)
	elif arena_kind == "mond":
		ash_color = Color(0.75, 0.78, 0.85)
	var m := _mat(ash_color, ash_color, 1.6)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = m
	ash.mesh = quad
	add_child(ash)

# --- Boss-Modell -----------------------------------------------------------------
# Vier Varianten: "oubli" (Endboss), "gardien" (Ritter), "sorciere" (Hexe), "corbeau" (Rabe).
# Oberflächen bekommen Rausch-Texturen (Farbe + Normal-Map), damit Stoff, Knochen
# und Metall nicht glatt wie Plastik aussehen. Liegt unter assets/boss/<style>.glb ein
# echtes 3D-Modell, wird stattdessen dieses verwendet.

var style := "oubli"
var accent := Color(1, 0.08, 0.05)
var cloth_strips: Array[Node3D] = []
var orbiters: Array[Node3D] = []

func _noise_texture(frequency: float, normal: bool, ramp: Gradient = null, noise_type: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH, seed_value: int = 0) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.noise_type = noise_type
	noise.frequency = frequency
	noise.fractal_octaves = 5
	noise.seed = seed_value
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	if normal:
		texture.as_normal_map = true
		texture.bump_strength = 5.0
	if ramp != null:
		texture.color_ramp = ramp
	return texture

func _gradient(dark: Color, light: Color) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, dark)
	g.set_color(1, light)
	return g

# Material mit Struktur: Farbverlauf aus Rauschen, Normal-Map, dreiseitige Projektion.
func _rich(dark: Color, light: Color, roughness: float, bump_frequency: float, metallic: float = 0.0, cellular: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var noise_type := FastNoiseLite.TYPE_CELLULAR if cellular else FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	m.albedo_texture = _noise_texture(0.012, false, _gradient(dark, light), noise_type, randi())
	m.normal_enabled = true
	m.normal_texture = _noise_texture(bump_frequency, true, null, noise_type, randi())
	m.normal_scale = 1.2
	m.roughness = roughness
	m.metallic = metallic
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(1.4, 1.4, 1.4)
	m.emission_enabled = true
	m.emission = Color.BLACK
	m.emission_energy_multiplier = 0.0
	flash_materials.append(m)
	return m

func _capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 24
	mesh.rings = 8
	return mesh

func _smooth_sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 32
	mesh.rings = 16
	return mesh

func _build_boss(look: Dictionary) -> void:
	style = str(look.get("style", "oubli"))
	accent = Color(str(look.get("accent", "#ff1408")))
	boss_root = Node3D.new()
	boss_root.position = boss_pos
	var size := float(look.get("scale", 1.0))
	boss_root.scale = Vector3(size, size, size)
	add_child(boss_root)
	boss_body = Node3D.new()
	boss_root.add_child(boss_body)

	eye_material = _mat(accent, accent, 9.0)
	eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	head = Node3D.new()
	head.position = Vector3(0, 5.45, 0.05)
	boss_body.add_child(head)

	var model_path := "res://assets/boss/%s.glb" % style
	var rigged_path := str(look.get("model", ""))
	if not rigged_path.is_empty() and ResourceLoader.exists(rigged_path):
		# Modell mit Skelett (z. B. der Wurzelhirt aus "Claude 1"): Knochen werden animiert.
		_build_rigged(rigged_path, float(look.get("model_scale", 2.7)), look)
	elif ResourceLoader.exists(model_path):
		# Eigenes Modell (z. B. aus Blender): wird an Stelle der Grundformen gezeigt.
		var model: Node3D = load(model_path).instantiate()
		boss_body.add_child(model)
		left_arm = _empty_arm(-1)
		right_arm = _empty_arm(1)
	else:
		match style:
			"gardien":
				_build_knight()
			"sorciere":
				_build_witch()
			"corbeau":
				_build_raven()
			_:
				_build_oubli()

	eye_light = OmniLight3D.new()
	eye_light.position = Vector3(0, 0.1, 0.8)
	eye_light.light_color = accent
	eye_light.light_energy = 2.0
	eye_light.omni_range = 3.5
	head.add_child(eye_light)

	aura = CPUParticles3D.new()
	aura.amount = 30
	aura.lifetime = 2.4
	aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	aura.emission_sphere_radius = 1.8
	aura.position = Vector3(0, 2.6, 0)
	aura.direction = Vector3(0, 1, 0)
	aura.spread = 40
	aura.gravity = Vector3(0, 0.6, 0)
	aura.initial_velocity_min = 0.3
	aura.initial_velocity_max = 0.9
	aura.scale_amount_min = 0.5
	aura.scale_amount_max = 1.3
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var m := _mat(accent, accent, 3.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = m
	aura.mesh = quad
	boss_body.add_child(aura)

	var boss_light := OmniLight3D.new()
	boss_light.position = Vector3(0, 3, 2.5)
	boss_light.light_color = accent.lerp(Color.WHITE, 0.5)
	boss_light.light_energy = 2.0
	boss_light.omni_range = 8
	boss_body.add_child(boss_light)
	# Gegenlicht vom Mond, damit sich die Silhouette abhebt
	var rim := SpotLight3D.new()
	rim.position = Vector3(0, 8, -6)
	rim.light_color = Color(1.0, 0.75, 0.65)
	rim.light_energy = 7.0
	rim.spot_range = 18
	rim.spot_angle = 38
	boss_root.add_child(rim)
	rim.look_at(boss_root.global_position + Vector3(0, 3, 0))
	# Vorderlicht schräg von oben, damit Details sichtbar sind
	var key := SpotLight3D.new()
	key.position = Vector3(3.5, 7.5, 5.5)
	key.light_color = Color(1.0, 0.85, 0.75)
	key.light_energy = 1.8
	key.spot_range = 16
	key.spot_angle = 30
	key.shadow_enabled = true
	boss_root.add_child(key)
	key.look_at(boss_root.global_position + Vector3(0, 3.5, 0))


# --- Modell mit Skelett ----------------------------------------------------------
# Für jeden Knochen entsteht ein Gelenk-Knoten an der gleichen Stelle. Die Animationen
# drehen nur diese Knoten, in _process werden die Drehungen auf das Skelett übertragen.
# Knochen des Wurzelhirts: Huefte, Bauch, Rumpf, KopfGelenk, Kiefer, ArmLinks,
# UnterarmLinks, ArmRechts, UnterarmRechts, Mantel, BeinLinks, UnterschenkelLinks,
# FussLinks, BeinRechts, UnterschenkelRechts, FussRechts.

var skeleton: Skeleton3D
var rig: Dictionary = {}          # Knochenname -> Gelenk-Knoten
var rig_bones: Dictionary = {}    # Gelenk-Knoten -> Knochennummer
var core_material: StandardMaterial3D
var core_light: OmniLight3D
var chest_node: Node3D
var hand_offset := Vector3(0, -1.7, 0.3)
var rooted := false               # Verwurzelt: das Herz liegt offen
var weapon: Node3D
var weapon_arm: Node3D
var creak_timer := 0.0
var creak_target := Vector3.ZERO

func _bestie_material(prefix: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.emission_enabled = true
	m.emission = Color.BLACK
	m.emission_energy_multiplier = 0.0
	match prefix:
		"haut":
			m.albedo_texture = load(HAIN + "textures/leder.png")
			m.normal_enabled = true
			m.normal_texture = load(HAIN + "textures/leder_n.png")
			m.normal_scale = 1.1
			m.roughness = 0.62
			m.uv1_scale = Vector3(1.4, 1.4, 1.4)
		"knochen":
			m.albedo_texture = load(HAIN + "textures/leder.png")
			m.normal_enabled = true
			m.normal_texture = load(HAIN + "textures/leder_n.png")
			m.normal_scale = 0.8
			m.roughness = 0.5
			m.uv1_scale = Vector3(2, 2, 2)
		"stoff":
			m.albedo_texture = load(HAIN + "textures/stoff.png")
			m.normal_enabled = true
			m.normal_texture = load(HAIN + "textures/stoff_n.png")
			m.roughness = 0.88
			m.uv1_scale = Vector3(2, 2, 2)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"fell":
			m.albedo_texture = load(HAIN + "textures/fell.png")
			m.normal_enabled = true
			m.normal_texture = load(HAIN + "textures/fell_n.png")
			m.roughness = 0.8
			m.uv1_scale = Vector3(1.5, 1.5, 1.5)
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"metall":
			m.albedo_texture = load(HAIN + "textures/leder.png")
			m.normal_enabled = true
			m.normal_texture = load(HAIN + "textures/metall_n.png")
			m.normal_scale = 0.8
			m.metallic = 0.9
			m.roughness = 0.42
			m.uv1_scale = Vector3(2, 2, 2)
		"glut":
			m.vertex_color_use_as_albedo = false
			m.albedo_color = accent
			m.emission = accent
			m.emission_energy_multiplier = 2.0
			m.roughness = 0.8
	return m

func _build_rigged(path: String, model_scale: float, look: Dictionary = {}) -> void:
	var holder := Node3D.new()
	holder.scale = Vector3.ONE * model_scale
	holder.position.y = 1.2 * model_scale        # Füsse auf dem Boden
	boss_body.add_child(holder)
	var figure: Node3D = load(path).instantiate()
	holder.add_child(figure)
	skeleton = figure.find_children("*", "Skeleton3D", true, false)[0]
	var materials := {}
	for mi in figure.find_children("*", "MeshInstance3D", true, false):
		var prefix := str(mi.name).get_slice("_", 0)
		if not materials.has(prefix):
			materials[prefix] = _bestie_material(prefix)
			if prefix != "glut":
				flash_materials.append(materials[prefix])
		mi.set_surface_override_material(0, materials[prefix])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	core_material = materials.get("glut", null)
	_rigidify(path)
	_eyes_config = look.get("eyes", {})	# Gelenke wie das Skelett aufbauen
	for i in range(skeleton.get_bone_count()):
		var joint := Node3D.new()
		var bone_name := skeleton.get_bone_name(i)
		joint.name = bone_name
		joint.position = skeleton.get_bone_rest(i).origin
		var parent_index := skeleton.get_bone_parent(i)
		if parent_index < 0:
			holder.add_child(joint)
		else:
			rig[skeleton.get_bone_name(parent_index)].add_child(joint)
		rig[bone_name] = joint
		rig_bones[joint] = i
	# Die Arm-Animationen erwarten Schulter > "Elbow". Links im Bild ist sein rechter Arm.
	left_arm = rig["ArmRechts"]
	right_arm = rig["ArmLinks"]
	for pair in [[left_arm, rig["UnterarmRechts"], -1], [right_arm, rig["UnterarmLinks"], 1]]:
		var shoulder: Node3D = pair[0]
		var forearm: Node3D = pair[1]
		var elbow := Node3D.new()
		elbow.name = "Elbow"
		shoulder.add_child(elbow)
		elbow.position = forearm.position
		forearm.set_meta("follow", elbow)
		shoulder.rotation_degrees = Vector3(-8, 0, pair[2] * 10)
		elbow.rotation_degrees = Vector3(-22, 0, 0)
		shoulder.set_meta("rest", shoulder.rotation_degrees)
		elbow.set_meta("rest", elbow.rotation_degrees)
		var hand := Node3D.new()
		hand.name = "Hand"
		hand.position = Vector3(0, -0.8, 0.05)
		elbow.add_child(hand)
	hand_offset = Vector3(0, -0.8, 0.1)
	_build_eyes()
	# Kopf: Augen-Licht und Treffer-Punkte hängen am Kopfgelenk
	var neck: Node3D = rig["KopfGelenk"]
	head.get_parent().remove_child(head)
	neck.add_child(head)
	head.position = Vector3(0, 0.15, 0.15)
	head.scale = Vector3.ONE / model_scale
	chest_node = Node3D.new()
	chest_node.position = Vector3(0, 0.45, 0.2)
	rig["Rumpf"].add_child(chest_node)
	# Leuchtendes Herz
	core_light = OmniLight3D.new()
	core_light.light_color = accent
	core_light.light_energy = 0.6
	core_light.omni_range = 4.0
	core_light.position = Vector3(0, 0.3, 0.4)
	rig["Rumpf"].add_child(core_light)
	# Waffe aus "Claude 1" in seiner rechten Hand (im Bild links), wie dort am Unterarm
	weapon_arm = left_arm
	var weapon_parts: Array = look.get("weapon", [])
	if not weapon_parts.is_empty():
		weapon = Node3D.new()
		weapon.position = Vector3(0, -0.06, 0.02)
		var rot: Array = look.get("weapon_rot", [-70, 0, 0])
		weapon.rotation_degrees = Vector3(rot[0], rot[1], rot[2])
		rig["UnterarmRechts"].get_meta("follow").get_node("Hand").add_child(weapon)
		for part in weapon_parts:
			var mesh_node := MeshInstance3D.new()
			mesh_node.mesh = load(HAIN + "models/" + str(part))
			var kind := "metall" if str(part).contains("stahl") else "haut"
			var mat := _bestie_material(kind)
			mat.vertex_color_use_as_albedo = false
			mat.albedo_color = Color(0.5, 0.5, 0.52) if kind == "metall" else Color(0.3, 0.22, 0.15)
			mesh_node.material_override = mat
			weapon.add_child(mesh_node)
	# Grundhaltung: steif, leicht gebeugt
	rig["Rumpf"].rotation_degrees.x = 8
	rig["KopfGelenk"].rotation_degrees.x = 12
	rig["Huefte"].set_meta("rest_pos", rig["Huefte"].position)

# Die Modelle aus "Claude 1" sind aus festen Teilen gebaut. Werden sie über die Haut
# (Skinning) verformt, zieht es die Dreiecke zwischen den Teilen zu langen Bändern.
# Darum wird jedes Dreieck dem Knochen zugeteilt, zu dem es am meisten gehört, und
# als festes Teil an diesen Knochen gehängt (BoneAttachment3D). So dehnt sich nichts.
static var _rigid_cache: Dictionary = {}

func _rigidify(figure_path: String) -> void:
	for mi in skeleton.find_children("*", "MeshInstance3D", true, false):
		var key := figure_path + ":" + str(mi.name)
		var parts: Dictionary = _rigid_cache.get(key, {})
		if parts.is_empty():
			parts = _split_by_bone(mi)
			_rigid_cache[key] = parts
		var material: Material = mi.get_surface_override_material(0)
		for bind in parts:
			var info: Dictionary = parts[bind]
			var attach := BoneAttachment3D.new()
			attach.bone_name = info["bone"]
			skeleton.add_child(attach)
			var piece := MeshInstance3D.new()
			piece.mesh = info["mesh"]
			piece.transform = info["bind_pose"]
			piece.material_override = material
			piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			attach.add_child(piece)
		mi.visible = false

func _split_by_bone(mi: MeshInstance3D) -> Dictionary:
	var arrays: Array = mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals = arrays[Mesh.ARRAY_NORMAL]
	var uvs = arrays[Mesh.ARRAY_TEX_UV]
	var colors = arrays[Mesh.ARRAY_COLOR]
	var bones = arrays[Mesh.ARRAY_BONES]
	var weights = arrays[Mesh.ARRAY_WEIGHTS]
	var index = arrays[Mesh.ARRAY_INDEX]
	if bones == null or weights == null or verts.is_empty():
		return {}
	if index == null or index.is_empty():
		index = PackedInt32Array(range(verts.size()))
	var per := int(bones.size() / verts.size())
	var groups := {}
	for t in range(0, index.size(), 3):
		var score := {}
		for c in range(3):
			var v: int = index[t + c]
			for k in range(per):
				var w: float = weights[v * per + k]
				if w > 0.0:
					var b := int(bones[v * per + k])
					score[b] = float(score.get(b, 0.0)) + w
		var best := -1
		var best_w := -1.0
		for b in score:
			if score[b] > best_w:
				best_w = score[b]
				best = b
		if not groups.has(best):
			groups[best] = PackedInt32Array()
		groups[best].append(index[t])
		groups[best].append(index[t + 1])
		groups[best].append(index[t + 2])
	var skin: Skin = mi.skin
	var result := {}
	for b in groups:
		var ids: PackedInt32Array = groups[b]
		var remap := {}
		var nv := PackedVector3Array()
		var nn := PackedVector3Array()
		var nu := PackedVector2Array()
		var nc := PackedColorArray()
		var ni := PackedInt32Array()
		for v in ids:
			if not remap.has(v):
				remap[v] = nv.size()
				nv.append(verts[v])
				if normals != null:
					nn.append(normals[v])
				if uvs != null:
					nu.append(uvs[v])
				if colors != null:
					nc.append(colors[v])
			ni.append(remap[v])
		var out := []
		out.resize(Mesh.ARRAY_MAX)
		out[Mesh.ARRAY_VERTEX] = nv
		out[Mesh.ARRAY_INDEX] = ni
		if normals != null:
			out[Mesh.ARRAY_NORMAL] = nn
		if uvs != null:
			out[Mesh.ARRAY_TEX_UV] = nu
		if colors != null:
			out[Mesh.ARRAY_COLOR] = nc
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
		var bone_name := skin.get_bind_name(b)
		if bone_name.is_empty():
			bone_name = skeleton.get_bone_name(skin.get_bind_bone(b))
		result[b] = {"mesh": mesh, "bone": bone_name, "bind_pose": skin.get_bind_pose(b)}
	return result
func _update_rig() -> void:
	if skeleton == null:
		return
	# Die Unterarme folgen den Ellbogen-Knoten der Arm-Animation
	for name in ["UnterarmLinks", "UnterarmRechts"]:
		var forearm: Node3D = rig[name]
		forearm.rotation = forearm.get_meta("follow").rotation
	for joint in rig_bones:
		var index: int = rig_bones[joint]
		skeleton.set_bone_pose_rotation(index, joint.quaternion)
		if joint.name == "Huefte":
			skeleton.set_bone_pose_position(index, joint.position)

# --- Posen wie in "Claude 1" ------------------------------------------------------
# Jedes Gelenk wird von einer Feder zu seiner Zielstellung gezogen (wie "drehe" in
# gegner.gd). So schwingen Bewegungen schwer nach, statt starr zu springen.
# Winkel in Grad. "H" = Höhe der Hüfte (Grundstellung -0.44), "torso" wird auf
# Bauch (45 %) und Rumpf (55 %) verteilt. AR/UR = rechter Arm mit der Waffe.
const POSES := {
	"idle": {"H": -0.47, "huefte": Vector3(0, 0, 0), "torso": Vector3(24, 0, 0), "kopf": Vector3(-14, 0, 0),
		"AL": Vector3(-16, 6, -10), "UL": -24.0, "AR": Vector3(-16, -6, 10), "UR": -24.0, "jaw": 5.0, "tempo": 6.0},
	# pose_hieb_ausholen / pose_hieb / pose_hieb_nach (rechter Arm, seite = -1)
	"windup_swing": {"H": -0.6, "huefte": Vector3(4, -12, 2), "torso": Vector3(-10, -26, -5), "kopf": Vector3(10, 0, 0),
		"AL": Vector3(-34, 0, -24), "UL": -40.0, "AR": Vector3(-162, -18, 12), "UR": -74.0, "jaw": 20.0, "tempo": 9.0},
	"strike_swing": {"H": -0.66, "huefte": Vector3(16, 14, -3), "torso": Vector3(30, 26, 5), "kopf": Vector3(-16, 0, 0),
		"AL": Vector3(34, -16, -22), "UL": -30.0, "AR": Vector3(-42, 44, 0), "UR": -6.0, "jaw": 34.0, "tempo": 26.0},
	"after_swing": {"H": -0.66, "huefte": Vector3(10, 6, 0), "torso": Vector3(24, 12, 3), "kopf": Vector3(-18, 0, 0),
		"AL": Vector3(10, 0, -14), "UL": -30.0, "AR": Vector3(-14, 36, 12), "UR": -28.0, "jaw": 16.0, "tempo": 9.0},
	# pose_beide_ausholen / pose_beide_schlag / pose_einschlag_nach
	"windup_both": {"H": -0.3, "huefte": Vector3(-6, 0, 0), "torso": Vector3(-30, 0, 0), "kopf": Vector3(14, 0, 0),
		"AL": Vector3(-176, 0, -10), "UL": -66.0, "AR": Vector3(-176, 0, 10), "UR": -66.0, "jaw": 24.0, "tempo": 7.0},
	"strike_both": {"H": -0.72, "huefte": Vector3(24, 0, 0), "torso": Vector3(46, 0, 0), "kopf": Vector3(-30, 0, 0),
		"AL": Vector3(-30, 0, 6), "UL": -6.0, "AR": Vector3(-30, 0, -6), "UR": -6.0, "jaw": 34.0, "tempo": 26.0},
	"after_both": {"H": -0.8, "huefte": Vector3(22, 0, 0), "torso": Vector3(60, 0, 0), "kopf": Vector3(-40, 0, 0),
		"AL": Vector3(-52, 6, 6), "UL": -10.0, "AR": Vector3(-48, -6, -6), "UR": -12.0, "jaw": 26.0, "tempo": 12.0},
	# Zaubern: wie pose_bruellen (Arme weit), dann nach vorne stossen
	"windup_cast": {"H": -0.5, "huefte": Vector3(0, 0, 0), "torso": Vector3(-8, 0, 0), "kopf": Vector3(-25, 0, 0),
		"AL": Vector3(-40, 0, -64), "UL": -66.0, "AR": Vector3(-40, 0, 64), "UR": -66.0, "jaw": 26.0, "tempo": 8.0},
	"strike_cast": {"H": -0.55, "huefte": Vector3(6, 0, 0), "torso": Vector3(22, 0, 0), "kopf": Vector3(-10, 0, 0),
		"AL": Vector3(-88, 0, -18), "UL": -10.0, "AR": Vector3(-88, 0, 18), "UR": -10.0, "jaw": 30.0, "tempo": 20.0},
	# pose_erholen: vornübergebeugt, schnauft
	"after_cast": {"H": -0.62, "huefte": Vector3(14, 0, 0), "torso": Vector3(32, 0, 0), "kopf": Vector3(-34, 0, 0),
		"AL": Vector3(-22, 0, -6), "UL": -18.0, "AR": Vector3(-14, 0, 6), "UR": -24.0, "jaw": 22.0, "tempo": 8.0},
	"roar": {"H": -0.4, "huefte": Vector3(0, 0, 0), "torso": Vector3(-26, 0, 0), "kopf": Vector3(-44, 0, 0),
		"AL": Vector3(-40, 0, -64), "UL": -66.0, "AR": Vector3(-40, 0, 64), "UR": -66.0, "jaw": 38.0, "tempo": 13.0},
	"hurt": {"H": -0.55, "huefte": Vector3(-6, 0, 4), "torso": Vector3(-18, 0, 6), "kopf": Vector3(-25, 0, 10),
		"AL": Vector3(10, 0, -18), "UL": -40.0, "AR": Vector3(10, 0, 18), "UR": -40.0, "jaw": 20.0, "tempo": 14.0},
	"rooted": {"H": -0.86, "huefte": Vector3(0, 0, 0), "torso": Vector3(12, 0, 0), "kopf": Vector3(26, 0, 0),
		"AL": Vector3(-26, 0, -56), "UL": -34.0, "AR": Vector3(-26, 0, 56), "UR": -34.0, "jaw": 12.0, "tempo": 6.0,
		"legs": [-74.0, 118.0, -60.0, 108.0]},
	"dead": {"H": -0.95, "huefte": Vector3(10, 0, 0), "torso": Vector3(78, 0, 8), "kopf": Vector3(45, 0, 10),
		"AL": Vector3(12, 0, -24), "UL": -10.0, "AR": Vector3(12, 0, 24), "UR": -10.0, "jaw": 30.0, "tempo": 4.0,
		"legs": [-80.0, 125.0, -70.0, 115.0]},
}
var pose_name := "idle"
var pose_next := ""           # Pose, die nach Ablauf der Haltezeit folgt
var pose_until := -1.0
var attack_group := "swing"
var joint_velocity := {}

func set_pose(name: String, hold: float = -1.0) -> void:
	if dead and name != "dead":
		return
	pose_name = name
	pose_until = time + hold if hold > 0.0 else -1.0

# Welche Haltung zu welchem Angriff passt
func _group_for(kind: String) -> String:
	if kind in ["slam", "stomp", "skulls", "bone_spikes", "toll"]:
		return "both"
	if kind in ["orb", "curse", "spores", "herd", "blades", "ash", "bone_armor", "root_self"]:
		return "cast"
	return "swing"

# Wird von Main.gd aufgerufen, wenn der Angriff nach dem Ausholen losgeht.
func strike() -> void:
	if skeleton != null:
		set_pose("strike_" + attack_group, 0.35)
		pose_next = "after_" + attack_group

func _joint(name: String) -> Node3D:
	# Die Unterarme werden über die Ellbogen-Knoten der Arme gesteuert
	if name == "UnterarmLinks":
		return right_arm.get_node("Elbow")
	if name == "UnterarmRechts":
		return left_arm.get_node("Elbow")
	return rig[name]

func _drive(node: Node3D, target_deg: Vector3, tempo: float, delta: float) -> void:
	var target := Vector3(deg_to_rad(target_deg.x), deg_to_rad(target_deg.y), deg_to_rad(target_deg.z))
	var velocity: Vector3 = joint_velocity.get(node, Vector3.ZERO)
	var error := target - node.rotation
	velocity += (error * tempo * tempo - velocity * 1.5 * tempo) * delta
	velocity = velocity.limit_length(25.0)
	node.rotation += velocity * delta
	joint_velocity[node] = velocity

# Wie in "Claude 1" (dort im festen Physik-Takt): Die Federn werden in kleinen,
# gleich grossen Schritten gerechnet. Sonst schaukeln sie sich bei wenig Bildern
# pro Sekunde auf und die Figur verdreht sich.
const RIG_STEP := 1.0 / 120.0
var rig_accumulator := 0.0

func _animate_rig(delta: float) -> void:
	rig_accumulator = minf(rig_accumulator + delta, 0.1)
	while rig_accumulator >= RIG_STEP:
		rig_accumulator -= RIG_STEP
		_animate_rig_step(RIG_STEP)
	_update_eyes(delta)

func _animate_rig_step(delta: float) -> void:
	if pose_until > 0.0 and time > pose_until and not dead:
		if pose_next != "":
			pose_name = pose_next
			pose_next = ""
			pose_until = time + 0.9
		else:
			pose_name = "rooted" if rooted else "idle"
			pose_until = -1.0
	var p: Dictionary = POSES.get(pose_name, POSES["idle"])
	var tempo: float = p["tempo"]
	var breath := sin(time * 2.2)
	# Im Stand pendeln Arme und Oberkörper leicht, Gewicht wandert von Bein zu Bein
	var idle := 1.0 if pose_name == "idle" or pose_name.begins_with("after") else 0.0
	var sway := sin(time * 1.1)
	var swing := sin(time * 1.7)
	# Hüfte heben/senken
	var hip: Node3D = rig["Huefte"]
	var rest_pos: Vector3 = hip.get_meta("rest_pos")
	var hip_y: float = p["H"] + breath * (0.02 if idle > 0.0 else 0.008)
	hip.position.y = lerpf(hip.position.y, hip_y, 1.0 - exp(-tempo * delta))
	hip.position.x = rest_pos.x + sway * 0.05 * idle
	hip.position.z = rest_pos.z
	# Im Memory steht er hinter den Karten: nicht so weit nach vorne kippen wie in "Claude 1"
	var hip_rot: Vector3 = p["huefte"]
	if pose_name != "rooted" and pose_name != "dead":
		hip_rot.x = minf(hip_rot.x, 8.0)
	# Gewicht wandert im Stand von Bein zu Bein
	hip_rot += Vector3(0, sway * 4.0, -sway * 3.0) * idle
	_drive(hip, hip_rot, tempo, delta)
	var torso_pose: Vector3 = p["torso"]
	if pose_name != "rooted" and pose_name != "dead":
		torso_pose.x = minf(torso_pose.x, 28.0)
	var torso: Vector3 = torso_pose + Vector3(breath * (5.0 if idle > 0.0 else 2.5), sway * 9.0 * idle, sin(time * 0.8) * 5.0 * idle)
	_drive(rig["Bauch"], torso * 0.45, tempo, delta)
	_drive(rig["Rumpf"], torso * 0.55, tempo, delta)
	# Kopf: schaut zur Kamera, knarrt in kleinen Rucken
	creak_timer -= delta
	if creak_timer <= 0.0:
		creak_timer = randf_range(0.6, 1.6)
		creak_target = Vector3(randf_range(-4, 4), randf_range(-10, 10), randf_range(-3, 3))
	# Der Kopf dreht gegen den Oberkörper, damit der Boss den Spieler im Blick behält
	var look_back := Vector3(0, -torso.y * 0.7, -torso.z * 0.7)
	_drive(rig["KopfGelenk"], p["kopf"] + creak_target + look_back, tempo * 1.2, delta)
	var jaw: float = p["jaw"] + (sin(time * 9.0) * 4.0 if raging else 0.0)
	_drive(rig["Kiefer"], Vector3(jaw, 0, 0), 12.0, delta)
	_drive(rig["Mantel"], Vector3(sin(time * 1.3) * 3.0 + torso.x * 0.15, 0, 0), 6.0, delta)
	# Arme: Oberarme und Unterarme mit Feder, die Arme schwingen leicht nach
	var arm_l: Vector3 = p["AL"] + Vector3(swing * 15.0 - breath * 3.0, 0, -6.0 + sin(time * 1.3) * 8.0) * idle
	var arm_r: Vector3 = p["AR"] + Vector3(-swing * 15.0 - breath * 3.0, 0, 6.0 - sin(time * 1.45 + 1.0) * 8.0) * idle
	# Seitwärts (Y/Z) ist bei diesem Modell gespiegelt, sonst kreuzen die Arme vor dem Körper
	arm_l = Vector3(arm_l.x, -arm_l.y, -arm_l.z)
	arm_r = Vector3(arm_r.x, -arm_r.y, -arm_r.z)
	_drive(rig["ArmLinks"], arm_l, tempo, delta)
	_drive(rig["ArmRechts"], arm_r, tempo, delta)
	_drive(_joint("UnterarmLinks"), Vector3(p["UL"] + sin(time * 1.9) * 14.0 * idle, 0, 0), tempo, delta)
	_drive(_joint("UnterarmRechts"), Vector3(p["UR"] + sin(time * 1.8 + 2.0) * 14.0 * idle, 0, 0), tempo, delta)
	# Beine: Knie beugen sich, wenn die Hüfte tiefer geht, damit die Füsse am Boden bleiben
	var legs: Array = p.get("legs", [])
	if legs.is_empty():
		var drop := clampf(-0.44 - hip.position.y, 0.0, 0.6)
		var bend := rad_to_deg(acos(clampf((0.69 - drop) / 0.69, -1.0, 1.0)))
		legs = [-bend, bend * 2.0, -bend, bend * 2.0]
	_drive(rig["BeinLinks"], Vector3(legs[0], 0, -2), tempo, delta)
	_drive(rig["UnterschenkelLinks"], Vector3(legs[1], 0, 0), tempo, delta)
	_drive(rig["BeinRechts"], Vector3(legs[2], 0, 2), tempo, delta)
	_drive(rig["UnterschenkelRechts"], Vector3(legs[3], 0, 0), tempo, delta)
	_drive(rig["FussLinks"], Vector3(-(legs[0] + legs[1]), 0, 0), tempo, delta)
	_drive(rig["FussRechts"], Vector3(-(legs[2] + legs[3]), 0, 0), tempo, delta)
	# Leuchtendes Herz
	var glow := 6.0 + sin(time * 5.0) * 2.0 if rooted else 0.6
	if core_light != null:
		core_light.light_energy = lerpf(core_light.light_energy, glow, minf(delta * 4.0, 1.0))
		if core_material != null:
			core_material.emission_energy_multiplier = 2.0 + core_light.light_energy * 0.8

var _eyes_config: Dictionary = {}
var eye_mat: StandardMaterial3D
var eye_glow_light: OmniLight3D

# Zwei kleine leuchtende Augen und ein Augenlicht am Kopfgelenk (Werte aus der
# Gegner-Szene in "Claude 1": Abstand x, Höhe y, vorne z, Grösse r, Farbe)
func _build_eyes() -> void:
	if _eyes_config.is_empty():
		return
	var color := Color(str(_eyes_config.get("color", "#ffb54d")))
	eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = color
	eye_mat.emission_enabled = true
	eye_mat.emission = color
	eye_mat.emission_energy_multiplier = 2.0
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var radius := float(_eyes_config.get("r", 0.02))
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var neck: Node3D = rig["KopfGelenk"]
	for side in [1, -1]:
		var eye := MeshInstance3D.new()
		eye.mesh = mesh
		eye.material_override = eye_mat
		eye.position = Vector3(float(_eyes_config.get("x", 0.08)) * side, float(_eyes_config.get("y", 0.2)), float(_eyes_config.get("z", 0.1)))
		neck.add_child(eye)
	eye_glow_light = OmniLight3D.new()
	eye_glow_light.light_color = color
	eye_glow_light.light_energy = 0.3
	eye_glow_light.omni_range = 4.0
	eye_glow_light.position = Vector3(0, 0.05, 1.6)
	neck.add_child(eye_glow_light)

# Die Augen leuchten auf, kurz bevor er zuschlägt (wie in "Claude 1")
func _update_eyes(delta: float) -> void:
	if eye_mat == null:
		return
	var target := 2.0
	if pose_name.begins_with("windup") or pose_name == "roar":
		target = 7.0 + sin(time * 14.0) * 1.5
	elif pose_name == "dead":
		target = 0.0
	eye_mat.emission_energy_multiplier = lerpf(eye_mat.emission_energy_multiplier, target, minf(delta * 6.0, 1.0))
	eye_glow_light.light_energy = eye_mat.emission_energy_multiplier * 0.4

func set_rooted(on: bool) -> void:
	rooted = on
	if skeleton != null:
		set_pose("rooted" if on else "idle")
# Hängende Stoffstreifen im Kreis: bewegen sich später im Wind.
func _cloak(material: Material, radius_top: float, radius_bottom: float, top_y: float, count: int, length_min: float, length_max: float, width: float) -> void:
	for i in range(count):
		var angle := TAU * i / count + randf_range(-0.05, 0.05)
		var length := randf_range(length_min, length_max)
		var pivot := Node3D.new()
		pivot.position = Vector3(cos(angle) * radius_top, top_y, sin(angle) * radius_top)
		pivot.rotation.y = -angle + PI / 2.0
		boss_body.add_child(pivot)
		var flare := atan2(radius_bottom - radius_top, top_y)
		pivot.rotation.x = 0.0
		var hang := Node3D.new()
		hang.rotation.x = -flare
		pivot.add_child(hang)
		var strip := BoxMesh.new()
		strip.size = Vector3(width * randf_range(0.8, 1.3), length, 0.04)
		_part(strip, material, hang, Vector3(0, -length / 2.0, 0), Vector3(0, 0, randf_range(-4, 4)))
		hang.set_meta("base", hang.rotation)
		hang.set_meta("phase", randf() * TAU)
		cloth_strips.append(hang)

func _build_arm(side: int, upper_mat: Material, fore_mat: Material, hand_mat: Material, shoulder_pos: Vector3, claws: bool, finger_length: float = 0.55) -> Node3D:
	var shoulder := Node3D.new()
	shoulder.position = Vector3(side * shoulder_pos.x, shoulder_pos.y, shoulder_pos.z)
	boss_body.add_child(shoulder)
	_part(_smooth_sphere(0.3), upper_mat, shoulder, Vector3.ZERO)
	_part(_capsule(0.21, 1.95), upper_mat, shoulder, Vector3(0, -0.9, 0))
	var elbow := Node3D.new()
	elbow.name = "Elbow"
	elbow.position = Vector3(0, -1.8, 0)
	shoulder.add_child(elbow)
	_part(_smooth_sphere(0.19), fore_mat, elbow, Vector3.ZERO)
	_part(_capsule(0.15, 1.75), fore_mat, elbow, Vector3(0, -0.82, 0), Vector3.ZERO, Vector3(1, 1, 0.85))
	var hand := Node3D.new()
	hand.name = "Hand"
	hand.position = Vector3(0, -1.72, 0)
	elbow.add_child(hand)
	_part(_smooth_sphere(0.17), hand_mat, hand, Vector3.ZERO, Vector3.ZERO, Vector3(1.1, 0.8, 0.6))
	# Finger aus je drei Gliedern, leicht gekrümmt
	for f in range(4):
		var knuckle := Node3D.new()
		knuckle.position = Vector3((f - 1.5) * 0.085, -0.1, 0.05)
		knuckle.rotation_degrees = Vector3(-12, 0, (f - 1.5) * 7)
		hand.add_child(knuckle)
		var segment_parent := knuckle
		var seg_len := finger_length / 3.0
		for s in range(3):
			_part(_capsule(0.035 - s * 0.007, seg_len), hand_mat, segment_parent, Vector3(0, -seg_len / 2.0, 0))
			var joint := Node3D.new()
			joint.position = Vector3(0, -seg_len, 0)
			joint.rotation_degrees.x = -14
			segment_parent.add_child(joint)
			segment_parent = joint
		if claws:
			_part(_cone(0.03, 0.32, 0.0, 6), hand_mat, segment_parent, Vector3(0, -0.14, 0), Vector3(180, 0, 0))
	shoulder.rotation_degrees = Vector3(-25, 0, side * 22)
	elbow.rotation_degrees = Vector3(-35, 0, 0)
	shoulder.set_meta("rest", shoulder.rotation_degrees)
	elbow.set_meta("rest", elbow.rotation_degrees)
	return shoulder

func _empty_arm(side: int) -> Node3D:
	var shoulder := Node3D.new()
	shoulder.position = Vector3(side * 1.25, 4.6, 0.1)
	boss_body.add_child(shoulder)
	var elbow := Node3D.new()
	elbow.name = "Elbow"
	elbow.position = Vector3(0, -1.8, 0)
	shoulder.add_child(elbow)
	shoulder.set_meta("rest", shoulder.rotation_degrees)
	elbow.set_meta("rest", elbow.rotation_degrees)
	return shoulder

func _attach_to_hand(arm: Node3D, node: Node3D) -> void:
	var hand: Node3D = arm.get_node("Elbow/Hand")
	hand.add_child(node)

# Endboss: uralter Waldgeist. Hirschschädel mit grossem Geweih, gekrümmter Körper
# aus knorrigem Holz und Wurzeln, moosgrüner zerfetzter Umhang, glühender Kern in
# der Brust, lange Krallenarme, krumme Beine und ein hoher, gedrehter Stab.
func _build_oubli() -> void:
	var bark := _rich(Color(0.1, 0.09, 0.07), Color(0.42, 0.38, 0.32), 0.95, 0.35, 0.0, true)
	var bark_dark := _rich(Color(0.08, 0.07, 0.05), Color(0.32, 0.28, 0.22), 0.95, 0.4, 0.0, true)
	var moss := _rich(Color(0.05, 0.09, 0.04), Color(0.22, 0.34, 0.15), 0.95, 0.12)
	var moss_light := _rich(Color(0.12, 0.2, 0.08), Color(0.38, 0.5, 0.24), 0.9, 0.3)
	var bone := _rich(Color(0.45, 0.42, 0.37), Color(0.82, 0.8, 0.74), 0.6, 0.22, 0.0, true)
	var wood := _rich(Color(0.05, 0.04, 0.03), Color(0.2, 0.15, 0.1), 0.85, 0.3)
	var core_mat := _mat(Color(1.0, 0.9, 0.45), Color(1.0, 0.82, 0.3), 6.0)
	core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# Gekrümmte Haltung: Oberkörper nach vorne gebeugt
	var torso := Node3D.new()
	torso.position = Vector3(0, 2.5, 0)
	torso.rotation_degrees.x = 16
	boss_body.add_child(torso)

	# Beine: Oberschenkel nach vorne, Schienbein zurück, Krallenfuss
	for side in [-1, 1]:
		var hip := Node3D.new()
		hip.position = Vector3(side * 0.55, 2.4, 0.1)
		hip.rotation_degrees = Vector3(-35, 0, side * 6)
		boss_body.add_child(hip)
		_part(_capsule(0.28, 1.6), bark, hip, Vector3(0, -0.7, 0))
		_part(_smooth_sphere(0.26), bark_dark, hip, Vector3(0, -1.4, 0))
		var knee := Node3D.new()
		knee.position = Vector3(0, -1.45, 0)
		knee.rotation_degrees.x = 70
		hip.add_child(knee)
		_part(_capsule(0.2, 1.5), bark, knee, Vector3(0, -0.7, 0))
		var foot := Node3D.new()
		foot.position = Vector3(0, -1.4, 0)
		foot.rotation_degrees.x = -35
		knee.add_child(foot)
		for toe in range(3):
			_part(_cone(0.07, 0.6, 0.0, 6), bone, foot, Vector3((toe - 1) * 0.12, 0, 0.25), Vector3(95, (toe - 1) * 18, 0))
		# Wurzelstränge um das Bein
		for k in range(4):
			_part(_capsule(0.05, 1.3), bark_dark, hip, Vector3(cos(k * 1.6) * 0.24, -0.7, sin(k * 1.6) * 0.24), Vector3(randf_range(-12, 12), 0, randf_range(-12, 12)))

	# Rumpf aus verdrehten Holzsträngen
	_part(_capsule(0.62, 2.4), bark, torso, Vector3(0, 1.0, 0), Vector3.ZERO, Vector3(1.25, 1, 0.85))
	for k in range(9):
		var a := TAU * k / 9.0
		var strand := Node3D.new()
		strand.position = Vector3(cos(a) * 0.62, 1.0, sin(a) * 0.48)
		strand.rotation = Vector3(sin(a) * 0.35, a, cos(a) * 0.35)
		torso.add_child(strand)
		_part(_capsule(0.09, 2.3), bark_dark, strand, Vector3.ZERO)
	# Brustkorb aus Wurzeln, dahinter der glühende Kern
	for r in range(5):
		var rib := TorusMesh.new()
		rib.inner_radius = 0.46 - r * 0.03
		rib.outer_radius = 0.56 - r * 0.03
		rib.rings = 32
		rib.ring_segments = 10
		_part(rib, bark_dark, torso, Vector3(0, 1.85 - r * 0.24, 0.32), Vector3(90, 0, 0), Vector3(1.15, 1, 0.6))
	_part(_capsule(0.08, 1.4), bark, torso, Vector3(0, 1.4, 0.68), Vector3(4, 0, 0))
	_part(_smooth_sphere(0.24), core_mat, torso, Vector3(0, 1.35, 0.45))
	var core_light := OmniLight3D.new()
	core_light.position = Vector3(0, 1.35, 0.9)
	core_light.light_color = Color(1.0, 0.82, 0.35)
	core_light.light_energy = 1.6
	core_light.omni_range = 3.0
	torso.add_child(core_light)
	# Schultern als knorrige Knollen mit Moos
	for side in [-1, 1]:
		_part(_smooth_sphere(0.36), bark, torso, Vector3(side * 0.9, 2.15, 0), Vector3(0, 0, side * 20), Vector3(1.3, 0.75, 0.9))
		_part(_smooth_sphere(0.22), bark_dark, torso, Vector3(side * 0.7, 2.35, -0.12))
		_part(_smooth_sphere(0.16), bark_dark, torso, Vector3(side * 1.1, 2.0, 0.15))
		for k in range(10):
			var tuft := Node3D.new()
			tuft.position = Vector3(side * randf_range(0.6, 1.25), 2.55, randf_range(-0.4, 0.3))
			tuft.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
			torso.add_child(tuft)
			_part(_cone(0.09, randf_range(0.2, 0.45), 0.0, 5), moss_light, tuft, Vector3(0, 0.1, 0))
	# Halskette aus Zähnen
	for k in range(11):
		var a := PI * 0.15 + PI * 0.7 * k / 10.0
		var tooth := Node3D.new()
		tooth.position = Vector3(cos(a) * 0.55, 2.35 - sin(a) * 0.12, sin(a) * 0.5 + 0.05)
		tooth.rotation = Vector3(PI, -a + PI / 2.0, 0)
		torso.add_child(tooth)
		_part(_cone(0.04, 0.22, 0.0, 6), bone, tooth, Vector3(0, 0.1, 0))

	# Moosgrüner, zerfetzter Umhang: hinten und an den Seiten, vorne offen
	_cloak_arc(moss, 0.95, 1.9, 4.75, 40, 3.2, 4.6, 0.36, deg_to_rad(40), deg_to_rad(320))
	_cloak_arc(moss_light, 1.05, 1.6, 4.6, 18, 1.6, 2.6, 0.3, deg_to_rad(55), deg_to_rad(305))

	# Kopf: langer Hirschschädel, nach vorne geneigt
	head.position = Vector3(0, 5.05, 0.75)
	head.rotation_degrees.x = 18
	_part(_smooth_sphere(0.34), bone, head, Vector3(0, 0.08, -0.05), Vector3.ZERO, Vector3(1.0, 0.95, 1.05))
	var snout := Node3D.new()
	snout.position = Vector3(0, -0.02, 0.22)
	snout.rotation_degrees.x = 104
	head.add_child(snout)
	_part(_cone(0.2, 1.25, 0.07, 16), bone, snout, Vector3(0, 0.55, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.75))
	_part(_smooth_sphere(0.08), bone, snout, Vector3(0, 1.17, 0), Vector3.ZERO, Vector3(1.0, 0.7, 0.8))
	_part(_cone(0.13, 1.0, 0.05, 12), bone, snout, Vector3(0, 0.48, -0.13), Vector3(-6, 0, 0), Vector3(0.9, 1.0, 0.6))
	for k in range(6):
		_part(_cone(0.025, 0.1, 0.0, 5), bone, snout, Vector3((k % 2 - 0.5) * 0.18, 0.25 + k * 0.1, -0.14), Vector3(-90, 0, 0))
	var socket := _mat(Color(0.01, 0.0, 0.0))
	for side in [-1, 1]:
		_part(_smooth_sphere(0.1), socket, head, Vector3(side * 0.2, 0.1, 0.18), Vector3.ZERO, Vector3(1.0, 1.1, 0.7))
		_part(_smooth_sphere(0.035), eye_material, head, Vector3(side * 0.2, 0.1, 0.24))
		_part(_smooth_sphere(0.09), bone, head, Vector3(side * 0.3, -0.05, 0.08), Vector3.ZERO, Vector3(0.8, 0.6, 1.2))
	# Grosses, verzweigtes Geweih
	for side in [-1, 1]:
		var antler := Node3D.new()
		antler.position = Vector3(side * 0.22, 0.32, -0.1)
		antler.rotation_degrees = Vector3(-30, side * 10, side * -22)
		head.add_child(antler)
		_antler_branch(antler, bone, 2.3, 0.08, 3, side)
	halo = null

	# Arme: lang, knorrig, mit Krallen
	left_arm = _build_arm(-1, bark, bark_dark, bone, Vector3(1.2, 4.55, 0.55), true, 0.95)
	right_arm = _build_arm(1, bark, bark_dark, bone, Vector3(1.2, 4.55, 0.55), true, 0.95)
	for arm in [left_arm, right_arm]:
		var elbow: Node3D = arm.get_node("Elbow")
		for k in range(5):
			_part(_smooth_sphere(randf_range(0.12, 0.2)), bark_dark, arm, Vector3(randf_range(-0.15, 0.15), -0.3 - k * 0.32, randf_range(-0.12, 0.12)))
			_part(_smooth_sphere(randf_range(0.09, 0.15)), bark, elbow, Vector3(randf_range(-0.12, 0.12), -0.25 - k * 0.3, randf_range(-0.1, 0.1)))
		for k in range(6):
			var shred := Node3D.new()
			shred.position = Vector3(randf_range(-0.2, 0.2), -0.4 - k * 0.25, -0.15)
			arm.add_child(shred)
			var strip := BoxMesh.new()
			strip.size = Vector3(0.18, randf_range(0.6, 1.1), 0.03)
			_part(strip, moss, shred, Vector3(0, -0.4, 0), Vector3(randf_range(-10, 10), 0, randf_range(-15, 15)))
	# Hoher, gedrehter Stab mit Schnecke oben
	var staff := Node3D.new()
	staff.rotation_degrees = Vector3(-10, 0, 8)
	_part(_capsule(0.07, 6.2), wood, staff, Vector3(0, 1.2, 0))
	for k in range(10):
		_part(_capsule(0.03, 0.7), wood, staff, Vector3(cos(k * 1.3) * 0.07, -1.2 + k * 0.6, sin(k * 1.3) * 0.07), Vector3(25, k * 70, 0))
	var curl := Node3D.new()
	curl.position = Vector3(0, 4.3, 0)
	staff.add_child(curl)
	for k in range(14):
		var a := k * 0.45
		var r := 0.38 - k * 0.022
		_part(_smooth_sphere(0.06 - k * 0.002), wood, curl, Vector3(cos(a) * r, sin(a) * r, 0))
	_attach_to_hand(right_arm, staff)

# Geweih rekursiv: jeder Ast teilt sich in kleinere Äste.
func _antler_branch(parent: Node3D, material: Material, length: float, radius: float, depth: int, side: int) -> void:
	_part(_cone(radius, length, radius * 0.45, 8), material, parent, Vector3(0, length / 2.0, 0))
	if depth <= 0:
		return
	var forks := 2 if depth > 1 else 3
	for i in range(forks):
		var branch := Node3D.new()
		branch.position = Vector3(0, length * (0.45 + i * 0.25), 0)
		branch.rotation_degrees = Vector3(randf_range(-25, 15), randf_range(-30, 30), side * (-28 - i * 14) * (1 if i % 2 == 0 else -0.7))
		parent.add_child(branch)
		_antler_branch(branch, material, length * 0.55, radius * 0.6, depth - 1, side)

# Umhang nur über einen Winkelbereich (vorne offen).
func _cloak_arc(material: Material, radius_top: float, radius_bottom: float, top_y: float, count: int, length_min: float, length_max: float, width: float, from_angle: float, to_angle: float) -> void:
	for i in range(count):
		var angle := lerpf(from_angle, to_angle, float(i) / float(count - 1)) + PI / 2.0
		var length := randf_range(length_min, length_max)
		var pivot := Node3D.new()
		pivot.position = Vector3(cos(angle) * radius_top, top_y, sin(angle) * radius_top * 0.8)
		pivot.rotation.y = -angle + PI / 2.0
		boss_body.add_child(pivot)
		var hang := Node3D.new()
		hang.rotation.x = -atan2(radius_bottom - radius_top, top_y)
		pivot.add_child(hang)
		var strip := BoxMesh.new()
		strip.size = Vector3(width * randf_range(0.8, 1.4), length, 0.04)
		_part(strip, material, hang, Vector3(0, -length / 2.0, 0), Vector3(0, 0, randf_range(-5, 5)))
		# ausgefranste Enden
		_part(_cone(width * 0.35, 0.5, 0.0, 4), material, hang, Vector3(randf_range(-0.1, 0.1), -length - 0.2, 0), Vector3(180, 0, 0), Vector3(1, 1, 0.12))
		hang.set_meta("base", hang.rotation)
		hang.set_meta("phase", randf() * TAU)
		cloth_strips.append(hang)

# Zwischenboss 1: gepanzerter Wächter mit Zweihänder.
func _build_knight() -> void:
	var steel := _rich(Color(0.18, 0.19, 0.22), Color(0.55, 0.57, 0.6), 0.32, 0.22, 0.9)
	var dark_steel := _rich(Color(0.08, 0.08, 0.1), Color(0.3, 0.3, 0.33), 0.38, 0.22, 0.9)
	var tabard := _rich(Color(0.18, 0.02, 0.03), Color(0.45, 0.08, 0.08), 0.9, 0.08)
	var gold := _rich(Color(0.35, 0.24, 0.08), Color(0.8, 0.62, 0.28), 0.3, 0.2, 0.95)
	_part(_cone(1.0, 2.0, 0.8, 32), dark_steel, boss_body, Vector3(0, 1.6, 0))
	_part(_cone(0.85, 1.8, 1.05, 32), steel, boss_body, Vector3(0, 3.5, 0))
	_part(_smooth_sphere(0.95), steel, boss_body, Vector3(0, 4.55, 0), Vector3.ZERO, Vector3(1.4, 0.75, 0.9))
	var belt := TorusMesh.new()
	belt.inner_radius = 0.8
	belt.outer_radius = 0.95
	_part(belt, gold, boss_body, Vector3(0, 2.65, 0))
	_cloak(tabard, 0.7, 1.0, 2.6, 10, 1.8, 2.4, 0.38)
	_cloak(dark_steel, 0.95, 1.35, 2.7, 14, 1.2, 1.4, 0.45)
	for side in [-1, 1]:
		_part(_smooth_sphere(0.62), steel, boss_body, Vector3(side * 1.25, 4.85, 0), Vector3.ZERO, Vector3(1.1, 0.75, 1.0))
		_part(_smooth_sphere(0.45), gold, boss_body, Vector3(side * 1.25, 4.95, 0), Vector3.ZERO, Vector3(1.15, 0.45, 1.05))
	# Helm mit Sehschlitz und Federbusch
	_part(_cone(0.42, 0.95, 0.38, 32), steel, head, Vector3(0, 0.1, 0))
	_part(_smooth_sphere(0.4), steel, head, Vector3(0, 0.55, 0), Vector3.ZERO, Vector3(1, 0.6, 1))
	var slit := BoxMesh.new()
	slit.size = Vector3(0.5, 0.05, 0.05)
	_part(slit, eye_material, head, Vector3(0, 0.15, 0.4))
	for i in range(14):
		var plume := Node3D.new()
		plume.position = Vector3(0, 0.75, -0.05 - i * 0.04)
		plume.rotation_degrees = Vector3(-60 - i * 6, 0, randf_range(-6, 6))
		head.add_child(plume)
		_part(_cone(0.05, 1.2, 0.0, 5), tabard, plume, Vector3(0, 0.6, 0))
	left_arm = _build_arm(-1, steel, dark_steel, steel, Vector3(1.3, 4.65, 0.05), false, 0.45)
	right_arm = _build_arm(1, steel, dark_steel, steel, Vector3(1.3, 4.65, 0.05), false, 0.45)
	var sword := Node3D.new()
	sword.rotation_degrees = Vector3(90, 0, 0)
	var blade := BoxMesh.new()
	blade.size = Vector3(0.22, 3.6, 0.05)
	_part(blade, steel, sword, Vector3(0, 2.2, 0))
	var guard := BoxMesh.new()
	guard.size = Vector3(0.9, 0.1, 0.12)
	_part(guard, gold, sword, Vector3(0, 0.35, 0))
	_part(_capsule(0.05, 0.6), dark_steel, sword, Vector3(0, 0.05, 0))
	_attach_to_hand(right_arm, sword)

# Zwischenboss 2: Hexe mit Spitzhut, schwebenden Büchern und Stab.
func _build_witch() -> void:
	var robe := _rich(Color(0.07, 0.03, 0.1), Color(0.3, 0.14, 0.38), 0.9, 0.09)
	var skin := _rich(Color(0.45, 0.42, 0.4), Color(0.75, 0.72, 0.68), 0.6, 0.15)
	var hair := _rich(Color(0.12, 0.12, 0.13), Color(0.55, 0.55, 0.58), 0.85, 0.3)
	var wood := _rich(Color(0.12, 0.07, 0.04), Color(0.35, 0.22, 0.12), 0.8, 0.2)
	var paper := _rich(Color(0.55, 0.48, 0.35), Color(0.85, 0.8, 0.65), 0.9, 0.3)
	_part(_cone(1.0, 3.6, 0.5, 32), robe, boss_body, Vector3(0, 2.9, 0))
	_cloak(robe, 0.6, 2.0, 4.5, 40, 3.8, 4.8, 0.4)
	_part(_smooth_sphere(0.75), robe, boss_body, Vector3(0, 4.55, 0), Vector3.ZERO, Vector3(1.3, 0.9, 0.85))
	# Gesicht und Haare
	_part(_smooth_sphere(0.36), skin, head, Vector3(0, 0, 0.02), Vector3.ZERO, Vector3(0.85, 1.15, 0.9))
	_part(_cone(0.06, 0.28, 0.0, 6), skin, head, Vector3(0, -0.02, 0.36), Vector3(80, 0, 0))
	for side in [-1, 1]:
		_part(_smooth_sphere(0.05), eye_material, head, Vector3(side * 0.13, 0.08, 0.3))
	for i in range(40):
		var strand := Node3D.new()
		var a := randf_range(-PI * 0.8, PI * 0.8)
		strand.position = Vector3(sin(a) * 0.32, 0.25, cos(a) * 0.25 - 0.12)
		strand.rotation = Vector3(PI + randf_range(-0.25, 0.1), a, 0)
		head.add_child(strand)
		_part(_cone(0.04, randf_range(1.2, 2.2), 0.0, 4), hair, strand, Vector3(0, 0.8, 0))
	# Spitzhut aus mehreren gekrümmten Teilen
	var brim := CylinderMesh.new()
	brim.top_radius = 0.95
	brim.bottom_radius = 1.0
	brim.height = 0.05
	brim.radial_segments = 32
	_part(brim, robe, head, Vector3(0, 0.38, 0))
	var tip := Node3D.new()
	tip.position = Vector3(0, 0.4, 0)
	head.add_child(tip)
	var radius := 0.45
	for k in range(5):
		_part(_cone(radius, 0.5, radius * 0.75, 24), robe, tip, Vector3(0, 0.25, 0))
		var next := Node3D.new()
		next.position = Vector3(0, 0.48, 0)
		next.rotation_degrees = Vector3(-8 - k * 5, 0, 0)
		tip.add_child(next)
		tip = next
		radius *= 0.75
	left_arm = _build_arm(-1, robe, robe, skin, Vector3(1.05, 4.7, 0.05), true, 0.55)
	right_arm = _build_arm(1, robe, robe, skin, Vector3(1.05, 4.7, 0.05), true, 0.55)
	var staff := Node3D.new()
	staff.rotation_degrees = Vector3(90, 0, 0)
	_part(_capsule(0.06, 4.2), wood, staff, Vector3(0, 0.4, 0))
	_part(_smooth_sphere(0.22), eye_material, staff, Vector3(0, 2.6, 0))
	_attach_to_hand(right_arm, staff)
	# Schwebende Bücher
	for i in range(6):
		var book := Node3D.new()
		book.set_meta("angle", TAU * i / 6.0)
		book.set_meta("height", 2.5 + (i % 3) * 1.1)
		boss_body.add_child(book)
		var cover := BoxMesh.new()
		cover.size = Vector3(0.5, 0.12, 0.38)
		_part(cover, wood, book, Vector3.ZERO)
		var pages := BoxMesh.new()
		pages.size = Vector3(0.46, 0.09, 0.34)
		_part(pages, paper, book, Vector3(0.02, 0, 0))
		orbiters.append(book)

# Zwischenboss 3: Rabenmann mit Federmantel, Schnabelmaske und Flügeln.
func _build_raven() -> void:
	var feathers := _rich(Color(0.02, 0.02, 0.03), Color(0.16, 0.17, 0.22), 0.55, 0.3, 0.2)
	var leather := _rich(Color(0.08, 0.06, 0.05), Color(0.28, 0.22, 0.17), 0.7, 0.15)
	var mask := _rich(Color(0.5, 0.45, 0.38), Color(0.88, 0.84, 0.75), 0.5, 0.2, 0.0, true)
	_part(_cone(1.0, 3.4, 0.55, 32), leather, boss_body, Vector3(0, 3.0, 0))
	# Federmantel aus vielen überlappenden Federn
	for row in range(6):
		var count := 26 - row * 2
		for i in range(count):
			var angle := TAU * i / count + row * 0.13
			var feather := Node3D.new()
			var radius := 0.75 + row * 0.22
			feather.position = Vector3(cos(angle) * radius, 4.8 - row * 0.75, sin(angle) * radius)
			feather.rotation = Vector3(0, -angle + PI / 2.0, 0)
			boss_body.add_child(feather)
			var tilt := Node3D.new()
			tilt.rotation.x = -0.25
			feather.add_child(tilt)
			var plate := BoxMesh.new()
			plate.size = Vector3(0.28, 1.3, 0.03)
			_part(plate, feathers, tilt, Vector3(0, -0.6, 0))
			tilt.set_meta("base", tilt.rotation)
			tilt.set_meta("phase", randf() * TAU)
			cloth_strips.append(tilt)
	_part(_smooth_sphere(0.85), feathers, boss_body, Vector3(0, 4.6, 0), Vector3.ZERO, Vector3(1.35, 0.85, 0.85))
	# Schnabelmaske
	_part(_smooth_sphere(0.38), mask, head, Vector3(0, 0.05, 0), Vector3.ZERO, Vector3(0.95, 1.05, 1.0))
	_part(_cone(0.2, 1.3, 0.0, 16), mask, head, Vector3(0, -0.12, 0.85), Vector3(78, 0, 0), Vector3(1, 1, 0.8))
	for side in [-1, 1]:
		var lens := TorusMesh.new()
		lens.inner_radius = 0.07
		lens.outer_radius = 0.1
		_part(lens, leather, head, Vector3(side * 0.15, 0.12, 0.33), Vector3(90, 0, 0))
		_part(_smooth_sphere(0.07), eye_material, head, Vector3(side * 0.15, 0.12, 0.33))
	_part(_cone(0.55, 0.9, 0.3, 24), leather, head, Vector3(0, 0.45, -0.05))
	var brim := CylinderMesh.new()
	brim.top_radius = 0.75
	brim.bottom_radius = 0.78
	brim.height = 0.04
	_part(brim, leather, head, Vector3(0, 0.12, -0.05))
	# Flügel aus langen Schwungfedern
	for side in [-1, 1]:
		var wing := Node3D.new()
		wing.position = Vector3(side * 0.6, 4.9, -0.5)
		wing.rotation_degrees = Vector3(0, side * -25, side * -20)
		boss_body.add_child(wing)
		for f in range(11):
			var quill := Node3D.new()
			quill.rotation_degrees = Vector3(0, 0, side * (-10 - f * 11))
			wing.add_child(quill)
			var long_feather := BoxMesh.new()
			long_feather.size = Vector3(0.32, 3.2 - abs(f - 4) * 0.18, 0.03)
			_part(long_feather, feathers, quill, Vector3(0, 1.5, 0))
		wing.set_meta("base", wing.rotation)
		wing.set_meta("phase", 0.0)
		cloth_strips.append(wing)
	left_arm = _build_arm(-1, leather, feathers, leather, Vector3(1.15, 4.7, 0.1), true, 0.6)
	right_arm = _build_arm(1, leather, feathers, leather, Vector3(1.15, 4.7, 0.1), true, 0.6)

# --- Laufende Animation ----------------------------------------------------------

func _process(delta: float) -> void:
	time += delta
	if boss_body == null or (dead and skeleton == null):
		return
	if skeleton != null:
		_animate_rig(delta)
	else:
		boss_body.position.y = sin(time * 1.3) * 0.18
		boss_body.rotation_degrees.y = sin(time * 0.5) * 4.0
		head.rotation_degrees.z = sin(time * 0.9) * 5.0
	if halo != null:
		halo.rotation_degrees.y = time * 25.0
	if not busy and skeleton == null:
		for arm in [left_arm, right_arm]:
			var rest: Vector3 = arm.get_meta("rest")
			arm.rotation_degrees = rest + Vector3(sin(time * 1.1 + arm.position.x) * 6.0, 0, 0)
	# Stoff, Federn und Flügel bewegen sich wie im Wind
	var wind := 2.2 if raging else 1.0
	for strip in cloth_strips:
		var base: Vector3 = strip.get_meta("base")
		var phase: float = strip.get_meta("phase")
		strip.rotation = base + Vector3(sin(time * 1.7 * wind + phase) * 0.08 * wind, 0, sin(time * 1.1 + phase) * 0.04)
	for book in orbiters:
		var angle: float = book.get_meta("angle") + time * 0.6
		book.position = Vector3(cos(angle) * 2.3, float(book.get_meta("height")) + sin(time * 2.0 + angle) * 0.25, sin(angle) * 1.4)
		book.rotation = Vector3(sin(time + angle) * 0.4, -angle, 0.3)
	var pulse := 1.0 + sin(time * (7.0 if raging else 3.0)) * 0.35
	eye_light.light_energy = (3.5 if raging else 2.0) * pulse
	for light in candles:
		light.light_energy = (2.6 if light.omni_range > 6.0 else 1.2) + randf() * 0.5
	if armor_ring != null:
		armor_ring.rotation.y = time * 1.5
	for bell in orbiters_scene:
		bell.rotation.z = sin(time * 0.7 + float(bell.get_meta("swing"))) * 0.09
	_update_rig()

func set_rage(on: bool) -> void:
	raging = on
	if on and skeleton != null:
		set_pose("roar", 1.8)
	aura.amount = 90 if on else 30
	aura.scale_amount_max = 2.0 if on else 1.3
	if moon_material == null:
		return
	var tween := create_tween()
	tween.tween_property(moon_material, "emission", Color(1.0, 0.15, 0.1) if on else Color(1.0, 0.45, 0.3), 1.5)
	tween.parallel().tween_property(moon_material, "albedo_color", Color(0.9, 0.2, 0.15) if on else Color(0.95, 0.6, 0.45), 1.5)

func chest_position() -> Vector3:
	if chest_node != null:
		return chest_node.global_position
	return boss_body.to_global(Vector3(0, 4.3, 0.6))

func hand_position(side: int) -> Vector3:
	var arm := right_arm if side > 0 else left_arm
	var elbow: Node3D = arm.get_node("Elbow")
	return elbow.to_global(hand_offset)

func _arm_pose(arm: Node3D, shoulder_rot: Vector3, elbow_rot: Vector3, duration: float) -> Tween:
	if skeleton != null:
		return null
	var elbow: Node3D = arm.get_node("Elbow")
	var tween := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(arm, "rotation_degrees", shoulder_rot, duration)
	tween.tween_property(elbow, "rotation_degrees", elbow_rot, duration)
	return tween

func _arms_rest(duration: float = 0.5) -> void:
	for arm in [left_arm, right_arm]:
		var elbow: Node3D = arm.get_node("Elbow")
		_arm_pose(arm, arm.get_meta("rest"), elbow.get_meta("rest"), duration)
	await get_tree().create_timer(duration).timeout
	busy = false

# Ausholen, je nach Angriff anders.
func windup(kind: String) -> void:
	busy = true
	attack_group = _group_for(kind)
	if skeleton != null:
		set_pose("rooted" if kind == "root_self" else "windup_" + attack_group)
	match kind:
		"slash":
			_arm_pose(right_arm, Vector3(-160, 0, 40), Vector3(-20, 0, 0), 0.8)
		"slam":
			_arm_pose(left_arm, Vector3(-170, 0, -15), Vector3(-30, 0, 0), 0.8)
			_arm_pose(right_arm, Vector3(-170, 0, 15), Vector3(-30, 0, 0), 0.8)
		"curse":
			_arm_pose(left_arm, Vector3(-80, 0, -40), Vector3(-60, 0, 0), 0.8)
		"roots":
			_arm_pose(right_arm, Vector3(-150, 0, 15), Vector3(-10, 0, 0), 0.9)
		"herd":
			_arm_pose(left_arm, Vector3(-85, 0, -12), Vector3(-5, 0, 0), 0.8)
		"spores":
			_arm_pose(left_arm, Vector3(-40, 0, -75), Vector3(-30, 0, 0), 0.9)
			_arm_pose(right_arm, Vector3(-40, 0, 75), Vector3(-30, 0, 0), 0.9)
		"stomp":
			_arm_pose(left_arm, Vector3(-165, 0, -20), Vector3(-25, 0, 0), 0.8)
			_arm_pose(right_arm, Vector3(-165, 0, 20), Vector3(-25, 0, 0), 0.8)
		"root_self":
			_arm_pose(left_arm, Vector3(-15, 0, -50), Vector3(-10, 0, 0), 0.9)
			_arm_pose(right_arm, Vector3(-15, 0, 50), Vector3(-10, 0, 0), 0.9)
		"bell", "bells", "toll":
			_arm_pose(left_arm, Vector3(-165, 0, -10), Vector3(-30, 0, 0), 1.0)
			_arm_pose(right_arm, Vector3(-120, 0, 25), Vector3(-40, 0, 0), 1.0)
		"blades":
			_arm_pose(left_arm, Vector3(-120, 0, -45), Vector3(-60, 0, 0), 0.6)
		"reap":
			_arm_pose(left_arm, Vector3(-150, 0, -50), Vector3(-15, 0, 0), 0.7)
		"ash":
			_arm_pose(left_arm, Vector3(-30, 0, -80), Vector3(-20, 0, 0), 0.8)
			_arm_pose(right_arm, Vector3(-30, 0, 80), Vector3(-20, 0, 0), 0.8)
		"bone_spikes", "skulls":
			_arm_pose(left_arm, Vector3(-160, 0, -20), Vector3(-20, 0, 0), 0.9)
			_arm_pose(right_arm, Vector3(-160, 0, 20), Vector3(-20, 0, 0), 0.9)
		"bone_armor":
			_arm_pose(left_arm, Vector3(-70, 0, 10), Vector3(-100, 0, 0), 0.9)
			_arm_pose(right_arm, Vector3(-70, 0, -10), Vector3(-100, 0, 0), 0.9)
		_:
			_arm_pose(left_arm, Vector3(-95, 0, -10), Vector3(-30, 0, 0), 0.8)
			_arm_pose(right_arm, Vector3(-95, 0, 10), Vector3(-30, 0, 0), 0.8)
	var tween := create_tween()
	tween.tween_property(boss_body, "rotation_degrees:x", -8.0, 0.8)

func stagger() -> void:
	busy = true
	if skeleton != null:
		set_pose("hurt", 0.8)
	_flash(Color(1, 0.95, 0.85), 2.0)
	var tween := create_tween()
	tween.tween_property(boss_body, "rotation_degrees:x", 18.0, 0.15)
	tween.tween_property(boss_body, "rotation_degrees:x", 0.0, 0.6).set_trans(Tween.TRANS_ELASTIC)
	_arm_pose(left_arm, Vector3(20, 0, -50), Vector3(-10, 0, 0), 0.2)
	_arm_pose(right_arm, Vector3(20, 0, 50), Vector3(-10, 0, 0), 0.2)
	await get_tree().create_timer(0.5).timeout
	_arms_rest()

func hurt() -> void:
	if skeleton != null and rig.has("Rumpf"):
		# Treffer: der Oberkörper wird kurz zurückgestossen
		var torso: Node3D = rig["Rumpf"]
		joint_velocity[torso] = joint_velocity.get(torso, Vector3.ZERO) + Vector3(-4.0, randf_range(-1.5, 1.5), 0)
	_flash(Color(1, 0.75, 0.6), 1.2)
	var tween := create_tween()
	tween.tween_property(boss_body, "rotation_degrees:x", 7.0, 0.08)
	tween.tween_property(boss_body, "rotation_degrees:x", 0.0, 0.35)

var flash_tween: Tween

# Kurzes Aufleuchten. Danach immer zurück zur Grundfarbe (auch bei vielen Treffern).
func _flash(color: Color, energy: float) -> void:
	if flash_tween != null and flash_tween.is_valid():
		flash_tween.kill()
	flash_tween = create_tween().set_parallel(true)
	for m in flash_materials:
		if not m.has_meta("base_emission"):
			m.set_meta("base_emission", m.emission)
			m.set_meta("base_energy", m.emission_energy_multiplier)
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		flash_tween.tween_property(m, "emission", m.get_meta("base_emission"), 0.3)
		flash_tween.tween_property(m, "emission_energy_multiplier", m.get_meta("base_energy"), 0.3)

# Schadenszahl als 3D-Text über dem Boss.
func damage_number(text: String, color: Color, at: Vector3 = Vector3.INF) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 96
	label.outline_size = 18
	label.modulate = color
	label.outline_modulate = Color.BLACK
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position = chest_position() + Vector3(randf_range(-0.8, 0.8), 1.2, 0.5) if at == Vector3.INF else at
	add_child(label)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 1.6, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.35)
	tween.chain().tween_callback(label.queue_free)

# Lichtkugel von den gefundenen Karten zum Boss.
func fire_beam(from: Vector3) -> void:
	var orb := _glow_orb(Color(1, 0.85, 0.4), 0.18)
	orb.position = from + Vector3(0, 0.3, 0)
	add_child(orb)
	var to := chest_position()
	var mid := (orb.position + to) / 2.0 + Vector3(0, 2.5, 0)
	var start := orb.position
	var tween := orb.create_tween()
	tween.tween_method(func(t: float): orb.position = _bezier(start, mid, to, t), 0.0, 1.0, 0.45)
	tween.tween_callback(func():
		_burst(to, Color(1, 0.8, 0.4))
		orb.queue_free()
		hurt()
	)

func _glow_orb(color: Color, radius: float) -> MeshInstance3D:
	var m := _mat(color, color, 8.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var orb := MeshInstance3D.new()
	orb.mesh = _sphere(radius)
	orb.material_override = m
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 3.0
	light.omni_range = 2.5
	orb.add_child(light)
	return orb

func _bezier(a: Vector3, b: Vector3, c: Vector3, t: float) -> Vector3:
	return a.lerp(b, t).lerp(b.lerp(c, t), t)

func _burst(at: Vector3, color: Color) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 40
	p.lifetime = 0.7
	p.explosiveness = 1.0
	p.position = at
	p.direction = Vector3(0, 1, 0)
	p.spread = 180
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	p.gravity = Vector3(0, -6, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	var m := _mat(color, color, 5.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = m
	p.mesh = quad
	add_child(p)
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)

# --- Fähigkeiten der Zwischenbosse ---------------------------------------------

# Le Sonneur: eine Glocke fällt von oben auf eine Karte.
func bell_drop(target: Vector3) -> void:
	var bell := _part(load(HAIN + "models/gloeckner/fallglocke.obj"), _bronze(), self, target + Vector3(0, 9, 0), Vector3.ZERO, Vector3.ONE * 0.75)
	var tween := bell.create_tween()
	tween.tween_property(bell, "position", target + Vector3(0, -0.2, 0), 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	shake(0.55, 0.4)
	_burst(target + Vector3(0, 0.2, 0), Color(0.9, 0.75, 0.5))
	var ring := tween
	ring = bell.create_tween()
	ring.tween_interval(0.35)
	ring.tween_property(bell, "position", target + Vector3(0, 9, 0), 0.6).set_trans(Tween.TRANS_QUAD)
	ring.tween_callback(bell.queue_free)

# La Veuve: Sicheln fliegen kreiselnd auf Karten.
func throw_blade(target: Vector3) -> void:
	var blade := Node3D.new()
	add_child(blade)
	var steel := _bestie_material("metall")
	steel.vertex_color_use_as_albedo = false
	steel.albedo_color = Color(0.6, 0.62, 0.68)
	steel.emission = accent
	steel.emission_energy_multiplier = 0.6
	var shape := MeshInstance3D.new()
	shape.mesh = load(HAIN + "models/witwe/sichel_stahl.obj")
	shape.material_override = steel
	shape.position = Vector3(-0.7, 0, -1.1)
	shape.scale = Vector3.ONE * 0.7
	blade.add_child(shape)
	var start := hand_position(-1)
	blade.position = start
	var mid := (start + target) / 2.0 + Vector3(0, 2.0, 0)
	var tween := blade.create_tween()
	tween.tween_method(func(t: float):
		blade.position = _bezier(start, mid, target, t)
		blade.rotation.y = t * TAU * 3.0
	, 0.0, 1.0, 0.45)
	await tween.finished
	_burst(target, accent)
	shake(0.2, 0.15)
	blade.queue_free()

# La Veuve: verschwindet in Asche und taucht wieder auf.
func ash_vanish(on: bool) -> void:
	for i in range(4):
		_burst(chest_position() + Vector3(randf_range(-1.2, 1.2), randf_range(-2.5, 1.5), 0.4), Color(0.55, 0.55, 0.6))
	if boss_body != null:
		var tween := create_tween()
		tween.tween_property(boss_body, "scale", Vector3.ONE * (0.02 if on else 1.0), 0.35)
		if not on:
			boss_body.scale = Vector3.ONE * 0.02

# Le Prince des Os: Schädel fallen vom Himmel.
func skull_drop(target: Vector3) -> void:
	var bone := _bestie_material("knochen")
	bone.vertex_color_use_as_albedo = false
	bone.albedo_color = Color(0.8, 0.78, 0.68)
	var skull := _part(load(HAIN + "models/level3/schaedel.obj"), bone, self, target + Vector3(randf_range(-1, 1), 8, randf_range(-1, 1)), Vector3(randf() * 360, randf() * 360, 0), Vector3.ONE * 5.0)
	var tween := skull.create_tween()
	tween.tween_property(skull, "position", target + Vector3(0, 0.2, 0), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	_burst(target, Color(0.85, 0.82, 0.7))
	shake(0.2, 0.15)
	var gone := skull.create_tween()
	gone.tween_property(skull, "scale", Vector3.ONE * 0.1, 0.4)
	gone.tween_callback(skull.queue_free)

# Le Prince des Os: Knochenpanzer, Knochensplitter kreisen um ihn.
var armor_ring: Node3D
func bone_armor(on: bool) -> void:
	if on:
		armor_ring = Node3D.new()
		armor_ring.position = boss_pos + Vector3(0, 3.0, 0)
		add_child(armor_ring)
		var bone := _bestie_material("knochen")
		bone.vertex_color_use_as_albedo = false
		bone.albedo_color = Color(0.82, 0.8, 0.7)
		bone.emission = accent
		bone.emission_energy_multiplier = 0.5
		for i in range(16):
			var a := TAU * i / 16.0
			_part(_cone(0.12, 0.9, 0.0, 6), bone, armor_ring, Vector3(cos(a) * 2.4, sin(i * 1.7) * 1.2, sin(a) * 1.6), Vector3(randf() * 360, 0, randf() * 360))
		var light := OmniLight3D.new()
		light.light_color = accent
		light.light_energy = 2.0
		light.omni_range = 6
		armor_ring.add_child(light)
	elif armor_ring != null:
		armor_ring.queue_free()
		armor_ring = null

# --- Angriffe des Wurzelhirts ---------------------------------------------------

func _board_normal() -> Vector3:
	return Vector3.UP.rotated(Vector3.RIGHT, deg_to_rad(board_tilt))

# Wurzeln brechen unter den Karten aus der Platte.
func root_spikes(points: Array, bones: bool = false) -> void:
	_arm_pose(right_arm, Vector3(-35, 0, 10), Vector3(-5, 0, 0), 0.12)
	shake(0.35, 0.3)
	var root_mat: Material = _stone("schiefer", 0.9, Color(0.26, 0.2, 0.14), 0.4) if arena_kind != "gothic" else _mat(Color(0.2, 0.14, 0.1))
	if bones:
		var bone := _bestie_material("knochen")
		bone.vertex_color_use_as_albedo = false
		bone.albedo_color = Color(0.8, 0.78, 0.7)
		bone.emission = accent * 0.3
		bone.emission_energy_multiplier = 0.6
		root_mat = bone
	var up := _board_normal()
	var spikes: Array[Node3D] = []
	for p in points:
		for k in range(3):
			var spike := Node3D.new()
			add_child(spike)
			var offset := Vector3(randf_range(-0.35, 0.35), 0, randf_range(-0.35, 0.35)).rotated(Vector3.RIGHT, deg_to_rad(board_tilt))
			spike.position = p + offset - up * 1.2
			spike.rotation_degrees = Vector3(board_tilt + randf_range(-18, 18), 0, randf_range(-18, 18))
			_part(_cone(randf_range(0.12, 0.2), randf_range(1.2, 1.9), 0.0, 7), root_mat, spike, Vector3(0, 0.8, 0))
			var tween := spike.create_tween()
			tween.tween_property(spike, "position", spike.position + up * 1.3, 0.09).set_ease(Tween.EASE_OUT)
			tween.tween_interval(0.45)
			tween.tween_property(spike, "position", spike.position - up * 0.2, 0.3)
			spikes.append(spike)
		_burst(p + up * 0.2, Color(0.55, 0.45, 0.3))
	await get_tree().create_timer(0.2).timeout
	for s in spikes:
		get_tree().create_timer(0.7).timeout.connect(s.queue_free)

# Dornenknechte (aus "Claude 1") kriechen aus dem Boden und rennen zu den Karten.
func herd_run(targets: Array) -> void:
	var body_mesh: Mesh = load(HAIN + "models/hirt/knecht.obj")
	var eye_mesh: Mesh = load(HAIN + "models/hirt/knecht_augen.obj")
	var bark := _bestie_material("haut")
	var eyes := _mat(accent, accent, 6.0)
	eyes.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var longest := 0.0
	for i in range(targets.size()):
		var target: Vector3 = targets[i]
		var minion := Node3D.new()
		var start := Vector3(randf_range(-3.0, 3.0), boss_pos.y, boss_pos.z + 2.2)
		minion.position = start - Vector3(0, 1.0, 0)
		minion.scale = Vector3.ONE * 1.3
		add_child(minion)
		_part(body_mesh, bark, minion, Vector3.ZERO)
		_part(eye_mesh, eyes, minion, Vector3.ZERO)
		minion.look_at(Vector3(target.x, minion.position.y, target.z), Vector3.UP, true)
		var duration := randf_range(0.85, 1.15)
		longest = maxf(longest, duration)
		var tween := minion.create_tween()
		tween.tween_property(minion, "position", start, 0.25)
		tween.tween_method(func(t: float):
			minion.position = start.lerp(target, t) + Vector3(0, abs(sin(t * PI * 5.0)) * 0.35, 0)
		, 0.0, 1.0, duration)
		tween.tween_callback(func():
			_spore_burst(target)
			minion.queue_free()
		)
	await get_tree().create_timer(0.25 + longest).timeout
	shake(0.25, 0.2)

func _spore_burst(at: Vector3) -> void:
	_burst(at, Color(0.6, 0.85, 0.3))
	var cloud := CPUParticles3D.new()
	cloud.one_shot = true
	cloud.emitting = true
	cloud.amount = 30
	cloud.set_meta("wichtig", true)
	cloud.lifetime = 1.4
	cloud.explosiveness = 0.9
	cloud.position = at
	cloud.spread = 180
	cloud.initial_velocity_min = 0.5
	cloud.initial_velocity_max = 1.6
	cloud.gravity = Vector3(0, 0.3, 0)
	cloud.scale_amount_min = 2.0
	cloud.scale_amount_max = 4.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.3, 0.3)
	var m := _mat(Color(0.55, 0.75, 0.3, 0.35), Color(0.4, 0.6, 0.2), 0.8)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = m
	cloud.mesh = quad
	add_child(cloud)
	get_tree().create_timer(2.0).timeout.connect(cloud.queue_free)

# Sporenwolke über einer Karte (wirkt wie ein Fluch).
func add_spore_cloud(card: Node3D) -> void:
	var cloud := CPUParticles3D.new()
	cloud.name = "Curse"
	cloud.amount = 22
	cloud.set_meta("wichtig", true)
	cloud.lifetime = 2.2
	cloud.position = Vector3(0, -0.2, 0)
	cloud.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	cloud.emission_sphere_radius = 0.45
	cloud.direction = Vector3(0, 1, 0)
	cloud.spread = 40
	cloud.gravity = Vector3(0, 0.15, 0)
	cloud.initial_velocity_min = 0.05
	cloud.initial_velocity_max = 0.2
	cloud.scale_amount_min = 2.5
	cloud.scale_amount_max = 4.5
	var quad := QuadMesh.new()
	quad.size = Vector2(0.25, 0.25)
	var m := _mat(Color(0.55, 0.8, 0.3, 0.3), Color(0.45, 0.7, 0.2), 1.2)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = m
	cloud.mesh = quad
	var light := OmniLight3D.new()
	light.light_color = Color(0.55, 0.9, 0.3)
	light.light_energy = 1.2
	light.omni_range = 1.8
	cloud.add_child(light)
	card.add_child(cloud)

# Stampfen: eine leuchtende Welle läuft vom Boss über das ganze Feld
# (wie die Bosswelle in "Claude 1").
func stomp_wave() -> void:
	_arm_pose(left_arm, Vector3(-20, 0, -15), Vector3(-5, 0, 0), 0.1)
	_arm_pose(right_arm, Vector3(-20, 0, 15), Vector3(-5, 0, 0), 0.1)
	if skeleton != null:
		var hip: Node3D = rig["Huefte"]
		var down := hip.create_tween()
		down.tween_property(hip, "position:y", hip.position.y - 0.15, 0.08)
		down.tween_property(hip, "position:y", hip.position.y, 0.4)
	await get_tree().create_timer(0.1).timeout
	shake(0.7, 0.6)
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.set_color(1, Color(1, 1, 1, 1))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.width = 4
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(accent.r, accent.g, accent.b, 0.55)
	m.albedo_texture = tex
	m.disable_fog = true
	var ring := CylinderMesh.new()
	ring.top_radius = 1.0
	ring.bottom_radius = 1.0
	ring.height = 1.6
	ring.cap_top = false
	ring.cap_bottom = false
	ring.radial_segments = 64
	var wave := _part(ring, m, self, Vector3(0, 0.3, boss_pos.z + 1.0))
	wave.scale = Vector3(0.5, 1, 0.5)
	var tween := wave.create_tween().set_parallel(true)
	tween.tween_property(wave, "scale", Vector3(15, 1.6, 15), 0.9)
	tween.tween_property(m, "albedo_color:a", 0.0, 0.9)
	await get_tree().create_timer(0.35).timeout
	get_tree().create_timer(0.7).timeout.connect(wave.queue_free)

# Einzelne Wurzel schlägt aus dem Boden (während er verwurzelt ist).
func root_lash(at: Vector3) -> void:
	await root_spikes([at])

# --- Angriffe ----------------------------------------------------------------------

# Warnring auf einer Karte, die gleich getroffen wird.
func add_warning(card: Node3D) -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 0.62
	var m := _mat(Color(1, 0.1, 0.05), Color(1, 0.05, 0.02), 5.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := MeshInstance3D.new()
	ring.mesh = torus
	ring.material_override = m
	ring.position = Vector3(0, -0.4, 0)
	card.add_child(ring)
	warnings.append(ring)
	var tween := ring.create_tween().set_loops()
	tween.tween_property(ring, "scale", Vector3(1.25, 1, 1.25), 0.25)
	tween.tween_property(ring, "scale", Vector3.ONE, 0.25)

# Warnstreifen über eine ganze Reihe.
func add_row_warning(row: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(7.0, 0.02, 1.15)
	var m := _mat(Color(1, 0.05, 0.05, 0.35), Color(1, 0.05, 0.02), 2.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var strip := _part(box, m, self, row + Vector3(0, -0.4, 0).rotated(Vector3.RIGHT, deg_to_rad(board_tilt)), Vector3(board_tilt, 0, 0))
	warnings.append(strip)
	var tween := strip.create_tween().set_loops()
	tween.tween_property(m, "albedo_color:a", 0.1, 0.25)
	tween.tween_property(m, "albedo_color:a", 0.45, 0.25)

func clear_warnings() -> void:
	for w in warnings:
		if is_instance_valid(w):
			w.queue_free()
	warnings.clear()

# Blutkugel fliegt auf eine Karte.
func cast_orb(target: Vector3) -> void:
	_arm_pose(left_arm, Vector3(-60, 0, -10), Vector3(-5, 0, 0), 0.12)
	_arm_pose(right_arm, Vector3(-60, 0, 10), Vector3(-5, 0, 0), 0.12)
	var orb := _glow_orb(Color(1, 0.08, 0.05), 0.32)
	var start := chest_position() + Vector3(0, 0, 0.8)
	orb.position = start
	add_child(orb)
	var mid := (start + target) / 2.0 + Vector3(0, 3.5, 0)
	var tween := orb.create_tween()
	tween.tween_method(func(t: float): orb.position = _bezier(start, mid, target, t), 0.0, 1.0, 0.55)
	await tween.finished
	_burst(target, Color(1, 0.1, 0.05))
	shake(0.25, 0.25)
	orb.queue_free()

# Klauenhieb fegt über eine Reihe.
func slash_row(row: Vector3) -> void:
	_arm_pose(right_arm, Vector3(-40, 0, -50), Vector3(-10, 0, 0), 0.15)
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.9, 1.3)
	var m := _mat(Color(1, 0.15, 0.1, 0.8), Color(1, 0.1, 0.05), 6.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var blade := _part(box, m, self, row + Vector3(4.5, 0.1, 0).rotated(Vector3.RIGHT, deg_to_rad(board_tilt)), Vector3(board_tilt, 0, 25))
	var tween := blade.create_tween()
	tween.tween_property(blade, "position:x", -4.5, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	shake(0.3, 0.25)
	blade.queue_free()

# Beide Arme schlagen auf den Boden, eine Schockwelle rollt über das Feld.
func slam() -> void:
	_arm_pose(left_arm, Vector3(-30, 0, -10), Vector3(-5, 0, 0), 0.12)
	_arm_pose(right_arm, Vector3(-30, 0, 10), Vector3(-5, 0, 0), 0.12)
	await get_tree().create_timer(0.12).timeout
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 48
	var m := _mat(Color(1, 0.2, 0.1, 0.9), Color(1, 0.1, 0.05), 5.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ring := _part(torus, m, self, board_point(Vector3(0, -0.35, 0)), Vector3(board_tilt, 0, 0))
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(8, 1, 8), 0.6)
	tween.tween_property(m, "albedo_color:a", 0.0, 0.6)
	shake(0.6, 0.5)
	await get_tree().create_timer(0.25).timeout
	get_tree().create_timer(0.5).timeout.connect(ring.queue_free)

# Fluch: lila Flamme auf einer Karte.
func cast_curse(target: Vector3) -> void:
	var orb := _glow_orb(Color(0.6, 0.15, 1.0), 0.25)
	var start := hand_position(-1)
	orb.position = start
	add_child(orb)
	var mid := (start + target) / 2.0 + Vector3(0, 2.5, 0)
	var tween := orb.create_tween()
	tween.tween_method(func(t: float): orb.position = _bezier(start, mid, target, t), 0.0, 1.0, 0.6)
	await tween.finished
	_burst(target, Color(0.6, 0.2, 1.0))
	orb.queue_free()

func add_curse_marker(card: Node3D) -> void:
	var flame := CPUParticles3D.new()
	flame.name = "Curse"
	flame.amount = 24
	flame.lifetime = 0.9
	flame.position = Vector3(0, -0.35, 0)
	flame.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flame.emission_sphere_radius = 0.4
	flame.direction = Vector3(0, 1, 0)
	flame.spread = 15
	flame.gravity = Vector3(0, 1.2, 0)
	flame.initial_velocity_min = 0.3
	flame.initial_velocity_max = 0.7
	var quad := QuadMesh.new()
	quad.size = Vector2(0.12, 0.12)
	var m := _mat(Color(0.65, 0.2, 1.0), Color(0.6, 0.1, 1.0), 4.0)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = m
	flame.mesh = quad
	var light := OmniLight3D.new()
	light.light_color = Color(0.6, 0.2, 1.0)
	light.light_energy = 1.5
	light.omni_range = 1.6
	flame.add_child(light)
	card.add_child(flame)

func remove_curse_marker(card: Node3D) -> void:
	var marker := card.get_node_or_null("Curse")
	if marker != null:
		marker.queue_free()

func finish_attack() -> void:
	# Nachschwingen läuft noch zu Ende, danach geht er in den Stand zurück
	var tween := create_tween()
	tween.tween_property(boss_body, "rotation_degrees:x", 0.0, 0.4)
	_arms_rest(0.6)

func shake(strength: float, duration: float) -> void:
	if camera == null:
		return
	var tween := create_tween()
	var steps := 8
	for i in range(steps):
		var fade := 1.0 - float(i) / steps
		tween.tween_property(camera, "h_offset", randf_range(-strength, strength) * fade, duration / steps)
		tween.parallel().tween_property(camera, "v_offset", randf_range(-strength, strength) * fade, duration / steps)
	tween.tween_property(camera, "h_offset", 0.0, 0.05)
	tween.parallel().tween_property(camera, "v_offset", 0.0, 0.05)

# Der Boss zerfällt.
func die() -> void:
	if skeleton != null:
		set_pose("dead")
	dead = true
	busy = true
	_flash(Color(1, 1, 1), 10.0)
	shake(0.5, 1.2)
	for i in range(6):
		_burst(chest_position() + Vector3(randf_range(-1.5, 1.5), randf_range(-2, 1.5), 0.5), Color(1, 0.3, 0.2))
	var tween := create_tween().set_parallel(true)
	tween.tween_property(boss_root, "position:y", boss_pos.y - 5.5, 1.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(boss_root, "rotation_degrees:z", 12.0, 1.8)
	tween.tween_property(eye_light, "light_energy", 0.0, 1.2)
	aura.emitting = false
	await tween.finished
