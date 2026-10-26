extends SceneTree

# Shared helpers for the greybox level builders in this folder (build_*.gd):
# boxes, houses, people, signs, doors, markers, trees, enemies, and the common
# nodes every level needs. A builder extends this and overrides build(), which
# runs on the first frame (the scripts the scenes use need the autoloads).
# docs/godot-starter/RIVERLANDS.md, "Building and editing the level".

var NPC
var SIGN
var EXAMINE
var LOCATION_DOOR
var LOOT
var BED
var MARKER
var LEVEL_MAP
var AMBIENCE
var NAV
var DAY_NIGHT
var FLICKER
var PACK
var PRESENCE
var CULTIST
var RITUAL
var WISPS
var PLAYER
var BANDIT
var ATMOSPHERE
var TEX := {}   # material kind -> its noise texture (levels/materials)
var STONE_NORMAL

var scene: Node3D
var _mats := {}


var _done := false


# On the first frame, not in _initialize: the scripts these scenes use need the
# autoloads, which aren't there yet while this script is being set up.
func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	NPC = load("res://interactables/npc.gd")
	SIGN = load("res://interactables/sign.gd")
	EXAMINE = load("res://interactables/examine.gd")
	LOCATION_DOOR = load("res://interactables/location_door.gd")
	LOOT = load("res://interactables/loot_container.gd")
	BED = load("res://interactables/bed.gd")
	MARKER = load("res://props/map_marker.gd")
	LEVEL_MAP = load("res://levels/level_map.gd")
	AMBIENCE = load("res://levels/ambience.gd")
	NAV = load("res://levels/nav_region.gd")
	DAY_NIGHT = load("res://levels/day_night.gd")
	FLICKER = load("res://props/flicker_light.gd")
	PACK = load("res://enemies/wolf_pack.gd")
	PRESENCE = load("res://props/story_presence.gd")
	CULTIST = load("res://enemies/cultist.gd")
	RITUAL = load("res://props/ritual_site.gd")
	WISPS = load("res://enemies/wisp_spawner.gd")
	PLAYER = load("res://player/player.tscn")
	BANDIT = load("res://enemies/bandit.tscn")
	ATMOSPHERE = load("res://levels/atmosphere.tres")
	for kind in ["ground", "stone", "grain"]:
		TEX[kind] = load("res://levels/materials/noise_%s.tres" % kind)
	STONE_NORMAL = load("res://levels/materials/noise_stone_normal.tres")
	build()
	return true


## Each builder builds and saves its scenes here.
func build() -> void:
	pass


func _save(scene_root: Node, path: String) -> void:
	var packed := PackedScene.new()
	var err := packed.pack(scene_root)
	if err != OK:
		push_error("pack failed for %s: %d" % [path, err])
		return
	ResourceSaver.save(packed, path)
	print("wrote ", path)
	scene_root.free()


# --- helpers --------------------------------------------------------------------------

## A material in `color`, with a noise texture over it so flat greybox surfaces read
## as surfaces: "ground" (big soft patches), "stone" (cracked, with a normal map),
## "grain" (fine grain: plaster, wood, cloth; the default) or "plain". The textures
## are world-space triplanar, so they line up across boxes of any size.
func mat(color: Color, transparent := false, kind := "grain") -> StandardMaterial3D:
	if transparent:
		kind = "plain"
	var key := "%s%s%s" % [color, transparent, kind]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		if transparent:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.15
		if TEX.has(kind):
			m.albedo_texture = TEX[kind]
			m.uv1_triplanar = true
			m.uv1_world_triplanar = true
			m.uv1_scale = Vector3.ONE * {"ground": 0.04, "stone": 0.35, "grain": 0.5}[kind]
		if kind == "stone":
			m.normal_enabled = true
			m.normal_texture = STONE_NORMAL
			m.roughness = 0.95
		if kind == "ground":
			m.roughness = 1.0
		_mats[key] = m
	return _mats[key]


func own(node: Node, parent: Node = null) -> Node:
	(parent if parent else scene).add_child(node)
	node.owner = scene
	return node


## Water (levels/materials/water.gdshader): ripples drifting with `flow` (metres a
## second, over the water's world x/z), dark looking down, bright at a glance.
func water_mat(flow := Vector2.ZERO) -> ShaderMaterial:
	var key := "water%s" % flow
	if not _mats.has(key):
		var m := ShaderMaterial.new()
		m.shader = load("res://levels/materials/water.gdshader")
		m.set_shader_parameter("ripples", load("res://levels/materials/noise_water_normal.tres"))
		m.set_shader_parameter("flow", flow * 0.07)   # into ripple-texture units (ripple_scale)
		_mats[key] = m
	return _mats[key]


