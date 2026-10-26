extends "res://tests/test_base.gd"
# Ilunhall (levels/builders/build_ilunhall.gd): the Imperial Road from the Grieving
# Fields and back, the Lower Steps and their people, the merchant, the trainer and
# the bed, and three quests: The Light in the Eaves (main), The Hundredth Horn and
# A Verse in the Eaves.
# Argument: what you do with Magister Vessa:
#   turn (default): talk her round; break the conduit; the horn to Nob; keep quiet
#   hand: the Lantern Order; leave the conduit running; tell Odo about Nob
#   fight: kill her; break the conduit; take the horn back to Odo; refuse to keep quiet
var f := 0
var step := 0
var wait := 0
var mode := ""
var p
var GS
var Q
var DM

func _initialize() -> void:
	mode = arg("turn")
	autoload("SaveSystem").delete_save()
	change_scene_to_file("res://levels/grieving_fields.tscn")

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

func talk(who: String) -> void:
	n(who).interact(p)

## Fast travel lands beside each place here on clear ground.
func check_arrivals() -> void:
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	for place in autoload("FastTravel").places_in("res://levels/ilunhall.tscn"):
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
		var ray := PhysicsRayQueryParameters3D.create(at + Vector3(0, 1, 0), at + Vector3(0, -3, 0), 1)
		ray.exclude = [p.get_rid()]
		ok(not blocked and not space.intersect_ray(ray).is_empty(), "%s: clear ground to fast travel to" % place["name"], at)

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
			autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
			wait = 5
		1:
			# The Deep Ring's note opens the next main quest.
			GS.set_flag("vessa_note_read")
			ok(Q.status("the_light_in_the_eaves")["state"] == "active", "V.'s note opens The Light in the Eaves")
			ok(Q.quests["the_light_in_the_eaves"].get("main", false), "a main quest")
			var road = n("ImperialRoad")
			ok(road != null and road.target_scene == "res://levels/ilunhall.tscn", "an Imperial Road east out of the Fields")
			road.interact(p)
			wait = 40
		2:
			ok(current_scene.name == "Ilunhall", "it leads to Ilunhall", current_scene.name)
			ok(p.global_position.distance_to(n("FromFields").global_position) < 1.5, "arriving on the quay from the west")
			ok(GS.has_flag("discovered_ilunhall"), "the Quay Steps found on arrival")
			ok(Q.current_objective("the_light_in_the_eaves").begins_with("Find out what's keeping"), "next: ask about the light-stone",
					Q.current_objective("the_light_in_the_eaves"))
			for who in ["Bruna", "NobHere/Nob", "Saelie", "Karra", "Ignatia", "Severin", "Odo", "Cassia"]:
				ok(n(who) != null, "%s is here" % who)
			ok(autoload("FastTravel").region_name("res://levels/ilunhall.tscn") == "Ilunhall", "a fast-travel region")
			check_arrivals()
			ok(n("GateBarred").is_present() and not n("GateOpen").is_present(), "the gate under the Market Steps is barred")
			autoload("Inventory").gold = 500
			autoload("Skills").levels["speech"] = 60
			# The lead: the eaves-wright, or the Lantern Order.
			if mode == "hand":
				talk("Severin"); pick("I'm looking for"); pick("If I find her"); pick("Alive, then")
				ok(GS.has_flag("severin_deal") and GS.has_flag("met_severin"), "Severin wants Vessa alive")
				ok(autoload("Reputation").known("lantern_order"), "the Lantern Order is known")
			else:
				talk("Karra"); pick("It goes grey"); pick("From below"); pick("Thank you")
			ok(GS.has_flag("undercroft_lead"), "a lead: the old cistern under the Market Steps")
			DM.end()
			ok(n("GateOpen").is_present() and not n("GateBarred").is_present(), "and the gate opens")
			# The Hundredth Horn.
			talk("NobHere/Nob"); pick("What kind"); pick("I'll get it")
			ok(Q.status("the_hundredth_horn")["state"] == "active", "Nob starts The Hundredth Horn")
			DM.end()
			ok(n("TrophyChest").lock_level == 2 and n("TrophyChest").contents.has("hundredth_horn"), "the horn's in a locked trophy chest")
			match mode:
				"turn":
					autoload("Inventory").add("hundredth_horn")   # the lock's tested in test_lockpicking
					talk("NobHere/Nob"); pick("Here. A hundred")
					ok(GS.has_flag("horn_to_nob") and GS.has_flag("lampless_friend"), "to Nob: a window without a lantern")
				"hand":
					talk("Odo"); pick("Nob Ashby on the quay")
					ok(GS.has_flag("horn_reported"), "Odo sends the watch")
				"fight":
					autoload("Inventory").add("hundredth_horn")
					talk("Odo"); pick("This is yours")
					ok(GS.has_flag("horn_returned") and autoload("Inventory").count("hundredth_horn") == 0, "the horn back to Odo")
			DM.end()
			ok(Q.status("the_hundredth_horn")["state"] == "completed", "The Hundredth Horn done (%s)" % mode)
			# Odo's bed.
			talk("Odo"); pick("I need a bed"); pick("Here's ten")
			ok(n("FeastBed").is_present(), "a bed at the back of the Long Table")
			DM.end()
			# A Verse in the Eaves: by day the runes say nothing.
			talk("Saelie"); pick("No."); pick("I'll read them")
			ok(Q.status("a_verse_in_the_eaves")["state"] == "active", "Saelie starts A Verse in the Eaves")
			DM.end()
			autoload("WorldClock").hour = 14.0
			n("RuneStone1").interact(p)
			ok(DM._choices.size() == 1 and DM._choices[0]["text"] == "(Leave it)", "by day the runes are dark")
			DM.end()
			autoload("WorldClock").hour = 22.0
			for i in [1, 2, 3]:
				n("RuneStone%d" % i).interact(p); pick("(Remember it)"); DM.end()
			talk("Saelie"); pick("Why are they afraid")
			ok(GS.has_flag("verse_sung") and GS.has_flag("choir_verse_ilunhall"), "she sings the third verse, the Choir's way")
			ok(autoload("Inventory").count("book_low_lane_verse") == 1, "and gives you the words")
			ok(Q.status("a_verse_in_the_eaves")["state"] == "completed", "A Verse in the Eaves done")
			DM.end()
			autoload("WorldClock").hour = 14.0
			# The merchant and the trainer.
			talk("Bruna"); pick("Let's trade.")
			wait = 5
		3:
			ok(autoload("TradeScreen").is_open and autoload("TradeScreen").merchant == "bruna", "Bruna's stall")
			autoload("TradeScreen").close()
			ok(autoload("Training").TRAINERS["ignatia"]["skill"] == "destruction", "Ignatia teaches Destruction")
			# Down into the Undercroft.
			n("GateOpen/UndercroftGate").interact(p)
			wait = 30
		4:
			ok(current_scene.name == "Undercroft", "down into the Undercroft", current_scene.name)
			wait = 5
		5:
			ok(GS.has_flag("discovered_undercroft"), "found the Undercroft")
			talk("VessaHere/Vessa")
			ok(DM._choices[0]["text"] == "(Leave her)", "Vessa won't talk with her people fighting")
			DM.end()
			n("Conduit").interact(p)
			ok(DM._choices[0]["text"] == "(Leave it)", "can't reach the conduit past the acolytes")
			DM.end()
			ok(n("Mercy").get_child_count() == 3, "three Mercy acolytes")
			kill_all("Mercy")
			wait = 10
		6:
			ok(GS.has_flag("undercroft_cleared"), "the Undercroft goes quiet")
			talk("VessaHere/Vessa"); pick("Why feed"); pick("And the wisps"); pick("Who is A.")
			match mode:
				"turn":
					pick("Turn on her")
					ok(GS.has_flag("vessa_turned") and autoload("Inventory").count("vessa_ledger") == 1, "Vessa turns: her ledger, and Karrowdeep next")
				"hand":
					pick("The Lantern Order is waiting")
					ok(GS.has_flag("vessa_handed"), "Vessa goes up to the Lantern Order")
				"fight":
					pick("(Attack her)")
			DM.end()
			wait = 5
		7:
			ok(not n("VessaHere").is_present(), "Vessa's gone from her desk")
			if mode == "fight":
				ok(n("VessaFights").is_present(), "and she fights")
				kill_all("VessaFights/VessaPack")
				wait = 10
		8:
			if mode == "fight":
				ok(GS.has_flag("vessa_killed"), "Magister Vessa falls")
			ok(Q.current_objective("the_light_in_the_eaves").begins_with("Decide what to do with the conduit"), "next: the conduit",
					Q.current_objective("the_light_in_the_eaves"))
			var veins = n("Veins")
			var before: float = veins.strength()
			n("Conduit").interact(p)
			if mode == "hand":
				pick("Leave it running")
				ok(GS.has_flag("conduit_spared") and is_equal_approx(veins.strength(), before), "the conduit keeps running, the veins stay gold")
			else:
				pick("Break it")
				ok(GS.has_flag("conduit_broken") and veins.strength() < before * 0.5, "the conduit breaks, and the veins go grey", [before, veins.strength()])
			DM.end()
			n("Stair").interact(p)
			wait = 30
		9:
			ok(current_scene.name == "Ilunhall", "back up on the Quay Steps")
			var eaves = n("HallOfSpearsLightStone")
			ok(eaves.is_dimmed() == (mode != "hand"), "the city's eaves dim only if the conduit broke")
			talk("Cassia")
			ok(autoload("Reputation").known("ilunar_empire"), "Steward Cassia (the Ilunar Empire is known now)")
			match mode:
				"turn":
					pick("The light-stone was being fed"); pick("Agreed")
					ok(GS.has_flag("light_hushed"), "paid to keep quiet")
				"hand":
					pick("The Mercy were feeding")
					ok(autoload("Reputation").value("ilunar_empire") >= 15, "the Empire's thanks", autoload("Reputation").value("ilunar_empire"))
				"fight":
					pick("The light-stone was being fed"); pick("People should know")
					ok(GS.has_flag("light_told"), "you won't keep quiet")
			DM.end()
			ok(Q.status("the_light_in_the_eaves")["state"] == "completed", "The Light in the Eaves done (%s)" % mode)
			if mode == "hand":
				talk("Severin")
				ok(DM._node["text"].find("purse") >= 0, "Severin's satisfied")
				ok(autoload("Reputation").value("lantern_order") >= 15, "the Lantern Order remembers", autoload("Reputation").value("lantern_order"))
				DM.end()
			n("ImperialRoad").interact(p)
			wait = 40
		10:
			ok(current_scene.name == "GrievingFields", "the Imperial Road leads back to the Fields")
			ok(p.global_position.distance_to(n("FromIlunhall").global_position) < 1.5, "at the east road")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
