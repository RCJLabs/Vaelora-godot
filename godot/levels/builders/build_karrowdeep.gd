extends "res://levels/builders/builder_base.gd"

# Builds the greybox of Karrowdeep, the Deepfolk's city in a hollow mountain, and
# Seam Nine under its lowest gallery, where the Mercy harvest a seam that sings:
#   levels/karrowdeep.tscn, levels/karrowdeep_seam.tscn
# Run from the godot folder:
#   godot --headless --path . -s levels/builders/build_karrowdeep.gd
# docs/godot-starter/KARROWDEEP.md.
#
# The city (all inside the mountain, y up, north is -z):
#   the Gate Hall (south, y 0)         the Deep Road out to Ilunhall
#   the Market Bridge (y 0)            stalls on a bridge over the chasm
#   the West and East Ledges (y 0)     the Anvil College and the Seal College
#   the Guild Gallery (north, y 0)     the Table of Guildmasters, the Law Wall
#   the Lowest Gallery (south-west, y -8, down a cut stair)  the Lamp and Pick,
#                                      and the Seal Door to Seam Nine

const ROCK := Color(0.24, 0.23, 0.24)
const DARK_ROCK := Color(0.15, 0.15, 0.17)
const CUT_STONE := Color(0.36, 0.34, 0.33)
const IRON := Color(0.2, 0.2, 0.22)
const TIMBER := Color(0.3, 0.2, 0.12)
const RUNE_ORE := Color(0.55, 0.8, 1.0)
const LAMP := Color(1.0, 0.7, 0.4)
const CEILING := 25.0


func build() -> void:
	_save(_build_city(), "res://levels/karrowdeep.tscn")
	_save(_build_seam(), "res://levels/karrowdeep_seam.tscn")


## Rock from deep under the chasm up to a floor at `top`, over a rectangle (x0, z0)-(x1, z1).
func floor_block(name: String, x0: float, x1: float, z0: float, z1: float, top: float, bottom := -42.0, color := CUT_STONE) -> StaticBody3D:
	return box(name, Vector3(x1 - x0, top - bottom, z1 - z0), Vector3((x0 + x1) / 2.0, (top + bottom) / 2.0, (z0 + z1) / 2.0), color, "surface_stone")


