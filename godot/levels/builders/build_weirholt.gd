extends SceneTree

# Builds the greybox Riverlands town of Weirholt and the culvert under its docks:
#   levels/weirholt.tscn, levels/weirholt_culvert.tscn
# Run from the godot folder:
#   godot --headless --path . -s levels/builders/build_weirholt.gd
# Everything is boxes and capsules until there's art; edit the layout here and
# re-run rather than hand-editing the .tscn files. docs/godot-starter/RIVERLANDS.md.

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
	PLAYER = load("res://player/player.tscn")
	BANDIT = load("res://enemies/bandit.tscn")
	ATMOSPHERE = load("res://levels/atmosphere.tres")
	_save(_build_town(), "res://levels/weirholt.tscn")
	_save(_build_culvert(), "res://levels/weirholt_culvert.tscn")
	return true


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


# --- Weirholt ----------------------------------------------------------------------------

const STONE := Color(0.42, 0.41, 0.4)
const DARK_STONE := Color(0.3, 0.3, 0.31)
const WOOD := Color(0.36, 0.24, 0.13)
const PLASTER := Color(0.72, 0.66, 0.55)
const ROOF := Color(0.32, 0.18, 0.12)
const SLATE := Color(0.22, 0.24, 0.27)
const GRASS := Color(0.3, 0.42, 0.22)
const WATER := Color(0.16, 0.3, 0.38, 0.75)


