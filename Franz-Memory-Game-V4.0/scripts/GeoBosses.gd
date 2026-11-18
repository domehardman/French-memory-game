extends Node3D
## Bosse aus einfachen Formen mit Pixel-Texturen und schwebenden, leuchtenden Augen.
## BossArena.gd baut den Boss hier, wenn in campaign.json "style": "geo_..." steht.
## Die Animationen der Angriffe (Ausholen, Zuschlagen, Treffer) kommen weiterhin aus
## BossArena.gd: die Hände hängen an unsichtbaren Armen und bewegen sich mit.
##
## Augen-Stimmungen (mood): "calm", "sleepy", "angry", "wide", "hurt", "rage".
## Jeder Boss hat eine Grundstimmung (z. B. der Sonneur ist meistens "sleepy").

var arena: Node3D               # BossArena
var style := ""
var base_mood := "calm"
var mood_now := ""
var mood_timer := 0.0
var time := 0.0
var blink_timer := 2.5
var eyes: Array[MeshInstance3D] = []
var eye_holder: Node3D
var eye_color := Color("#ffd27a")
var eye_textures: Dictionary = {}
var swingers: Array[Dictionary] = []   # Teile, die pendeln oder kreisen
var parts: Array[Node3D] = []          # alles, was beim Tod auseinanderfällt

# --- Aufbau ---------------------------------------------------------------------------

func build(arena_node: Node3D, style_name: String, accent: Color) -> void:
	arena = arena_node
	style = style_name
	match style:
		"geo_sonneur":
			_build_sonneur(accent)
		"geo_veuve":
			_build_veuve(accent)
		"geo_prince":
			_build_prince(accent)
		"geo_patre":
			_build_patre(accent)
		_:
			_build_sonneur(accent)

# Pixel-Material: 8×8 Bild mit Grundfarbe, hellen und dunklen Tupfen, überall gleich gross
func material(base: Color, metallic: float = 0.0, emission: float = 0.0) -> StandardMaterial3D:
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(base)
	for p in [Vector2i(1, 1), Vector2i(5, 2), Vector2i(3, 5), Vector2i(7, 6)]:
		img.set_pixelv(p, base.lightened(0.16))
	for p in [Vector2i(6, 0), Vector2i(2, 3), Vector2i(0, 6), Vector2i(5, 7)]:
		img.set_pixelv(p, base.darkened(0.16))
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(1.4, 1.4, 1.4)
	m.roughness = 0.55
	m.metallic = metallic
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = base
		m.emission_energy_multiplier = emission
	arena.flash_materials.append(m)
	return m

