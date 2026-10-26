extends "res://levels/builders/builder_base.gd"

# Builds the greybox Grieving Fields: the Ashen village of Greyfold on the old
# battlefields, and the Deep Ring under them (one of the twelve sites):
#   levels/grieving_fields.tscn, levels/grieving_deep_ring.tscn
# Run from the godot folder:
#   godot --headless --path . -s levels/builders/build_grieving_fields.gd
# docs/godot-starter/GRIEVING_FIELDS.md.

const ASH_GRASS := Color(0.36, 0.37, 0.31)
const GREY_STONE := Color(0.5, 0.5, 0.5)
const DARK := Color(0.2, 0.2, 0.22)
const ASH_WALL := Color(0.55, 0.55, 0.52)
const ASH_ROOF := Color(0.28, 0.28, 0.3)
const RUST := Color(0.4, 0.25, 0.15)


func build() -> void:
	_save(_build_fields(), "res://levels/grieving_fields.tscn")
	_save(_build_deep_ring(), "res://levels/grieving_deep_ring.tscn")


func _build_fields() -> Node3D:
	scene = Node3D.new()
	scene.name = "GrievingFields"
	scene.add_to_group("navmesh_source", true)
	common("GrievingFields", true, "fields")
	box("Ground", Vector3(200, 1, 200), Vector3(0, -0.5, 0), ASH_GRASS).add_to_group("ground_cover", true)
	ground_cover("ashfield", Rect2(-100, -100, 200, 200))
	skirt(ASH_GRASS)
	box("Road", Vector3(5, 0.04, 80), Vector3(0, 0.02, -58), Color(0.38, 0.35, 0.3))

	# Greyfold: low grey houses in a ring around the Listening Stone.
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		var pos := Vector3(cos(a) * 15.0, 0, sin(a) * 15.0)
		house("House%d" % (i + 1), Vector3(5, 3, 4), pos, ASH_WALL, ASH_ROOF)
	box("ListeningStone", Vector3(1.4, 4.5, 1.0), Vector3(0, 2.25, -2), GREY_STONE, "surface_stone")
	box("Well", Vector3(1.6, 1, 1.6), Vector3(4, 0.5, 4), DARK, "surface_stone")
	lantern("LanternGreyfold", Vector3(-3, 0, 3), Color(0.8, 0.85, 1.0))
	signpost("GreyfoldSign", "GREYFOLD.\nSpeak softly. The lights are listening.", Vector3(2.5, 1.4, -20), PI)

	# The laying grounds: the Ashen lay their dead out under the sky.
	for i in 6:
		box("Bier%d" % (i + 1), Vector3(1, 0.6, 2.2), Vector3(36 + (i % 3) * 3, 0.3, -30 + (i / 3) * 4), GREY_STONE, "surface_stone")
	examine("LayingGrounds", "Look at the laying grounds", "", "res://dialogue/fields_laying.json",
			Vector3(0.6, 1.2, 0.6), Vector3(33, 0.6, -26), GREY_STONE)

	# The old battlefield: broken spears and rusted shields in the grass.
	var rng := RandomNumberGenerator.new()
	rng.seed = 340
	for i in 40:
		var x := rng.randf_range(-95, 95)
		var z := rng.randf_range(-95, 95)
		if Vector2(x, z).length() < 24.0 or absf(x) < 4.0:
			continue
		var spear := MeshInstance3D.new()
		spear.name = "Spear%d" % i
		var m := BoxMesh.new()
		m.size = Vector3(0.08, 2.2, 0.08)
		m.material = mat(RUST)
		spear.mesh = m
		spear.position = Vector3(x, 0.9, z)
		spear.rotation = Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
		own(spear)

	# Three toppled cairns (Cairns of the Rising).
	for c in [["CairnWest", Vector3(-60, 0, -50)], ["CairnEast", Vector3(65, 0, 40)], ["CairnSouth", Vector3(-50, 0, 62)]]:
		examine(c[0], "Look at the toppled cairn", "", "res://dialogue/fields_%s.json" % String(c[0]).to_snake_case(),
				Vector3(2.2, 0.6, 2.2), c[1] + Vector3(0, 0.3, 0), GREY_STONE)

	# Corin Dray's hut, west; Marta's wagon by the road.
	house("CorinHut", Vector3(4, 2.6, 4), Vector3(-36, 0, 10), Color(0.45, 0.42, 0.38), ASH_ROOF)
	box("MartaWagon", Vector3(2.4, 1.6, 4), Vector3(9, 0.8, -24), Color(0.5, 0.35, 0.2), "surface_wood")

	# The sinkhole down to the Deep Ring, north-east.
	for i in 6:
		var a := TAU * i / 6.0
		box("SinkRim%d" % (i + 1), Vector3(2.4, 0.8, 1), Vector3(55, 0.4, -65) + Vector3(cos(a) * 3.2, 0, sin(a) * 3.2), DARK, "surface_stone").rotation.y = -a
	door("Sinkhole", "res://levels/grieving_deep_ring.tscn", "FromFields", "the Deep Ring", "Climb down into",
			Vector3(3, 0.2, 3), Vector3(55, 0.1, -65), Color(0.05, 0.05, 0.06))
	marker("FromDeepRing", Vector3(55, 0, -59), 0.0)

	# People.
	npc("Ysolde", "Listener Ysolde", "res://dialogue/ysolde.json", Vector3(1.5, 0, -2), Color(0.32, 0.34, 0.44), PI, null, "ashen/priest")
	npc("Hesk", "Old Hesk", "res://dialogue/hesk.json", Vector3(-8, 0, 6), Color(0.38, 0.33, 0.26), PI / 2.0, null, "ashen/commoner")
	npc("Corin", "Corin Dray", "res://dialogue/corin.json", Vector3(-36, 0, 13), Color(0.35, 0.36, 0.38), PI, null, "human/hunter")
	npc("Marta", "Marta Coil", "res://dialogue/marta.json", Vector3(9, 0, -21.5), Color(0.55, 0.45, 0.25), PI, null, "human/merchant")
	npc("Bram", "Bram", "res://dialogue/bram.json", Vector3(-14, 0, -6), Color(0.42, 0.4, 0.3), PI / 3.0, null, "ashen/worker")
	# A day by the clock (Ysolde listens at the stone, day and night).
	gathering(Vector3(3, 0, 3))   # by the Listening Stone
	routines(["Hesk", "Corin", "Marta", "Bram"])

	# The way back north to the Riverlands.
	door("RiverRoad", "res://levels/weirholt.tscn", "FromFields", "the Riverlands", "Take the north road to",
			Vector3(3, 2, 0.4), Vector3(0, 1, -97), Color(0.45, 0.32, 0.18))
	marker("FromRiverlands", Vector3(0, 0, -92), PI)
	signpost("RoadSign", "North: Weirholt and the Riverlands.\nSouth: Greyfold, and the Grieving Fields.", Vector3(3, 1.4, -90), PI)

	# The Imperial Road east to Ilunhall.
	box("ImperialRoadPaving", Vector3(60, 0.04, 5), Vector3(68, 0.02, 0), Color(0.4, 0.38, 0.34))
	door("ImperialRoad", "res://levels/ilunhall.tscn", "FromFields", "Ilunhall", "Take the Imperial Road to",
			Vector3(0.4, 3, 4), Vector3(97, 1.5, 0), Color(0.45, 0.32, 0.18))
	marker("FromIlunhall", Vector3(92, 0, 0), PI / 2.0)
	signpost("ImperialSign", "East: the Imperial Road, to Ilunhall.\nWest: Greyfold.", Vector3(90, 1.4, 3), PI / 2.0)

	var level_map := Node.new()
	level_map.name = "LevelMap"
	level_map.set_script(LEVEL_MAP)
	level_map.set("map_name", "The Grieving Fields")
	level_map.set("area", Rect2(-100, -100, 200, 200))
	level_map.set("camera_height", 120.0)
	own(level_map)
	map_marker("MapGreyfold", "greyfold", "Greyfold", Vector3(0, 0, 0), 1)
	map_marker("MapLayingGrounds", "laying_grounds", "The laying grounds", Vector3(38, 0, -28))
	map_marker("MapSinkhole", "sinkhole", "The sinkhole", Vector3(55, 0, -65), 3)
	map_marker("MapCorinHut", "corin_hut", "Corin's hut", Vector3(-36, 0, 10), 2)

	var player: Node3D = PLAYER.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.position = Vector3(0, 1, -90)
	own(player)
	return scene