func _build_town() -> Node3D:
	scene = Node3D.new()
	scene.name = "Weirholt"
	scene.add_to_group("navmesh_source", true)
	common("Weirholt", true)

	# Ground on both banks of the Greywater, the river between (x 22..34, flowing south).
	box("GroundWest", Vector3(82, 1, 120), Vector3(-19, -0.5, 0), GRASS)
	box("GroundEast", Vector3(26, 1, 120), Vector3(47, -0.5, 0), GRASS)
	box("RiverBed", Vector3(12, 1, 120), Vector3(28, -1.9, 0), Color(0.25, 0.22, 0.18), "surface_stone")
	var water := MeshInstance3D.new()
	water.name = "River"
	var wm := BoxMesh.new()
	wm.size = Vector3(12, 0.1, 120)
	wm.material = mat(WATER, true)
	water.mesh = wm
	water.position = Vector3(28, -0.35, 0)
	own(water)
	box("Ford", Vector3(12, 0.6, 4), Vector3(28, -0.5, 44), Color(0.4, 0.37, 0.32), "surface_stone")
	box("Road", Vector3(6, 0.04, 30), Vector3(0, 0.02, -45), Color(0.4, 0.33, 0.24))

	# Town walls (the river is the east side).
	box("WallNorthW", Vector3(30, 4, 1), Vector3(-19, 2, -34), STONE, "surface_stone")
	box("WallNorthE", Vector3(16, 4, 1), Vector3(12, 2, -34), STONE, "surface_stone")
	box("WallSouthW", Vector3(30, 4, 1), Vector3(-19, 2, 34), STONE, "surface_stone")
	box("WallSouthE", Vector3(16, 4, 1), Vector3(12, 2, 34), STONE, "surface_stone")
	box("WallWest", Vector3(1, 4, 69), Vector3(-34, 2, 0), STONE, "surface_stone")
	box("GatePostNW", Vector3(1.2, 5, 1.2), Vector3(-4.6, 2.5, -34), DARK_STONE, "surface_stone")
	box("GatePostNE", Vector3(1.2, 5, 1.2), Vector3(4.6, 2.5, -34), DARK_STONE, "surface_stone")
	box("GatePostSW", Vector3(1.2, 5, 1.2), Vector3(-4.6, 2.5, 34), DARK_STONE, "surface_stone")
	box("GatePostSE", Vector3(1.2, 5, 1.2), Vector3(4.6, 2.5, 34), DARK_STONE, "surface_stone")

	# The weir and the mill.
	box("Weir", Vector3(12, 1.6, 1.6), Vector3(28, -0.6, 0), DARK_STONE, "surface_stone")
	house("Mill", Vector3(6, 5, 8), Vector3(16, 0, -2), PLASTER, ROOF)
	var wheel := MeshInstance3D.new()
	wheel.name = "Waterwheel"
	var cyl := CylinderMesh.new()
	cyl.top_radius = 2.2
	cyl.bottom_radius = 2.2
	cyl.height = 0.6
	cyl.material = mat(WOOD)
	wheel.mesh = cyl
	wheel.position = Vector3(20.4, 0.8, -2)
	wheel.rotation.z = PI / 2.0
	own(wheel)
	examine("Millstone", "Look at the new millstone", "", "res://dialogue/weirholt_millstone.json",
			Vector3(1.4, 0.5, 1.4), Vector3(17, 0.25, 3.2), Color(0.55, 0.55, 0.62))

	# The market square.
	box("WennaStall", Vector3(3, 1, 1.2), Vector3(-4, 0.5, 3), WOOD, "surface_wood")
	box("Stall2", Vector3(3, 1, 1.2), Vector3(4, 0.5, 4), WOOD, "surface_wood")
	signpost("NoticeBoard", "WEIRHOLT, on the Greywater.\nTolls by order of the River Compact: 2 coppers a cart, 5 a barge.\nThe Lantern Weir: beds and supper.\nFever in the Lanes. Keep your distance. - A. Fenn, physician",
			Vector3(0, 1.4, -4), PI)
	lantern("LanternSquare", Vector3(2, 0, 0))

	# The Lantern Weir (inn): open at the front, a bed inside.
	box("InnBack", Vector3(10, 4, 0.5), Vector3(-14, 2, -21), PLASTER, "surface_wood")
	box("InnSideW", Vector3(0.5, 4, 7), Vector3(-19, 2, -17.5), PLASTER, "surface_wood")
	box("InnSideE", Vector3(0.5, 4, 7), Vector3(-9, 2, -17.5), PLASTER, "surface_wood")
	box("InnRoof", Vector3(11, 0.4, 8), Vector3(-14, 4.2, -17.5), ROOF, "surface_wood")
	box("InnCounter", Vector3(4, 1.1, 0.8), Vector3(-12, 0.55, -16.5), WOOD, "surface_wood")
	var room := Node3D.new()   # the bed's there once you've paid Hedda for it
	room.name = "InnRoom"
	room.set_script(PRESENCE)
	room.set("show_flag", "inn_room")
	own(room)
	box("InnBed", Vector3(1.2, 0.5, 2.2), Vector3(-17.5, 0.25, -19), Color(0.5, 0.2, 0.18), "surface_wood", room, BED)
	lantern("LanternInn", Vector3(-8, 0, -13))

	# The River Compact's counting house.
	house("CountingHouse", Vector3(8, 4.5, 6), Vector3(8, 0, -19), Color(0.6, 0.55, 0.45), SLATE)
	signpost("CompactSign", "The River Compact. Weirholt counting house.\nTolls, manifests, licences.", Vector3(8, 1.6, -15.9), PI)

	# The Lanes: the Passengers' quarter, south-west.
	house("LanesHouseA", Vector3(5, 3.5, 5), Vector3(-25, 0, 10), Color(0.55, 0.5, 0.45), SLATE)
	house("LanesHouseB", Vector3(5, 3.5, 5), Vector3(-27, 0, 21), Color(0.5, 0.47, 0.44), SLATE)
	house("LanesHouseC", Vector3(5, 3.5, 4), Vector3(-17, 0, 26), Color(0.52, 0.48, 0.44), SLATE)
	examine("LanesWell", "Look into the well", "", "res://dialogue/weirholt_well.json",
			Vector3(1.6, 1, 1.6), Vector3(-21, 0.5, 17), DARK_STONE)
	house("Surgery", Vector3(5, 3.5, 4), Vector3(-10, 0, 7), PLASTER, ROOF)

	# Barracks and the toll-fort.
	house("Barracks", Vector3(8, 4, 5), Vector3(-12, 0, 26), Color(0.48, 0.46, 0.42), SLATE)
	box("TollTower", Vector3(6, 8, 6), Vector3(15, 4, 28), DARK_STONE, "surface_stone")
	box("TollHut", Vector3(4, 3, 3), Vector3(8, 1.5, 27.5), WOOD, "surface_wood")
	var strongbox := box("TollStrongbox", Vector3(0.9, 0.6, 0.6), Vector3(8, 0.3, 29.4), Color(0.3, 0.22, 0.12), "surface_wood", null, LOOT)
	strongbox.set("container_name", "toll strongbox")
	strongbox.set("contents", {"toll_ledger": 1})
	strongbox.set("gold", 15)
	strongbox.set("lock_level", 1)
	lantern("LanternToll", Vector3(5, 0, 31))

	# The docks and the barge Heron.
	box("Docks", Vector3(8, 0.3, 14), Vector3(24, -0.15, 19), WOOD, "surface_wood")
	box("Heron", Vector3(4.5, 1, 10), Vector3(30.8, -0.5, 19), Color(0.3, 0.2, 0.12), "surface_wood")
	examine("HeronCrates", "Look at the sealed crates", "", "res://dialogue/weirholt_heron.json",
			Vector3(2, 1.2, 2.4), Vector3(30.8, 0.6, 20), Color(0.42, 0.3, 0.16))
	door("CulvertGrate", "res://levels/weirholt_culvert.tscn", "FromWeirholt", "the culvert", "Climb down into",
			Vector3(1.6, 0.2, 1.6), Vector3(19, 0.1, 27), Color(0.2, 0.2, 0.22))
	marker("FromCulvert", Vector3(17.5, 0, 25), PI / 2.0)
	lantern("LanternDocks", Vector3(21, 0, 13), Color(0.8, 0.85, 1.0))

	# People.
	npc("Hedda", "Hedda Marrow", "res://dialogue/hedda.json", Vector3(-12, 0, -17.5), Color(0.6, 0.35, 0.3), PI)
	var tarle_presence := Node3D.new()
	tarle_presence.name = "TarlePresence"
	tarle_presence.set_script(PRESENCE)
	tarle_presence.set("hide_flag", "tarle_gone")
	own(tarle_presence)
	npc("Tarle", "Factor Tarle", "res://dialogue/tarle.json", Vector3(8, 0, -14.8), Color(0.3, 0.32, 0.45), PI, tarle_presence)
	npc("Wenna", "Wenna Pike", "res://dialogue/wenna.json", Vector3(-4, 0, 4.2), Color(0.55, 0.5, 0.25), PI)
	npc("Varga", "Captain Varga", "res://dialogue/varga.json", Vector3(-8, 0, 22), Color(0.45, 0.1, 0.12), PI)
	npc("Dace", "Sergeant Dace", "res://dialogue/dace.json", Vector3(5.5, 0, 28), Color(0.4, 0.15, 0.15), -PI / 2.0)
	npc("Ama", "Goodwife Ama", "res://dialogue/ama.json", Vector3(2, 0, 38), Color(0.45, 0.4, 0.25))
	npc("Teodor", "Teodor", "res://dialogue/teodor.json", Vector3(-20, 0, 13), Color(0.55, 0.55, 0.6), PI / 2.0)
	npc("Fenn", "Physician Fenn", "res://dialogue/fenn.json", Vector3(-10, 0, 9.5), Color(0.2, 0.2, 0.2), PI)
	npc("JoryDocks", "Jory Vell", "res://dialogue/jory_weirholt.json", Vector3(22.5, 0.15, 16), Color(0.6, 0.5, 0.2), -PI / 2.0)

	# The way back north, and where you arrive from it.
	door("NorthRoad", "res://levels/test_level.tscn", "FromWeirholt", "the Greywater Vale", "Take the north road to",
			Vector3(3, 2, 0.4), Vector3(0, 1, -57), Color(0.45, 0.32, 0.18))
	marker("FromVale", Vector3(0, 0, -52), PI)
	signpost("RoadSign", "North: the Greywater Vale, Riverwatch and the waystation.\nSouth: Weirholt.", Vector3(3, 1.4, -50), PI)

	# The map.
	var level_map := Node.new()
	level_map.name = "LevelMap"
	level_map.set_script(LEVEL_MAP)
	level_map.set("map_name", "Weirholt")
	level_map.set("area", Rect2(-60, -60, 120, 120))
	own(level_map)
	map_marker("MapWeirholt", "weirholt", "Weirholt", Vector3(0, 0, 0), 1, true)
	map_marker("MapInn", "lantern_weir", "The Lantern Weir", Vector3(-14, 0, -17))
	map_marker("MapCountingHouse", "counting_house", "Compact counting house", Vector3(8, 0, -19))
	map_marker("MapDocks", "weirholt_docks", "The docks", Vector3(24, 0, 19))
	map_marker("MapTollFort", "toll_fort", "The toll-fort", Vector3(15, 0, 28))
	map_marker("MapLanes", "the_lanes", "The Lanes", Vector3(-22, 0, 17))
	map_marker("MapMill", "weirholt_mill", "The mill", Vector3(16, 0, -2))

	var player: Node3D = PLAYER.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.position = Vector3(0, 1, -50)
	own(player)
	return scene


