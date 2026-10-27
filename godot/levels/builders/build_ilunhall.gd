extends "res://levels/builders/builder_base.gd"

# Builds the greybox Lower Steps of Ilunhall, the capital: four terraces climbing
# from a fjord quay to the doors of the Hall of Spears, and the Undercroft under
# the Market Steps, where the Mercy feed the city's light-stone:
#   levels/ilunhall.tscn, levels/ilunhall_undercroft.tscn
# Run from the godot folder:
#   godot --headless --path . -s levels/builders/build_ilunhall.gd
# docs/godot-starter/ILUNHALL.md.

const GILT := Color(0.72, 0.55, 0.2)
const TIMBER := Color(0.34, 0.22, 0.12)
const DARK_TIMBER := Color(0.2, 0.13, 0.08)
const QUAY_STONE := Color(0.4, 0.4, 0.42)
const PAVING := Color(0.42, 0.4, 0.36)
const ROCK := Color(0.28, 0.29, 0.31)
const GRASS := Color(0.24, 0.3, 0.16)
const RUNE_BLUE := Color(0.45, 0.7, 1.0)

var LIGHT_STONE


func build() -> void:
	LIGHT_STONE = load("res://props/light_stone.gd")
	_save(_build_city(), "res://levels/ilunhall.tscn")
	_save(_build_undercroft(), "res://levels/ilunhall_undercroft.tscn")


## A terrace: a stone block from below the quay up to `top`, paved on top, between
## z_front (its retaining wall) and z_back.
func terrace(name: String, top: float, z_front: float, z_back: float) -> void:
	var depth := z_front - z_back
	box(name + "Wall", Vector3(170, top + 0.9, depth), Vector3(0, (top - 1.1) / 2.0, (z_front + z_back) / 2.0), QUAY_STONE, "surface_stone")
	box(name, Vector3(170, 0.1, depth), Vector3(0, top - 0.05, (z_front + z_back) / 2.0), PAVING)


## Steps up a terrace wall: a ramp from (x, y, z_bottom) up `rise` over `run`, going north.
func ramp(name: String, x: float, y: float, z_bottom: float, rise: float, run: float, width: float) -> void:
	var length := sqrt(run * run + rise * rise)
	var angle := atan2(rise, run)
	var body := box(name, Vector3(width, 0.4, length), Vector3(x, y + rise / 2.0 - 0.2 / cos(angle), z_bottom - run / 2.0), PAVING, "surface_stone")
	body.rotation.x = -angle


## One of the city's great halls, long side to the south: timber walls, a gilded
## gable roof, and light-stone along the eaves and the ridge (glowing gold at night;
## dimmed once `dim_flag` is set).
func great_hall(name: String, size: Vector3, pos: Vector3, wall := TIMBER, dim_flag := "conduit_broken") -> void:
	box(name, size, pos + Vector3(0, size.y / 2.0, 0), wall, "surface_wood")
	var pitch := deg_to_rad(32.0)
	var slab := (size.z / 2.0 + 0.8) / cos(pitch)
	for side in [-1.0, 1.0]:
		var roof := MeshInstance3D.new()
		roof.name = "%sRoof%s" % [name, "S" if side > 0 else "N"]
		var m := BoxMesh.new()
		m.size = Vector3(size.x + 1.2, 0.35, slab)
		m.material = mat(GILT)
		roof.mesh = m
		roof.position = pos + Vector3(0, size.y + size.z / 4.0 * tan(pitch), side * size.z / 4.0)
		roof.rotation.x = side * pitch
		own(roof)
	var eaves := Node3D.new()
	eaves.name = name + "LightStone"
	eaves.set_script(LIGHT_STONE)
	eaves.set("dim_flag", dim_flag)
	own(eaves)
	var ridge_y := size.y + size.z / 2.0 * tan(pitch) + 0.15
	for strip in [[Vector3(0, size.y - 0.05, size.z / 2.0 + 0.75)], [Vector3(0, size.y - 0.05, -size.z / 2.0 - 0.75)], [Vector3(0, ridge_y, 0)]]:
		var s := MeshInstance3D.new()
		s.name = "Strip%d" % eaves.get_child_count()
		var sm := BoxMesh.new()
		sm.size = Vector3(size.x + 1.2, 0.18, 0.18)
		s.mesh = sm
		s.position = pos + strip[0]
		own(s, eaves)
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = Color(1.0, 0.75, 0.4)
	glow.light_energy = 2.0
	glow.omni_range = maxf(size.x, 14.0)
	glow.position = pos + Vector3(0, size.y - 0.5, size.z / 2.0 + 2.5)
	own(glow, eaves)


