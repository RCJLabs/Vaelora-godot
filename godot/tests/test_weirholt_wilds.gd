extends "res://tests/test_base.gd"
# The country around Weirholt (levels/builders/build_weirholt.gd, _build_wilds):
# the woods road, the toll-road gang (Varga's bounty, or an overturned cart), and
# the Weirstones across the ford, where the Mercy feed on one of the twelve sites
# at night (main quest "The Weirstones", after Down the Greywater).
var f := 0
var step := 0
var wait := 0
var p
var GS
var Q
var DM

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/weirholt.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func pick(start: String) -> bool:
	var t: Array = DM._choices.map(func(c): return c["text"])
	for i in t.size():
		if t[i].begins_with(start):
			DM.choose(i)
			return true
	ok(false, "choice '%s' offered" % start, t)
	return false

func kill_all(group: String) -> void:
	for e in n(group).get_children():
		e.take_hit(9999.0, p.global_position, 0.0, 0.0)

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	GS = autoload("GameState"); Q = autoload("QuestLog"); DM = autoload("DialogueManager")
	match step:
		0:
			wait = 5
		1:
			ok(n("FromVale").global_position.z < -85, "you arrive at the top of the woods road, not at the gate")
			ok(n("NorthRoad").global_position.z < -95, "the way north is at the far end of the road")
			var trees := current_scene.get_children().filter(func(c): return c.name.begins_with("Tree"))
			ok(trees.size() == 70, "woods along the road", trees.size())
			ok(trees.all(func(t): return absf(t.global_position.x) >= 6.0), "none of them on the road")
			ok(n("LevelMap").area.size.x >= 200.0, "a bigger map")
			# The toll-road gang.
			n("RobbedCart").interact(p)
			ok(Q.status("toll_road_gang")["state"] == "active", "an overturned cart starts The Toll-Road Gang")
			DM.end()
			n("Varga").interact(p)
			pick("Somebody's robbing carts")
			ok(GS.has_flag("bounty_accepted"), "Varga puts a hundred gold on them")
			DM.end()
			ok(n("TollRoadGang").get_child_count() == 3, "three of them in the clearing")
			kill_all("TollRoadGang")
			wait = 10
		2:
			ok(GS.has_flag("toll_gang_cleared"), "the camp goes quiet")
			var gold: int = autoload("Inventory").gold
			n("Varga").interact(p)
			pick("The camp in the woods is cleared")
			ok(GS.has_flag("bounty_paid") and autoload("Inventory").gold == gold + 100, "a hundred gold from Varga")
			ok(Q.status("toll_road_gang")["state"] == "completed", "The Toll-Road Gang done")
			DM.end()
			# The Weirstones: only once the barges are dealt with.
			ok(Q.status("the_weirstones")["state"] == "hidden", "The Weirstones isn't open yet")
			GS.set_flag("barges_resolved")
			ok(Q.status("the_weirstones")["state"] == "active", "Down the Greywater's end opens The Weirstones")
			ok(Q.quests["the_weirstones"].get("main", false), "a main quest")
			n("Varga").interact(p)
			pick("Where does the ledger's trail go")
			ok(GS.has_flag("weirstones_hinted"), "Varga points you across the ford")
			DM.end()
			ok(not n("Acolytes").visible, "nobody at the stones until the rite")
			autoload("WorldClock").hour = 13.0
			p.global_position = n("Weirstones").global_position + Vector3(0, 0.5, 12)
			wait = 10
		3:
			ok(GS.has_flag("weirstones_seen_by_day") and not GS.has_flag("weirstones_rite"), "by day: an empty circle and a humming bundle")
			n("DrainFocus").interact(p)
			ok(not GS.has_flag("weirstones_letter"), "you can't get at it yet")
			DM.end()
			for a in n("Acolytes").get_children():
				a.set_physics_process(false)
			autoload("WorldClock").hour = 23.0
			wait = 10
		4:
			ok(GS.has_flag("weirstones_rite") and n("Acolytes").visible, "after dark: the rite, and three acolytes")
			ok(Q.current_objective("the_weirstones").begins_with("Stop whoever"), "next: stop them", Q.current_objective("the_weirstones"))
			kill_all("Acolytes")
			wait = 10
		5:
			ok(GS.has_flag("weirstones_cleared"), "the chanting stops")
			n("DrainFocus").interact(p)
			ok(GS.has_flag("weirstones_letter"), "a letter from V.: the harvest moves to the Grieving Fields")
			pick("Break the cage open")
			ok(GS.has_flag("weirstones_freed") and Q.status("the_weirstones")["state"] == "completed", "the light goes back to the stones: done")
			DM.end()
			var gold: int = autoload("Inventory").gold
			n("Varga").interact(p)
			pick("The Weirstones are quiet")
			ok(GS.has_flag("weirstones_reported") and autoload("Inventory").gold == gold + 50, "Varga hears about the Grieving Fields")
			DM.end()
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
