extends "res://levels/builders/builder_base.gd"

# Builds the greybox of the Glass Coast, Sundra's northern shore where the Mage War
# burned the sand to glass, and the Under-Glass, the vault beneath the Scar that
# holds the founders' confession and won't open:
#   levels/glass_coast.tscn, levels/glass_vault.tscn
# Run from the godot folder:
#   godot --headless --path . -s levels/builders/build_glass_coast.gd
# docs/godot-starter/GLASS_COAST.md.
#
# The coast (y 0, north is -z): the sea and the mole (the ship to Ilunhall) in the
# south; Sarabh, a harbour town round an oasis well; the Glass College's spire to
# the north-east; and north of the town, the Scar: a plain of fused glass, with
# the Mercy's camp on its edge and, in the middle, the ward over the stair down.

const SAND := Color(0.78, 0.66, 0.45)
const ADOBE := Color(0.82, 0.7, 0.52)
const ADOBE_DARK := Color(0.6, 0.48, 0.34)
const PALM := Color(0.3, 0.42, 0.18)
const PALM_TRUNK := Color(0.45, 0.33, 0.2)
const GLASS := Color(0.55, 0.8, 0.82)
const BLACK_GLASS := Color(0.08, 0.1, 0.12)
const AWNING := Color(0.7, 0.25, 0.2)

var GUARDIAN


func build() -> void:
	GUARDIAN = load("res://enemies/stone_guardian.tscn")
	_save(_build_coast(), "res://levels/glass_coast.tscn")
	_save(_build_vault(), "res://levels/glass_vault.tscn")


## Glass you can see into a little: smooth, cold, faintly lit from inside.
func glass_mat(color := GLASS, glow := 0.15) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.4
	m.roughness = 0.06
	m.emission_enabled = glow > 0.0
	m.emission = color
	m.emission_energy_multiplier = glow
	return m


## A flat-roofed Sundran house: a block with a parapet and a door on the side that
## faces the middle of the town (in the "home_door" group, for routines).
func flat_house(name: String, size: Vector3, pos: Vector3, toward := Vector3(0, 0, 22)) -> void:
	box(name, size, pos + Vector3(0, size.y / 2.0, 0), ADOBE, "surface_stone")
	box(name + "Parapet", Vector3(size.x + 0.3, 0.5, size.z + 0.3), pos + Vector3(0, size.y + 0.25, 0), ADOBE_DARK)
	var to := toward - pos
	to.y = 0.0
	var face := Vector3(signf(to.x), 0, 0) if absf(to.x) > absf(to.z) else Vector3(0, 0, signf(to.z))
	var half := size.x / 2.0 if face.x != 0.0 else size.z / 2.0
	var door := Node3D.new()
	door.name = name + "Door"
	door.position = pos + face * (half + 0.05) + Vector3(0, 1.1, 0)
	door.rotation.y = atan2(face.x, face.z)
	door.add_to_group("home_door", true)
	own(door)
	var dm := MeshInstance3D.new()
	dm.name = "Mesh"
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 2.2, 0.1)
	bm.material = mat(ADOBE_DARK.darkened(0.4))
	dm.mesh = bm
	own(dm, door)


## A date palm: a leaning trunk and a crown of fronds.
func palm(name: String, pos: Vector3, height := 7.0) -> void:
	var t := box(name, Vector3(0.45, height, 0.45), pos + Vector3(0, height / 2.0, 0), PALM_TRUNK, "surface_wood")
	t.rotation.z = 0.06
	var crown := MeshInstance3D.new()
	crown.name = name + "Fronds"
	var sm := SphereMesh.new()
	sm.radius = 2.4
	sm.height = 1.2
	sm.material = mat(PALM)
	crown.mesh = sm
	crown.position = pos + Vector3(0.4, height, 0)
	own(crown)


## A shard of fused glass standing out of the Scar.
func shard(name: String, pos: Vector3, height: float, lean: float) -> void:
	var b := box(name, Vector3(0.8, height, 0.5), pos + Vector3(0, height / 2.0 - 0.2, 0), GLASS, "surface_stone")
	b.get_node("Mesh").mesh.material = glass_mat(GLASS, 0.1)
	b.rotation = Vector3(lean, lean * 3.0, lean * 0.6)


