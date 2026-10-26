extends "res://levels/builders/builder_base.gd"

# Builds the greybox Riverlands town of Weirholt and the culvert under its docks:
#   levels/weirholt.tscn, levels/weirholt_culvert.tscn
# Run from the godot folder:
#   godot --headless --path . -s levels/builders/build_weirholt.gd
# Everything is boxes and capsules until there's art; edit the layout here and
# re-run rather than hand-editing the .tscn files. docs/godot-starter/RIVERLANDS.md.

func build() -> void:
	_save(_build_town(), "res://levels/weirholt.tscn")
	_save(_build_culvert(), "res://levels/weirholt_culvert.tscn")


# --- Weirholt ----------------------------------------------------------------------------

const STONE := Color(0.42, 0.41, 0.4)
const DARK_STONE := Color(0.3, 0.3, 0.31)
const WOOD := Color(0.36, 0.24, 0.13)
const PLASTER := Color(0.66, 0.6, 0.5)
const ROOF := Color(0.32, 0.18, 0.12)
const SLATE := Color(0.22, 0.24, 0.27)
const GRASS := Color(0.25, 0.33, 0.15)
const WATER := Color(0.22, 0.36, 0.42, 0.8)


func _build_town() -> Node3D:
	scene = Node3D.new()
	scene.name = "Weirholt"
	scene.add_to_group("navmesh_source", true)
	common("Weirholt", true, "riverlands")

	# Ground on both banks of the Greywater, the river between (x 22..34, flowing south).
	box("GroundWest", Vector3(122, 1, 200), Vector3(-39, -0.5, 0), GRASS)
	box("GroundEast", Vector3(66, 1, 200), Vector3(67, -0.5, 0), GRASS)
	skirt(GRASS)
	box("RiverBed", Vector3(12, 1, 200), Vector3(28, -1.9, 0), Color(0.25, 0.22, 0.18), "surface_stone")
	var water := MeshInstance3D.new()
	water.name = "River"
	var wm := BoxMesh.new()
	wm.size = Vector3(12, 0.1, 200)
	wm.material = mat(WATER, true)
	water.mesh = wm
	water.position = Vector3(28, -0.35, 0)
	own(water)
	box("Ford", Vector3(12, 0.6, 4), Vector3(28, -0.5, 44), Color(0.4, 0.37, 0.32), "surface_stone")
	box("Road", Vector3(6, 0.04, 64), Vector3(0, 0.02, -66), Color(0.4, 0.33, 0.24))

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
	npc("Hedda", "Hedda Marrow", "res://dialogue/hedda.json", Vector3(-12, 0, -17.5), Color(0.6, 0.35, 0.3), PI, null, "human/innkeeper")
	var tarle_presence := Node3D.new()
	tarle_presence.name = "TarlePresence"
	tarle_presence.set_script(PRESENCE)
	tarle_presence.set("hide_flag", "tarle_gone")
	own(tarle_presence)
	npc("Tarle", "Factor Tarle", "res://dialogue/tarle.json", Vector3(8, 0, -14.8), Color(0.3, 0.32, 0.45), PI, tarle_presence, "human/official")
	npc("Wenna", "Wenna Pike", "res://dialogue/wenna.json", Vector3(-4, 0, 4.2), Color(0.55, 0.5, 0.25), PI, null, "small_folk/merchant")
	npc("Varga", "Captain Varga", "res://dialogue/varga.json", Vector3(-8, 0, 22), Color(0.45, 0.1, 0.12), PI, null, "human/guard")
	npc("Dace", "Sergeant Dace", "res://dialogue/dace.json", Vector3(5.5, 0, 28), Color(0.4, 0.15, 0.15), -PI / 2.0, null, "orc/guard")
	npc("Ama", "Goodwife Ama", "res://dialogue/ama.json", Vector3(2, 0, 38), Color(0.45, 0.4, 0.25), 0.0, null, "human/worker")
	npc("Teodor", "Teodor", "res://dialogue/teodor.json", Vector3(-20, 0, 13), Color(0.55, 0.55, 0.6), PI / 2.0, null, "passenger/commoner")
	npc("Fenn", "Physician Fenn", "res://dialogue/fenn.json", Vector3(-10, 0, 9.5), Color(0.2, 0.2, 0.2), PI, null, "human/physician")
	npc("JoryDocks", "Jory Vell", "res://dialogue/jory_weirholt.json", Vector3(22.5, 0.15, 16), Color(0.6, 0.5, 0.2), -PI / 2.0, null, "small_folk/merchant")

	# The way back north, and where you arrive from it.
	door("NorthRoad", "res://levels/test_level.tscn", "FromWeirholt", "the Greywater Vale", "Take the north road to",
			Vector3(3, 2, 0.4), Vector3(0, 1, -97), Color(0.45, 0.32, 0.18))
	marker("FromVale", Vector3(0, 0, -92), PI)
	# South, to the Grieving Fields.
	box("SouthRoad", Vector3(5, 0.04, 62), Vector3(0, 0.02, 66), Color(0.4, 0.33, 0.24))
	door("FieldsRoad", "res://levels/grieving_fields.tscn", "FromRiverlands", "the Grieving Fields", "Take the south road to",
			Vector3(3, 2, 0.4), Vector3(0, 1, 97), Color(0.45, 0.32, 0.18))
	marker("FromFields", Vector3(0, 0, 92), 0.0)
	signpost("FieldsSign", "South: the Grieving Fields and Greyfold.\nNorth: Weirholt.", Vector3(3, 1.4, 90))
	signpost("RoadSign", "North: the Greywater Vale, Riverwatch and the waystation.\nSouth: Weirholt, a mile on. Mind the woods.", Vector3(3, 1.4, -90), PI)

	_build_wilds()

	# The map.
	var level_map := Node.new()
	level_map.name = "LevelMap"
	level_map.set_script(LEVEL_MAP)
	level_map.set("map_name", "Weirholt")
	level_map.set("area", Rect2(-100, -100, 200, 200))
	level_map.set("camera_height", 120.0)
	own(level_map)
	map_marker("MapWeirholt", "weirholt", "Weirholt", Vector3(0, 0, 0), 1)
	map_marker("MapInn", "lantern_weir", "The Lantern Weir", Vector3(-14, 0, -17))
	map_marker("MapCountingHouse", "counting_house", "Compact counting house", Vector3(8, 0, -19))
	map_marker("MapDocks", "weirholt_docks", "The docks", Vector3(24, 0, 19))
	map_marker("MapTollFort", "toll_fort", "The toll-fort", Vector3(15, 0, 28))
	map_marker("MapLanes", "the_lanes", "The Lanes", Vector3(-22, 0, 17))
	map_marker("MapMill", "weirholt_mill", "The mill", Vector3(16, 0, -2))
	map_marker("MapGangCamp", "toll_road_camp", "Camp in the woods", Vector3(-45, 0, -70))
	map_marker("MapWeirstones", "weirstones", "The Weirstones", Vector3(70, 0, 30))
	map_marker("MapFord", "weirholt_ford", "The ford", Vector3(28, 0, 44))
	map_marker("MapFarm", "ama_farm", "Ama's farm", Vector3(-62, 0, 52))

	var player: Node3D = PLAYER.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.position = Vector3(0, 1, -90)
	own(player)
	return scene


