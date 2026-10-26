extends "res://tests/test_base.gd"
# The Grieving Fields (levels/builders/build_grieving_fields.gd): the road from
# Weirholt and back, Greyfold and its people, the merchant and the trainer, and
# its three quests: The Deep Ring (main), The Wisp-Finder, Cairns of the Rising.
# Argument: how The Wisp-Finder ends: persuade (default), pay or exile.
var f := 0
var step := 0
var wait := 0
var mode := ""
var p
var GS
var Q
var DM

func _initialize() -> void:
	mode = arg("persuade")
	autoload("SaveSystem").delete_save()
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

## Fast travel lands beside each place here on clear ground (as test_fast_travel checks for the others).
func check_arrivals() -> void:
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	for place in autoload("FastTravel").places_in("res://levels/grieving_fields.tscn"):
		var at: Vector3 = place["arrival"]
		var q := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.4
		q.shape = sphere
		q.collision_mask = 1
		q.exclude = [p.get_rid()]
		var blocked := false
		for h in [0.6, 1.4]:
			q.transform = Transform3D(Basis(), at + Vector3(0, h, 0))
			blocked = blocked or not space.intersect_shape(q, 1).is_empty()
		ok(not blocked, "%s: clear ground to fast travel to" % place["name"], at)

func talk(who: String) -> void:
	n(who).interact(p)

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
			# An Ashen character (made here, not in _initialize: GameState's own setup would reset the race).
			autoload("Character").create(load("res://races/ashen.tres"), "T", "soldier", [], {}, {})
			wait = 5
		1:
			ok(GS.race == "Ashen", "playing an Ashen", GS.race)
			var road = n("FieldsRoad")
			ok(road != null and road.target_scene == "res://levels/grieving_fields.tscn", "a south road out of Weirholt")
			road.interact(p)
			wait = 30
		2:
			ok(current_scene.name == "GrievingFields", "it leads to the Grieving Fields", current_scene.name)
			ok(p.global_position.distance_to(n("FromRiverlands").global_position) < 1.5, "arriving on the north road")
			for who in ["Ysolde", "Hesk", "Corin", "Marta", "Bram"]:
				ok(n(who) != null, "%s is here" % who)
			ok(autoload("FastTravel").region_name("res://levels/grieving_fields.tscn") != "", "a fast-travel region")
			check_arrivals()
			autoload("Inventory").gold = 500
			autoload("Skills").levels["speech"] = 60
			# Ysolde: an Ashen player is kin.
			talk("Ysolde")
			ok(GS.has_flag("met_ysolde"), "met the Listener (the Ashen of the Fields are known now)")
			pick("You can hear them too")
			ok(GS.has_flag("ysolde_kin"), "an Ashen player hears the lights too")
			pick("What's wrong here")
			ok(Q.status("the_deep_ring")["state"] == "active", "Ysolde starts The Deep Ring")
			DM.end()
			# Cairns.
			talk("Hesk"); pick("I'll put them back")
			ok(Q.status("cairns_of_the_rising")["state"] == "active", "Hesk starts Cairns of the Rising")
			DM.end()
			for c in ["CairnWest", "CairnEast", "CairnSouth"]:
				n(c).interact(p); pick("Stack it again"); DM.end()
			talk("Hesk")
			ok(GS.has_flag("cairns_thanked") and Q.status("cairns_of_the_rising")["state"] == "completed", "all three cairns: done")
			DM.end()
			# The Wisp-Finder.
			talk("Corin"); pick("Who pays you"); pick("It isn't all")
			ok(Q.status("the_wisp_finder")["state"] == "active" and GS.has_flag("corin_confronted"), "Corin sells lights to people in masks")
			match mode:
				"persuade":
					pick("They're draining them")
					ok(GS.has_flag("corin_quit"), "talked round")
				"pay":
					pick("Here: a hundred gold")
					ok(GS.has_flag("corin_paid_off"), "paid off")
				"exile":
					DM.end()
					talk("Ysolde"); pick("Corin Dray sells wisps")
					ok(GS.has_flag("corin_exiled"), "Ysolde sends him away")
			DM.end()
			ok(Q.status("the_wisp_finder")["state"] == "completed", "The Wisp-Finder done (%s)" % mode)
			# Merchant and trainer.
			talk("Marta"); pick("Let's trade.")
			wait = 5
		3:
			ok(autoload("TradeScreen").is_open and autoload("TradeScreen").merchant == "marta", "Marta's wagon")
			autoload("TradeScreen").close()
			ok(autoload("Training").TRAINERS["ysolde"]["skill"] == "sight", "Ysolde teaches Sight")
			# Into the Deep Ring.
			p.global_position = n("MapSinkhole").global_position + Vector3(0, 0.5, 8)
			wait = 10
		4:
			ok(GS.has_flag("discovered_sinkhole"), "found the sinkhole")
			n("Sinkhole").interact(p)
			wait = 30
		5:
			ok(current_scene.name == "DeepRing", "down into the Deep Ring", current_scene.name)
			n("HarvestEngine").interact(p)
			ok(not GS.has_flag("vessa_note_read"), "can't reach the engine with the Mercy about")
			DM.end()
			ok(n("Mercy").get_child_count() == 4, "three acolytes and the Harvest-Warden")
			for e in n("Mercy").get_children():
				e.take_hit(9999.0, p.global_position, 0.0, 0.0)
			wait = 10
		6:
			ok(GS.has_flag("deep_ring_cleared"), "the Deep Ring goes quiet")
			n("HarvestEngine").interact(p)
			ok(GS.has_flag("vessa_note_read"), "V.'s note: come to me at Ilunhall")
			pick("Smash the rune-iron")
			ok(GS.has_flag("harvest_engine_broken"), "the lights go free")
			DM.end()
			n("Ladder").interact(p)
			wait = 30
		7:
			ok(current_scene.name == "GrievingFields", "back up on the Fields")
			talk("Ysolde"); pick("The Deep Ring is broken")
			ok(Q.status("the_deep_ring")["state"] == "completed", "The Deep Ring done")
			ok(autoload("Reputation").value("ashen_fields") >= 20, "Greyfold won't forget", autoload("Reputation").value("ashen_fields"))
			pick("There was a note")
			DM.end()
			n("RiverRoad").interact(p)
			wait = 30
		8:
			ok(current_scene.name == "Weirholt", "the north road leads back to Weirholt")
			ok(p.global_position.distance_to(n("FromFields").global_position) < 1.5, "at the south road")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