func _build_city() -> Node3D:
	scene = Node3D.new()
	scene.name = "Ilunhall"
	scene.add_to_group("navmesh_source", true)
	common("Ilunhall", true, "capital")
	skirt(ROCK)

	# The fjord, south of the quay; cliffs east and west; the mountain behind.
	var water := MeshInstance3D.new()
	water.name = "Fjord"
	var wm := PlaneMesh.new()
	wm.size = Vector2(1600, 700)
	wm.material = water_mat(Vector2(0.08, 0.04))
	water.mesh = wm
	water.position = Vector3(0, -0.9, 390)
	own(water)
	box("CliffWest", Vector3(24, 46, 340), Vector3(-97, 22, 50), ROCK, "surface_stone")
	box("CliffEast", Vector3(24, 46, 340), Vector3(97, 22, 50), ROCK, "surface_stone")
	box("Mountain", Vector3(260, 80, 50), Vector3(0, 39, -135), ROCK, "surface_stone")

	# The four terraces: the Quay Steps (y 0), the Long Halls (4), the Feast Steps
	# (8) and the Hall of Spears' forecourt (12).
	box("QuaySteps", Vector3(170, 1, 52), Vector3(0, -0.5, 14), PAVING, "surface_stone")
	terrace("LongHalls", 4.0, -12.0, -42.0)
	terrace("FeastSteps", 8.0, -42.0, -72.0)
	terrace("Forecourt", 12.0, -72.0, -110.0)
	ramp("MarketSteps", 0.0, 0.0, 0.0, 4.0, 12.0, 8.0)
	ramp("HallSteps", 0.0, 4.0, -30.0, 4.0, 12.0, 6.0)
	ramp("SpearSteps", 0.0, 8.0, -60.0, 4.0, 12.0, 6.0)

	# The quay: piers, longships, the market, the harbour houses.
	for x in [-30.0, 40.0]:
		box("Pier%d" % int(x), Vector3(4, 1, 18), Vector3(x, -0.5, 49), DARK_TIMBER, "surface_wood")
	for ship in [["Longship1", Vector3(-25, -0.6, 52)], ["Longship2", Vector3(46, -0.6, 50)]]:
		box(ship[0], Vector3(3, 1.4, 16), ship[1], DARK_TIMBER, "surface_wood")
		box(ship[0] + "Mast", Vector3(0.3, 8, 0.3), ship[1] + Vector3(0, 4.5, 0), DARK_TIMBER)
	box("BrunaStall", Vector3(4, 1.1, 1.2), Vector3(-20, 0.55, 17), TIMBER, "surface_wood")
	box("BrunaAwning", Vector3(4.6, 0.15, 2.6), Vector3(-20, 2.6, 17.6), Color(0.45, 0.2, 0.15))
	for i in 5:
		box("Crate%d" % (i + 1), Vector3(1, 1, 1), Vector3(26 + (i % 3) * 1.1, 0.5, 30 + (i / 3) * 1.1), TIMBER, "surface_wood")
	for h in [["HarbourHouse1", -60.0], ["HarbourHouse2", -44.0], ["HarbourHouse3", 46.0], ["HarbourHouse4", 62.0]]:
		house(h[0], Vector3(10, 4, 6), Vector3(h[1], 0, -6), Color(0.5, 0.42, 0.32), DARK_TIMBER)
	signpost("QuaySign", "ILUNHALL.\nThe Quay Steps. Up: the Long Halls, the Feast Steps, the Hall of Spears.\nWest: the Imperial Road.",
			Vector3(-70, 1.4, 15), -PI / 2.0)
	lantern("LanternQuay", Vector3(-10, 0, 10))
	lantern("LanternPier", Vector3(36, 0, 36))

	# The barred gate under the Market Steps: the Undercroft, once you know.
	var barred := Node3D.new()
	barred.name = "GateBarred"
	barred.set_script(PRESENCE)
	barred.set("hide_flag", "undercroft_lead")
	own(barred)
	var bars := box("UndercroftBars", Vector3(2.4, 2.6, 0.3), Vector3(12, 1.3, -11.8), Color(0.12, 0.12, 0.13), "", barred, EXAMINE)
	bars.set("prompt", "Look at the barred gate")
	bars.set("speaker", "")
	bars.set("dialogue_file", "res://dialogue/ilunhall_gate.json")
	var open := Node3D.new()
	open.name = "GateOpen"
	open.set_script(PRESENCE)
	open.set("show_flag", "undercroft_lead")
	own(open)
	var gate := box("UndercroftGate", Vector3(2.4, 2.6, 0.3), Vector3(12, 1.3, -11.8), Color(0.05, 0.05, 0.06), "", open, LOCATION_DOOR)
	gate.set("target_scene", "res://levels/ilunhall_undercroft.tscn")
	gate.set("target_marker", "FromQuay")
	gate.set("destination_name", "the Undercroft")
	gate.set("verb", "Go down into")
	marker("FromUndercroft", Vector3(12, 0, -8), 0.0)

	# The Long Halls: the Ember College and the Lantern Order's chapterhouse, and
	# Karra's scaffold on the College's eaves.
	great_hall("EmberCollege", Vector3(24, 8, 12), Vector3(-40, 4, -34), Color(0.4, 0.18, 0.12))
	great_hall("Chapterhouse", Vector3(16, 7, 10), Vector3(40, 4, -34), Color(0.3, 0.3, 0.32))
	for i in 3:
		box("Scaffold%d" % (i + 1), Vector3(0.2, 8, 0.2), Vector3(-27 + i * 1.6, 8, -27), TIMBER)
	box("ScaffoldDeck", Vector3(4, 0.15, 1.6), Vector3(-25.4, 8.5, -27), TIMBER, "surface_wood")
	lantern("LanternCollege", Vector3(-30, 4, -24), Color(1, 0.6, 0.35))
	lantern("LanternChapter", Vector3(32, 4, -24), Color(1, 0.85, 0.6))

	# The Feast Steps: the Long Table, a feast hall open at the front (a bed at the
	# back once you've paid Odo; the Hundredth Horn in its trophy chest), and the
	# Rune Bridge up to the forecourt.
	box("LongTableBack", Vector3(22, 7, 0.6), Vector3(-38, 11.5, -69), TIMBER, "surface_wood")
	box("LongTableWallW", Vector3(0.6, 7, 14), Vector3(-49, 11.5, -62), TIMBER, "surface_wood")
	box("LongTableWallE", Vector3(0.6, 7, 14), Vector3(-27, 11.5, -62), TIMBER, "surface_wood")
	box("LongTableRoof", Vector3(23, 0.5, 15), Vector3(-38, 15.2, -62), GILT, "surface_wood")
	box("LongTable", Vector3(14, 0.9, 1.6), Vector3(-38, 8.45, -62), DARK_TIMBER, "surface_wood")
	for i in 6:
		box("Bench%d" % (i + 1), Vector3(2, 0.5, 0.5), Vector3(-44 + (i % 3) * 5.5, 8.25, -63.6 + (i / 3) * 3.2), TIMBER, "surface_wood")
	var trophies := box("TrophyChest", Vector3(1.4, 0.8, 0.8), Vector3(-46, 8.4, -67.8), Color(0.35, 0.2, 0.1), "surface_wood", null, LOOT)
	trophies.set("container_name", "trophy chest")
	trophies.set("contents", {"hundredth_horn": 1})
	trophies.set("lock_level", 2)
	var room := Node3D.new()
	room.name = "FeastBed"
	room.set_script(PRESENCE)
	room.set("show_flag", "feast_bed")
	own(room)
	box("FeastHallBed", Vector3(1.2, 0.5, 2.2), Vector3(-30, 8.25, -66.5), Color(0.5, 0.2, 0.18), "surface_wood", room, BED)
	var hearth := OmniLight3D.new()
	hearth.name = "FeastFire"
	hearth.set_script(FLICKER)
	hearth.light_color = Color(1, 0.6, 0.3)
	hearth.light_energy = 2.0
	hearth.omni_range = 14.0
	hearth.position = Vector3(-38, 10.5, -64)
	own(hearth)
	var feast_eaves := Node3D.new()
	feast_eaves.name = "LongTableLightStone"
	feast_eaves.set_script(LIGHT_STONE)
	feast_eaves.set("dim_flag", "conduit_broken")
	own(feast_eaves)
	var fs := MeshInstance3D.new()
	fs.name = "Strip"
	var fsm := BoxMesh.new()
	fsm.size = Vector3(23, 0.18, 0.18)
	fs.mesh = fsm
	fs.position = Vector3(-38, 14.9, -54.4)
	own(fs, feast_eaves)

	# The Rune Bridge: rune-lit stones along its rails, readable only at night.
	box("RuneBridgePierA", Vector3(1.2, 9, 1.2), Vector3(43.2, 4.5, -64), QUAY_STONE, "surface_stone")
	box("RuneBridgePierB", Vector3(1.2, 9, 1.2), Vector3(46.8, 4.5, -64), QUAY_STONE, "surface_stone")
	ramp("RuneBridge", 45.0, 8.0, -56.0, 4.0, 16.0, 3.4)
	for side in [-1.0, 1.0]:
		var rail := box("RuneBridgeRail%s" % ("W" if side < 0 else "E"), Vector3(0.2, 0.9, 16.6), Vector3(45 + side * 1.8, 10.45, -64), QUAY_STONE, "surface_stone")
		rail.rotation.x = -atan2(4.0, 16.0)
	for i in 3:
		var z := -59.0 - i * 5.0
		var y := 8.0 + (-56.0 - z) / 16.0 * 4.0   # the bridge's deck at z
		examine("RuneStone%d" % (i + 1), "Look at the runes", "", "res://dialogue/ilunhall_runestone_%d.json" % (i + 1),
				Vector3(0.5, 1.1, 0.5), Vector3(43.0 if i != 1 else 47.0, y + 0.8, z), RUNE_BLUE)
		var rl := OmniLight3D.new()
		rl.name = "RuneLight%d" % (i + 1)
		rl.light_color = RUNE_BLUE
		rl.light_energy = 0.8
		rl.omni_range = 4.0
		rl.position = Vector3(45, y + 1.6, z)
		own(rl)

	# The forecourt and the Hall of Spears: its roof held up by a forest of spear-shafts.
	great_hall("HallOfSpears", Vector3(52, 14, 26), Vector3(0, 12, -96), Color(0.36, 0.24, 0.13))
	box("SpearPortico", Vector3(52, 0.5, 8), Vector3(0, 23.5, -79), GILT)
	for row in 2:
		for i in 26:
			var shaft := MeshInstance3D.new()
			shaft.name = "Spear%d_%d" % [row, i]
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.07
			cyl.bottom_radius = 0.1
			cyl.height = 11.3
			cyl.radial_segments = 6
			cyl.material = mat(DARK_TIMBER)
			shaft.mesh = cyl
			shaft.position = Vector3(-25 + i * 2.0, 17.65, -76.2 - row * 3.0)
			own(shaft)
	examine("HallDoors", "Look at the doors of the Hall of Spears", "", "res://dialogue/ilunhall_hall_doors.json",
			Vector3(6, 9, 0.4), Vector3(0, 16.5, -82.8), GILT)
	lantern("LanternForecourtW", Vector3(-10, 12, -75))
	lantern("LanternForecourtE", Vector3(10, 12, -75))

	# People.
	npc("Bruna", "Bruna Deepseal", "res://dialogue/bruna.json", Vector3(-20, 0, 15.5), Color(0.35, 0.3, 0.45), PI, null, "deepfolk/merchant")
	var nob_here := Node3D.new()   # Nob's off the quay once Odo's heard about him
	nob_here.name = "NobHere"
	nob_here.set_script(PRESENCE)
	nob_here.set("hide_flag", "horn_reported")
	own(nob_here)
	npc("Nob", "Nob Ashby", "res://dialogue/nob.json", Vector3(28, 0, 28), Color(0.3, 0.28, 0.25), PI, nob_here, "small_folk/commoner")
	npc("Saelie", "Saelie of the Low Lane", "res://dialogue/saelie.json", Vector3(37, 0, 34), Color(0.3, 0.4, 0.5), PI, null, "passenger/priest")
	npc("Karra", "Karra Seamwright", "res://dialogue/karra.json", Vector3(-25, 4, -24.5), Color(0.45, 0.3, 0.18), PI, null, "deepfolk/worker")
	npc("Ignatia", "Magister Ignatia Rufa", "res://dialogue/ignatia.json", Vector3(-40, 4, -25.5), Color(0.55, 0.15, 0.1), PI, null, "orc/scholar")
	npc("Severin", "Inquisitor-Captain Severin", "res://dialogue/severin.json", Vector3(40, 4, -26.5), Color(0.2, 0.18, 0.16), PI, null, "human/inquisitor")
	npc("Odo", "Hallmaster Odo", "res://dialogue/odo.json", Vector3(-38, 8, -59), Color(0.5, 0.35, 0.2), PI, null, "human/innkeeper")
	npc("Cassia", "Steward Cassia Varro", "res://dialogue/cassia.json", Vector3(5, 12, -77), Color(0.45, 0.12, 0.2), PI, null, "human/official")
	# A day by the clock for the quay and the scaffold (the rest keep their posts).
	gathering(Vector3(-36, 8, -50))   # outside the Long Table
	routines(["Bruna", "Karra"])
	# The law: two wardens (guards, systems/crime.gd), one watching the quay stalls.
	npc("QuayWarden", "Warden of the Quay", "res://dialogue/warden.json", Vector3(-6, 0, 22), Color(0.3, 0.32, 0.4), PI / 2.0, null, "human/guard")
	npc("BridgeWarden", "Bridge Warden", "res://dialogue/warden.json", Vector3(42, 8, -47), Color(0.3, 0.32, 0.4), PI, null, "orc/guard")
	marker("JailRelease", Vector3(-6, 0, 25), 0.0)
	npc("Quill", "Quill", "res://dialogue/quill.json", Vector3(33, 0, 37), Color(0.25, 0.24, 0.22), PI, null, "small_folk/commoner")   # the Low Lane fence
	goods("BrunaIngots", "steel_ingot", 2, Vector3(-21.2, 1.2, 17), "Bruna Deepseal")
	goods("BrunaTonic", "potion_restore_magicka_1", 1, Vector3(-18.8, 1.2, 17), "Bruna Deepseal")
	stores("OdoCask", "Odo's strongbox", {"bread": 2}, 35, Vector3(-30, 8.35, -66), "Hallmaster Odo", 1)

	# The road back west to the Grieving Fields.
	door("ImperialRoad", "res://levels/grieving_fields.tscn", "FromIlunhall", "the Grieving Fields", "Take the Imperial Road to",
			Vector3(0.4, 3, 4), Vector3(-84, 1.5, 20), Color(0.45, 0.32, 0.18))
	marker("FromFields", Vector3(-78, 0, 20), -PI / 2.0)
	# The Deep Road east, into the mountains, to Karrowdeep (docs/godot-starter/KARROWDEEP.md).
	door("DeepRoad", "res://levels/karrowdeep.tscn", "FromIlunhall", "Karrowdeep", "Take the Deep Road to",
			Vector3(0.4, 3, 4), Vector3(84.6, 1.5, 20), Color(0.35, 0.25, 0.15))
	marker("FromKarrowdeep", Vector3(79, 0, 20), PI / 2.0)
	# The ship south across the sea to the Glass Coast (docs/godot-starter/GLASS_COAST.md).
	door("ShipToGlass", "res://levels/glass_coast.tscn", "FromIlunhall", "the Glass Coast", "Take ship to",
			Vector3(2, 2.5, 0.4), Vector3(40, 1.25, 57.6), Color(0.4, 0.28, 0.16))
	marker("FromGlassCoast", Vector3(40, 0, 52), 0.0)
	signpost("DeepRoadSign", "East: the Deep Road, to Karrowdeep under the mountain.", Vector3(80, 1.4, 16), PI / 2.0)

	var level_map := Node.new()
	level_map.name = "LevelMap"
	level_map.set_script(LEVEL_MAP)
	level_map.set("map_name", "Ilunhall: the Lower Steps")
	level_map.set("area", Rect2(-90, -115, 180, 175))
	level_map.set("camera_height", 120.0)
	own(level_map)
	map_marker("MapIlunhall", "ilunhall", "Ilunhall: the Quay Steps", Vector3(-64, 0, 18), 1)
	map_marker("MapEmberCollege", "ember_college", "The Ember College", Vector3(-40, 4, -26), 2)
	map_marker("MapChapterhouse", "chapterhouse", "The Lantern Order's chapterhouse", Vector3(40, 4, -27), 2)
	map_marker("MapLongTable", "long_table", "The Long Table", Vector3(-38, 8, -53), 2)
	map_marker("MapRuneBridge", "rune_bridge", "The Rune Bridge", Vector3(45, 8, -50))
	map_marker("MapHallOfSpears", "hall_of_spears", "The Hall of Spears", Vector3(0, 12, -78))

	var player: Node3D = PLAYER.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.position = Vector3(-78, 1, 20)
	player.rotation.y = -PI / 2.0
	own(player)
	return scene


