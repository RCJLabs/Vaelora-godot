extends "res://tests/test_base.gd"
# Ithmarren (levels/builders/build_ithmarren.gd): the Hollow Way from Karrowdeep and
# back, the canopy city (you can walk from the forest floor up to every bough), its
# people, the merchant, the trainer and the bed, the law there, and three quests:
# The Well Kept Badly (main), A Lie Well Told, Night-Blooms.
# docs/godot-starter/ITHMARREN.md.
# Argument: how you get through the Root Door, and what you do with the well:
#   letter (default): Lirael fooled (Glamour 30) for Sylvaine's letter; shame
#                     Ithariel with it for the key; unbind the well
#   steal: Rhosyn's lead; the key from Sennaveth's coffer; the letter from the
#          letter-box; give the well to the Moot
#   glamour: Glamour 40 opens the Root Door; Persuade Lirael; drink the well
var f := 0
var step := 0
var wait := 0
var mode := ""
var p
var GS
var Q
var DM
var I
var lit_before := 0.0

func _initialize() -> void:
	mode = arg("letter")
	autoload("SaveSystem").delete_save()
	change_scene_to_file("res://levels/karrowdeep.tscn")

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
	for place in autoload("FastTravel").places_in("res://levels/ithmarren.tscn"):
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

## A path on the navmesh from `a` that ends within a metre and a half of `b`.
func walkable(a: Vector3, b: Vector3) -> bool:
	var path := NavigationServer3D.map_get_path(p.get_world_3d().navigation_map, a, b, true)
	return not path.is_empty() and path[path.size() - 1].distance_to(b) < 1.5

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
	GS = autoload("GameState"); Q = autoload("QuestLog"); DM = autoload("DialogueManager"); I = autoload("Inventory")
	match step:
		0:
			autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
			wait = 5
		1:
			# Reporting Seam Nine opens the next main quest.
			GS.set_flag("seam_reported")
			ok(Q.status("the_well_kept_badly")["state"] == "active", "Seam Nine reported: The Well Kept Badly opens")
			ok(Q.quests["the_well_kept_badly"].get("main", false), "a main quest")
			var way = n("HollowWay")
			ok(way != null and way.target_scene == "res://levels/ithmarren.tscn", "a Hollow Way out of Karrowdeep's Guild Gallery")
			way.interact(p)
			wait = 40
		2:
			ok(current_scene.name == "Ithmarren", "it leads to Ithmarren", current_scene.name)
			ok(p.global_position.distance_to(n("FromKarrowdeep").global_position) < 1.5, "out of the mountain's foot")
			wait = 60   # the navmesh bakes
		3:
			ok(GS.has_flag("discovered_ithmarren"), "Ithmarren found on arrival")
			ok(Q.current_objective("the_well_kept_badly").begins_with("Find out where the harvest goes"), "next: where the harvest goes",
					Q.current_objective("the_well_kept_badly"))
			for who in ["Calaneth", "Ithariel", "Lirael", "Sylvaine", "Tamsin", "Maelis", "Fennick", "Rhosyn", "BoughWarden", "RootWarden"]:
				ok(n(who) != null, "%s is here" % who)
			ok(autoload("FastTravel").region_name("res://levels/ithmarren.tscn") == "Ithmarren", "a fast-travel region")
			ok(autoload("Crime").region() == "ithmarren" and n("RootWarden").role == "guard", "the Houses' law, and their wardens")
			check_arrivals()
			# Up into the boughs on foot: from the forest floor to every deck.
			var floor_spot := Vector3(12, 0, 56)
			for deck in [["the Gate Landing", Vector3(-4, 12, 15)], ["the Lantern Gardens", Vector3(-24, 12, -1)], ["the Veil Terrace", Vector3(28, 12, 4)],
					["the Moot Hall", Vector3(-8, 20, -22)], ["the Sennaveth Bough", Vector3(24, 20, -24)], ["the Root Door", Vector3(1, 0, -18)]]:
				ok(walkable(floor_spot, deck[1]), "a way on foot from the forest floor to %s" % deck[0])
			ok(not walkable(floor_spot, Vector3(0, 40, -26)), "(and the check can fail: nothing climbs the Moot Tree's bare trunk)")
			ok(n("RootShut").is_present() and not n("RootOpen").is_present(), "the Root Door is shut")
			autoload("WorldClock").hour = 13.0
			I.gold = 600
			autoload("Skills").levels["speech"] = 60
			wait = 10
		4:
			# Where the harvest goes: the Moot-Speaker, or Rhosyn at the roots.
			if mode == "steal":
				talk("Rhosyn"); pick("Where do you get it")
			else:
				talk("Calaneth")
				ok(autoload("Reputation").known("great_houses"), "the Great Houses are known (Calaneth)")
				pick("The Mercy's harvest comes to Ithmarren")
			ok(GS.has_flag("well_lead"), "the well under the Moot Tree, in House Sennaveth's keeping")
			DM.end()
			# A Lie Well Told.
			talk("Sylvaine"); pick("What does the Veil College want"); pick("I'll bring it")
			ok(Q.status("a_lie_well_told")["state"] == "active", "Sylvaine starts A Lie Well Told")
			DM.end()
			match mode:
				"letter":
					autoload("Skills").levels["glamour"] = 30
					talk("Lirael"); pick("I'm the courier"); pick("(Wear a Sennaveth face.)")
					ok(GS.has_flag("lirael_fooled") and I.count("sennaveth_letter") == 1, "Lirael hands it to a Sennaveth face")
				"glamour":
					talk("Lirael"); pick("I'm the courier"); pick("Lady Ithariel sent me")
					ok(GS.has_flag("letter_given") and I.count("sennaveth_letter") == 1, "Lirael believes Ithariel sent you")
				"steal":
					var box = n("LetterBox/SennavethLetters")
					ok(box.belongs_to == "Steward Lirael", "the house letter-box is Lirael's")
					box.unlock()
					box.interact(p)
					ok(I.count("sennaveth_letter") == 1, "the letter, from the box")
			DM.end()
			wait = 3
		5:
			if mode != "steal":
				ok(not n("LetterBox").is_present(), "once he's handed it over, the box is empty")
			talk("Sylvaine"); pick("I have House Sennaveth's letter")
			ok(GS.has_flag("lie_done") and I.count("sennaveth_letter") == 1, "Sylvaine reads it, and you keep it")
			DM.end()
			ok(Q.status("a_lie_well_told")["state"] == "completed", "A Lie Well Told done (%s)" % mode)
			# The Root Door.
			match mode:
				"letter":
					talk("Ithariel"); pick("Your house keeps the Rootwell"); pick("I've read your letter")
					ok(GS.has_flag("ithariel_shamed") and I.count("root_key") == 1, "shamed with her own letter: the root-key")
				"steal":
					var coffer = n("SennavethCoffer")
					ok(coffer.belongs_to == "Lady Ithariel Sennaveth" and coffer.contents.has("root_key"), "a root-key in Sennaveth's coffer")
					coffer.unlock()
					coffer.interact(p)
					ok(I.count("root_key") == 1 and autoload("Crime").stolen_count("root_key", "ithmarren") == 1, "taken, and stolen")
				"glamour":
					n("RootShut/RootDoor").interact(p)
					ok(DM._choices.all(func(c): return not c["text"].begins_with("(Wear a Sennaveth")), "no Sennaveth face at Glamour 15")
					DM.end()
					autoload("Skills").levels["glamour"] = 40
			DM.end()
			n("RootShut/RootDoor").interact(p)
			if mode == "glamour":
				pick("(Wear a Sennaveth face.)")
				ok(GS.has_flag("root_glamoured"), "Glamour 40: the roots let family in")
			else:
				pick("Open it")
				ok(I.count("root_key") == 0, "the key stays in the knot")
			ok(GS.has_flag("rootwell_open"), "the Root Door opens")
			DM.end()
			ok(n("RootOpen").is_present(), "a stair down")
			n("RootOpen/RootwellDoor").interact(p)
			wait = 30
		6:
			ok(current_scene.name == "Rootwell", "down into the Rootwell", current_scene.name)
			wait = 5
		7:
			ok(GS.has_flag("discovered_rootwell"), "the Rootwell found")
			n("TheWell").interact(p)
			ok(DM._choices[0]["text"] == "(Step back.)", "the well can't be reached past the takers")
			DM.end()
			ok(n("Takers").get_child_count() == 5 and n("Takers/Caerwyn").display_name == "Lord Caerwyn Sennaveth", "two Mercy, two essence-takers and Lord Caerwyn")
			kill_all("Takers")
			wait = 10
		8:
			ok(GS.has_flag("rootwell_cleared"), "the Rootwell goes quiet")
			n("RootwellLetter").interact(p)
			ok(I.count("rootwell_letter") == 1, "a card on Caerwyn's desk, from A.")
			lit_before = n("WellLight").strength()
			var corruption: float = autoload("Corruption").value
			n("TheWell").interact(p)
			match mode:
				"letter":
					pick("Break the root-cages")
					ok(GS.has_flag("well_unbound") and n("WellLight").strength() < lit_before * 0.5, "unbound: the well goes dark")
				"steal":
					pick("Leave it bound")
					ok(GS.has_flag("well_given") and is_equal_approx(n("WellLight").strength(), lit_before), "given to the Moot: still bound, still lit")
				"glamour":
					pick("Kneel, and drink")
					ok(GS.has_flag("well_drunk") and autoload("Corruption").value >= corruption + 30.0, "drunk: the lights are in you (corruption)",
							autoload("Corruption").value)
			DM.end()
			n("RootStair").interact(p)
			wait = 30
		9:
			ok(current_scene.name == "Ithmarren" and p.global_position.distance_to(n("FromRootwell").global_position) < 1.5, "back up at the Moot Tree's roots")
			ok(n("GardenLanterns").is_dimmed() == (mode == "letter"), "the Gardens' lanterns dim only if the well was unbound")
			var gold_before: int = I.gold
			var rep_before: int = autoload("Reputation").value("great_houses")
			talk("Calaneth"); pick("There was a note on Lord Caerwyn's desk")
			ok(GS.has_flag("card_shown"), "Calaneth reads A.'s card: look under the glass")
			match mode:
				"letter":
					pick("I broke the root-cages")
					ok(I.gold == gold_before + 50 and autoload("Reputation").value("great_houses") == rep_before - 5, "the Moot's angry, for fifty years")
				"steal":
					pick("The takers are gone")
					ok(I.gold == gold_before + 200 and autoload("Reputation").value("great_houses") > rep_before, "the Moot keeps it, and pays")
				"glamour":
					pick("I drank it")
					ok(I.gold == gold_before and autoload("Reputation").value("great_houses") == rep_before - 20, "Calaneth sees what you are now")
			DM.end()
			ok(Q.status("the_well_kept_badly")["state"] == "completed", "The Well Kept Badly done (%s)" % mode)
			talk("Rhosyn")
			ok(DM.is_active and DM._node == DM._nodes["after_" + {"letter": "unbound", "steal": "given", "glamour": "drunk"}[mode]], "Rhosyn knows what you did")
			DM.end()
			# Night-Blooms: shut by day, open at night.
			talk("Fennick"); pick("Can I help"); pick("Three moonpetals")
			ok(Q.status("night_blooms")["state"] == "active", "Fennick starts Night-Blooms")
			DM.end()
			n("NightBloom1").interact(p)
			ok(DM._choices.size() == 1 and DM._choices[0]["text"] == "(Leave it.)", "by day the bud is shut")
			DM.end()
			autoload("WorldClock").hour = 23.0
			if I.count("moonpetal") > 0:
				I.remove("moonpetal", I.count("moonpetal"))
			for i in [1, 2, 3]:
				n("NightBloom%d" % i).interact(p); pick("Pick it gently"); DM.end()
			ok(I.count("moonpetal") == 3, "three moonpetals, picked in the dark")
			autoload("WorldClock").hour = 13.0
			wait = 5
		10:
			talk("Fennick"); pick("I've brought your moonpetals")
			ok(GS.has_flag("blooms_done") and I.count("moonpetal") == 0, "Fennick takes them, gently")
			DM.end()
			ok(Q.status("night_blooms")["state"] == "completed", "Night-Blooms done")
			# The trainer, the merchant, the bed.
			ok(autoload("Training").TRAINERS["sylvaine"]["skill"] == "glamour", "Sylvaine teaches Glamour")
			talk("Maelis"); pick("I need a bed"); pick("Here's ten")
			ok(n("LanternBed").is_present(), "a hammock at the back of the Hanging Lantern")
			DM.end()
			talk("Tamsin"); pick("Let's trade.")
			wait = 5
		11:
			ok(autoload("TradeScreen").is_open and autoload("TradeScreen").merchant == "tamsin", "Tamsin's stall in the Lantern Gardens")
			autoload("TradeScreen").close()
			n("HollowWay").interact(p)
			wait = 40
		12:
			ok(current_scene.name == "Karrowdeep", "the Hollow Way leads back to Karrowdeep")
			ok(p.global_position.distance_to(n("FromIthmarren").global_position) < 1.5, "in the Guild Gallery")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
