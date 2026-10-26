extends "res://levels/builders/builder_base.gd"

# Builds the greybox of Ithmarren, the elves' city in the canopy of a forest of
# giant trees, and the Rootwell under its Moot Tree, where House Sennaveth keeps
# the city's well, badly:
#   levels/ithmarren.tscn, levels/ithmarren_rootwell.tscn
# Run from the godot folder:
#   godot --headless --path . -s levels/builders/build_ithmarren.gd
# docs/godot-starter/ITHMARREN.md.
#
# The city (y up, north is -z): the forest floor (y 0), where the Hollow Way comes
# out of the mountain's foot, and a stair up to the boughs:
#   the Gate Landing (y 12)       the Hanging Lantern (an inn), the Bough Warden
#   the Lantern Gardens (y 12)    Tamsin's stall, Fennick's night-blooms
#   the Veil Terrace (y 12)       the Veil College (Glamour)
#   the Moot Hall (y 20)          the Moot-Speaker, round the Moot Tree
#   the Sennaveth Bough (y 20)    House Sennaveth
# and at the Moot Tree's roots, on the forest floor, the Root Door.

const BARK := Color(0.33, 0.25, 0.18)
const LEAF := Color(0.22, 0.36, 0.18)
const DECK := Color(0.42, 0.32, 0.2)
const GROWN := Color(0.4, 0.42, 0.28)   # walls grown, not built
const GROWN_ROOF := Color(0.24, 0.34, 0.2)
const FLOOR := Color(0.2, 0.26, 0.14)
const LANTERN := Color(0.85, 1.0, 0.6)
const SENNAVETH := Color(0.42, 0.18, 0.3)

var LIGHT_STONE


func build() -> void:
	LIGHT_STONE = load("res://props/light_stone.gd")
	_save(_build_city(), "res://levels/ithmarren.tscn")
	_save(_build_rootwell(), "res://levels/ithmarren_rootwell.tscn")


## A giant tree: a trunk from the roots up past the city, and a crown high above.
func trunk(name: String, pos: Vector3, radius: float, height := 62.0) -> void:
	var body := StaticBody3D.new()
	body.name = name
	body.position = pos + Vector3(0, height / 2.0 - 1.0, 0)
	body.add_to_group("surface_wood", true)
	own(body)
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius * 0.8
	cyl.bottom_radius = radius * 1.15
	cyl.height = height
	cyl.radial_segments = 14
	cyl.material = mat(BARK)
	mesh.mesh = cyl
	own(mesh, body)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var cs := CylinderShape3D.new()
	cs.radius = radius
	cs.height = height
	shape.shape = cs
	own(shape, body)
	var leaves := MeshInstance3D.new()   # not "Crown": the pine dresser leaves it alone
	leaves.name = name + "Leaves"
	var sm := SphereMesh.new()
	sm.radius = radius * 4.0
	sm.height = radius * 3.0
	sm.material = mat(LEAF)
	leaves.mesh = sm
	leaves.position = pos + Vector3(0, height - 4.0, 0)
	leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # let the light through to the boughs
	own(leaves)


## A low rail from a to b (on a deck at their height).
func rail(name: String, a: Vector3, b: Vector3) -> void:
	if a.distance_to(b) < 0.3:
		return
	var body := box(name, Vector3(0.25, 1.0, a.distance_to(b)), (a + b) / 2.0 + Vector3(0, 0.5, 0), BARK, "surface_wood")
	body.rotation.y = atan2(b.x - a.x, b.z - a.z)