# --- the Undercroft --------------------------------------------------------------------------

func _build_undercroft() -> Node3D:
	scene = Node3D.new()
	scene.name = "Undercroft"
	scene.add_to_group("navmesh_source", true)
	common("Undercroft", false)
	air(0.025, Color(0.75, 0.8, 0.78))   # damp
	var stone := Color(0.26, 0.25, 0.24)
	# A stair-tunnel south from the gate into an old cistern hall, pillars in rows,
	# gold veins of light-stone climbing the walls up into the city.
	box("TunnelFloor", Vector3(5, 0.5, 12), Vector3(0, -0.25, 4), stone, "surface_stone")
	box("TunnelCeiling", Vector3(5, 0.5, 12), Vector3(0, 3.75, 4), stone, "surface_stone")
	box("TunnelW", Vector3(0.5, 4, 12), Vector3(-2.5, 1.75, 4), stone, "surface_stone")
	box("TunnelE", Vector3(0.5, 4, 12), Vector3(2.5, 1.75, 4), stone, "surface_stone")
	box("TunnelN", Vector3(5, 4, 0.5), Vector3(0, 1.75, -2), stone, "surface_stone")
	box("HallFloor", Vector3(28, 0.5, 26), Vector3(0, -0.25, 23), stone, "surface_stone")
	box("HallCeiling", Vector3(28, 0.5, 26), Vector3(0, 7.25, 23), stone, "surface_stone")
	box("HallW", Vector3(0.5, 7.5, 26), Vector3(-14, 3.5, 23), stone, "surface_stone")
	box("HallE", Vector3(0.5, 7.5, 26), Vector3(14, 3.5, 23), stone, "surface_stone")
	box("HallS", Vector3(28, 7.5, 0.5), Vector3(0, 3.5, 36), stone, "surface_stone")
	box("HallNW", Vector3(11.5, 7.5, 0.5), Vector3(-8.25, 3.5, 10), stone, "surface_stone")
	box("HallNE", Vector3(11.5, 7.5, 0.5), Vector3(8.25, 3.5, 10), stone, "surface_stone")
	for row in 2:
		for i in 3:
			box("Pillar%d_%d" % [row, i], Vector3(1.2, 7, 1.2), Vector3(-7 + i * 7.0, 3.5, 16 + row * 10.0), stone, "surface_stone")
	var cistern := MeshInstance3D.new()
	cistern.name = "Cistern"
	var cm := BoxMesh.new()
	cm.size = Vector3(26, 0.05, 4)
	cm.material = water_mat(Vector2.ZERO)
	cistern.mesh = cm
	cistern.position = Vector3(0, 0.03, 33.5)
	own(cistern)

	# The veins of light-stone, and the conduit that feeds them.
	var veins := Node3D.new()
	veins.name = "Veins"
	veins.set_script(LIGHT_STONE)
	veins.set("dim_flag", "conduit_broken")
	veins.set("day_energy", 2.0)   # underground: the clock doesn't matter
	veins.set("night_energy", 2.0)
	veins.set("dimmed", 0.1)
	own(veins)
	for i in 6:
		var v := MeshInstance3D.new()
		v.name = "Vein%d" % (i + 1)
		var vm := BoxMesh.new()
		vm.size = Vector3(0.25, 7, 0.25)
		v.mesh = vm
		v.position = Vector3(-13.6 if i < 3 else 13.6, 3.5, 14 + (i % 3) * 8.0)
		own(v, veins)
	var vglow := OmniLight3D.new()
	vglow.name = "VeinGlow"
	vglow.light_color = Color(1.0, 0.75, 0.4)
	vglow.light_energy = 2.5
	vglow.omni_range = 20.0
	vglow.position = Vector3(0, 6, 24)
	own(vglow, veins)
	examine("Conduit", "Look at the conduit", "", "res://dialogue/ilunhall_conduit.json",
			Vector3(2.4, 3.2, 2.4), Vector3(0, 1.6, 23), Color(0.75, 0.6, 0.3))
	for i in 4:
		box("Cage%d" % (i + 1), Vector3(1, 1.2, 1), Vector3(-3 + i * 2.0, 0.6, 27), Color(0.18, 0.18, 0.2))
	for i in 3:
		var light := OmniLight3D.new()
		light.name = "Torch%d" % (i + 1)
		light.set_script(FLICKER)
		light.light_color = Color(1, 0.65, 0.35)
		light.light_energy = 1.2
		light.omni_range = 7.0
		light.position = Vector3(1.8, 2.6, 0.5 + i * 4.0)
		own(light)

	# The Mercy, and Magister Vessa at her desk by the cistern.
	var mercy := Node3D.new()
	mercy.name = "Mercy"
	mercy.set_script(PACK)
	mercy.set("cleared_flag", "undercroft_cleared")
	mercy.set("cleared_message", "The Undercroft is quiet. Only the conduit hums, and Vessa hasn't moved.")
	own(mercy)
	for spot in [["Acolyte1", Vector3(-5, 0, 18)], ["Acolyte2", Vector3(5, 0, 19)]]:
		enemy(mercy, spot[0], "Mercy Acolyte", spot[1], PI, CULTIST, {"gold": 15})
	enemy(mercy, "Acolyte3", "Mercy Drawer", Vector3(0, 0, 24), PI, CULTIST, {"gold": 15, "caster": true, "max_health": 45.0})
	box("VessaDesk", Vector3(2.4, 0.9, 1.1), Vector3(8, 0.45, 31.5), DARK_TIMBER, "surface_wood")
	var vessa_here := Node3D.new()
	vessa_here.name = "VessaHere"
	vessa_here.set_script(PRESENCE)
	vessa_here.set("hide_flag", "vessa_gone")
	own(vessa_here)
	npc("Vessa", "Magister Vessa", "res://dialogue/vessa.json", Vector3(8, 0, 30), Color(0.4, 0.34, 0.45), 0.0, vessa_here, "human/scholar")
	var vessa_fight := Node3D.new()
	vessa_fight.name = "VessaFights"
	vessa_fight.set_script(PRESENCE)
	vessa_fight.set("show_flag", "vessa_fight")
	own(vessa_fight)
	var vessa_pack := Node3D.new()
	vessa_pack.name = "VessaPack"
	vessa_pack.set_script(PACK)
	vessa_pack.set("cleared_flag", "vessa_killed")
	vessa_pack.set("cleared_message", "Magister Vessa falls, grey to the shoulder. The conduit keeps humming.")
	own(vessa_pack, vessa_fight)
	enemy(vessa_pack, "VessaFoe", "Magister Vessa", Vector3(8, 0, 30), 0.0, CULTIST,
			{"gold": 80, "max_health": 160.0, "attack_damage": 16.0, "guard_chance": 0.6, "parry_chance": 0.2,
			"caster": true, "bolt_damage": 18.0, "draw_damage": 7.0,   # a magister: she casts
			"look_vary": false, "look_role": "scholar", "look_cloth": Color(0.4, 0.34, 0.45)})

	map_marker("MapUndercroft", "undercroft", "The Undercroft", Vector3(0, 0, 12))
	door("Stair", "res://levels/ilunhall.tscn", "FromUndercroft", "the Quay Steps", "Climb up to",
			Vector3(1.6, 3.5, 0.3), Vector3(0, 1.75, -1.6), Color(0.35, 0.25, 0.15))
	marker("FromQuay", Vector3(0, 0, 1), PI)

	var level_map := Node.new()
	level_map.name = "LevelMap"
	level_map.set_script(LEVEL_MAP)
	level_map.set("map_name", "The Undercroft")
	level_map.set("area", Rect2(-15, -3, 30, 40))
	level_map.set("camera_height", 40.0)
	own(level_map)

	var player: Node3D = PLAYER.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	player.name = "Player"
	player.position = Vector3(0, 1, 1)
	own(player)
	return scene