## A low stone rail along an edge (so the chasm isn't one step away).
func rail(name: String, a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	var body := box(name, Vector3(0.35, 1.1, length), (a + b) / 2.0 + Vector3(0, 0.55, 0), DARK_ROCK, "surface_stone")
	body.rotation.y = atan2(b.x - a.x, b.z - a.z)


## A seam of rune-ore in the rock: a glowing strip, and (with `lit`) a cold light by it.
func vein(name: String, pos: Vector3, size: Vector3, lit := true, energy := 1.2) -> void:
	var m := MeshInstance3D.new()
	m.name = name
	var bm := BoxMesh.new()
	bm.size = size
	var glow := StandardMaterial3D.new()
	glow.albedo_color = RUNE_ORE
	glow.emission_enabled = true
	glow.emission = RUNE_ORE
	glow.emission_energy_multiplier = energy
	bm.material = glow
	m.mesh = bm
	m.position = pos
	own(m)
	if lit:
		var l := OmniLight3D.new()
		l.name = name + "Light"
		l.light_color = RUNE_ORE
		l.light_energy = 2.2
		l.omni_range = 18.0
		l.position = pos + Vector3(0, 0, 0)
		own(l)


## A brazier's warm light (flickering), for the halls people live in.
func brazier(name: String, pos: Vector3, range_m := 10.0) -> void:
	box(name, Vector3(0.7, 0.9, 0.7), pos + Vector3(0, 0.45, 0), IRON, "surface_stone")
	var l := OmniLight3D.new()
	l.name = name + "Fire"
	l.set_script(FLICKER)
	l.light_color = LAMP
	l.light_energy = 2.4
	l.omni_range = range_m
	l.position = pos + Vector3(0, 1.4, 0)
	own(l)


## A ramp up `rise` over `run`, going north from (x, y, z_bottom) (as Ilunhall's steps).
func ramp(name: String, x: float, y: float, z_bottom: float, rise: float, run: float, width: float) -> void:
	var length := sqrt(run * run + rise * rise)
	var angle := atan2(rise, run)
	var body := box(name, Vector3(width, 0.4, length), Vector3(x, y + rise / 2.0 - 0.2 / cos(angle), z_bottom - run / 2.0), CUT_STONE, "surface_stone")
	body.rotation.x = -angle


func _build_city() -> Node3D:
	scene = Node3D.new()
	scene.name = "Karrowdeep"
	scene.add_to_group("navmesh_source", true)
	common("Karrowdeep", false)
	var env: Environment = scene.get_node("WorldEnvironment").environment
	env.ambient_light_color = Color(0.42, 0.47, 0.6)   # the rune-ore's cold light, everywhere a little
	env.ambient_light_energy = 1.3
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.14, 0.2)
	env.fog_density = 0.005

	# The mountain: walls, a ceiling, and the chasm's far floor.
	box("WallWest", Vector3(2, CEILING + 45, 104), Vector3(-47, CEILING / 2.0 - 20, -1), ROCK, "surface_stone")
	box("WallEast", Vector3(2, CEILING + 45, 104), Vector3(47, CEILING / 2.0 - 20, -1), ROCK, "surface_stone")
	box("WallNorth", Vector3(96, CEILING + 45, 2), Vector3(0, CEILING / 2.0 - 20, -53), ROCK, "surface_stone")
	box("WallSouth", Vector3(96, CEILING + 45, 2), Vector3(0, CEILING / 2.0 - 20, 51), ROCK, "surface_stone")
	box("Ceiling", Vector3(96, 2, 106), Vector3(0, CEILING + 1, -1), ROCK, "surface_stone")
	box("ChasmFloor", Vector3(28, 1, 40), Vector3(0, -40.5, 0), DARK_ROCK, "surface_stone")

	# The floors.
	floor_block("GateHall", -14, 46, 20, 50, 0.0)
	floor_block("GuildGallery", -46, 46, -52, -20, 0.0)
	floor_block("WestLedge", -46, -14, -20, 4, 0.0)
	floor_block("EastLedge", 14, 46, -20, 20, 0.0)
	floor_block("StairRockW", -46, -32, 4, 20, 0.0)
	floor_block("StairRockE", -28, -14, 4, 20, 0.0)
	floor_block("GateRockW", -20, -14, 20, 50, CEILING, -12.0, ROCK)   # between the Gate Hall and the gallery below
	floor_block("LowestGallery", -46, -20, 20, 50, -8.0, -12.0)
	ramp("CutStair", -30.0, -8.0, 20.0, 8.0, 16.0, 4.0)   # down from the West Ledge
	box("MarketBridge", Vector3(12, 1, 40), Vector3(0, -0.5, 0), CUT_STONE, "surface_stone")
	for z in [-9.0, 9.0]:
		box("BridgePier%d" % int(z), Vector3(3, 39, 3), Vector3(0, -20.5, z), DARK_ROCK, "surface_stone")
	rail("RailBridgeW", Vector3(-6, 0, -20), Vector3(-6, 0, 20))
	rail("RailBridgeE", Vector3(6, 0, -20), Vector3(6, 0, 20))
	rail("RailWestLedge", Vector3(-14, 0, -20), Vector3(-14, 0, 20))
	rail("RailEastLedge", Vector3(14, 0, -20), Vector3(14, 0, 20))
	rail("RailGateW", Vector3(-14, 0, 20), Vector3(-6, 0, 20))
	rail("RailGateE", Vector3(6, 0, 20), Vector3(14, 0, 20))
	rail("RailGuildW", Vector3(-14, 0, -20), Vector3(-6, 0, -20))
	rail("RailGuildE", Vector3(6, 0, -20), Vector3(14, 0, -20))

	# Rune-ore in the walls: the city's only daylight.
	vein("VeinChasmW", Vector3(-13.6, -10, 0), Vector3(0.3, 18, 6))
	vein("VeinChasmE", Vector3(13.6, -14, -6), Vector3(0.3, 14, 5))
	vein("VeinGate", Vector3(20, 6, 49.6), Vector3(10, 0.4, 0.3))
	vein("VeinGallery", Vector3(-20, 8, -51.6), Vector3(16, 0.5, 0.3))
	vein("VeinEast", Vector3(45.6, 7, -4), Vector3(0.3, 0.5, 20))
	vein("VeinLowest", Vector3(-45.6, -3, 36), Vector3(0.3, 0.4, 18))
	vein("VeinCeiling", Vector3(0, CEILING - 0.2, 0), Vector3(3, 0.3, 30), false)

	# The Gate Hall: the Deep Road in, the warden, the assay.
	door("DeepRoad", "res://levels/ilunhall.tscn", "FromKarrowdeep", "Ilunhall", "Take the Deep Road to",
			Vector3(3, 3.5, 0.4), Vector3(14, 1.75, 49.6), Color(0.35, 0.25, 0.15))
	marker("FromIlunhall", Vector3(14, 0, 45), 0.0)
	signpost("GateSign", "KARROWDEEP.\nBy the Table's law: weigh honest, cut true, seal what is sealed.\nNorth: the Market Bridge and the Guild Gallery. West, down the Cut Stair: the Lowest Gallery.",
			Vector3(18, 1.4, 44), 0.0)
	brazier("BrazierGate1", Vector3(6, 0, 30))
	brazier("BrazierGate2", Vector3(30, 0, 30))
	box("AssayBench", Vector3(2.4, 0.9, 1), Vector3(9, 0.45, 23), TIMBER, "surface_wood")
	examine("AssayScales", "Look at the assay scales", "", "res://dialogue/karrowdeep_scales.json",
			Vector3(0.8, 0.5, 0.5), Vector3(9, 1.15, 23), Color(0.6, 0.5, 0.25))

	# The Market Bridge: stalls over the dark.
	box("GrimaStall", Vector3(1.4, 1, 4), Vector3(-3.6, 0.5, 4), TIMBER, "surface_wood")
	box("StallE1", Vector3(1.4, 1, 3), Vector3(3.6, 0.5, -6), TIMBER, "surface_wood")
	box("StallE2", Vector3(1.4, 1, 3), Vector3(3.6, 0.5, 10), TIMBER, "surface_wood")
	for z in [-14.0, 0.0, 14.0]:
		var l := OmniLight3D.new()
		l.name = "BridgeLamp%d" % int(z)
		l.light_color = LAMP
		l.light_energy = 1.2
		l.omni_range = 9.0
		l.position = Vector3(0, 3.5, z)
		own(l)

	# The West Ledge: the Anvil College (builders, stone-shapers), the Delvings.
	house("AnvilCollege", Vector3(14, 7, 10), Vector3(-30, 0, -10), Color(0.42, 0.32, 0.24), IRON)
	box("AnvilBench", Vector3(2.2, 0.9, 0.9), Vector3(-20, 0.45, -2), TIMBER, "surface_wood")
	brazier("BrazierAnvil", Vector3(-17, 0, -12))
	# The East Ledge: the Seal College (rune-cutters), the Delvings.
	house("SealCollege", Vector3(14, 7, 10), Vector3(30, 0, -10), Color(0.3, 0.33, 0.4), IRON)
	vein("VeinSeal", Vector3(30, 7.2, -4.8), Vector3(14, 0.3, 0.3), false)
	brazier("BrazierSeal", Vector3(18, 0, -2))
	for h in [["DelvingE1", Vector3(30, 0, 9)], ["DelvingE2", Vector3(40, 0, 9)], ["DelvingG1", Vector3(36, 0, 32)],
			["DelvingG2", Vector3(36, 0, 42)], ["DelvingW1", Vector3(-38, 0, -2)]]:
		house(h[0], Vector3(6, 3.5, 5), h[1], Color(0.36, 0.33, 0.3), IRON)

	# The Guild Gallery: the Table of Guildmasters, the Law Wall.
	box("TableBack", Vector3(24, 9, 0.8), Vector3(0, 4.5, -50.6), CUT_STONE, "surface_stone")
	box("TableWallW", Vector3(0.8, 9, 12), Vector3(-12, 4.5, -45), CUT_STONE, "surface_stone")
	box("TableWallE", Vector3(0.8, 9, 12), Vector3(12, 4.5, -45), CUT_STONE, "surface_stone")
	box("TableRoof", Vector3(25, 0.8, 13), Vector3(0, 9.4, -45), DARK_ROCK, "surface_stone")
	box("GuildTable", Vector3(10, 0.9, 2), Vector3(0, 0.45, -46), DARK_ROCK, "surface_stone")
	brazier("BrazierTableW", Vector3(-9, 0, -42))
	brazier("BrazierTableE", Vector3(9, 0, -42))
	examine("LawWall", "Read the guild-law", "", "res://dialogue/karrowdeep_law.json",
			Vector3(10, 4, 0.3), Vector3(-28, 3, -51.8), Color(0.45, 0.42, 0.38))

	# The Lowest Gallery: the Lamp and Pick (a bed at the back, once paid), the Seal Door.
	box("LampBack", Vector3(14, 6, 0.6), Vector3(-34, -5, 49.4), TIMBER, "surface_wood")
	box("LampCounter", Vector3(5, 1.1, 0.8), Vector3(-34, -7.45, 44), TIMBER, "surface_wood")
	for i in 4:
		box("LampBench%d" % (i + 1), Vector3(2, 0.5, 0.5), Vector3(-40 + (i % 2) * 5, -7.75, 36 + (i / 2) * 3.0), TIMBER, "surface_wood")
	var lamp_bed := Node3D.new()
	lamp_bed.name = "LampBed"
	lamp_bed.set_script(PRESENCE)
	lamp_bed.set("show_flag", "lamp_bed")
	own(lamp_bed)
	box("LampAndPickBed", Vector3(1.2, 0.5, 2.2), Vector3(-26, -7.75, 47), Color(0.4, 0.22, 0.18), "surface_wood", lamp_bed, BED)
	brazier("BrazierLamp", Vector3(-30, -8, 40), 12.0)
	# The Seal Door: shut by guild-law (a key, Runecraft, or a story); then it's a way down.
	box("SealFrame", Vector3(0.6, 5, 5), Vector3(-45.6, -5.5, 30), DARK_ROCK, "surface_stone")
	var sealed := Node3D.new()
	sealed.name = "SealShut"
	sealed.set_script(PRESENCE)
	sealed.set("hide_flag", "seam_nine_open")
	own(sealed)
	var seal := box("SealDoor", Vector3(0.4, 3.6, 3), Vector3(-45.1, -6.2, 30), Color(0.3, 0.42, 0.55), "", sealed, EXAMINE)
	seal.set("prompt", "Look at the Seal Door")
	seal.set("speaker", "")
	seal.set("dialogue_file", "res://dialogue/karrowdeep_seal_door.json")
	var opened := Node3D.new()
	opened.name = "SealOpen"
	opened.set_script(PRESENCE)
	opened.set("show_flag", "seam_nine_open")
	own(opened)
	var way := box("SeamDoor", Vector3(0.4, 3.6, 3), Vector3(-45.1, -6.2, 30), Color(0.05, 0.05, 0.07), "", opened, LOCATION_DOOR)
	way.set("target_scene", "res://levels/karrowdeep_seam.tscn")
	way.set("target_marker", "FromKarrowdeep")
	way.set("destination_name", "Seam Nine")
	way.set("verb", "Go down into")
	marker("FromSeam", Vector3(-42, -8, 30), -PI / 2.0)

	# People.
	npc("Hrodna", "Guildmaster Hrodna", "res://dialogue/hrodna.json", Vector3(0, 0, -43.5), Color(0.38, 0.3, 0.2), PI, null, "deepfolk/official")
	npc("Orsa", "Magister Orsa Deepcut", "res://dialogue/orsa.json", Vector3(24, 0, -3), Color(0.3, 0.36, 0.5), PI / 2.0, null, "deepfolk/scholar")
	npc("Bek", "Master Bek", "res://dialogue/bek.json", Vector3(-21.5, 0, -2), Color(0.45, 0.3, 0.18), -PI / 2.0, null, "deepfolk/worker")
	npc("Grima", "Grima Coldiron", "res://dialogue/grima.json", Vector3(-5, 0, 4), Color(0.5, 0.4, 0.25), -PI / 2.0, null, "deepfolk/merchant")
	npc("Torvald", "Torvald of the Lamp", "res://dialogue/torvald.json", Vector3(-34, -8, 45.2), Color(0.5, 0.32, 0.22), 0.0, null, "deepfolk/innkeeper")
	npc("Ebba", "Ebba Lowlamp", "res://dialogue/ebba.json", Vector3(-38, -8, 26), Color(0.35, 0.3, 0.25), PI / 2.0, null, "deepfolk/worker")
	npc("Pell", "Assayer Pell", "res://dialogue/pell.json", Vector3(9, 0, 21.6), Color(0.3, 0.3, 0.38), PI, null, "small_folk/official")
	gathering(Vector3(-34, -8, 38))   # the Lamp and Pick
	routines(["Grima", "Ebba", "Bek"])
	# The law: the Table's wardens (guards, systems/crime.gd).
	npc("BridgeWarden", "Warden of the Bridge", "res://dialogue/karrowdeep_warden.json", Vector3(-8, 0, 24), Color(0.3, 0.3, 0.35), 0.0, null, "deepfolk/guard")
	npc("GalleryWarden", "Gallery Warden", "res://dialogue/karrowdeep_warden.json", Vector3(16, 0, -26), Color(0.3, 0.3, 0.35), PI, null, "orc/guard")
	marker("JailRelease", Vector3(24, 0, 40), 0.0)
	# What's someone's.
	goods("GrimaIngots", "iron_ingot", 3, Vector3(-3.6, 1.1, 3), "Grima Coldiron")
	goods("GrimaPicks", "lockpick", 4, Vector3(-3.6, 1.1, 5), "Grima Coldiron")
	var slate_here := Node3D.new()   # gone from the bench once Bek hands it over
	slate_here.name = "SlateOnBench"
	slate_here.set_script(PRESENCE)
	slate_here.set("hide_flag", "bek_gave_slate")
	own(slate_here)
	goods("SealSlate", "seal_slate", 1, Vector3(-20, 1.0, -2), "Master Bek", 0, "the Seal College's rune-slate", slate_here)
	stores("HrodnaStrongbox", "the Guildmaster's strongbox", {"seal_key": 1}, 60, Vector3(9, 0.35, -48.5), "Guildmaster Hrodna", 3)
	stores("TorvaldTill", "Torvald's till", {}, 30, Vector3(-36, -7.65, 45.0), "Torvald of the Lamp", 1)

	var level_map := Node.new()
	level_map.name = "LevelMap"
	level_map.set_script(LEVEL_MAP)
	level_map.set("map_name", "Karrowdeep")
	level_map.set("area", Rect2(-46, -52, 92, 102))
	level_map.set("camera_height", CEILING - 1.5)
	own(level_map)
	map_marker("MapKarrowdeep", "karrowdeep", "Karrowdeep: the Gate Hall", Vector3(20, 0, 36), 1)
	map_marker("MapMarketBridge", "market_bridge", "The Market Bridge", Vector3(0, 0, -6))
	map_marker("MapTable", "guild_table", "The Table of Guildmasters", Vector3(0, 0, -36), 2)
	map_marker("MapSealCollege", "seal_college", "The Seal College", Vector3(20, 0, -8), 2)
	map_marker("MapAnvilCollege", "anvil_college", "The Anvil College", Vector3(-18, 0, -14), 2)
	map_marker("MapLampAndPick", "lamp_and_pick", "The Lamp and Pick", Vector3(-30, -8, 30), 2)

	var player: Node3D = PLAYER.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.position = Vector3(14, 1, 45)
	own(player)
	return scene


