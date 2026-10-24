extends "res://tests/test_base.gd"
# Compass and map: discovering places, quest markers following objectives, compass
# bearings, the map tab (M) and its zoom, and maps in interiors.
var f := 0
var step := 0
var wait := 0
var p
var GS
var CM

func _initialize() -> void:
	change_scene_to_file("res://levels/test_level.tscn")

func press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)

func marker(node_name: String) -> Node:
	return current_scene.find_child(node_name, true, false)

func targets() -> Array:
	return load("res://systems/waypoints.gd").quest_targets(self)

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	GS = autoload("GameState"); CM = autoload("CharacterMenu")
	var W = load("res://systems/waypoints.gd")
	match step:
		0:
			wait = 10
		1:
			ok(marker("MapWaystation").is_discovered(), "the waystation is known from the start")
			ok(marker("MapStoneCircle").is_discovered(), "the stone circle, 14 m from spawn, is found at once")
			ok(not marker("MapBanditCamp").is_discovered(), "the bandit camp isn't")
			ok(targets().is_empty(), "no quests, no quest markers", targets())
			p.global_position = Vector3(-26, 0.05, -26)   # about 11 m from the bandit camp's centre
			wait = 45
		2:
			ok(marker("MapBanditCamp").is_discovered() and GS.has_flag("discovered_bandit_camp"), "walking close discovers it")
			p.global_position = Vector3(0, 0.05, 0)
			ok(not marker("MapOldBarrow").is_discovered(), "far places stay undiscovered")
			# Quest markers follow the next objective.
			GS.set_flag("wolf_quest_accepted")
			var t: Array = targets()
			ok(t.size() == 1 and t[0]["position"].distance_to(marker("GreyfangPack").global_position) < 0.01, "accepting the wolf quest marks the pack", t)
			GS.set_flag("stones_quest_started")
			ok(targets().size() == 2, "a second quest adds its marker", targets().size())
			GS.set_flag("touched_crystal")
			ok(targets().size() == 4, "next stones objective: the three shards", targets().size())
			marker("RuneShard1").queue_free()
			wait = 2
		3:
			ok(targets().size() == 3, "a picked-up shard drops off the compass", targets().size())
			GS.set_flag("wolves_cleared")
			var t: Array = targets().filter(func(x): return x["title"] == "The Greyfang Pack")
			ok(t.size() == 1 and t[0]["position"].distance_to(marker("Maren").global_position) < 0.01, "wolves dead: the marker moves to Maren")
			# Bearings: 0 = north (-Z), 90 = east (+X).
			near(W.bearing(Vector3.ZERO, Vector3(0, 0, -10)), 0.0, 0.01, "bearing north")
			near(W.bearing(Vector3.ZERO, Vector3(10, 0, 0)), 90.0, 0.01, "bearing east")
			near(absf(W.bearing(Vector3.ZERO, Vector3(0, 0, 10))), 180.0, 0.01, "bearing south")
			p.rotation.y = deg_to_rad(-90.0)
			wait = 2
		4:
			near(W.heading(p.camera), 90.0, 0.5, "turned right: facing east")
			var compass = p.hud.compass
			ok(compass != null and compass.is_visible_in_tree(), "the HUD has a compass")
			near(compass.x_for(90.0, 90.0), compass.WIDTH / 2.0, 0.01, "what you face is in the middle of the strip")
			near(compass.x_for(135.0, 90.0), compass.WIDTH * 0.75, 0.01, "45 degrees right is three quarters along")
			ok(is_nan(compass.x_for(270.0, 90.0)), "behind you is off the strip")
			press("map")
			wait = 5
		5:
			ok(CM.is_open and CM.tabs.current_tab == CM.MAP_TAB, "M opens the map tab")
			var map = CM.map_view
			map._overlay.size = Vector2(500, 500)   # headless runs have no window to lay the menu out in
			ok(map._level_map != null and map._level_map.map_name == "The North Road", "the level's map is found")
			ok(not map._empty_label.visible, "no 'no map' message outdoors")
			var at: Vector2 = map.to_map(p.global_position)
			ok(Rect2(Vector2.ZERO, map._overlay.size).has_point(at), "the player is on the map", at)
			near(map.to_map(Vector3(0, 0, 0)).x, map._overlay.size.x / 2.0, 1.0, "the world centre is the map centre")
			ok(map.to_map(Vector3(0, 0, -30)).y < map.to_map(Vector3(0, 0, 30)).y, "north is up")
			var full: float = map.shown_area().size.x
			map._zoom = 1
			ok(map.shown_area().size.x < full, "zooming in shows less", map.shown_area().size.x)
			ok(map.shown_area().get_center().distance_to(Vector2(p.global_position.x, p.global_position.z)) < 0.01, "zoomed in, the map centres on the player")
			map._zoom = 0
			press("map")
			wait = 5
		6:
			ok(not CM.is_open, "M again closes it")
			autoload("SaveSystem").travel("res://levels/test_dungeon.tscn", "FromOutside")
			wait = 30
		7:
			press("map")
			wait = 5
		8:
			var map = CM.map_view
			ok(map._level_map != null and map._level_map.map_name == "The Old Barrow", "the barrow has its own map")
			ok(map._level_map.camera_height < 4.0, "indoor map camera sits under the ceiling", map._level_map.camera_height)
			ok(targets().is_empty(), "outside quests have no markers underground")
			CM.close()
			ok(autoload("KeyBindings").event_name(autoload("KeyBindings").binding("map", false)) == "M", "the map is on M (rebindable)")
			return done()
	step += 1
	return false