## A solid box (StaticBody3D with a mesh and a collision shape) centred at `pos`.
## Its material (mat()): stone if it's surface_stone, ground if it's a big flat slab
## (grounds, roads, fields), fine grain otherwise.
func box(name: String, size: Vector3, pos: Vector3, color: Color, surface := "", parent: Node = null, script: Script = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	if script:
		body.set_script(script)
	body.position = pos
	if surface != "":
		body.add_to_group(surface, true)
	own(body, parent)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	var kind := "stone" if surface == "surface_stone" else ("ground" if size.y <= 1.0 and size.x * size.z >= 50.0 else "grain")
	box_mesh.material = mat(color, false, kind)
	mesh.mesh = box_mesh
	own(mesh, body)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	own(shape, body)
	return body


## A greybox house: a solid block (the collision) dressed as a house: a gabled roof
## along its long side with a ridge beam, dark corner posts, a door and windows on the
## side facing the middle of the level (where the streets are), windows glowing warm
## at night (props/light_stone.gd), and a chimney.
func house(name: String, size: Vector3, pos: Vector3, wall: Color, roof: Color) -> void:
	box(name, size, pos + Vector3(0, size.y / 2.0, 0), wall, "surface_wood")
	var dressing := Node3D.new()
	dressing.name = name + "Dressing"
	dressing.position = pos
	own(dressing)
	var timber := wall.darkened(0.6).lerp(Color(0.2, 0.13, 0.08), 0.6)
	# The roof: two slabs meeting at a ridge over the long side.
	var along_x := size.x >= size.z
	var span := size.z if along_x else size.x
	var length := (size.x if along_x else size.z) + 0.8
	var pitch := deg_to_rad(35.0)
	var slab := (span / 2.0 + 0.5) / cos(pitch)
	for side in [-1.0, 1.0]:
		var m := BoxMesh.new()
		m.size = Vector3(length, 0.25, slab) if along_x else Vector3(slab, 0.25, length)
		m.material = mat(roof)
		var piece := MeshInstance3D.new()
		piece.name = "Roof%s" % ("A" if side < 0 else "B")
		piece.mesh = m
		var rise := size.y + span / 4.0 * tan(pitch)
		if along_x:
			piece.position = Vector3(0, rise, side * span / 4.0)
			piece.rotation.x = side * pitch
		else:
			piece.position = Vector3(side * span / 4.0, rise, 0)
			piece.rotation.z = -side * pitch
		own(piece, dressing)
	# Gable ends: wedges of wall under the roof's ends.
	var ridge_y := size.y + span / 2.0 * tan(pitch)
	var ridge := BoxMesh.new()
	ridge.size = Vector3(length, 0.22, 0.22) if along_x else Vector3(0.22, 0.22, length)
	ridge.material = mat(timber)
	var beam := MeshInstance3D.new()
	beam.name = "Ridge"
	beam.mesh = ridge
	beam.position = Vector3(0, ridge_y + 0.05, 0)
	own(beam, dressing)
	for end in [-1.0, 1.0]:
		var gable := MeshInstance3D.new()
		gable.name = "Gable%s" % ("A" if end < 0 else "B")
		var prism := PrismMesh.new()
		prism.size = Vector3(span, ridge_y - size.y, 0.2)
		prism.material = mat(wall)
		gable.mesh = prism
		gable.position = Vector3(end * (size.x / 2.0 - 0.1), size.y + (ridge_y - size.y) / 2.0, 0) if along_x \
				else Vector3(0, size.y + (ridge_y - size.y) / 2.0, end * (size.z / 2.0 - 0.1))
		if along_x:
			gable.rotation.y = PI / 2.0
		own(gable, dressing)
	# Corner posts.
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			post.name = "Post"
			var pm := BoxMesh.new()
			pm.size = Vector3(0.22, size.y, 0.22)
			pm.material = mat(timber)
			post.mesh = pm
			post.position = Vector3(cx * (size.x / 2.0 + 0.02), size.y / 2.0, cz * (size.z / 2.0 + 0.02))
			own(post, dressing)
	# The front: the wall facing the middle of the level.
	var to_middle := Vector2(-pos.x, -pos.z)
	var front := Vector3(signf(to_middle.x), 0, 0) if absf(to_middle.x) > absf(to_middle.y) else Vector3(0, 0, signf(to_middle.y) if to_middle.y != 0.0 else 1.0)
	var half := size / 2.0
	var depth := half.x if front.x != 0.0 else half.z
	var across := Vector3(-front.z, 0, front.x)   # along the front wall
	var width := size.z if front.x != 0.0 else size.x
	var door := MeshInstance3D.new()
	door.name = "Door"
	var dm := BoxMesh.new()
	dm.size = Vector3(1.1, 2.0, 0.12)
	dm.material = mat(timber.darkened(0.3))
	door.mesh = dm
	door.position = front * (depth + 0.03) + Vector3(0, 1.0, 0)
	door.rotation.y = atan2(front.x, front.z)
	door.add_to_group("home_door", true)   # someone lives here (interactables/npc.gd routines)
	own(door, dressing)
	var windows := Node3D.new()
	windows.name = "Windows"
	windows.set_script(load("res://props/light_stone.gd"))
	windows.set("day_energy", 0.0)
	windows.set("night_energy", 1.4)
	windows.set("surface", Color(0.12, 0.11, 0.1))   # dark glass by day
	windows.set("glow", Color(1.0, 0.68, 0.35))
	own(windows, dressing)
	var panes := []
	if width > 3.5:
		panes.append(front * (depth + 0.03) + across * width * 0.3)
		panes.append(front * (depth + 0.03) - across * width * 0.3)
	panes.append(-front * (depth + 0.03))   # one at the back
	for i in panes.size():
		var w := MeshInstance3D.new()
		w.name = "Window%d" % i
		var wm := BoxMesh.new()
		wm.size = Vector3(0.7, 0.7, 0.08)
		w.mesh = wm
		w.position = panes[i] + Vector3(0, minf(1.8, size.y * 0.6), 0)
		w.rotation.y = atan2(front.x, front.z)
		own(w, windows)
	# A chimney near one end.
	var chimney := MeshInstance3D.new()
	chimney.name = "Chimney"
	var cm := BoxMesh.new()
	cm.size = Vector3(0.6, 1.8, 0.6)
	cm.material = mat(Color(0.35, 0.33, 0.32), false, "stone")
	chimney.mesh = cm
	var along := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	chimney.position = along * ((size.x if along_x else size.z) * 0.3) + Vector3(0, ridge_y - 0.1, 0) + (Vector3(0, 0, 0.5) if along_x else Vector3(0.5, 0, 0))
	own(chimney, dressing)


## Where people gather in the evening (interactables/npc.gd routines): the inn, the square.
func gathering(pos: Vector3) -> void:
	marker("Gathering", pos, 0.0)


## Give these people a day by the clock (interactables/npc.gd, Routine).
func routines(names: Array) -> void:
	for who in names:
		var person := scene.find_child(who, true, false)
		if person:
			person.set("routine", true)


func npc(name: String, display: String, dialogue: String, pos: Vector3, color: Color, facing := 0.0, parent: Node = null, look := "human/commoner") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.set_script(NPC)
	body.set("display_name", display)
	body.set("dialogue_file", dialogue)
	body.set("race", look.get_slice("/", 0))
	body.set("role", look.get_slice("/", 1))
	body.position = pos
	body.rotation.y = facing
	own(body, parent)
	var mesh := MeshInstance3D.new()
	mesh.name = "MeshInstance3D"
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	capsule.material = mat(color)
	mesh.mesh = capsule
	mesh.position.y = 0.9
	own(mesh, body)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.radius = 0.4
	capsule_shape.height = 1.8
	shape.shape = capsule_shape
	shape.position.y = 0.9
	own(shape, body)
	return body


func signpost(name: String, text: String, pos: Vector3, facing := 0.0) -> void:
	var body := box(name, Vector3(1.2, 0.7, 0.1), pos, Color(0.45, 0.32, 0.18), "surface_wood", null, SIGN)
	body.set("text", text)
	body.rotation.y = facing


func examine(name: String, prompt: String, speaker: String, dialogue: String, size: Vector3, pos: Vector3, color: Color) -> StaticBody3D:
	var body := box(name, size, pos, color, "", null, EXAMINE)
	body.set("prompt", prompt)
	body.set("speaker", speaker)
	body.set("dialogue_file", dialogue)
	return body


func door(name: String, target: String, marker: String, destination: String, verb: String, size: Vector3, pos: Vector3, color: Color) -> void:
	var body := box(name, size, pos, color, "", null, LOCATION_DOOR)
	body.set("target_scene", target)
	body.set("target_marker", marker)
	body.set("destination_name", destination)
	body.set("verb", verb)


func marker(name: String, pos: Vector3, facing := 0.0) -> void:
	var m := Marker3D.new()
	m.name = name
	m.position = pos
	m.rotation.y = facing
	own(m)


func map_marker(name: String, id: String, display: String, pos: Vector3, kind := 0, discovered := false) -> void:
	var m := Node3D.new()
	m.name = name
	m.set_script(MARKER)
	m.position = pos
	m.set("location_id", id)
	m.set("display_name", display)
	m.set("kind", kind)
	m.set("starts_discovered", discovered)
	own(m)


func lantern(name: String, pos: Vector3, color := Color(1, 0.75, 0.45)) -> void:
	box(name, Vector3(0.15, 2.6, 0.15), pos + Vector3(0, 1.3, 0), Color(0.2, 0.2, 0.22))
	var light := OmniLight3D.new()
	light.name = name + "Light"
	light.set_script(FLICKER)
	light.light_color = color
	light.light_energy = 1.4
	light.omni_range = 9.0
	light.position = pos + Vector3(0, 2.8, 0)
	own(light)


## The nodes every level needs. `mood`: an outdoor level's weather (levels/moods/<mood>.tres).
func common(level_name: String, outdoor: bool, mood := "") -> void:
	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	if outdoor:
		env.environment = ATMOSPHERE
	else:
		var e := Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.02, 0.02, 0.025)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.3, 0.32, 0.35)
		e.ambient_light_energy = 0.45
		e.tonemap_mode = Environment.TONE_MAPPER_ACES
		e.glow_enabled = true
		env.environment = e
	own(env)
	if outdoor:
		var sun := DirectionalLight3D.new()
		sun.name = "Sun"
		sun.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-40), deg_to_rad(25), 0)), Vector3(0, 10, 0))
		sun.light_color = Color(1, 0.84, 0.66)
		sun.light_energy = 1.6
		sun.shadow_enabled = true
		sun.directional_shadow_max_distance = 80.0
		own(sun)
		var dn := Node.new()
		dn.name = "DayNight"
		dn.set_script(DAY_NIGHT)
		if mood != "":
			dn.set("mood", load("res://levels/moods/%s.tres" % mood))
		own(dn)
	var nav := NavigationRegion3D.new()
	nav.name = "NavigationRegion3D"
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_WITH_CHILDREN
	nm.geometry_source_group_name = &"navmesh_source"
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.agent_height = 1.0
	nm.agent_radius = 0.5
	nm.agent_max_climb = 0.5
	nav.navigation_mesh = nm
	nav.set_script(NAV)
	own(nav)
	var amb := Node.new()
	amb.name = "Ambience"
	amb.set_script(AMBIENCE)
	amb.set("indoor", not outdoor)
	own(amb)


