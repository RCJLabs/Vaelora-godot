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

func mat(color: Color, transparent := false) -> StandardMaterial3D:
	var key := "%s%s" % [color, transparent]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.9
		if transparent:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats[key] = m
	return _mats[key]


func own(node: Node, parent: Node = null) -> Node:
	(parent if parent else scene).add_child(node)
	node.owner = scene
	return node


## A solid box (StaticBody3D with a mesh and a collision shape) centred at `pos`.
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
	box_mesh.material = mat(color)
	mesh.mesh = box_mesh
	own(mesh, body)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	own(shape, body)
	return body


## A greybox house: a solid block with a darker roof slab on top.
func house(name: String, size: Vector3, pos: Vector3, wall: Color, roof: Color) -> void:
	box(name, size, pos + Vector3(0, size.y / 2.0, 0), wall, "surface_wood")
	var slab := MeshInstance3D.new()
	slab.name = name + "Roof"
	var m := BoxMesh.new()
	m.size = Vector3(size.x + 0.6, 0.4, size.z + 0.6)
	m.material = mat(roof)
	slab.mesh = m
	slab.position = pos + Vector3(0, size.y + 0.2, 0)
	own(slab)


func npc(name: String, display: String, dialogue: String, pos: Vector3, color: Color, facing := 0.0, parent: Node = null) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = name
	body.set_script(NPC)
	body.set("display_name", display)
	body.set("dialogue_file", dialogue)
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


func common(level_name: String, outdoor: bool) -> void:
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
