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
			var full_region: float = map._atlas.region.size.x
			# A tap (a finger is the left mouse button too) doesn't zoom: it used to, as "attack".
			for pressed in [true, false]:
				var tap := InputEventMouseButton.new()
				tap.button_index = MOUSE_BUTTON_LEFT
				tap.pressed = pressed
				tap.position = Vector2(250, 250)
				map._gui_input(tap)
			ok(is_equal_approx(map.zoom, 1.0), "a tap doesn't zoom", map.zoom)
			# The + button, the wheel and a pinch zoom in; - zooms out.
			map._buttons.get_node("ZoomIn").pressed.emit()
			ok(map.shown_area().size.x < full and map._atlas.region.size.x < full_region, "+ zooms in (cropping the picture)", map.shown_area().size.x)
			var wheel := InputEventMouseButton.new()
			wheel.button_index = MOUSE_BUTTON_WHEEL_UP
			wheel.pressed = true
			wheel.position = Vector2(250, 250)
			var before: float = map.zoom
			map._gui_input(wheel)
			near(map.zoom, before * map.ZOOM_STEP, 0.01, "the wheel zooms in")
			map._buttons.get_node("ZoomOut").pressed.emit()
			map._buttons.get_node("ZoomOut").pressed.emit()
			near(map.zoom, 1.0, 0.01, "- zooms back out")
			for t in [[0, Vector2(150, 250)], [1, Vector2(250, 250)]]:
				var touch := InputEventScreenTouch.new()
				touch.index = t[0]
				touch.position = t[1]
				touch.pressed = true
				map._gui_input(touch)
			var spread := InputEventScreenDrag.new()
			spread.index = 1
			spread.position = Vector2(350, 250)
			map._gui_input(spread)
			near(map.zoom, 2.0, 0.01, "spreading two fingers twice as far apart zooms in twice")
			for i in [0, 1]:
				var up := InputEventScreenTouch.new()
				up.index = i
				up.pressed = false
				map._gui_input(up)
			# Dragging moves the map (the picture follows the finger), and stops at the edges.
			var was: Vector2 = map.center
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			map._gui_input(press)
			var drag := InputEventMouseMotion.new()
			drag.relative = Vector2(100, 0)
			map._gui_input(drag)
			ok(map.center.x < was.x, "dragging right shows what's to the west", [was, map.center])
			drag.relative = Vector2(-100000, -100000)
			map._gui_input(drag)
			var area: Rect2 = map.shown_area()
			var whole: Rect2 = map.full_area()
			ok(area.end.x <= whole.end.x + 0.01 and area.end.y <= whole.end.y + 0.01, "and stops at the edge of the level")
			press.pressed = false
			map._gui_input(press)
			map._buttons.get_node("ZoomMe").pressed.emit()
			ok(map.shown_area().get_center().distance_to(Vector2(p.global_position.x, p.global_position.z)) < 0.01, "Me centres the map on the player")
			map.set_zoom(1.0)
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