# --- the culvert -------------------------------------------------------------------------

func _build_culvert() -> Node3D:
	scene = Node3D.new()
	scene.name = "WeirholtCulvert"
	scene.add_to_group("navmesh_source", true)
	common("WeirholtCulvert", false)
	var stone := Color(0.25, 0.25, 0.26)
	# A tunnel running south (z 0..36), a side chamber east at the far end.
	box("Floor", Vector3(8, 0.5, 40), Vector3(0, -0.25, 18), stone, "surface_stone")
	box("Ceiling", Vector3(8, 0.5, 40), Vector3(0, 3.25, 18), stone, "surface_stone")
	box("WallW", Vector3(0.5, 3, 40), Vector3(-4, 1.5, 18), stone, "surface_stone")
	box("WallE", Vector3(0.5, 3, 28), Vector3(4, 1.5, 14), stone, "surface_stone")
	box("WallN", Vector3(8, 3, 0.5), Vector3(0, 1.5, -2), stone, "surface_stone")
	box("WallS", Vector3(16, 3, 0.5), Vector3(4, 1.5, 38), stone, "surface_stone")
	box("ChamberFloor", Vector3(8, 0.5, 10), Vector3(8, -0.25, 33), stone, "surface_stone")
	box("ChamberCeiling", Vector3(8, 0.5, 10), Vector3(8, 3.25, 33), stone, "surface_stone")
	box("ChamberWallE", Vector3(0.5, 3, 10), Vector3(12, 1.5, 33), stone, "surface_stone")
	box("ChamberWallN", Vector3(8, 3, 0.5), Vector3(8, 1.5, 28), stone, "surface_stone")
	var channel := MeshInstance3D.new()
	channel.name = "Runoff"
	var cm := BoxMesh.new()
	cm.size = Vector3(1.4, 0.05, 38)
	cm.material = mat(WATER, true)
	channel.mesh = cm
	channel.position = Vector3(-2.8, 0.03, 18)
	own(channel)
	for i in 4:
		var light := OmniLight3D.new()
		light.name = "Lamp%d" % (i + 1)
		light.set_script(FLICKER)
		light.light_color = Color(1, 0.7, 0.4)
		light.light_energy = 1.2
		light.omni_range = 8.0
		light.position = Vector3(3.2, 2.4, 4 + i * 9)
		own(light)

	# The smugglers moving the barges' cargo.
	var pack := Node3D.new()
	pack.name = "Smugglers"
	pack.set_script(PACK)
	pack.set("cleared_flag", "culvert_cleared")
	pack.set("cleared_message", "The culvert goes quiet, apart from the water.")
	own(pack)
	var spots := [Vector3(1, 0, 14), Vector3(-1.5, 0, 20), Vector3(7, 0, 33)]
	for i in spots.size():
		var b: Node3D = BANDIT.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
		b.name = "Smuggler%d" % (i + 1)
		b.set("display_name", "Smuggler" if i < 2 else "Smuggler Boss")
		b.position = spots[i]
		b.rotation.y = PI
		if i == 2:
			b.set("max_health", 90.0)
			b.set("attack_damage", 13.0)
			b.set("gold", 25)
		pack.add_child(b)
		b.owner = scene

	# The cages and the ledger.
	for i in 3:
		box("Cage%d" % (i + 1), Vector3(1, 1.2, 1), Vector3(10.5, 0.6, 30 + i * 2), Color(0.18, 0.18, 0.2))
	examine("Cages", "Look at the cages", "", "res://dialogue/weirholt_cages.json",
			Vector3(0.6, 0.6, 0.6), Vector3(10.5, 1.5, 32), Color(0.75, 0.85, 1.0))
	var glow := OmniLight3D.new()
	glow.name = "CageGlow"
	glow.light_color = Color(0.7, 0.85, 1.0)
	glow.light_energy = 1.5
	glow.omni_range = 5.0
	glow.position = Vector3(10, 1.5, 32)
	own(glow)
	var chest := box("LedgerChest", Vector3(1.2, 0.7, 0.8), Vector3(6, 0.35, 36.8), Color(0.32, 0.22, 0.12), "surface_wood", null, LOOT)
	chest.set("container_name", "smugglers' chest")
	chest.set("contents", {"harvest_ledger": 1, "minor_healing_potion": 1})
	chest.set("gold", 40)

	door("Ladder", "res://levels/weirholt.tscn", "FromCulvert", "Weirholt", "Climb up to",
			Vector3(1.2, 3, 0.3), Vector3(0, 1.5, -1.6), Color(0.35, 0.25, 0.15))
	marker("FromWeirholt", Vector3(0, 0, 1), PI)

	var level_map := Node.new()
	level_map.name = "LevelMap"
	level_map.set_script(LEVEL_MAP)
	level_map.set("map_name", "The culvert")
	level_map.set("area", Rect2(-10, -4, 26, 44))
	level_map.set("camera_height", 30.0)
	own(level_map)

	var player: Node3D = PLAYER.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.position = Vector3(0, 1, 1)
	own(player)
	return scene