func _build_coast() -> Node3D:
	scene = Node3D.new()
	scene.name = "GlassCoast"
	scene.add_to_group("navmesh_source", true)
	common("GlassCoast", true, "glass")
	box("Ground", Vector3(220, 1, 200), Vector3(0, -0.5, -40), SAND)
	skirt(SAND)
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	var sm := PlaneMesh.new()
	sm.size = Vector2(1600, 700)
	sm.material = water_mat(Vector2(0.05, 0.08))
	sea.mesh = sm
	sea.position = Vector3(0, -0.6, 410)
	own(sea)
	box("Beach", Vector3(220, 1, 20), Vector3(0, -0.8, 66), SAND)

	# The mole, and the ship home.
	box("Mole", Vector3(6, 1.2, 30), Vector3(10, -0.4, 62), Color(0.55, 0.5, 0.42), "surface_stone")
	box("Dhow", Vector3(4, 1.6, 14), Vector3(16, -0.5, 70), Color(0.4, 0.28, 0.16), "surface_wood")
	box("DhowMast", Vector3(0.3, 9, 0.3), Vector3(16, 4.8, 70), Color(0.4, 0.28, 0.16))
	door("ShipHome", "res://levels/ilunhall.tscn", "FromGlassCoast", "Ilunhall", "Take ship back to",
			Vector3(2, 2.5, 0.4), Vector3(10, 1.45, 76.6), Color(0.4, 0.28, 0.16))
	marker("FromIlunhall", Vector3(10, 0.2, 70), 0.0)

	# Sarabh: flat roofs round an oasis well, palms, a market, the Cistern House.
	box("WellRim", Vector3(6, 0.8, 6), Vector3(0, 0.4, 22), Color(0.6, 0.55, 0.45), "surface_stone")
	var oasis := MeshInstance3D.new()
	oasis.name = "Oasis"
	var om := BoxMesh.new()
	om.size = Vector3(5, 0.05, 5)
	om.material = water_mat(Vector2(0.01, 0.0))
	oasis.mesh = om
	oasis.position = Vector3(0, 0.78, 22)
	own(oasis)
	for p in [["Palm1", Vector3(-6, 0, 17)], ["Palm2", Vector3(6, 0, 17)], ["Palm3", Vector3(-6, 0, 28)], ["Palm4", Vector3(7, 0, 29)],
			["Palm5", Vector3(-22, 0, 40)], ["Palm6", Vector3(30, 0, 38)]]:
		palm(p[0], p[1])
	for h in [["HouseSamira", Vector3(7, 4, 6), Vector3(-18, 0, 12)], ["HouseW1", Vector3(8, 4.5, 6), Vector3(-20, 0, 30)],
			["HouseE1", Vector3(8, 4, 6), Vector3(20, 0, 12)], ["HouseE2", Vector3(7, 5, 6), Vector3(22, 0, 32)],
			["HouseN1", Vector3(9, 4, 6), Vector3(-6, 0, 2)], ["HouseN2", Vector3(7, 4, 6), Vector3(10, 0, 0)]]:
		flat_house(h[0], h[1], h[2])
	box("NadiraStall", Vector3(3, 1, 1.2), Vector3(8, 0.5, 22), Color(0.5, 0.36, 0.22), "surface_wood")
	box("NadiraAwning", Vector3(3.6, 0.12, 2.4), Vector3(8, 2.6, 22.6), AWNING)
	# The Cistern House: an open courtyard inn (a bed in the alcove, once paid).
	box("CisternBack", Vector3(10, 4, 0.6), Vector3(-26, 2, 49), ADOBE, "surface_stone")
	box("CisternWallW", Vector3(0.6, 4, 8), Vector3(-31, 2, 45), ADOBE, "surface_stone")
	box("CisternCounter", Vector3(3, 1.1, 0.8), Vector3(-26, 0.55, 44), Color(0.5, 0.36, 0.22), "surface_wood")
	var bed := Node3D.new()
	bed.name = "CisternBed"
	bed.set_script(PRESENCE)
	bed.set("show_flag", "cistern_bed")
	own(bed)
	box("CisternHouseBed", Vector3(1.2, 0.5, 2.2), Vector3(-29.5, 0.25, 46.5), Color(0.6, 0.3, 0.25), "surface_wood", bed, BED)
	lantern("LanternCistern", Vector3(-23, 0, 43))
	# The collector's booth, and his chest of water-tallies.
	box("TallyBooth", Vector3(3, 2.4, 2.4), Vector3(-10, 1.2, 36), ADOBE_DARK, "surface_stone")
	# Jamila's kiln.
	box("Kiln", Vector3(2.4, 2, 2.4), Vector3(-30, 1, 14), Color(0.42, 0.3, 0.24), "surface_stone")
	var kiln_fire := OmniLight3D.new()
	kiln_fire.name = "KilnFire"
	kiln_fire.set_script(FLICKER)
	kiln_fire.light_color = Color(1, 0.55, 0.25)
	kiln_fire.light_energy = 2.0
	kiln_fire.omni_range = 8.0
	kiln_fire.position = Vector3(-30, 1.6, 15.6)
	own(kiln_fire)
	lantern("LanternSquare", Vector3(4, 0, 26))
	lantern("LanternMole", Vector3(8, 0.2, 52))
	signpost("SarabhSign", "SARABH, ON THE GLASS COAST.\nWater by the Sovereign's measure. North: the Scar. Mind the glass; it cuts.",
			Vector3(14, 1.4, 48), 0.0)

	# The Glass College: a spire of fused glass on the Scar's edge.
	var spire := box("GlassSpire", Vector3(10, 32, 10), Vector3(45, 16, -26), GLASS, "surface_stone")
	spire.get_node("Mesh").mesh.material = glass_mat(GLASS, 0.25)
	var spire_top := box("GlassSpireTop", Vector3(6, 10, 6), Vector3(45, 37, -26), GLASS)
	spire_top.get_node("Mesh").mesh.material = glass_mat(Color(0.75, 0.95, 1.0), 0.6)
	box("CollegeSteps", Vector3(6, 0.4, 3), Vector3(45, 0.2, -19.5), Color(0.6, 0.6, 0.58), "surface_stone")

	# The Scar: fused glass from the town's north edge to the horizon.
	var scar := box("Scar", Vector3(170, 0.3, 90), Vector3(0, 0.05, -88), GLASS, "surface_stone")
	scar.get_node("Mesh").mesh.material = glass_mat(Color(0.42, 0.62, 0.6), 0.08)
	var i := 0
	for s in [[Vector3(-40, 0, -60), 3.5, 0.2], [Vector3(-20, 0, -78), 5.0, -0.25], [Vector3(30, 0, -66), 4.0, 0.3], [Vector3(55, 0, -90), 6.0, -0.15],
			[Vector3(-60, 0, -100), 4.5, 0.25], [Vector3(18, 0, -112), 3.0, -0.3], [Vector3(-28, 0, -120), 5.5, 0.18], [Vector3(66, 0, -55), 3.5, 0.22]]:
		i += 1
		shard("Shard%d" % i, s[0], s[1], s[2])
	for spot in [["SingingGlass1", Vector3(-24, 0.5, -70)], ["SingingGlass2", Vector3(32, 0.5, -84)], ["SingingGlass3", Vector3(-8, 0.5, -118)]]:
		var e := examine(spot[0], "Listen to the glass", "", "res://dialogue/glass_singing_%s.json" % spot[0].right(1),
				Vector3(0.5, 0.8, 0.5), spot[1], Color(0.7, 0.95, 1.0))
		e.get_node("Mesh").mesh.material = glass_mat(Color(0.7, 0.95, 1.0), 0.5)

	# The Mercy's camp on the Scar's west edge.
	for t in [["MercyTent1", Vector3(-52, 0, -52)], ["MercyTent2", Vector3(-58, 0, -60)], ["MercyTent3", Vector3(-46, 0, -62)]]:
		box(t[0], Vector3(3.5, 2.2, 3), t[1] + Vector3(0, 1.1, 0), Color(0.28, 0.24, 0.32), "surface_wood")
	var camp_fire := OmniLight3D.new()
	camp_fire.name = "MercyFire"
	camp_fire.set_script(FLICKER)
	camp_fire.light_color = Color(1, 0.6, 0.3)
	camp_fire.light_energy = 1.6
	camp_fire.omni_range = 10.0
	camp_fire.position = Vector3(-52, 1, -57)
	own(camp_fire)

	# The Under-Glass: a ring of black glass in the middle of the Scar, and the
	# College's ward over the stair down (lifted by Ophira, the Mercy's cut, or Sight).
	for k in 8:
		var a := TAU * k / 8.0
		var ring := box("BlackRing%d" % (k + 1), Vector3(1.2, 1.4 + (k % 3) * 0.6, 1.2), Vector3(sin(a) * 7.0, 0.7, -100 + cos(a) * 7.0), BLACK_GLASS, "surface_stone")
		ring.get_node("Mesh").mesh.material = glass_mat(BLACK_GLASS, 0.0)
	box("StairWell", Vector3(4, 0.4, 4), Vector3(0, 0.2, -100), BLACK_GLASS, "surface_stone")
	var warded := Node3D.new()
	warded.name = "WardUp"
	warded.set_script(PRESENCE)
	warded.set("hide_flag", "vault_open")
	own(warded)
	var ward := box("UnderGlassWard", Vector3(3.2, 2.8, 0.3), Vector3(0, 1.8, -97.8), Color(0.7, 0.9, 1.0), "", warded, EXAMINE)
	ward.get_node("Mesh").mesh.material = glass_mat(Color(0.7, 0.9, 1.0), 0.8)
	ward.set("prompt", "Look at the ward")
	ward.set("speaker", "")
	ward.set("dialogue_file", "res://dialogue/glass_ward.json")
	var opened := Node3D.new()
	opened.name = "WardDown"
	opened.set_script(PRESENCE)
	opened.set("show_flag", "vault_open")
	own(opened)
	var stair := box("UnderGlassStair", Vector3(3.2, 2.8, 0.3), Vector3(0, 1.8, -97.8), BLACK_GLASS, "", opened, LOCATION_DOOR)
	stair.set("target_scene", "res://levels/glass_vault.tscn")
	stair.set("target_marker", "FromScar")
	stair.set("destination_name", "the Under-Glass")
	stair.set("verb", "Go down into")
	marker("FromVault", Vector3(0, 0.3, -94), PI)

	# People.
	npc("Ophira", "Seer-Magister Ophira", "res://dialogue/ophira.json", Vector3(45, 0.4, -18), Color(0.55, 0.6, 0.7), PI, null, "human/scholar")
	npc("Ammara", "Sister Ammara", "res://dialogue/ammara.json", Vector3(-50, 0.2, -56), Color(0.22, 0.18, 0.26), PI / 2.0, null, "human/priest")
	npc("Amir", "Collector Amir Tahan", "res://dialogue/amir.json", Vector3(-10, 0, 38.2), Color(0.5, 0.42, 0.2), PI, null, "human/official")
	npc("Samira", "Samira", "res://dialogue/samira.json", Vector3(-13, 0, 14), Color(0.55, 0.3, 0.3), -PI / 2.0, null, "human/commoner")
	npc("Jamila", "Jamila the Glassblower", "res://dialogue/jamila.json", Vector3(-27.5, 0, 14), Color(0.4, 0.38, 0.3), -PI / 2.0, null, "orc/worker")
	npc("Nadira", "Nadira", "res://dialogue/nadira.json", Vector3(8, 0, 20.6), Color(0.6, 0.45, 0.3), PI, null, "human/merchant")
	npc("Rafiq", "Rafiq of the Cistern House", "res://dialogue/rafiq.json", Vector3(-26, 0, 45.2), Color(0.5, 0.4, 0.3), 0.0, null, "small_folk/innkeeper")
	gathering(Vector3(0, 0, 30))   # by the oasis
	routines(["Samira", "Nadira", "Jamila"])
	# The law: the Sovereign's wardens (guards, systems/crime.gd).
	npc("SquareWarden", "Sovereign's Warden", "res://dialogue/glass_warden.json", Vector3(4, 0, 36), Color(0.6, 0.55, 0.4), PI / 2.0, null, "human/guard")
	npc("MoleWarden", "Sovereign's Warden", "res://dialogue/glass_warden.json", Vector3(12.5, 0.2, 52), Color(0.6, 0.55, 0.4), PI, null, "human/guard")
	marker("JailRelease", Vector3(0, 0, 40), PI)
	# What's someone's.
	goods("NadiraFlasks", "water_flask", 3, Vector3(7, 1.1, 22), "Nadira")
	goods("NadiraBread", "bread", 2, Vector3(9, 1.1, 22), "Nadira")
	stores("TallyChest", "the collector's tally-chest", {"water_tally": 1}, 70, Vector3(-10, 0.35, 34.2), "Collector Amir Tahan", 1)   # behind his booth

	var level_map := Node.new()
	level_map.name = "LevelMap"
	level_map.set_script(LEVEL_MAP)
	level_map.set("map_name", "The Glass Coast")
	level_map.set("area", Rect2(-90, -135, 180, 215))
	level_map.set("camera_height", 120.0)
	own(level_map)
	map_marker("MapGlassCoast", "glass_coast", "The Glass Coast: Sarabh's mole", Vector3(10, 0.2, 58), 1)
	map_marker("MapSarabh", "sarabh", "Sarabh's oasis", Vector3(-4, 0, 30))
	map_marker("MapGlassCollege", "glass_college", "The Glass College", Vector3(38, 0, -20), 2)
	map_marker("MapMercyCamp", "mercy_camp_scar", "The Mercy's camp", Vector3(-44, 0, -60), 2)
	map_marker("MapUnderGlass", "under_glass", "The Under-Glass", Vector3(-6, 0, -112))

	var player: Node3D = PLAYER.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.position = Vector3(10, 1, 70)
	own(player)
	return scene