## A deck round (or beside) a trunk: (x0, z0)-(x1, z1) at `top`, railed on every
## edge except a 4 m gap at each point in `gaps` (where walkways join).
func platform(name: String, x0: float, x1: float, z0: float, z1: float, top: float, gaps: Array) -> void:
	box(name, Vector3(x1 - x0, 0.6, z1 - z0), Vector3((x0 + x1) / 2.0, top - 0.3, (z0 + z1) / 2.0), DECK, "surface_wood")
	var edges := [[Vector3(x0, top, z0), Vector3(x1, top, z0)], [Vector3(x1, top, z0), Vector3(x1, top, z1)],
			[Vector3(x1, top, z1), Vector3(x0, top, z1)], [Vector3(x0, top, z1), Vector3(x0, top, z0)]]
	var n := 0
	for edge in edges:
		var a: Vector3 = edge[0]
		var b: Vector3 = edge[1]
		var length := a.distance_to(b)
		var cuts := []   # [from, to] along the edge, in metres
		for g in gaps:
			var p := Vector3(g.x, top, g.z)
			var t := (p - a).dot((b - a).normalized())
			var off := ((a + (b - a).normalized() * t) - p).length()
			if off < 0.6 and t > -2.0 and t < length + 2.0:
				cuts.append([t - 2.0, t + 2.0])
		cuts.sort_custom(func(x, y): return x[0] < y[0])
		var at := 0.0
		for c in cuts:
			if c[0] > at:
				n += 1
				rail("%sRail%d" % [name, n], a.lerp(b, at / length), a.lerp(b, minf(c[0], length) / length))
			at = maxf(at, c[1])
		if at < length:
			n += 1
			rail("%sRail%d" % [name, n], a.lerp(b, at / length), b)


## A walkway (a bridge, or a stair if the ends differ in height) from a to b, railed.
func walkway(name: String, a: Vector3, b: Vector3, width := 3.0) -> void:
	var d := b - a
	var basis := Basis.looking_at(d.normalized(), Vector3.UP)
	var mid := (a + b) / 2.0
	var body := box(name, Vector3(width, 0.4, d.length()), Vector3.ZERO, DECK, "surface_wood")
	body.transform = Transform3D(basis, mid - basis.y * 0.2)
	for side in [-1.0, 1.0]:
		var r := box("%sRail%s" % [name, "L" if side < 0 else "R"], Vector3(0.2, 1.0, d.length()), Vector3.ZERO, BARK, "surface_wood")
		r.transform = Transform3D(basis, mid + basis.y * 0.5 + basis.x * side * (width / 2.0 - 0.1))


## A string of garden lanterns (light-stone: dimmer by day, and dimmed for good
## once `dim_flag` is set).
func lanterns(name: String, points: Array, dim_flag := "well_unbound") -> void:
	var group := Node3D.new()
	group.name = name
	group.set_script(LIGHT_STONE)
	group.set("dim_flag", dim_flag)
	group.set("surface", LANTERN)
	group.set("glow", Color(0.75, 1.0, 0.55))
	own(group)
	for i in points.size():
		var m := MeshInstance3D.new()
		m.name = "Lantern%d" % (i + 1)
		var sm := SphereMesh.new()
		sm.radius = 0.22
		sm.height = 0.44
		m.mesh = sm
		m.position = points[i]
		own(m, group)
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = Color(0.75, 1.0, 0.55)
	glow.light_energy = 1.6
	glow.omni_range = 14.0
	var centre := Vector3.ZERO
	for pt in points:
		centre += pt
	glow.position = centre / points.size()
	own(glow, group)