func _mesh(mesh: Mesh, mat: Material, parent: Node3D, pos: Vector3, rot: Vector3 = Vector3.ZERO, scale_v: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = pos
	instance.rotation_degrees = rot
	instance.scale = scale_v
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(instance)
	parts.append(instance)
	return instance

static func frustum(bottom: float, top: float, height: float, segments: int = 8) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.bottom_radius = bottom
	m.top_radius = top
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m

static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

static func ball(radius: float, segments: int = 10) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = segments / 2
	return m

static func ring(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 16
	m.ring_segments = 6
	return m

# Rhombus (Oktaeder) aus zwei Pyramiden
func rhombus(parent: Node3D, mat: Material, pos: Vector3, width: float, height: float) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = 45
	parent.add_child(holder)
	_mesh(frustum(width, 0.0, height / 2.0, 4), mat, holder, Vector3(0, height / 4.0, 0))
	_mesh(frustum(0.0, width, height / 2.0, 4), mat, holder, Vector3(0, -height / 4.0, 0))
	return holder

# Unsichtbarer Arm mit schwebender Hand (BossArena bewegt Schulter und Ellbogen)
func floating_arm(side: int, shoulder: Vector3, hand: Mesh, mat: Material, reach: float = 1.8) -> Node3D:
	var arm := Node3D.new()
	arm.position = Vector3(side * shoulder.x, shoulder.y, shoulder.z)
	arena.boss_body.add_child(arm)
	var elbow := Node3D.new()
	elbow.name = "Elbow"
	elbow.position = Vector3(0, -reach, 0)
	arm.add_child(elbow)
	var hand_node := Node3D.new()
	hand_node.name = "Hand"
	hand_node.position = Vector3(0, -reach * 0.6, 0)
	elbow.add_child(hand_node)
	_mesh(hand, mat, hand_node, Vector3.ZERO, Vector3(0, 0, side * 12.0))
	arm.rotation_degrees = Vector3(-20, 0, side * 28)
	elbow.rotation_degrees = Vector3(-30, 0, 0)
	arm.set_meta("rest", arm.rotation_degrees)
	elbow.set_meta("rest", elbow.rotation_degrees)
	return arm

# --- Le Sonneur ---------------------------------------------------------------------
# Glöckner aus Formen: Kopf = Rhombus, Körper = Stufenglocke aus drei Kegelstümpfen,
# darunter pendelt ein Klöppel. Taub und träge: die Augen sind meist halb zu.

func _build_sonneur(accent: Color) -> void:
	base_mood = "sleepy"
	eye_color = Color("#ffc23d")
	var amber := material(accent)
	var bronze := material(accent.darkened(0.45), 0.35)
	var light := material(accent.lightened(0.35))
	var dark := material(Color("#3b2a3f"))
	var body: Node3D = arena.boss_body
	# Stufenglocke
	_mesh(ring(1.55, 1.85), bronze, body, Vector3(0, 0.95, 0))
	_mesh(frustum(1.75, 1.35, 1.1), amber, body, Vector3(0, 1.5, 0))
	_mesh(frustum(1.3, 1.0, 1.2), light, body, Vector3(0, 2.65, 0))
	_mesh(frustum(0.98, 0.62, 1.0), amber, body, Vector3(0, 3.75, 0))
	_mesh(frustum(0.6, 0.35, 0.35), bronze, body, Vector3(0, 4.42, 0))
	# Klöppel: Stange mit Kugel, pendelt unter der Glocke
	var clapper := Node3D.new()
	clapper.position = Vector3(0, 1.6, 0)
	body.add_child(clapper)
	_mesh(frustum(0.07, 0.07, 1.3, 6), dark, clapper, Vector3(0, -0.65, 0))
	_mesh(ball(0.38, 8), bronze, clapper, Vector3(0, -1.35, 0))
	swingers.append({"node": clapper, "kind": "pendulum", "amount": 14.0, "speed": 1.6})
	# Kopf: grosser Rhombus, schwebt über dem Körper
	var head_shape := rhombus(arena.head, amber, Vector3(0, 0.45, 0), 1.35, 2.7)
	_mesh(ring(0.35, 0.52), bronze, arena.head, Vector3(0, 2.0, 0), Vector3(90, 0, 0))
	swingers.append({"node": head_shape, "kind": "turn", "amount": 6.0, "speed": 0.7})
	# Zwei kleine Glocken kreisen um ihn
	for i in range(2):
		var mini := Node3D.new()
		mini.set_meta("angle", PI * i)
		mini.set_meta("height", 3.0 + i * 0.8)
		body.add_child(mini)
		_mesh(frustum(0.32, 0.16, 0.4, 8), light, mini, Vector3.ZERO)
		_mesh(ball(0.08, 6), dark, mini, Vector3(0, -0.24, 0))
		swingers.append({"node": mini, "kind": "orbit", "radius": 2.6, "speed": 0.5, "angle": PI * i, "height": 3.0 + i * 0.9})
	# Schwebende Würfel-Hände, rechts mit Hämmerchen
	arena.left_arm = floating_arm(-1, Vector3(1.9, 3.9, 0.2), box(Vector3(0.6, 0.6, 0.6)), bronze)
	arena.right_arm = floating_arm(1, Vector3(1.9, 3.9, 0.2), box(Vector3(0.6, 0.6, 0.6)), bronze)
	var hammer := Node3D.new()
	hammer.rotation_degrees = Vector3(0, 0, -20)
	arena.right_arm.get_node("Elbow/Hand").add_child(hammer)
	_mesh(frustum(0.05, 0.05, 1.1, 6), dark, hammer, Vector3(0, 0.55, 0.0))
	_mesh(box(Vector3(0.6, 0.32, 0.32)), light, hammer, Vector3(0, 1.15, 0))
	arena.hand_offset = Vector3(0, -1.1, 0.1)
	_build_eyes(Vector3(0, 0.5, 1.45), 0.62, 0.52)

# --- La Veuve de Cendre --------------------------------------------------------------
# Aschenwitwe aus Formen: langer schmaler Kegel als Kleid, Kopf = umgedrehtes Prisma
# (Schleier), Heiligenschein-Ring, drei Sicheln kreisen um sie. Schmale Schlitzaugen.

func _build_veuve(accent: Color) -> void:
	base_mood = "slit"
	eye_color = Color("#a8d4ff")
	var dress := material(Color("#39406e"))
	var dress_light := material(Color("#4a5288"))
	var veil := material(Color("#2a2f55"))
	var ice := material(accent, 0.0, 0.8)
	var pale := material(Color("#c9d4f0"))
	var body: Node3D = arena.boss_body
	# Kleid: schmaler hoher Kegel, unten ein leuchtender Saum
	_mesh(frustum(1.5, 0.3, 4.0, 10), dress, body, Vector3(0, 2.6, 0))
	_mesh(frustum(1.62, 1.5, 0.3, 10), ice, body, Vector3(0, 0.72, 0))
	_mesh(frustum(0.98, 0.9, 0.16, 10), ice, body, Vector3(0, 2.75, 0))
	_mesh(frustum(0.35, 1.05, 0.5, 6), dress_light, body, Vector3(0, 4.75, 0))
	# Kopf: Schleier als umgedrehtes Prisma, dahinter ein langer Schleier
	var prism_mesh := PrismMesh.new()
	prism_mesh.size = Vector3(1.6, 2.1, 1.0)
	_mesh(prism_mesh, veil, arena.head, Vector3(0, 0.55, 0), Vector3(0, 0, 180))
	var back_veil := PrismMesh.new()
	back_veil.size = Vector3(1.9, 3.6, 0.18)
	_mesh(back_veil, dress_light, arena.head, Vector3(0, -0.4, -0.45), Vector3(0, 0, 180))
	# Heiligenschein
	var halo_node := Node3D.new()
	halo_node.position = Vector3(0, 1.95, -0.1)
	arena.head.add_child(halo_node)
	_mesh(ring(0.6, 0.72), ice, halo_node, Vector3.ZERO, Vector3(75, 0, 0))
	swingers.append({"node": halo_node, "kind": "tilt", "amount": 8.0, "speed": 0.9})
	# Drei Sicheln kreisen um sie
	for i in range(3):
		var orbit := Node3D.new()
		body.add_child(orbit)
		var blade := sickle(Color("#d6e2ff"), accent)
		blade.scale = Vector3.ONE * 1.2
		orbit.add_child(blade)
		parts.append(blade)
		swingers.append({"node": orbit, "kind": "orbit", "radius": 2.5, "speed": 0.7, "angle": TAU * i / 3.0, "height": 3.2 + (i % 2) * 0.6, "spin": 90.0})
	# Schwebende Hände (spitze Prismen), links hält sie eine Sichel
	var hand_mesh := PrismMesh.new()
	hand_mesh.size = Vector3(0.45, 0.65, 0.28)
	arena.left_arm = floating_arm(-1, Vector3(1.5, 4.4, 0.2), hand_mesh, pale)
	arena.right_arm = floating_arm(1, Vector3(1.5, 4.4, 0.2), hand_mesh, pale)
	var held := sickle(Color("#d6e2ff"), accent)
	held.scale = Vector3.ONE * 1.4
	held.rotation_degrees = Vector3(0, 0, 160)
	arena.left_arm.get_node("Elbow/Hand").add_child(held)
	arena.hand_offset = Vector3(0, -1.1, 0.1)
	_build_eyes(Vector3(0, 0.95, 0.62), 0.5, 0.42)

# Sichel: Griff und eine Klinge aus vier Stücken im Bogen
func sickle(steel: Color, glow: Color) -> Node3D:
	var root := Node3D.new()
	var steel_mat := material(steel, 0.4)
	steel_mat.emission_enabled = true
	steel_mat.emission = glow
	steel_mat.emission_energy_multiplier = 0.4
	var grip := material(Color("#2a2f55"))
	var handle := MeshInstance3D.new()
	handle.mesh = frustum(0.05, 0.05, 0.8, 6)
	handle.material_override = grip
	handle.position = Vector3(0, -0.4, 0)
	root.add_child(handle)
	# Klinge: sechs Stücke im Bogen, zur Spitze hin schmaler
	for k in range(6):
		var a := deg_to_rad(5.0 + k * 28.0)
		var piece := MeshInstance3D.new()
		piece.mesh = box(Vector3(0.36, 0.2 - k * 0.022, 0.07))
		piece.material_override = steel_mat
		piece.position = Vector3(cos(a) * 0.65 - 0.65, sin(a) * 0.65, 0)
		piece.rotation.z = a + PI / 2.0
		root.add_child(piece)
	return root

# Asche: kleine Würfel fliegen auseinander (Verschwinden) oder zusammen (Auftauchen)
func ash_cubes(at: Vector3, appear: bool) -> void:
	var colors := [Color("#6b6f8a"), Color("#9aa0bd"), Color("#39406e"), eye_color]
	for i in range(26):
		var cube := MeshInstance3D.new()
		cube.mesh = box(Vector3.ONE * randf_range(0.15, 0.32))
		var m := StandardMaterial3D.new()
		m.albedo_color = colors[i % colors.size()]
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cube.material_override = m
		arena.add_child(cube)
		var out := at + Vector3(randf_range(-2.5, 2.5), randf_range(-3.0, 2.5), randf_range(-1.5, 1.5))
		var inside := at + Vector3(randf_range(-0.6, 0.6), randf_range(-2.0, 1.0), randf_range(-0.4, 0.4))
		cube.global_position = inside if not appear else out
		var tween := cube.create_tween().set_parallel(true)
		tween.tween_property(cube, "global_position", out if not appear else inside, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(cube, "rotation_degrees", Vector3(randf_range(-200, 200), randf_range(-200, 200), 0), 0.6)
		tween.tween_property(m, "albedo_color:a", 0.0, 0.6).set_delay(0.2)
		tween.chain().tween_callback(cube.queue_free)

# --- Le Prince des Os ------------------------------------------------------------------
# Knochenprinz aus Würfeln: gestapelter Körper, grosser Würfel-Schädel mit klapperndem
# Kiefer und einer Krone aus fünf goldenen Pyramiden. Dunkle Augenhöhlen, darin
# leuchtende Pupillen, die herumschauen.

func _build_prince(accent: Color) -> void:
	base_mood = "calm"
	eye_color = accent.lightened(0.2)
	var bone := material(Color("#efe6cf"))
	var bone_dark := material(Color("#c9bf9f"))
	var mint := material(accent, 0.0, 0.7)
	var gold := material(Color("#f2c14e"), 0.5)
	var socket := material(Color("#1d1a2b"))
	var body: Node3D = arena.boss_body
	# Wirbel unten (er schwebt), Becken, Bauch, Brust
	for k in range(3):
		_mesh(box(Vector3.ONE * (0.35 - k * 0.07)), bone_dark, body, Vector3(0, 0.95 - k * 0.42, 0), Vector3(0, k * 25.0, 0))
	_mesh(box(Vector3(1.7, 0.8, 1.0)), bone, body, Vector3(0, 1.45, 0))
	_mesh(box(Vector3(1.1, 0.9, 0.8)), bone_dark, body, Vector3(0, 2.25, 0))
	_mesh(box(Vector3(2.4, 1.4, 1.3)), bone, body, Vector3(0, 3.4, 0))
	# Rippen: dunkle Schlitze vorne auf der Brust
	for k in range(3):
		_mesh(box(Vector3(1.7 - k * 0.25, 0.12, 0.05)), socket, body, Vector3(0, 3.75 - k * 0.32, 0.66))
	# Schulterstücke in Mint
	for side in [-1.0, 1.0]:
		_mesh(box(Vector3(0.9, 0.6, 1.1)), mint, body, Vector3(side * 1.45, 4.05, 0), Vector3(0, 0, side * -12.0))
	_mesh(box(Vector3(0.5, 0.5, 0.5)), bone_dark, body, Vector3(0, 4.35, 0))
	# Kopf: Würfel-Schädel mit Augenhöhlen, Kiefer und Krone
	_mesh(box(Vector3(1.8, 1.6, 1.6)), bone, arena.head, Vector3(0, 0.75, 0))
	for side in [-1.0, 1.0]:
		_mesh(box(Vector3(0.55, 0.5, 0.06)), socket, arena.head, Vector3(side * 0.42, 0.85, 0.81))
	_mesh(box(Vector3(0.22, 0.28, 0.06)), socket, arena.head, Vector3(0, 0.38, 0.81))
	var jaw := Node3D.new()
	jaw.position = Vector3(0, -0.25, 0.05)
	arena.head.add_child(jaw)
	_mesh(box(Vector3(1.4, 0.4, 1.4)), bone_dark, jaw, Vector3.ZERO)
	for k in range(5):
		_mesh(box(Vector3(0.14, 0.16, 0.06)), bone, jaw, Vector3(-0.44 + k * 0.22, 0.24, 0.68))
	swingers.append({"node": jaw, "kind": "jaw", "y": -0.25})
	_mesh(box(Vector3(1.9, 0.25, 1.7)), gold, arena.head, Vector3(0, 1.66, 0))
	for k in range(5):
		var x := -0.72 + k * 0.36
		var height := 0.55 if k != 2 else 0.85
		_mesh(frustum(0.17, 0.0, height, 4), gold, arena.head, Vector3(x, 1.78 + height / 2.0, 0.55), Vector3(0, 45, 0))
	_mesh(ball(0.12, 6), mint, arena.head, Vector3(0, 2.1, 0.72))
	# Würfel-Hände, rechts ein Zepter mit Mint-Rhombus
	arena.left_arm = floating_arm(-1, Vector3(1.9, 4.0, 0.2), box(Vector3(0.65, 0.65, 0.65)), bone)
	arena.right_arm = floating_arm(1, Vector3(1.9, 4.0, 0.2), box(Vector3(0.65, 0.65, 0.65)), bone)
	var scepter := Node3D.new()
	scepter.rotation_degrees = Vector3(0, 0, -15)
	arena.right_arm.get_node("Elbow/Hand").add_child(scepter)
	_mesh(frustum(0.06, 0.06, 1.8, 6), gold, scepter, Vector3(0, 0.6, 0))
	rhombus(scepter, mint, Vector3(0, 1.75, 0), 0.3, 0.7)
	arena.hand_offset = Vector3(0, -1.1, 0.1)
	# Pupillen in den Augenhöhlen
	_build_eyes(Vector3(0, 0.85, 0.9), 0.5, 0.36)
	swingers.append({"node": eye_holder, "kind": "look", "x": 0.0})

# Würfel-Schädel für den Angriff "skulls"
func falling_skull() -> Node3D:
	var root := Node3D.new()
	var bone := material(Color("#efe6cf"))
	var socket := material(Color("#1d1a2b"))
	var head := MeshInstance3D.new()
	head.mesh = box(Vector3(0.9, 0.8, 0.8))
	head.material_override = bone
	root.add_child(head)
	for side in [-1.0, 1.0]:
		var hole := MeshInstance3D.new()
		hole.mesh = box(Vector3(0.26, 0.24, 0.04))
		hole.material_override = socket
		hole.position = Vector3(side * 0.2, 0.06, 0.41)
		root.add_child(hole)
	var jaw := MeshInstance3D.new()
	jaw.mesh = box(Vector3(0.7, 0.2, 0.7))
	jaw.material_override = bone
	jaw.position = Vector3(0, -0.5, 0)
	root.add_child(jaw)
	return root

func bone_material(accent: Color) -> StandardMaterial3D:
	var m := material(Color("#efe6cf"))
	m.emission_enabled = true
	m.emission = accent
	m.emission_energy_multiplier = 0.25
	return m

# --- Le Pâtre des Racines ----------------------------------------------------------------
# Wurzelhirt aus Formen: Baumstamm mit Wurzeln und Moos-Kragen, Hirschschädel aus Blöcken
# mit grossem Geweih, schwebende Holzhände und ein Hirtenstab. In der Brust sitzt das
# leuchtende Herz hinter zwei Rindentüren, die beim Verwurzeln aufgehen.

var heart_material: StandardMaterial3D
var heart_light: OmniLight3D
var heart_holder: Node3D
var heart_doors: Array[Node3D] = []
var door_tween: Tween
var minion_materials: Dictionary = {}

# Material, das nicht beim Treffer aufblitzt (für Herz und kleine Helfer)
func _quiet_material(base: Color, emission: float = 0.0) -> StandardMaterial3D:
	var m := material(base, 0.0, emission)
	arena.flash_materials.erase(m)
	return m

# Leuchtet leicht, die Pixel-Tupfen der Textur bleiben dabei sichtbar
func _lit(base: Color, emission: float) -> StandardMaterial3D:
	var m := material(base, 0.0, emission * 0.5)
	m.emission_texture = m.albedo_texture
	return m

# Gerader Balken von a nach b (in der XY-Ebene), für Geweih und Hirtenstab
func _bar(parent: Node3D, a: Vector3, b: Vector3, thick: float, mat: Material) -> MeshInstance3D:
	var d := b - a
	var bar := _mesh(box(Vector3(thick, d.length() + thick * 0.4, thick)), mat, parent, (a + b) / 2.0)
	bar.rotation.z = atan2(-d.x, d.y)
	return bar

func _antler(side: float, bone: Material, tip: Material) -> void:
	var root := Node3D.new()
	root.position = Vector3(side * 0.42, 0.9, -0.05)
	root.scale = Vector3.ONE * 0.82
	arena.head.add_child(root)
	var main: Array[Vector3] = [Vector3.ZERO, Vector3(0.36, 0.55, 0), Vector3(0.62, 1.2, 0), Vector3(0.56, 1.95, 0), Vector3(0.84, 2.5, 0)]
	for i in range(main.size()):
		main[i].x *= side
	for i in range(main.size() - 1):
		_bar(root, main[i], main[i + 1], 0.24 - i * 0.03, bone)
	# Sprossen: [Ansatz auf dem Hauptast, Spitze]
	var tines := [[1, Vector3(0.95, 0.72, 0)], [2, Vector3(1.22, 1.5, 0)], [3, Vector3(0.14, 2.3, 0)], [3, Vector3(1.16, 2.12, 0)]]
	for t in tines:
		var end: Vector3 = t[1]
		end.x *= side
		_bar(root, main[int(t[0])], end, 0.13, bone)
		rhombus(root, tip, end + Vector3(0, 0.08, 0), 0.1, 0.24)
	rhombus(root, tip, main[4] + Vector3(0, 0.1, 0), 0.12, 0.3)
	swingers.append({"node": root, "kind": "tilt", "amount": 2.5 * side, "speed": 0.8})

func _mushroom(parent: Node3D, pos: Vector3, size: float, cap: Material, stem: Material) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.scale = Vector3.ONE * size
	parent.add_child(holder)
	_mesh(frustum(0.1, 0.08, 0.26, 6), stem, holder, Vector3(0, 0.13, 0))
	_mesh(frustum(0.34, 0.1, 0.2, 8), cap, holder, Vector3(0, 0.34, 0))

func _claw_hand(side: int, bark: Material, bone: Material) -> Node3D:
	var arm := floating_arm(side, Vector3(2.3, 4.15, 0.25), box(Vector3(0.66, 0.5, 0.6)), bark)
	var hand: Node3D = arm.get_node("Elbow/Hand")
	for k in range(3):
		_mesh(frustum(0.0, 0.11, 0.42, 4), bone, hand, Vector3(-0.2 + k * 0.2, -0.42, 0.08), Vector3(0, 45, 0))
	return arm

func _build_patre(accent: Color) -> void:
	base_mood = "stare"
	eye_color = accent.lightened(0.25)
	# Die Farben leuchten ganz leicht, damit er sich vom Hintergrund abhebt
	var bark := _lit(Color("#b5642f"), 0.16)
	var bark_light := _lit(Color("#d98f4e"), 0.14)
	var bark_dark := _lit(Color("#7a4228"), 0.16)
	var moss := _lit(Color("#58c936"), 0.2)
	var moss_dark := _lit(Color("#2f9a3f"), 0.2)
	var bone := _lit(Color("#e8dcc0"), 0.04)
	var bone_dark := _lit(Color("#c4b28b"), 0.05)
	var socket := material(Color("#241a2c"))
	var cap := _lit(Color("#f4476b"), 0.2)
	var glow := material(accent, 0.0, 1.1)
	var body: Node3D = arena.boss_body
	arena.body_bob = 0.05          # er wurzelt im Boden und schwebt kaum
	arena.eye_light_strength = 0.3 # sonst überstrahlt das Augenlicht den hellen Schädel
	# Wurzeln laufen sternförmig vom Stamm weg
	for i in range(7):
		var root := Node3D.new()
		root.rotation_degrees.y = i * 360.0 / 7.0 + 12.0
		body.add_child(root)
		var length := 1.35 + (i % 3) * 0.2
		_mesh(frustum(0.36, 0.05, length, 6), bark_dark if i % 2 else bark, root, Vector3(0, 0.2, 0.95 + length / 2.0), Vector3(84, 0, 0))
	# Stamm: drei gestapelte Kegelstümpfe, oben breite Schultern
	_mesh(frustum(1.55, 1.2, 1.5, 8), bark_dark, body, Vector3(0, 0.75, 0))
	_mesh(frustum(1.2, 1.05, 1.4, 8), bark, body, Vector3(0, 2.2, 0))
	_mesh(frustum(1.05, 1.42, 1.3, 8), bark_light, body, Vector3(0, 3.55, 0))
	# Moos-Kragen mit herabhängenden Streifen
	_mesh(frustum(1.72, 1.5, 0.3, 8), moss_dark, body, Vector3(0, 4.3, 0))
	_mesh(frustum(1.5, 0.62, 0.55, 8), moss, body, Vector3(0, 4.72, 0))
	for i in range(12):
		var a := TAU * i / 12.0 + 0.15
		var length := 0.45 + (i * 7 % 4) * 0.2
		_mesh(box(Vector3(0.3, length, 0.18)), moss_dark if i % 2 else moss, body, Vector3(sin(a) * 1.58, 4.2 - length / 2.0, cos(a) * 1.58), Vector3(0, rad_to_deg(a), 0))
	_mesh(frustum(0.42, 0.3, 0.45, 6), bark_dark, body, Vector3(0, 5.1, 0))
	_mushroom(body, Vector3(-1.2, 4.42, 0.62), 1.25, cap, bone)
	_mushroom(body, Vector3(1.05, 4.42, 0.82), 0.9, cap, bone)
	_mushroom(body, Vector3(1.3, 1.42, 0.45), 1.1, cap, bone)
	# Herz in der Brust, hinter zwei Rindentüren
	_mesh(box(Vector3(1.0, 1.3, 0.2)), socket, body, Vector3(0, 3.35, 1.05))
	heart_material = _quiet_material(accent, 2.2)
	heart_holder = Node3D.new()
	heart_holder.position = Vector3(0, 3.35, 1.24)
	body.add_child(heart_holder)
	rhombus(heart_holder, heart_material, Vector3.ZERO, 0.32, 0.92)
	arena.chest_node = heart_holder
	heart_light = OmniLight3D.new()
	heart_light.position = Vector3(0, 3.35, 1.8)
	heart_light.light_color = accent
	heart_light.light_energy = 0.7
	heart_light.omni_range = 4.0
	body.add_child(heart_light)
	for side in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(side * 0.5, 3.35, 1.2)
		hinge.set_meta("side", side)
		body.add_child(hinge)
		# In der Mitte bleibt ein Spalt offen: dort scheint das Herz durch
		_mesh(box(Vector3(0.45, 1.3, 0.1)), bark_light, hinge, Vector3(-side * 0.225, 0, 0.1))
		heart_doors.append(hinge)
	# Kopf: Hirschschädel aus Blöcken
	_mesh(box(Vector3(1.3, 0.95, 1.0)), bone, arena.head, Vector3(0, 0.45, 0))
	_mesh(frustum(0.34, 0.68, 1.15, 4), bone_dark, arena.head, Vector3(0, -0.6, 0.12), Vector3(0, 45, 0))
	_mesh(box(Vector3(0.34, 0.2, 0.14)), socket, arena.head, Vector3(0, -1.08, 0.3))
	for side in [-1.0, 1.0]:
		_mesh(box(Vector3(0.46, 0.42, 0.06)), socket, arena.head, Vector3(side * 0.34, 0.5, 0.51))
		_mesh(frustum(0.2, 0.0, 0.62, 4), moss, arena.head, Vector3(side * 0.98, 0.5, 0), Vector3(0, 45, side * -105.0))
		_antler(side, bone, glow)
	_build_eyes(Vector3(0, 0.5, 0.56), 0.46, 0.4)
	# Drei leuchtende Samen kreisen um ihn
	for i in range(3):
		var seed_node := Node3D.new()
		body.add_child(seed_node)
		rhombus(seed_node, glow, Vector3.ZERO, 0.17, 0.42)
		swingers.append({"node": seed_node, "kind": "orbit", "radius": 3.0, "speed": 0.55, "angle": TAU * i / 3.0, "height": 1.9 + i * 1.05})
	# Schwebende Holzhände, rechts der Hirtenstab mit Laterne
	arena.left_arm = _claw_hand(-1, bark_light, bone)
	arena.right_arm = _claw_hand(1, bark_light, bone)
	var staff := Node3D.new()
	staff.rotation_degrees = Vector3(0, 0, -12)
	arena.right_arm.get_node("Elbow/Hand").add_child(staff)
	_mesh(frustum(0.08, 0.07, 3.5, 6), bark_dark, staff, Vector3(0, 0.65, 0))
	var center := Vector3(0.42, 2.4, 0)
	var last := center + Vector3(-0.42, 0, 0)
	for k in range(1, 6):
		var a := deg_to_rad(180.0 - k * 40.0)
		var next := center + Vector3(cos(a), sin(a), 0) * 0.42
		_bar(staff, last, next, 0.14, bark_dark)
		last = next
	var lantern := Node3D.new()
	lantern.position = last
	staff.add_child(lantern)
	rhombus(lantern, glow, Vector3(0, -0.3, 0), 0.14, 0.38)
	swingers.append({"node": lantern, "kind": "pendulum", "amount": 12.0, "speed": 1.5})
	arena.hand_offset = Vector3(0, -1.1, 0.1)

# Verwurzeln: die Rindentüren gehen auf, das Herz liegt offen
func set_rooted(on: bool) -> void:
	if heart_doors.is_empty():
		return
	arena.body_bob = 0.0 if on else 0.05
	if door_tween != null and door_tween.is_valid():
		door_tween.kill()
	door_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for hinge in heart_doors:
		var side := float(hinge.get_meta("side"))
		door_tween.tween_property(hinge, "rotation_degrees:y", side * 115.0 if on else 0.0, 0.45)
	door_tween.tween_property(heart_holder, "scale", Vector3.ONE * (1.25 if on else 1.0), 0.45)
	set_mood(idle_mood())

# Wurzeln, die beim Angriff aus dem Boden schiessen
func root_material() -> StandardMaterial3D:
	if not minion_materials.has("root"):
		minion_materials["root"] = _quiet_material(Color("#a9683f"), 0.3)
	return minion_materials["root"]

# Dornenknecht aus Würfeln für den Angriff "herd"
func thorn_minion() -> Node3D:
	if not minion_materials.has("bark"):
		minion_materials["bark"] = _quiet_material(Color("#8f5636"), 0.25)
		minion_materials["moss"] = _quiet_material(Color("#79d94f"), 0.3)
		minion_materials["thorn"] = _quiet_material(Color("#f4ecd6"), 0.25)
		minion_materials["eye"] = _quiet_material(eye_color, 2.0)
	var root := Node3D.new()
	var parts_list := [
		[box(Vector3(0.62, 0.5, 0.62)), "bark", Vector3(0, 0.34, 0), Vector3.ZERO],
		[box(Vector3(0.7, 0.14, 0.7)), "moss", Vector3(0, 0.62, 0), Vector3.ZERO],
		[box(Vector3(0.12, 0.12, 0.05)), "eye", Vector3(-0.14, 0.4, 0.32), Vector3.ZERO],
		[box(Vector3(0.12, 0.12, 0.05)), "eye", Vector3(0.14, 0.4, 0.32), Vector3.ZERO],
		[frustum(0.1, 0.0, 0.3, 4), "thorn", Vector3(-0.2, 0.82, 0), Vector3(0, 45, 0)],
		[frustum(0.1, 0.0, 0.38, 4), "thorn", Vector3(0.05, 0.86, -0.12), Vector3(0, 45, 0)],
		[frustum(0.1, 0.0, 0.3, 4), "thorn", Vector3(0.24, 0.82, 0.08), Vector3(0, 45, 0)],
	]
	for p in parts_list:
		var mesh_part := MeshInstance3D.new()
		mesh_part.mesh = p[0]
		mesh_part.material_override = minion_materials[p[1]]
		mesh_part.position = p[2]
		mesh_part.rotation_degrees = p[3]
		root.add_child(mesh_part)
	return root

# --- Augen ------------------------------------------------------------------------------

func _build_eyes(center: Vector3, spacing: float, size: float) -> void:
	eye_holder = Node3D.new()
	eye_holder.position = center
	arena.head.add_child(eye_holder)
	for side in [-1, 1]:
		var quad := QuadMesh.new()
		quad.size = Vector2(size, size)
		var eye := MeshInstance3D.new()
		eye.mesh = quad
		eye.position = Vector3(side * spacing / 2.0 + side * size * 0.3, 0, 0)
		eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		m.albedo_color = eye_color
		m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
		m.disable_fog = true
		eye.material_override = m
		eye.set_meta("side", side)
		eye_holder.add_child(eye)
		eyes.append(eye)
	set_mood(base_mood)

# 8×8 Augenbilder: "#" = leuchtet, "o" = Pupille (dunkel). Linkes Auge, das rechte wird gespiegelt.
const EYE_SHAPES := {
	"calm": ["..####..", ".######.", "########", "###oo###", "###oo###", "########", ".######.", "..####.."],
	"sleepy": ["........", "........", "........", "########", "###oo###", "########", ".######.", "..####.."],
	"angry": ["#.......", "###.....", "#####...", "#######.", "###oo###", "###oo###", ".######.", "..####.."],
	"wide": [".######.", "########", "###..###", "##.oo.##", "##.oo.##", "###..###", "########", ".######."],
	"hurt": ["##......", ".###....", "..####..", "....####", "....####", "..####..", ".###....", "##......"],
	"rage": ["##......", "####....", "######..", "########", "##o..o##", "########", ".######.", "........"],
	"slit": ["........", "........", "........", "########", "##oo####", ".######.", "........", "........"],
	"blink": ["........", "........", "........", "........", "########", "########", "........", "........"],
	"stare": ["...##...", "..####..", ".######.", ".##oo##.", ".##oo##.", ".######.", "..####..", "...##..."],
}

func _eye_texture(shape: String, flip: bool) -> Texture2D:
	var key := shape + ("_r" if flip else "_l")
	if eye_textures.has(key):
		return eye_textures[key]
	var rows: Array = EYE_SHAPES.get(shape, EYE_SHAPES["calm"])
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in range(8):
		var row: String = rows[y]
		for x in range(8):
			var c := row[7 - x] if flip else row[x]
			if c == "#":
				img.set_pixel(x, y, Color(1, 1, 1, 1))
			elif c == "o":
				img.set_pixel(x, y, Color(0.12, 0.06, 0.1, 1))
	var tex := ImageTexture.create_from_image(img)
	eye_textures[key] = tex
	return tex

func _show_eyes(shape: String) -> void:
	var tint := Color(1.0, 0.22, 0.18) if shape == "rage" else eye_color
	for eye in eyes:
		var m: StandardMaterial3D = eye.material_override
		m.albedo_texture = _eye_texture(shape, int(eye.get_meta("side")) > 0)
		m.albedo_color = tint

# Stimmung zeigen; duration < 0 = bleibt, sonst danach zurück zur Grundstimmung
func set_mood(shape: String, duration: float = -1.0) -> void:
	mood_now = shape
	mood_timer = duration
	_show_eyes(shape)

func idle_mood() -> String:
	if arena.rooted:
		return "wide"
	return "rage" if arena.raging else base_mood

# --- Bewegung -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	time += delta
	# Herz des Wurzelhirten pulsiert, offen viel stärker
	if heart_material != null:
		var open: bool = arena.rooted
		var beat := 0.5 + 0.5 * sin(time * (6.0 if open or arena.raging else 2.6))
		heart_material.emission_energy_multiplier = (3.2 + beat * 2.6) if open else (1.8 + beat * 0.9)
		heart_light.light_energy = 0.0 if arena.dead else ((3.5 + beat * 2.0) if open else (0.2 + beat * 0.2))
	if mood_timer > 0.0:
		mood_timer -= delta
		if mood_timer <= 0.0:
			set_mood(idle_mood())
	# Blinzeln (nicht, wenn gerade eine besondere Stimmung gezeigt wird)
	blink_timer -= delta
	if blink_timer <= 0.0 and mood_timer <= 0.0 and not arena.dead:
		_show_eyes("blink")
		await get_tree().create_timer(0.12).timeout
		if mood_timer <= 0.0 and not arena.dead:
			_show_eyes(mood_now)
		blink_timer = randf_range(2.0, 4.5)
	# Augen schweben leicht und unabhängig voneinander
	for eye in eyes:
		var side := float(eye.get_meta("side"))
		eye.position.y = sin(time * 2.2 + side) * 0.04
		eye.position.z = 0.05 + sin(time * 1.3 + side * 2.0) * 0.03
	if eye_holder != null:
		# Augen schauen immer zur Kamera
		var cam: Camera3D = arena.camera
		if cam != null:
			var to_cam: Vector3 = cam.global_position - eye_holder.global_position
			eye_holder.global_rotation = Vector3(0, atan2(to_cam.x, to_cam.z), 0)
	for s in swingers:
		var node: Node3D = s["node"]
		match str(s["kind"]):
			"pendulum":
				var speed := float(s["speed"]) * (1.8 if arena.raging else 1.0)
				node.rotation_degrees.z = sin(time * speed) * float(s["amount"])
				node.rotation_degrees.x = sin(time * speed * 0.7) * float(s["amount"]) * 0.4
			"turn":
				node.rotation_degrees.y = 45.0 + sin(time * float(s["speed"])) * float(s["amount"])
			"orbit":
				var a := float(s["angle"]) + time * float(s["speed"]) * (1.6 if arena.raging else 1.0)
				node.position = Vector3(cos(a) * float(s["radius"]), float(s["height"]) + sin(time * 1.8 + a) * 0.2, sin(a) * float(s["radius"]) * 0.6)
				if s.has("spin"):
					node.rotation_degrees.z += float(s["spin"]) * get_process_delta_time() * (2.0 if arena.raging else 1.0)
				else:
					node.rotation_degrees.z = sin(time * 3.0 + a) * 15.0
			"tilt":
				node.rotation_degrees.z = sin(time * float(s["speed"])) * float(s["amount"])
			"jaw":
				# Kiefer klappert beim Ausholen und im Wutmodus
				var open := 0.12 if (arena.busy or arena.raging) else 0.03
				node.position.y = float(s["y"]) - absf(sin(time * (14.0 if arena.busy else 2.0))) * open
			"look":
				# Pupillen schauen in den Augenhöhlen herum
				node.position.x = float(s["x"]) + sin(time * 0.7) * 0.09 + sin(time * 2.3) * 0.03

# Tod: Teile fliegen auseinander, Augen erlöschen
func shatter() -> void:
	set_mood("hurt")
	for part in parts:
		if not is_instance_valid(part):
			continue
		var dir := Vector3(randf_range(-1, 1), randf_range(0.2, 1.2), randf_range(-0.4, 1.0)).normalized()
		var tween := part.create_tween().set_parallel(true)
		tween.tween_property(part, "position", part.position + dir * randf_range(1.0, 2.5), 1.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(part, "rotation_degrees", part.rotation_degrees + Vector3(randf_range(-180, 180), randf_range(-180, 180), randf_range(-180, 180)), 1.4)
	var fade := create_tween()
	fade.tween_interval(0.6)
	fade.tween_callback(func():
		for eye in eyes:
			eye.visible = false)

# Fallende Glocke für den Angriff "bell" (statt des Modells aus dem alten Projekt)
func falling_bell() -> Node3D:
	var bell := Node3D.new()
	var amber := material(Color("#e6a84d"))
	var bronze := material(Color("#e6a84d").darkened(0.45), 0.35)
	var mesh_a := MeshInstance3D.new()
	mesh_a.mesh = frustum(0.85, 0.55, 0.8)
	mesh_a.material_override = amber
	mesh_a.position.y = 0.4
	bell.add_child(mesh_a)
	var mesh_b := MeshInstance3D.new()
	mesh_b.mesh = frustum(0.52, 0.28, 0.45)
	mesh_b.material_override = bronze
	mesh_b.position.y = 1.02
	bell.add_child(mesh_b)
	var rim := MeshInstance3D.new()
	rim.mesh = ring(0.78, 0.95)
	rim.material_override = bronze
	bell.add_child(rim)
	return bell
