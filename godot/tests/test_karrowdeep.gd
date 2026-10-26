extends "res://tests/test_base.gd"
# Karrowdeep (levels/builders/build_karrowdeep.gd): the Deep Road from Ilunhall and
# back, the city in the mountain and its people, the merchant, the trainer and the
# bed, the law there, and three quests: The Seam That Whispers (main), The Anvil and
# the Seal, The Short Weight. docs/godot-starter/KARROWDEEP.md.
# Argument: how you get past the Seal Door, and what you do after:
#   key (default): Ebba's word gets Hrodna's key; collapse the seam; talk Bek round;
#                  report Pell
#   steal: the key from Hrodna's strongbox; seal the seam; take the slate off Bek's
#          bench; take Pell's money
#   rune: Runecraft 40 unpicks the door; collapse the seam; buy the slate
var f := 0
var step := 0
var wait := 0
var mode := ""
var p
var GS
var Q
var DM
var I

func _initialize() -> void:
	mode = arg("key")
	autoload("SaveSystem").delete_save()
	change_scene_to_file("res://levels/ilunhall.tscn")

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
	for place in autoload("FastTravel").places_in("res://levels/karrowdeep.tscn"):
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
	GS = autoload("GameState"); Q = autoload("QuestLog"); DM = autoload("DialogueManager"); I = autoload("Inventory")
	match step:
		0:
			autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
			wait = 5
		1:
			# Telling Cassia about the light opens the next main quest, whatever Vessa's fate.
			GS.set_flag("light_reported")
			ok(Q.status("the_seam_that_whispers")["state"] == "active", "the Light reported: The Seam That Whispers opens")
			ok(Q.quests["the_seam_that_whispers"].get("main", false), "a main quest")
			var road = n("DeepRoad")
			ok(road != null and road.target_scene == "res://levels/karrowdeep.tscn", "a Deep Road east off Ilunhall's quay")
			road.interact(p)
			wait = 40
		2:
			ok(current_scene.name == "Karrowdeep", "it leads to Karrowdeep", current_scene.name)
			ok(p.global_position.distance_to(n("FromIlunhall").global_position) < 1.5, "arriving in the Gate Hall")
			ok(GS.has_flag("discovered_karrowdeep"), "Karrowdeep found on arrival")
			ok(Q.current_objective("the_seam_that_whispers").begins_with("Find out whose seam"), "next: whose seam",
					Q.current_objective("the_seam_that_whispers"))
			for who in ["Hrodna", "Orsa", "Bek", "Grima", "Torvald", "Ebba", "Pell", "BridgeWarden", "GalleryWarden"]:
				ok(n(who) != null, "%s is here" % who)
			ok(autoload("FastTravel").region_name("res://levels/karrowdeep.tscn") == "Karrowdeep", "a fast-travel region")
			ok(autoload("Crime").region() == "karrowdeep" and n("BridgeWarden").role == "guard", "the Table's law, and its wardens")
			ok(n("SealShut").is_present() and not n("SealOpen").is_present(), "the Seal Door is shut")
			check_arrivals()
			autoload("WorldClock").hour = 13.0
			I.gold = 600
			autoload("Skills").levels["speech"] = 60
			wait = 10
		3:
			# The Short Weight, from Ebba on the Lowest Gallery.
			talk("Ebba"); pick("You look like someone's"); pick("I'll look at them")
			ok(Q.status("the_short_weight")["state"] == "active", "Ebba starts The Short Weight")
			DM.end()
			n("AssayScales").interact(p); pick("Weigh the big counterweight")
			ok(GS.has_flag("scales_rigged"), "the counterweight's hollow")
			DM.end()
			# Whose seam: the Table (and Ebba's carts, in the key mode).
			if mode == "key":
				talk("Ebba"); pick("Anything strange"); DM.end()
				ok(GS.has_flag("ebba_heard"), "Ebba hears carts and singing past the Seal Door")
			talk("Hrodna")
			ok(autoload("Reputation").known("deep_guilds"), "the Deep Guilds are known (Hrodna)")
			if mode == "key":
				pick("Someone's cutting Seam Nine")   # Ebba's already named it
			else:
				pick("The Mercy lit Ilunhall's halls")
				ok(GS.has_flag("seam_nine_named"), "the ninth seam's mark")
				pick("Then someone's cutting it")
			match mode:
				"key":
					pick("Your own hewers hear carts")
					ok(I.count("seal_key") == 1 and GS.has_flag("seal_key_given"), "Ebba's word: Hrodna's seal-key")
				_:
					ok(DM._choices.all(func(c): return not c["text"].begins_with("Your own hewers")), "without Ebba's word, no proof to offer")
					pick("Then I'll find another way")
			DM.end()
			# The Short Weight's end.
			if mode == "steal":
				talk("Pell"); pick("Eighty gold")
				ok(GS.has_flag("weight_hushed"), "Pell buys your silence")
			else:
				talk("Hrodna"); pick("The assayer on the Gate Hall")
				ok(GS.has_flag("weight_reported") and autoload("Reputation").value("deep_guilds") >= 10, "the Table fines Pell")
			DM.end()
			ok(Q.status("the_short_weight")["state"] == "completed", "The Short Weight done (%s)" % mode)
			talk("Ebba")
			pick("The Table's fined Pell" if mode != "steal" else "Pell won't be weighing light")
			ok(GS.has_flag("ebba_settled"), "Ebba hears how it ended")
			DM.end()
			# Into Seam Nine.
			match mode:
				"steal":
					var box = n("HrodnaStrongbox")
					ok(box.belongs_to == "Guildmaster Hrodna" and box.contents.has("seal_key"), "a seal-key in the Guildmaster's strongbox")
					box.unlock()   # the lock's tested in test_lockpicking
					box.interact(p)
					ok(I.count("seal_key") == 1, "taken")
					ok(autoload("Crime").stolen_count("seal_key", "karrowdeep") == 1, "and it's stolen")
				"rune":
					n("SealShut/SealDoor").interact(p)
					ok(DM._choices.all(func(c): return not c["text"].begins_with("Read the seals")), "the seals can't be read at Runecraft 15")
					DM.end()
					autoload("Skills").levels["runecraft"] = 40
			n("SealShut/SealDoor").interact(p)
			if mode == "rune":
				pick("Read the seals")
				ok(GS.has_flag("seal_unpicked"), "Runecraft 40: the seals unpicked")
			else:
				pick("Turn the key")
				ok(I.count("seal_key") == 0, "the key stays in the door")
			ok(GS.has_flag("seam_nine_open"), "the Seal Door opens")
			DM.end()
			ok(n("SealOpen").is_present(), "a way down")
			n("SealOpen/SeamDoor").interact(p)
			wait = 30
		4:
			ok(current_scene.name == "SeamNine", "down into Seam Nine", current_scene.name)
			wait = 5
		5:
			ok(GS.has_flag("discovered_seam_nine"), "Seam Nine found")
			n("TheSeam").interact(p)
			ok(DM._choices[0]["text"] == "(Step back.)", "the seam can't be dealt with past the Mercy")
			DM.end()
			ok(n("Mercy").get_child_count() == 4 and n("Mercy/Keld").display_name == "Brother Keld", "three Mercy miners and Brother Keld")
			kill_all("Mercy")
			wait = 10
		6:
			ok(GS.has_flag("seam_cleared"), "Seam Nine goes quiet")
			n("KeldOrders").interact(p)
			ok(I.count("keld_orders") == 1, "Brother Keld's orders, from A.")
			DM.end()
			n("TheDeep").interact(p); pick("Listen")
			ok(GS.has_flag("heard_blind_choir"), "the blind choir, below")
			DM.end()
			n("TheSeam").interact(p)
			if mode == "steal":
				pick("Shut the harvest-frame")
				ok(GS.has_flag("seam_sealed"), "the seam left to the Table")
			else:
				pick("Knock out the props")
				ok(GS.has_flag("seam_collapsed"), "the face comes down; the lights go free")
			DM.end()
			n("SealStair").interact(p)
			wait = 30
		7:
			ok(current_scene.name == "Karrowdeep" and p.global_position.distance_to(n("FromSeam").global_position) < 1.5, "back up on the Lowest Gallery")
			var rep_before: int = autoload("Reputation").value("deep_guilds")
			var gold_before: int = I.gold
			talk("Hrodna"); pick("The Mercy were harvesting it")
			ok(GS.has_flag("keld_shown"), "Hrodna reads Keld's orders")
			if mode == "steal":
				pick("The Mercy are gone")
				ok(I.gold == gold_before + 200 and autoload("Reputation").value("deep_guilds") > rep_before, "sealed: the Table pays its debts (gains scale with race and Presence)",
						[I.gold - gold_before, autoload("Reputation").value("deep_guilds") - rep_before])
			else:
				pick("I brought the face down")
				ok(I.gold == gold_before + 50 and autoload("Reputation").value("deep_guilds") == rep_before - 10, "collapsed: the Guilds lost their richest seam")
			DM.end()
			ok(Q.status("the_seam_that_whispers")["state"] == "completed", "The Seam That Whispers done (%s)" % mode)
			# The Anvil and the Seal.
			talk("Orsa"); pick("The Seal College and the Anvil"); pick("I'll get it back")
			ok(Q.status("the_anvil_and_the_seal")["state"] == "active", "Orsa starts The Anvil and the Seal")
			DM.end()
			match mode:
				"key":
					talk("Bek"); pick("The Seal College wants"); pick("Copy it and keep it")
					ok(I.count("seal_slate") == 1 and GS.has_flag("bek_gave_slate"), "Bek's talked round")
				"rune":
					var gold_was: int = I.gold
					talk("Bek"); pick("The Seal College wants"); pick("Name a price")
					ok(I.count("seal_slate") == 1 and I.gold < gold_was, "bought off Bek")
				"steal":
					var slate = n("SlateOnBench/SealSlate")
					ok(slate.prompt.begins_with("Steal"), "the slate on Bek's bench is his", slate.prompt)
					slate.interact(p)
					ok(I.count("seal_slate") == 1, "taken off the bench")
			DM.end()
			wait = 5
		8:
			if mode != "steal":
				ok(not n("SlateOnBench").is_present(), "the bench slate goes when Bek hands it over")
			talk("Orsa"); pick("I have your slate")
			ok(GS.has_flag("slate_returned") and I.count("seal_slate") == 0, "the slate back at the Seal College")
			DM.end()
			ok(Q.status("the_anvil_and_the_seal")["state"] == "completed", "The Anvil and the Seal done (%s)" % mode)
			# The trainer, the merchant, the bed.
			ok(autoload("Training").TRAINERS["orsa"]["skill"] == "runecraft", "Orsa teaches Runecraft")
			talk("Torvald"); pick("I need a bed"); pick("Here's ten")
			ok(n("LampBed").is_present(), "a bed at the back of the Lamp and Pick")
			DM.end()
			talk("Grima"); pick("Let's trade.")
			wait = 5
		9:
			ok(autoload("TradeScreen").is_open and autoload("TradeScreen").merchant == "grima", "Grima's stall on the Market Bridge")
			autoload("TradeScreen").close()
			n("DeepRoad").interact(p)
			wait = 40
		10:
			ok(current_scene.name == "Ilunhall", "the Deep Road leads back to Ilunhall")
			ok(p.global_position.distance_to(n("FromKarrowdeep").global_position) < 1.5, "at the east end of the quay")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