func _build_city() -> Node3D:
	scene = Node3D.new()
	scene.name = "Ithmarren"
	scene.add_to_group("navmesh_source", true)
	common("Ithmarren", true, "canopy")
	box("Ground", Vector3(200, 1, 200), Vector3(0, -0.5, 0), FLOOR).add_to_group("ground_cover", true)
	ground_cover("meadow", Rect2(-100, -100, 200, 200))
	skirt(FLOOR)

	# The forest: the city's five trees, and the ones round it.
	trunk("GateTree", Vector3(0, 0, 20), 3.0)
	trunk("GardenTree", Vector3(-33, 0, 0), 3.5)
	trunk("VeilTree", Vector3(21, 0, 0), 3.5)
	trunk("MootTree", Vector3(0, 0, -26), 5.0, 70.0)
	trunk("SennavethTree", Vector3(27, 0, -30), 3.5)
	for t in [["Wild1", Vector3(-55, 0, -40), 4.0], ["Wild2", Vector3(55, 0, 30), 4.0], ["Wild3", Vector3(-50, 0, 45), 3.0],
			["Wild4", Vector3(50, 0, -62), 4.0], ["Wild5", Vector3(-22, 0, -62), 3.0], ["Wild6", Vector3(62, 0, -10), 3.5],
			["Wild7", Vector3(-70, 0, 5), 3.5], ["Wild8", Vector3(24, 0, 58), 3.0]]:
		trunk(t[0], t[1], t[2])

	# The mountain's foot, and the Hollow Way back through it to Karrowdeep.
	box("MountainFoot", Vector3(90, 24, 12), Vector3(0, 11, 94), Color(0.3, 0.29, 0.3), "surface_stone")
	door("HollowWay", "res://levels/karrowdeep.tscn", "FromIthmarren", "Karrowdeep", "Take the Hollow Way to",
			Vector3(3.5, 3.5, 0.4), Vector3(0, 1.75, 87.8), Color(0.3, 0.24, 0.18))
	marker("FromKarrowdeep", Vector3(0, 0, 83), 0.0)
	signpost("ForestSign", "ITHMARREN.\nThe Houses' city is above you. Climb.\nThe Root Door, under the Moot Tree: by the Houses' leave only.", Vector3(5, 1.4, 70), 0.0)
	box("Road", Vector3(4, 0.04, 30), Vector3(0, 0.02, 70), Color(0.32, 0.28, 0.2))

	# Up into the boughs.
	walkway("BoughStair", Vector3(12, 0, 52), Vector3(5, 12, 27), 3.0)
	platform("GateLanding", -9, 9, 13, 27, 12.0, [Vector3(5, 12, 27), Vector3(-9, 12, 17), Vector3(9, 12, 17)])
	platform("LanternGardens", -36, -16, -9, 9, 12.0, [Vector3(-16, 12, 5), Vector3(-20, 12, -9)])
	platform("VeilTerrace", 17, 37, -8, 8, 12.0, [Vector3(17, 12, 5), Vector3(20, 12, -8)])
	platform("MootHall", -12, 12, -34, -18, 20.0, [Vector3(-12, 20, -26), Vector3(12, 20, -26), Vector3(12, 20, -30)])
	platform("SennavethBough", 20, 40, -40, -22, 20.0, [Vector3(20, 20, -30)])
	walkway("GardenBridge", Vector3(-9, 12, 17), Vector3(-16, 12, 5))
	walkway("VeilBridge", Vector3(9, 12, 17), Vector3(17, 12, 5))
	walkway("GardenStair", Vector3(-20, 12, -9), Vector3(-12, 20, -26))
	walkway("VeilStair", Vector3(20, 12, -8), Vector3(12, 20, -26))
	walkway("SennavethBridge", Vector3(12, 20, -30), Vector3(20, 20, -30))

	# The Gate Landing: the Hanging Lantern (a bed at the back, once paid).
	box("LanternCounter", Vector3(3, 1.1, 0.8), Vector3(-6, 12.55, 18), DECK, "surface_wood")
	var lantern_bed := Node3D.new()
	lantern_bed.name = "LanternBed"
	lantern_bed.set_script(PRESENCE)
	lantern_bed.set("show_flag", "lantern_bed")
	own(lantern_bed)
	box("HangingLanternBed", Vector3(1.2, 0.5, 2.2), Vector3(-7, 12.25, 24), Color(0.35, 0.45, 0.3), "surface_wood", lantern_bed, BED)
	lanterns("GateLanterns", [Vector3(-8, 14.5, 14), Vector3(8, 14.5, 14), Vector3(-8, 14.5, 26), Vector3(8, 14.5, 26)])
	house("GateHouse", Vector3(5, 3.5, 4), Vector3(6, 12, 23), GROWN, GROWN_ROOF)

	# The Lantern Gardens: Tamsin's stall, Fennick's beds, the night-blooms.
	box("TamsinStall", Vector3(3, 1, 1.2), Vector3(-22, 12.5, 4), DECK, "surface_wood")
	for i in 3:
		box("GardenBed%d" % (i + 1), Vector3(3.5, 0.5, 1.6), Vector3(-27 + i * 4.5, 12.25, -5), Color(0.25, 0.2, 0.12), "surface_wood")
	for spot in [["NightBloom1", Vector3(-27, 12.7, -5)], ["NightBloom2", Vector3(-22.5, 12.7, -5)], ["NightBloom3", Vector3(-18, 12.7, -5)]]:
		examine(spot[0], "Look at the night-bloom", "", "res://dialogue/ithmarren_bloom_%s.json" % spot[0].right(1),
				Vector3(0.4, 0.4, 0.4), spot[1], Color(0.75, 0.75, 0.95))
	lanterns("GardenLanterns", [Vector3(-34, 14.5, -8), Vector3(-18, 14.5, -8), Vector3(-34, 14.5, 8), Vector3(-18, 14.5, 8), Vector3(-26, 15, 0)])
	house("GardenHouse", Vector3(5, 3.5, 4), Vector3(-27, 12, 6.8), GROWN, GROWN_ROOF)

	# The Veil Terrace: the Veil College.
	house("VeilCollege", Vector3(8, 6, 6), Vector3(32, 12, -3), Color(0.38, 0.36, 0.46), GROWN_ROOF)
	lanterns("VeilLanterns", [Vector3(18, 14.5, -7), Vector3(36, 14.5, -7), Vector3(36, 14.5, 7), Vector3(26, 14.5, 7)])

	# The Moot Hall: a ring of seats round the Moot Tree.
	for i in 6:
		var a := TAU * i / 6.0 + TAU / 12.0   # none in front of the Speaker
		box("MootSeat%d" % (i + 1), Vector3(2, 0.5, 0.6), Vector3(sin(a) * 8.5, 20.25, -26 + cos(a) * 6.5), DECK, "surface_wood")
	lanterns("MootLanterns", [Vector3(-11, 22.5, -19), Vector3(11, 22.5, -19), Vector3(-11, 22.5, -33), Vector3(11, 22.5, -33)])

	# The Sennaveth Bough: House Sennaveth, its coffer and its letter-box.
	house("SennavethHouse", Vector3(6, 4, 6), Vector3(36, 20, -31), SENNAVETH, GROWN_ROOF)
	lanterns("SennavethLanterns", [Vector3(21, 22.5, -23), Vector3(39, 22.5, -23), Vector3(39, 22.5, -39)], "")

	# The Root Door, at the Moot Tree's roots.
	var shut := Node3D.new()
	shut.name = "RootShut"
	shut.set_script(PRESENCE)
	shut.set("hide_flag", "rootwell_open")
	own(shut)
	var root_door := box("RootDoor", Vector3(3, 3.6, 0.4), Vector3(0, 1.8, -20.6), Color(0.3, 0.2, 0.12), "", shut, EXAMINE)
	root_door.set("prompt", "Look at the Root Door")
	root_door.set("speaker", "")
	root_door.set("dialogue_file", "res://dialogue/ithmarren_root_door.json")
	var open := Node3D.new()
	open.name = "RootOpen"
	open.set_script(PRESENCE)
	open.set("show_flag", "rootwell_open")
	own(open)
	var way := box("RootwellDoor", Vector3(3, 3.6, 0.4), Vector3(0, 1.8, -20.6), Color(0.05, 0.06, 0.04), "", open, LOCATION_DOOR)
	way.set("target_scene", "res://levels/ithmarren_rootwell.tscn")
	way.set("target_marker", "FromIthmarren")
	way.set("destination_name", "the Rootwell")
	way.set("verb", "Go down into")
	marker("FromRootwell", Vector3(0, 0, -17), PI)
	lantern("LanternRoots", Vector3(-4, 0, -15), LANTERN)

	# People.
	npc("Calaneth", "Moot-Speaker Calaneth", "res://dialogue/calaneth.json", Vector3(0, 20, -19.6), Color(0.35, 0.4, 0.3), PI, null, "elf/official")
	npc("Ithariel", "Lady Ithariel Sennaveth", "res://dialogue/ithariel.json", Vector3(32, 20, -24), SENNAVETH, PI, null, "elf/official")
	npc("Lirael", "Steward Lirael", "res://dialogue/lirael.json", Vector3(22.5, 20, -26.5), Color(0.36, 0.22, 0.3), PI, null, "elf/official")
	npc("Sylvaine", "Magister Sylvaine", "res://dialogue/sylvaine.json", Vector3(30, 12, 2), Color(0.4, 0.38, 0.5), PI, null, "elf/scholar")
	npc("Tamsin", "Tamsin Leafwright", "res://dialogue/tamsin.json", Vector3(-22, 12, 2.6), Color(0.35, 0.45, 0.25), 0.0, null, "elf/merchant")
	npc("Maelis", "Maelis of the Hanging Lantern", "res://dialogue/maelis.json", Vector3(-6, 12, 16.8), Color(0.45, 0.35, 0.25), PI, null, "elf/innkeeper")
	npc("Fennick", "Fennick", "res://dialogue/fennick.json", Vector3(-20, 12, -2), Color(0.38, 0.35, 0.22), PI / 2.0, null, "small_folk/worker")
	npc("Rhosyn", "Rhosyn", "res://dialogue/rhosyn.json", Vector3(-7, 0, -14), Color(0.32, 0.32, 0.34), PI / 2.0, null, "elf/commoner")
	gathering(Vector3(-25, 12, 0))   # the Lantern Gardens
	routines(["Tamsin", "Fennick"])
	# The Houses' law: two wardens (guards, systems/crime.gd).
	npc("BoughWarden", "Bough Warden", "res://dialogue/ithmarren_warden.json", Vector3(8, 12, 14.5), Color(0.3, 0.38, 0.3), PI / 2.0, null, "elf/guard")
	npc("RootWarden", "Root Warden", "res://dialogue/ithmarren_warden.json", Vector3(4, 0, -16), Color(0.3, 0.38, 0.3), PI, null, "elf/guard")
	marker("JailRelease", Vector3(4, 0, 64), PI)
	# What's someone's.
	goods("TamsinPotions", "minor_healing_potion", 2, Vector3(-23, 13.1, 4), "Tamsin Leafwright")
	goods("TamsinMoss", "blue_moss", 3, Vector3(-21, 13.1, 4), "Tamsin Leafwright")
	stores("SennavethCoffer", "House Sennaveth's coffer", {"root_key": 1}, 90, Vector3(38, 20.35, -37), "Lady Ithariel Sennaveth", 3)
	var letters := Node3D.new()   # emptied once Lirael hands the letter over himself
	letters.name = "LetterBox"
	letters.set_script(PRESENCE)
	letters.set("hide_flag", "letter_given")
	own(letters)
	stores("SennavethLetters", "the house letter-box", {"sennaveth_letter": 1}, 0, Vector3(22, 20.35, -38), "Steward Lirael", 1, letters)

	var level_map := Node.new()
	level_map.name = "LevelMap"
	level_map.set_script(LEVEL_MAP)
	level_map.set("map_name", "Ithmarren")
	level_map.set("area", Rect2(-75, -70, 150, 165))
	level_map.set("camera_height", 120.0)
	own(level_map)
	map_marker("MapIthmarren", "ithmarren", "Ithmarren: the Hollow Way", Vector3(4, 0, 66), 1)
	map_marker("MapGateLanding", "gate_landing", "The Gate Landing", Vector3(5, 12, 11))
	map_marker("MapLanternGardens", "lantern_gardens", "The Lantern Gardens", Vector3(-25, 12, -6), 2)
	map_marker("MapVeilCollege", "veil_college", "The Veil College", Vector3(26, 12, -6), 2)
	map_marker("MapMootHall", "moot_hall", "The Moot Hall", Vector3(-7, 20, -33))
	map_marker("MapRootDoor", "root_door", "The Root Door", Vector3(-2, 0, -20))

	var player: Node3D = PLAYER.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.position = Vector3(0, 1, 83)
	own(player)
	return scene


