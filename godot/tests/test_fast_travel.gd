extends "res://tests/test_base.gd"
# Fast travel (systems/fast_travel.gd, Tab → World): the places come from each
# region's map markers, only discovered ones, every arrival point is clear ground,
# time passes, and you can't go with enemies about or from an interior.
var f := 0
var step := 0
var wait := 0
var p
var GS
var FT
var hour_before := 0.0
var day_before := 0

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

## Every place in the loaded region: nothing solid where you'd stand, ground under it.
func check_arrivals(scene_path: String) -> void:
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	for place in FT.places_in(scene_path):
		var at: Vector3 = place["arrival"]
		var body := SphereShape3D.new()
		body.radius = 0.4
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = body
		q.collision_mask = 1
		q.exclude = [p.get_rid()]
		var blocked := false
		for h in [0.6, 1.4]:
			q.transform = Transform3D(Basis(), at + Vector3(0, h, 0))
			blocked = blocked or not space.intersect_shape(q, 1).is_empty()
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3(0, 1, 0), at + Vector3(0, -3, 0), 1)
		ray.exclude = [p.get_rid()]
		ok(not blocked and not space.intersect_ray(ray).is_empty(), "%s: clear ground to arrive on" % place["name"], at)

func clock() -> float:
	return autoload("WorldClock").day * 24.0 + autoload("WorldClock").hour

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	GS = autoload("GameState"); FT = autoload("FastTravel")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			wait = 5
		1:
			var vale: Array = FT.places_in("res://levels/test_level.tscn")
			var weir: Array = FT.places_in("res://levels/weirholt.tscn")
			ok(vale.size() >= 9 and weir.size() >= 10, "places read from both regions' scenes", [vale.size(), weir.size()])
			ok(vale.any(func(pl): return pl["id"] == "waystation"), "the waystation is one")
			var known: Array = FT.discovered().map(func(pl): return pl["id"])
			ok("waystation" in known and not "weirholt" in known and not "the_lanes" in known, "at the start you know the waystation and what's in sight, not the Riverlands", known)
			check_arrivals("res://levels/test_level.tscn")
			# Rules.
			ok(FT.why_not() == "", "free to travel on a quiet road", FT.why_not())
			autoload("Character").modes["hardcore"] = true
			ok(FT.why_not().begins_with("Hardcore"), "but not in Hardcore", FT.why_not())
			autoload("Character").modes["hardcore"] = false
			var wolf = n("GreyfangPack/Wolf1")
			wolf.global_position = p.global_position + Vector3(3, 0, 0)
			wolf.state = wolf.State.CHASE
			ok(FT.why_not() == "Not with enemies nearby.", "not with a wolf on your heels", FT.why_not())
			wolf.state = wolf.State.IDLE
			wolf.global_position = p.global_position + Vector3(40, 0, 40)
			# Same region.
			GS.set_flag("discovered_stone_circle")
			var circle: Dictionary = FT.discovered().filter(func(pl): return pl["id"] == "stone_circle")[0]
			hour_before = clock()
			ok(FT.go(circle), "travel to the stone circle")
			ok(p.global_position.distance_to(circle["arrival"]) < 0.5, "you're there", p.global_position)
			ok(clock() - hour_before >= FT.MIN_HOURS - 0.001, "and time has passed", clock() - hour_before)
			ok(not FT.go({"id": "weirholt", "starts_discovered": false, "name": "Weirholt", "scene": "res://levels/weirholt.tscn", "node": "MapWeirholt", "position": Vector3.ZERO, "arrival": Vector3.ZERO}), "not somewhere you haven't found")
			# Another region.
			GS.set_flag("discovered_weirholt")
			var town: Dictionary = FT.discovered().filter(func(pl): return pl["id"] == "weirholt")[0]
			ok(is_equal_approx(FT.hours_to(town), FT.REGION_HOURS), "another region: a few hours on the road")
			hour_before = clock()
			FT.go(town)
			wait = 30
		2:
			ok(current_scene.name == "Weirholt", "fast travel to Weirholt", current_scene.name)
			ok(p.global_position.distance_to(n("MapWeirholt").arrival_point()) < 0.5, "into the town square")
			near(clock() - hour_before, FT.REGION_HOURS, 0.01, "three hours later")
			check_arrivals("res://levels/weirholt.tscn")
			# From an interior, no.
			n("CulvertGrate").interact(p)
			wait = 30
		3:
			ok(FT.why_not() == "Find your way outside first.", "not from the culvert", FT.why_not())
			n("Ladder").interact(p)
			wait = 30
		4:
			# The World tab.
			autoload("CharacterMenu").open()
			wait = 5
		5:
			var menu = autoload("CharacterMenu")
			ok(menu.tabs.get_tab_title(menu.WORLD_TAB) == "World", "a World tab")
			var buttons: Array = menu.world_page.find_children("*", "Button", true, false).filter(func(b): return b.has_meta("place"))
			var ids: Array = buttons.map(func(b): return b.get_meta("place"))
			ok(ids == FT.discovered().map(func(pl): return pl["id"]) and "weirholt" in ids and "stone_circle" in ids, "a Travel button for each place you know, and only those", ids)
			ok(not "weirstones" in ids, "not the Weirstones: never been there", ids)
			var home = buttons[0]
			home.pressed.emit()
			wait = 30
		6:
			ok(not autoload("CharacterMenu").is_open, "the menu closes")
			ok(current_scene.name == "TestLevel", "and you're back at the waystation", current_scene.name)
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