# --- Seam Nine ------------------------------------------------------------------------------

func _build_seam() -> Node3D:
	scene = Node3D.new()
	scene.name = "SeamNine"
	scene.add_to_group("navmesh_source", true)
	common("SeamNine", false)
	var env: Environment = scene.get_node("WorldEnvironment").environment
	env.ambient_light_color = Color(0.36, 0.4, 0.52)
	env.ambient_light_energy = 0.9
	# A sloping drift from the Seal Door down into a worked cavern, where the seam
	# glows and the Mercy have cages and a harvest-frame; past it, the Deep: a shaft.
	box("DriftFloor", Vector3(5, 0.5, 20), Vector3(0, -0.25, 9), CUT_STONE, "surface_stone")
	box("DriftCeiling", Vector3(5, 0.5, 20), Vector3(0, 3.75, 9), ROCK, "surface_stone")
	box("DriftW", Vector3(0.5, 4, 20), Vector3(-2.5, 1.75, 9), ROCK, "surface_stone")
	box("DriftE", Vector3(0.5, 4, 20), Vector3(2.5, 1.75, 9), ROCK, "surface_stone")
	box("DriftN", Vector3(5, 4, 0.5), Vector3(0, 1.75, -1), ROCK, "surface_stone")
	box("CavernFloor", Vector3(34, 0.5, 30), Vector3(0, -0.25, 34), CUT_STONE, "surface_stone")
	box("CavernCeiling", Vector3(34, 0.5, 30), Vector3(0, 9.25, 34), ROCK, "surface_stone")
	box("CavernW", Vector3(0.5, 9.5, 30), Vector3(-17, 4.5, 34), ROCK, "surface_stone")
	box("CavernE", Vector3(0.5, 9.5, 30), Vector3(17, 4.5, 34), ROCK, "surface_stone")
	box("CavernS", Vector3(34, 9.5, 0.5), Vector3(0, 4.5, 49), ROCK, "surface_stone")
	box("CavernNW", Vector3(14.5, 9.5, 0.5), Vector3(-9.75, 4.5, 19), ROCK, "surface_stone")
	box("CavernNE", Vector3(14.5, 9.5, 0.5), Vector3(9.75, 4.5, 19), ROCK, "surface_stone")
	for i in 3:
		box("Prop%d" % (i + 1), Vector3(0.6, 9, 0.6), Vector3(-8 + i * 8.0, 4.5, 28), TIMBER, "surface_wood")
	for i in 2:
		var l := OmniLight3D.new()
		l.name = "DriftLamp%d" % (i + 1)
		l.set_script(FLICKER)
		l.light_color = LAMP
		l.light_energy = 1.1
		l.omni_range = 7.0
		l.position = Vector3(1.8, 2.6, 4 + i * 8.0)
		own(l)

	# The seam: a wall of rune-ore that sings (the vein dims once it's dealt with).
	vein("Seam", Vector3(0, 3.5, 48.6), Vector3(16, 6, 0.4), true, 0.45)
	examine("TheSeam", "Look at the seam", "", "res://dialogue/karrowdeep_seam.json",
			Vector3(4, 4, 1), Vector3(0, 2, 47.6), RUNE_ORE)
	for spot in [Vector3(-14, 3, 30), Vector3(14, 3, 30), Vector3(0, 6, 40)]:
		var t := OmniLight3D.new()
		t.name = "MinerLamp%d" % int(spot.x + 20)
		t.set_script(FLICKER)
		t.light_color = LAMP
		t.light_energy = 1.6
		t.omni_range = 12.0
		t.position = spot
		own(t)
	for i in 4:
		box("Cage%d" % (i + 1), Vector3(1, 1.2, 1), Vector3(-9 + i * 2.2, 0.6, 44), IRON)
	box("HarvestFrame", Vector3(3, 4, 1), Vector3(9, 2, 44), IRON, "surface_stone")
	box("KeldTable", Vector3(2, 0.9, 1), Vector3(12, 0.45, 38), TIMBER, "surface_wood")
	var orders := box("KeldOrders", Vector3(0.35, 0.1, 0.3), Vector3(12, 0.95, 38), Color(0.75, 0.7, 0.6), "", null, PICKUP)
	orders.collision_layer = 8
	orders.set("item_id", "keld_orders")
	# The Deep: a shaft in the cavern floor's west end, roped off. Listen, at your risk.
	box("ShaftRim", Vector3(4, 0.6, 4), Vector3(-12, 0.3, 36), DARK_ROCK, "surface_stone")
	examine("TheDeep", "Listen at the shaft", "", "res://dialogue/karrowdeep_deep.json",
			Vector3(3, 0.2, 3), Vector3(-12, 0.7, 36), Color(0.03, 0.03, 0.04))

	# The Mercy: three miners in grey, and Brother Keld, their foreman.
	var mercy := Node3D.new()
	mercy.name = "Mercy"
	mercy.set_script(PACK)
	mercy.set("cleared_flag", "seam_cleared")
	mercy.set("cleared_message", "Seam Nine is quiet but for the seam itself, singing to nobody.")
	own(mercy)
	for spot in [["Miner1", Vector3(-6, 0, 30)], ["Miner2", Vector3(6, 0, 31)], ["Miner3", Vector3(0, 0, 36)]]:
		enemy(mercy, spot[0], "Mercy Miner", spot[1], PI, CULTIST, {"gold": 12, "look_race": "deepfolk", "look_vary": false})
	enemy(mercy, "Keld", "Brother Keld", Vector3(10, 0, 40), PI, CULTIST,
			{"gold": 60, "max_health": 140.0, "attack_damage": 15.0, "guard_chance": 0.6, "parry_chance": 0.15,
			"look_vary": false, "look_race": "deepfolk", "look_role": "mercy", "look_cloth": Color(0.22, 0.18, 0.26)})

	map_marker("MapSeamNine", "seam_nine", "Seam Nine", Vector3(0, 0, 3), 3)
	door("SealStair", "res://levels/karrowdeep.tscn", "FromSeam", "the Lowest Gallery", "Climb up to",
			Vector3(1.6, 3.5, 0.3), Vector3(0, 1.75, -0.6), Color(0.3, 0.42, 0.55))
	marker("FromKarrowdeep", Vector3(0, 0, 2), PI)

	var level_map := Node.new()
	level_map.name = "LevelMap"
	level_map.set_script(LEVEL_MAP)
	level_map.set("map_name", "Seam Nine")
	level_map.set("area", Rect2(-17, -1, 34, 50))
	level_map.set("camera_height", 8.5)
	own(level_map)

	var player: Node3D = PLAYER.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.position = Vector3(0, 1, 2)
	own(player)
	return scene