## The ground going on past the level's edge to the horizon (no collision; the
## level's own edges stop you), so the sky's dark underside never shows. Under
## everything, below rivers and cellars' tops.
func skirt(color: Color) -> void:
	var plane := MeshInstance3D.new()
	plane.name = "GroundSkirt"
	var m := PlaneMesh.new()
	m.size = Vector2(1600, 1600)
	m.material = mat(color, false, "ground")
	plane.mesh = m
	plane.position.y = -1.2
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	own(plane)


## Grass, flowers and stones on the bodies in the "ground_cover" group, over `area`
## (props/ground_cover.gd).
func ground_cover(style: String, area: Rect2) -> void:
	var cover := Node3D.new()
	cover.name = "GroundCover"
	cover.set_script(load("res://props/ground_cover.gd"))
	cover.set("style", style)
	cover.set("area", area)
	own(cover)


# --- trees and enemies -------------------------------------------------------------------

const TRUNK := Color(0.3, 0.2, 0.12)
const LEAVES := Color(0.18, 0.32, 0.16)


func tree(name: String, pos: Vector3, height: float) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos
	body.add_to_group("surface_wood", true)
	own(body)
	var trunk := MeshInstance3D.new()
	trunk.name = "Trunk"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.35
	cyl.height = height
	cyl.material = mat(TRUNK)
	trunk.mesh = cyl
	trunk.position.y = height / 2.0
	own(trunk, body)
	var crown := MeshInstance3D.new()
	crown.name = "Crown"
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.8
	cone.height = height * 0.8
	cone.material = mat(LEAVES)
	crown.mesh = cone
	crown.position.y = height * 0.9
	own(crown, body)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var cs := CylinderShape3D.new()
	cs.radius = 0.35
	cs.height = height
	shape.shape = cs
	shape.position.y = height / 2.0
	own(shape, body)


func enemy(parent: Node, name: String, display: String, pos: Vector3, facing: float, script: Script = null, props := {}) -> void:
	var b: Node3D = BANDIT.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	b.name = name
	if script:
		b.set_script(script)
	b.set("display_name", display)
	for key in props:
		b.set(key, props[key])
	b.position = pos
	b.rotation.y = facing
	parent.add_child(b)
	b.owner = scene