# --- the Deep Ring --------------------------------------------------------------------------

func _build_deep_ring() -> Node3D:
	scene = Node3D.new()
	scene.name = "DeepRing"
	scene.add_to_group("navmesh_source", true)
	common("DeepRing", false)
	var stone := Color(0.24, 0.24, 0.26)
	# A tunnel south from the ladder into a round chamber, ringed by eight stones.
	box("TunnelFloor", Vector3(6, 0.5, 16), Vector3(0, -0.25, 6), stone, "surface_stone")
	box("TunnelCeiling", Vector3(6, 0.5, 16), Vector3(0, 3.75, 6), stone, "surface_stone")
	box("TunnelW", Vector3(0.5, 4, 16), Vector3(-3, 1.75, 6), stone, "surface_stone")
	box("TunnelE", Vector3(0.5, 4, 16), Vector3(3, 1.75, 6), stone, "surface_stone")
	box("TunnelN", Vector3(6, 4, 0.5), Vector3(0, 1.75, -2), stone, "surface_stone")
	box("ChamberFloor", Vector3(30, 0.5, 30), Vector3(0, -0.25, 28), stone, "surface_stone")
	box("ChamberCeiling", Vector3(30, 0.5, 30), Vector3(0, 6.25, 28), stone, "surface_stone")
	box("ChamberW", Vector3(0.5, 6.5, 30), Vector3(-15, 3, 28), stone, "surface_stone")
	box("ChamberE", Vector3(0.5, 6.5, 30), Vector3(15, 3, 28), stone, "surface_stone")
	box("ChamberS", Vector3(30, 6.5, 0.5), Vector3(0, 3, 43), stone, "surface_stone")
	box("ChamberNW", Vector3(12, 6.5, 0.5), Vector3(-9, 3, 13), stone, "surface_stone")
	box("ChamberNE", Vector3(12, 6.5, 0.5), Vector3(9, 3, 13), stone, "surface_stone")
	var centre := Vector3(0, 0, 28)
	for i in 8:
		var a := TAU * i / 8.0
		box("RingStone%d" % (i + 1), Vector3(1.2, 3.5, 0.8), centre + Vector3(cos(a) * 9.0, 1.75, sin(a) * 9.0), Color(0.45, 0.45, 0.48), "surface_stone").rotation.y = -a
	examine("HarvestEngine", "Look at the machine in the middle of the ring", "", "res://dialogue/deep_ring_engine.json",
			Vector3(2.4, 3, 2.4), centre + Vector3(0, 1.5, 0), Color(0.55, 0.65, 0.8))
	var glow := OmniLight3D.new()
	glow.name = "EngineGlow"
	glow.light_color = Color(0.7, 0.8, 1.0)
	glow.light_energy = 3.0
	glow.omni_range = 18.0
	glow.position = centre + Vector3(0, 4, 0)
	own(glow)
	for i in 3:
		var light := OmniLight3D.new()
		light.name = "Torch%d" % (i + 1)
		light.set_script(FLICKER)
		light.light_color = Color(1, 0.65, 0.35)
		light.light_energy = 1.2
		light.omni_range = 8.0
		light.position = Vector3(2.2, 2.6, 1 + i * 5)
		own(light)

	var mercy := Node3D.new()
	mercy.name = "Mercy"
	mercy.set_script(PACK)
	mercy.set("cleared_flag", "deep_ring_cleared")
	mercy.set("cleared_message", "The Deep Ring is quiet. Only the machine is still humming.")
	own(mercy)
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		enemy(mercy, "Acolyte%d" % (i + 1), "Mercy Acolyte", centre + Vector3(cos(a) * 5.5, 0, sin(a) * 5.5), PI, CULTIST, {"gold": 15})
	enemy(mercy, "Warden", "Harvest-Warden", centre + Vector3(0, 0, -4), PI, CULTIST,
			{"gold": 60, "max_health": 140.0, "attack_damage": 15.0, "guard_chance": 0.7, "parry_chance": 0.25})

	door("Ladder", "res://levels/grieving_fields.tscn", "FromDeepRing", "the Grieving Fields", "Climb up to",
			Vector3(1.2, 3.5, 0.3), Vector3(0, 1.75, -1.6), Color(0.35, 0.25, 0.15))
	marker("FromFields", Vector3(0, 0, 1), PI)

	var level_map := Node.new()
	level_map.name = "LevelMap"
	level_map.set_script(LEVEL_MAP)
	level_map.set("map_name", "The Deep Ring")
	level_map.set("area", Rect2(-16, -3, 32, 47))
	level_map.set("camera_height", 40.0)
	own(level_map)

	var player: Node3D = PLAYER.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.position = Vector3(0, 1, 1)
	own(player)
	return scene
