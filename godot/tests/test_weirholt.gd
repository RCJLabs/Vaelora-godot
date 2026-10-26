extends "res://tests/test_base.gd"
# The Riverlands' first town, Weirholt (levels/weirholt.tscn, built by
# levels/builders/build_weirholt.gd): the south road from the Vale and back, the
# people, the inn, the merchant and the trainer, and its three quests:
#   Down the Greywater  the barges at the dark of the Wanderer, the culvert, the ledger
#   The Toll of the Weir   Sergeant Dace's double toll
#   Fever in the Lanes  the Passengers blamed for a fever that's in the water
# Argument: how Down the Greywater ends: varga (default), bribe or flee.
var f := 0
var step := 0
var wait := 0
var mode := ""
var p
var GS
var Q
var DM
var gold_before := 0

func _initialize() -> void:
	mode = arg("varga")
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

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

func talk(npc: String) -> void:
	n(npc).interact(p)

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
			var road = n("SouthRoad")
			ok(road != null and road.target_scene == "res://levels/weirholt.tscn", "a south road out of the Vale")
			road.interact(p)
			wait = 30
		2:
			ok(current_scene.name == "Weirholt", "the south road leads to Weirholt", current_scene.name)
			ok(p.global_position.distance_to(n("FromVale").global_position) < 1.5, "arriving at the north road")
			for who in ["Hedda", "TarlePresence/Tarle", "Wenna", "Varga", "Dace", "Ama", "Teodor", "Fenn", "JoryDocks"]:
				ok(n(who) != null, "%s is in town" % who)
			ok(n("LevelMap").map_name == "Weirholt", "Weirholt has a map")
			autoload("Inventory").gold = 500
			autoload("Skills").levels["speech"] = 60
			# The inn.
			ok(not n("InnRoom").is_present(), "no bed until you've paid")
			talk("Hedda")
			pick("I need a bed"); pick("Here.")
			ok(GS.has_flag("inn_room") and n("InnRoom").is_present(), "Hedda's back room, for five gold")
			DM.end()
			# Jory, and the barges.
			talk("JoryDocks")
			pick("You look like"); pick("I'll look into it")
			ok(Q.status("down_the_greywater")["state"] == "active", "Jory starts Down the Greywater")
			ok(Q.quests["down_the_greywater"].get("main", false), "a main quest")
			DM.end()
			talk("TarlePresence/Tarle")
			ok(GS.has_flag("met_tarle"), "met the factor (the River Compact is known now)")
			pick("What do the barges carry")
			ok(GS.has_flag("asked_tarle_barges"), "Tarle lies nicely")
			DM.end()
			autoload("WorldClock").hour = 12.0
			n("HeronCrates").interact(p)
			ok(not GS.has_flag("heron_inspected"), "not by day: too many eyes")
			DM.end()
			autoload("WorldClock").hour = 23.0
			n("HeronCrates").interact(p)
			ok(GS.has_flag("heron_inspected"), "after dark: cages of light, and a tag that says culvert")
			DM.end()
			n("CulvertGrate").interact(p)
			wait = 30
		3:
			ok(current_scene.name == "WeirholtCulvert", "down into the culvert", current_scene.name)
			var smugglers: Array = n("Smugglers").get_children()
			ok(smugglers.size() == 3, "three smugglers", smugglers.size())
			for s in smugglers:
				s.take_hit(9999.0, p.global_position, 0.0, 0.0)
			wait = 10
		4:
			ok(GS.has_flag("culvert_cleared"), "the culvert goes quiet")
			n("LedgerChest").interact(p)
			ok(autoload("Inventory").count("harvest_ledger") == 1, "the smugglers' ledger")
			n("Cages").interact(p)
			pick("Open the cage")
			ok(GS.has_flag("culvert_wisp_freed"), "a caged wisp, let go")
			DM.end()
			n("Ladder").interact(p)
			wait = 30
		5:
			ok(current_scene.name == "Weirholt", "back up to the docks")
			ok(p.global_position.distance_to(n("FromCulvert").global_position) < 1.5, "at the culvert grate")
			gold_before = autoload("Inventory").gold
			match mode:
				"varga":
					talk("Varga"); pick("I have something you should see")
					ok(GS.has_flag("ledger_to_varga") and autoload("Inventory").gold == gold_before + 75, "Varga takes the ledger, and pays")
				"bribe":
					talk("TarlePresence/Tarle"); pick("I found your ledger"); pick("Deal.")
					ok(GS.has_flag("tarle_bribed") and autoload("Inventory").gold == gold_before + 200, "Tarle buys his ledger back")
					ok(autoload("Reputation").value("river_compact") > 0, "the Compact remembers its friends")
				"flee":
					talk("TarlePresence/Tarle"); pick("I found your ledger"); pick("No.")
					ok(GS.has_flag("tarle_fled"), "Tarle runs")
			DM.end()
			ok(Q.status("down_the_greywater")["state"] == "completed", "Down the Greywater done (%s)" % mode)
			ok(Q.status("down_the_greywater")["outcome"] != "", "with an outcome in the journal")
			ok(n("TarlePresence").is_present() == (mode == "bribe"), "Tarle's gone unless you sold him the ledger")
			# The Toll of the Weir: the ledger route.
			talk("Ama")
			ok(Q.status("toll_of_the_weir")["state"] == "active", "Ama starts The Toll of the Weir")
			DM.end()
			talk("Dace"); pick("The board in the square says two")
			ok(GS.has_flag("toll_confronted"), "Dace says rates went up")
			DM.end()
			autoload("Inventory").add("lockpick", 3)
			var box = n("TollStrongbox")
			box.unlock()
			box.interact(p)
			ok(autoload("Inventory").count("toll_ledger") == 1, "the toll ledger, from the strongbox")
			talk("Varga"); pick("Sergeant Dace is taking double toll")
			ok(GS.has_flag("dace_reported") and GS.has_flag("toll_settled"), "Varga deals with Dace")
			DM.end()
			talk("Ama")
			ok(GS.has_flag("ama_thanked") and Q.status("toll_of_the_weir")["state"] == "completed", "Ama's coppers come back: done")
			DM.end()
			# Fever in the Lanes.
			talk("Teodor"); pick("What do you think it is")
			ok(Q.status("lanes_fever")["state"] == "active", "Teodor starts Fever in the Lanes")
			DM.end()
			n("LanesWell").interact(p)
			ok(GS.has_flag("well_examined"), "a sheen on the well water, and a pipe to the mill")
			DM.end()
			n("Millstone").interact(p)
			ok(GS.has_flag("millstone_found"), "the Compact's seam-stone millstone")
			DM.end()
			talk("Fenn"); pick("It isn't the Passengers"); pick("Come and look at the well")
			ok(GS.has_flag("lanes_cleared") and Q.status("lanes_fever")["state"] == "completed", "Fenn says it in the square: done")
			DM.end()
			# The merchant and the trainer.
			talk("Wenna"); pick("Let's trade.")
			wait = 5
		6:
			ok(autoload("TradeScreen").is_open and autoload("TradeScreen").merchant == "wenna", "Wenna's stall")
			autoload("TradeScreen").close()
			talk("Varga")
			ok(DM._choices.any(func(c): return c.get("open_training", "") == "varga"), "Varga gives lessons")
			ok(autoload("Training").TRAINERS["varga"]["skill"] == "block", "in Block")
			DM.end()
			n("NorthRoad").interact(p)
			wait = 30
		7:
			ok(current_scene.name == "TestLevel", "the north road leads home")
			ok(p.global_position.distance_to(n("FromWeirholt").global_position) < 1.5, "arriving at the south road")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