# --- the wilds around the town ------------------------------------------------------------

func _build_wilds() -> void:
	# Woods either side of the north road (z -40..-95), kept off the road itself.
	var rng := RandomNumberGenerator.new()
	rng.seed = 902
	var placed := 0
	while placed < 70:
		var x := rng.randf_range(-95, 18)
		var z := rng.randf_range(-96, -40)
		if absf(x) < 6.0 or (x > -55 and x < -35 and z > -80 and z < -60):   # the road, the gang's clearing
			continue
		tree("Tree%d" % placed, Vector3(x, 0, z), rng.randf_range(5.0, 8.0))
		placed += 1
	# A robbed cart on the road, and the toll-road gang's camp in a clearing west of it.
	examine("RobbedCart", "Look at the overturned cart", "", "res://dialogue/weirholt_cart.json",
			Vector3(2.2, 1.2, 3.5), Vector3(4.5, 0.6, -72), Color(0.38, 0.27, 0.15))
	box("GangTentA", Vector3(3, 2, 3), Vector3(-48, 1, -73), Color(0.45, 0.4, 0.3), "surface_wood")
	box("GangTentB", Vector3(3, 2, 3), Vector3(-41, 1, -75), Color(0.42, 0.38, 0.3), "surface_wood")
	var fire := OmniLight3D.new()
	fire.name = "GangFire"
	fire.set_script(FLICKER)
	fire.light_color = Color(1, 0.6, 0.3)
	fire.light_energy = 2.0
	fire.omni_range = 10.0
	fire.position = Vector3(-45, 0.8, -69)
	own(fire)
	var gang := Node3D.new()
	gang.name = "TollRoadGang"
	gang.set_script(PACK)
	gang.set("cleared_flag", "toll_gang_cleared")
	gang.set("cleared_message", "The camp in the woods is quiet. The north road's safe, for now.")
	own(gang)
	enemy(gang, "Highwayman1", "Highwayman", Vector3(-46, 0, -66), PI, null, {"gold": 10})
	enemy(gang, "Highwayman2", "Highwayman", Vector3(-42, 0, -68), PI, null, {"gold": 10})
	enemy(gang, "GangLeader", "Gang Leader", Vector3(-45, 0, -72), PI, null, {"gold": 30, "max_health": 90.0, "attack_damage": 13.0, "guard_chance": 0.7})
	var gang_chest := box("GangChest", Vector3(1.2, 0.7, 0.8), Vector3(-44.5, 0.35, -76), Color(0.32, 0.22, 0.12), "surface_wood", null, LOOT)
	gang_chest.set("container_name", "gang's chest")
	gang_chest.set("contents", {"minor_healing_potion": 2, "lockpick": 3, "bread": 2})
	gang_chest.set("gold", 60)

	# The Weirstones: one of the twelve sites, on the east bank past the ford.
	var circle := Vector3(70, 0, 30)
	for i in 8:
		var a := TAU * i / 8.0
		box("Weirstone%d" % (i + 1), Vector3(1.2, 3.2, 0.8), circle + Vector3(cos(a) * 7.0, 1.6, sin(a) * 7.0), Color(0.5, 0.5, 0.48), "surface_stone").rotation.y = -a
	examine("DrainFocus", "Look at the thing in the middle of the circle", "", "res://dialogue/weirholt_focus.json",
			Vector3(1, 1.4, 1), circle + Vector3(0, 0.7, 0), Color(0.6, 0.7, 0.85))
	var glow := OmniLight3D.new()
	glow.name = "RiteGlow"
	glow.light_color = Color(0.7, 0.8, 1.0)
	glow.light_energy = 3.0
	glow.omni_range = 14.0
	glow.position = circle + Vector3(0, 2.5, 0)
	own(glow)
	var acolytes := Node3D.new()
	acolytes.name = "Acolytes"
	acolytes.set_script(PACK)
	acolytes.set("cleared_flag", "weirstones_cleared")
	acolytes.set("cleared_message", "The chanting stops. Whatever was humming in the middle of the circle falters.")
	own(acolytes)
	for i in 3:
		var a := TAU * i / 3.0 + 0.4
		enemy(acolytes, "Acolyte%d" % (i + 1), "Mercy Acolyte", circle + Vector3(cos(a) * 4.0, 0, sin(a) * 4.0), -a - PI / 2.0,
				CULTIST, {"wait_for_flag": "weirstones_rite", "gold": 15})
	var rite := Node3D.new()
	rite.name = "Weirstones"
	rite.set_script(RITUAL)
	rite.position = circle
	var hidden: Array[NodePath] = [NodePath("../Acolytes"), NodePath("../RiteGlow")]
	rite.set("hidden_until_start", hidden)
	rite.set("radius", 18.0)
	rite.set("started_flag", "weirstones_rite")
	rite.set("slain_flag", "weirstones_cleared")
	rite.set("seen_by_day_flag", "weirstones_seen_by_day")
	rite.set("day_message", "A ring of eight standing stones on the east bank, and in the middle something wrapped in oilcloth, humming. Cart ruts, boot prints, cold ashes. Whoever uses this place comes at night.")
	rite.set("night_message", "Three hooded figures stand in the circle, hands out to the thing in the middle. The stones are glowing, and the light is running out of them into it.")
	own(rite)
	var wisps := Node3D.new()
	wisps.name = "WeirstoneWisps"
	wisps.set_script(WISPS)
	wisps.position = circle
	wisps.set("count", 2)
	wisps.set("radius", 9.0)
	wisps.set("drain_flag", "")
	own(wisps)

	# Ama's farm, west of the town.
	house("Farmhouse", Vector3(7, 4, 5), Vector3(-62, 0, 52), PLASTER, ROOF)
	for i in 3:
		box("Field%d" % (i + 1), Vector3(12, 0.1, 6), Vector3(-80 + i * 13, 0.05, 66), Color(0.38, 0.3, 0.18))
	box("Scarecrow", Vector3(0.3, 2.2, 0.3), Vector3(-67, 1.1, 66), Color(0.5, 0.42, 0.25))


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