# --- the Under-Glass ------------------------------------------------------------------------

func _build_vault() -> Node3D:
	scene = Node3D.new()
	scene.name = "UnderGlass"
	scene.add_to_group("navmesh_source", true)
	common("UnderGlass", false)
	var env: Environment = scene.get_node("WorldEnvironment").environment
	env.ambient_light_color = Color(0.45, 0.6, 0.65)
	env.ambient_light_energy = 0.9
	var wall := Color(0.12, 0.16, 0.18)
	# A glass stair down, then a long hall of glass pillars to the vault door.
	box("StairFloor", Vector3(4, 0.5, 12), Vector3(0, -0.25, 5), wall, "surface_stone")
	box("StairCeiling", Vector3(4, 0.5, 12), Vector3(0, 3.75, 5), wall, "surface_stone")
	box("StairW", Vector3(0.5, 4, 12), Vector3(-2, 1.75, 5), wall, "surface_stone")
	box("StairE", Vector3(0.5, 4, 12), Vector3(2, 1.75, 5), wall, "surface_stone")
	box("StairN", Vector3(4, 4, 0.5), Vector3(0, 1.75, -1), wall, "surface_stone")
	box("HallFloor", Vector3(26, 0.5, 40), Vector3(0, -0.25, 31), wall, "surface_stone")
	box("HallCeiling", Vector3(26, 0.5, 40), Vector3(0, 9.25, 31), wall, "surface_stone")
	box("HallW", Vector3(0.5, 9.5, 40), Vector3(-13, 4.5, 31), wall, "surface_stone")
	box("HallE", Vector3(0.5, 9.5, 40), Vector3(13, 4.5, 31), wall, "surface_stone")
	box("HallS", Vector3(26, 9.5, 0.5), Vector3(0, 4.5, 51), wall, "surface_stone")
	box("HallNW", Vector3(11, 9.5, 0.5), Vector3(-7.5, 4.5, 11), wall, "surface_stone")
	box("HallNE", Vector3(11, 9.5, 0.5), Vector3(7.5, 4.5, 11), wall, "surface_stone")
	for row in 2:
		for k in 3:
			var pillar := box("GlassPillar%d_%d" % [row, k], Vector3(1.2, 9, 1.2), Vector3(-8 + row * 16.0, 4.5, 18 + k * 9.0), GLASS, "surface_stone")
			pillar.get_node("Mesh").mesh.material = glass_mat(GLASS, 0.5)
	for k in 3:
		var l := OmniLight3D.new()
		l.name = "PillarLight%d" % (k + 1)
		l.light_color = Color(0.6, 0.9, 1.0)
		l.light_energy = 1.6
		l.omni_range = 14.0
		l.position = Vector3(0, 6, 18 + k * 12.0)
		own(l)

	# The Glass Sentinel, woken when you walk into the hall.
	var sentinel: Node3D = GUARDIAN.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	sentinel.name = "GlassSentinel"
	sentinel.set_script(load("res://enemies/glass_sentinel.gd"))
	sentinel.set("display_name", "The Glass Sentinel")
	sentinel.position = Vector3(0, 0, 36)
	sentinel.rotation.y = 0.0
	own(sentinel)
	var arena := Area3D.new()
	arena.name = "SentinelArena"
	arena.set_script(load("res://props/puzzle/boss_arena.gd"))
	arena.collision_layer = 0
	arena.collision_mask = 2
	arena.position = Vector3(0, 2, 28)
	arena.set("boss", NodePath("../GlassSentinel"))
	own(arena)
	var shape := CollisionShape3D.new()
	shape.name = "Shape"
	var bs := BoxShape3D.new()
	bs.size = Vector3(24, 4, 30)
	shape.shape = bs
	own(shape, arena)

	# The Seal of the Twelve, on the far wall: a socket for each well, lit for the
	# ones whose wells you've stood at and dealt with.
	var seal_light := OmniLight3D.new()
	seal_light.name = "SealLight"
	seal_light.light_color = Color(0.6, 0.85, 0.95)
	seal_light.light_energy = 1.4
	seal_light.omni_range = 9.0
	seal_light.position = Vector3(0, 4.5, 45)
	own(seal_light)
	var seal := box("SealOfTwelve", Vector3(8, 7, 0.6), Vector3(0, 3.5, 50.4), BLACK_GLASS, "surface_stone")
	seal.get_node("Mesh").mesh.material = glass_mat(BLACK_GLASS, 0.0)
	var wells := ["stones_quest_done", "weirstones_freed", "deep_ring_reported", "seam_resolved", "well_resolved", "glass_sentinel_down",
			"", "", "", "", "", ""]
	for k in 12:
		var a := TAU * k / 12.0
		var at := Vector3(sin(a) * 2.6, 3.6 + cos(a) * 2.6, 50.0)
		var dark := MeshInstance3D.new()
		dark.name = "Socket%d" % (k + 1)
		var dm := SphereMesh.new()
		dm.radius = 0.32
		dm.height = 0.64
		dm.material = glass_mat(Color(0.15, 0.18, 0.2), 0.0)
		dark.mesh = dm
		dark.position = at
		own(dark)
		if wells[k] != "":
			var lit := Node3D.new()
			lit.name = "SocketLit%d" % (k + 1)
			lit.set_script(PRESENCE)
			lit.set("show_flag", wells[k])
			own(lit)
			var glow := MeshInstance3D.new()
			glow.name = "Glow"
			var gm := SphereMesh.new()
			gm.radius = 0.36
			gm.height = 0.72
			gm.material = glass_mat(Color(0.75, 1.0, 0.8), 3.0)
			glow.mesh = gm
			glow.position = at + Vector3(0, 0, -0.05)
			own(glow, lit)
	examine("TheSeal", "Look at the seal", "", "res://dialogue/glass_seal.json", Vector3(3, 2, 0.5), Vector3(0, 1.2, 49.7), BLACK_GLASS)

	map_marker("MapUnderGlassVault", "under_glass_vault", "The Under-Glass", Vector3(0, 0, 3), 3)
	door("GlassStair", "res://levels/glass_coast.tscn", "FromVault", "the Scar", "Climb up to",
			Vector3(1.6, 3.5, 0.3), Vector3(0, 1.75, -0.6), Color(0.3, 0.4, 0.45))
	marker("FromScar", Vector3(0, 0, 2), PI)

	var level_map := Node.new()
	level_map.name = "LevelMap"
	level_map.set_script(LEVEL_MAP)
	level_map.set("map_name", "The Under-Glass")
	level_map.set("area", Rect2(-13, -1, 26, 52))
	level_map.set("camera_height", 8.5)
	own(level_map)

	var player: Node3D = PLAYER.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.position = Vector3(0, 1, 2)
	own(player)
	return scene