# --- the Rootwell ---------------------------------------------------------------------------

func _build_rootwell() -> Node3D:
	scene = Node3D.new()
	scene.name = "Rootwell"
	scene.add_to_group("navmesh_source", true)
	common("Rootwell", false)
	air(0.025, Color(0.75, 0.85, 0.7))   # green, close, pollen in it
	var env: Environment = scene.get_node("WorldEnvironment").environment
	env.ambient_light_color = Color(0.4, 0.46, 0.36)
	env.ambient_light_energy = 0.9
	var root := Color(0.28, 0.2, 0.13)
	var earth := Color(0.22, 0.17, 0.12)
	# A root-lined stair down from the door into a hollow under the Moot Tree, with
	# the well in the middle: a pool of light, roots grown into cages round it.
	box("StairFloor", Vector3(4, 0.5, 14), Vector3(0, -0.25, 6), earth, "surface_wood")
	box("StairCeiling", Vector3(4, 0.5, 14), Vector3(0, 3.75, 6), root, "surface_wood")
	box("StairW", Vector3(0.5, 4, 14), Vector3(-2, 1.75, 6), root, "surface_wood")
	box("StairE", Vector3(0.5, 4, 14), Vector3(2, 1.75, 6), root, "surface_wood")
	box("StairN", Vector3(4, 4, 0.5), Vector3(0, 1.75, -1), root, "surface_wood")
	box("HollowFloor", Vector3(32, 0.5, 30), Vector3(0, -0.25, 28), earth, "surface_wood")
	box("HollowCeiling", Vector3(32, 0.5, 30), Vector3(0, 8.25, 28), root, "surface_wood")
	box("HollowW", Vector3(0.5, 8.5, 30), Vector3(-16, 4, 28), root, "surface_wood")
	box("HollowE", Vector3(0.5, 8.5, 30), Vector3(16, 4, 28), root, "surface_wood")
	box("HollowS", Vector3(32, 8.5, 0.5), Vector3(0, 4, 43), root, "surface_wood")
	box("HollowNW", Vector3(14, 8.5, 0.5), Vector3(-9, 4, 13), root, "surface_wood")
	box("HollowNE", Vector3(14, 8.5, 0.5), Vector3(9, 4, 13), root, "surface_wood")
	for i in 5:
		var a := TAU * i / 5.0
		box("RootPillar%d" % (i + 1), Vector3(1, 8, 1), Vector3(sin(a) * 9.0, 4, 30 + cos(a) * 8.0), root, "surface_wood")

	# The well, and its light (it goes out if the well's unbound or drunk).
	box("WellRim", Vector3(5, 0.6, 5), Vector3(0, 0.3, 30), Color(0.3, 0.3, 0.26), "surface_stone")
	var pool := Node3D.new()
	pool.name = "WellLight"
	pool.set_script(LIGHT_STONE)
	pool.set("dim_flag", "well_emptied")
	pool.set("day_energy", 2.4)   # underground: the clock doesn't matter
	pool.set("night_energy", 2.4)
	pool.set("dimmed", 0.05)
	pool.set("surface", LANTERN)
	pool.set("glow", Color(0.75, 1.0, 0.6))
	own(pool)
	var water := MeshInstance3D.new()
	water.name = "Pool"
	var wm := BoxMesh.new()
	wm.size = Vector3(4, 0.1, 4)
	water.mesh = wm
	water.position = Vector3(0, 0.62, 30)
	own(water, pool)
	var glow := OmniLight3D.new()
	glow.name = "PoolGlow"
	glow.light_color = Color(0.75, 1.0, 0.6)
	glow.light_energy = 2.2
	glow.omni_range = 18.0
	glow.position = Vector3(0, 3, 30)
	own(glow, pool)
	examine("TheWell", "Look into the well", "", "res://dialogue/ithmarren_well.json",
			Vector3(4, 0.6, 4), Vector3(0, 0.9, 30), LANTERN)
	for i in 4:
		box("RootCage%d" % (i + 1), Vector3(1, 1.4, 1), Vector3(-9 + i * 6.0, 0.7, 38), root)
	box("CaerwynDesk", Vector3(2, 0.9, 1), Vector3(11, 0.45, 20), Color(0.35, 0.2, 0.25), "surface_wood")
	var letter := box("RootwellLetter", Vector3(0.35, 0.1, 0.3), Vector3(11, 0.95, 20), Color(0.75, 0.7, 0.65), "", null, PICKUP)
	letter.collision_layer = 8
	letter.set("item_id", "rootwell_letter")
	for spot in [Vector3(-12, 3, 20), Vector3(12, 3, 36), Vector3(-10, 3, 38)]:
		var t := OmniLight3D.new()
		t.name = "RootLamp%d" % int(spot.z)
		t.set_script(FLICKER)
		t.light_color = Color(1.0, 0.75, 0.45)
		t.light_energy = 1.4
		t.omni_range = 10.0
		t.position = spot
		own(t)

	# The takers: two Mercy, two of Sennaveth's essence-takers, and Lord Caerwyn.
	var takers := Node3D.new()
	takers.name = "Takers"
	takers.set_script(PACK)
	takers.set("cleared_flag", "rootwell_cleared")
	takers.set("cleared_message", "The Rootwell is quiet. Only the well hums, and the roots creak.")
	own(takers)
	for spot in [["Mercy1", Vector3(-6, 0, 22), "mercy"], ["Mercy2", Vector3(6, 0, 23), "mercy"]]:
		enemy(takers, spot[0], "Mercy Acolyte", spot[1], PI, CULTIST, {"gold": 15})
	for spot in [["Taker1", Vector3(-4, 0, 34)], ["Taker2", Vector3(4, 0, 35)]]:
		enemy(takers, spot[0], "Sennaveth Essence-Taker", spot[1], PI, CULTIST,
				{"gold": 20, "look_vary": false, "look_race": "elf", "look_role": "official", "look_cloth": SENNAVETH})
	enemy(takers, "Caerwyn", "Lord Caerwyn Sennaveth", Vector3(10, 0, 24), PI, CULTIST,
			{"gold": 80, "max_health": 150.0, "attack_damage": 15.0, "guard_chance": 0.55, "parry_chance": 0.2,
			"look_vary": false, "look_race": "elf", "look_role": "official", "look_cloth": Color(0.3, 0.12, 0.22)})

	map_marker("MapRootwell", "rootwell", "The Rootwell", Vector3(0, 0, 3), 3)
	door("RootStair", "res://levels/ithmarren.tscn", "FromRootwell", "the forest floor", "Climb up to",
			Vector3(1.6, 3.5, 0.3), Vector3(0, 1.75, -0.6), Color(0.3, 0.2, 0.12))
	marker("FromIthmarren", Vector3(0, 0, 2), PI)

	var level_map := Node.new()
	level_map.name = "LevelMap"
	level_map.set_script(LEVEL_MAP)
	level_map.set("map_name", "The Rootwell")
	level_map.set("area", Rect2(-16, -1, 32, 44))
	level_map.set("camera_height", 7.5)
	own(level_map)

	var player: Node3D = PLAYER.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.position = Vector3(0, 1, 2)
	own(player)
	return scene
