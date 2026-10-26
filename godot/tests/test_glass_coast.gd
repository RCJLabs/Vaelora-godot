extends "res://tests/test_base.gd"
# The Glass Coast (levels/builders/build_glass_coast.gd): the ship from Ilunhall and
# back, Sarabh and the Scar (you can walk from the mole to the College, the Mercy's
# camp and the ward), its people, the merchant, the trainer and the bed, the law
# there, the Under-Glass vault and the Seal of the Twelve, and three quests: Under
# the Glass (main), The Sovereign's Due, Glass That Sings.
# docs/godot-starter/GLASS_COAST.md.
# Argument: how you get past the ward, and who you tell:
#   college (default): Ophira's lead and ward-glass; pay Samira's due; tell Ophira all
#   mercy: Ammara's lead and the Mercy's cut; lean on Amir; tell Ammara
#   sight: Ophira's lead, but Sight 40 through the ward; steal the tally-stone;
#          lie to Ophira (Glamour 40)
var f := 0
var step := 0
var wait := 0
var mode := ""
var p
var GS
var Q
var DM
var I
var gold_before := 0

func _initialize() -> void:
	mode = arg("college")
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

func offered(start: String) -> bool:
	return DM._choices.any(func(c): return c["text"].begins_with(start))

func talk(who: String) -> void:
	n(who).interact(p)

## Fast travel lands beside each place here on clear ground.
func check_arrivals() -> void:
	var space: PhysicsDirectSpaceState3D = p.get_world_3d().direct_space_state
	for place in autoload("FastTravel").places_in("res://levels/glass_coast.tscn"):
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
			# Reporting the Rootwell opens the next main quest.
			GS.set_flag("well_reported")
			ok(Q.status("under_the_glass")["state"] == "active", "the Rootwell reported: Under the Glass opens")
			ok(Q.quests["under_the_glass"].get("main", false), "a main quest")
			var ship = n("ShipToGlass")
			ok(ship != null and ship.target_scene == "res://levels/glass_coast.tscn", "a ship from Ilunhall's quay")
			ship.interact(p)
			wait = 40
		2:
			ok(current_scene.name == "GlassCoast", "it sails to the Glass Coast", current_scene.name)
			ok(p.global_position.distance_to(n("FromIlunhall").global_position) < 1.5, "off the ship on Sarabh's mole")
			wait = 60   # the navmesh bakes
		3:
			ok(GS.has_flag("discovered_glass_coast"), "the Glass Coast found on arrival")
			ok(Q.current_objective("under_the_glass").begins_with("Find out what's under the glass"), "next: what's under the glass",
					Q.current_objective("under_the_glass"))
			for who in ["Ophira", "Ammara", "Amir", "Samira", "Jamila", "Nadira", "Rafiq", "SquareWarden", "MoleWarden"]:
				ok(n(who) != null, "%s is here" % who)
			ok(autoload("FastTravel").region_name("res://levels/glass_coast.tscn") == "The Glass Coast", "a fast-travel region",
					autoload("FastTravel").region_name("res://levels/glass_coast.tscn"))
			ok(autoload("Crime").region() == "glass_coast" and n("SquareWarden").role == "guard", "the Sovereign's law, and his wardens")
			check_arrivals()
			# On foot from the mole to everywhere that matters.
			var mole := Vector3(10, 0.2, 66)
			for place in [["Ophira on the College steps", Vector3(45, 0.4, -16.5)], ["the Mercy's camp", Vector3(-50, 0.2, -54)],
					["the ward", Vector3(0, 0.2, -95)], ["the Cistern House", Vector3(-26, 0, 46.5)], ["Jamila's kiln", Vector3(-26, 0, 14)],
					["Amir's booth", Vector3(-10, 0, 39.5)], ["the singing glass", Vector3(-8, 0.2, -116.5)]]:
				ok(walkable(mole, place[1]), "a way on foot from the mole to %s" % place[0])
			ok(not walkable(mole, Vector3(45, 33, -26)), "(and the check can fail: nobody walks up the glass spire)")
			ok(n("WardUp").is_present() and not n("WardDown").is_present(), "the ward is up")
			autoload("WorldClock").hour = 13.0
			I.gold = 600
			autoload("Skills").levels["speech"] = 60
			wait = 10
		4:
			# What's under the glass: Ophira at the College, or Ammara at the Mercy's camp.
			if mode == "mercy":
				talk("Ammara"); pick("What are the Mercy doing")
				ok(GS.has_flag("mercy_cut"), "the Mercy cut a way through the ward")
			else:
				talk("Ophira"); pick("The card says to look under the glass")
				ok(I.count("ward_glass") == 1, "Ophira gives you the College's ward-glass")
			ok(GS.has_flag("under_glass_lead"), "a vault under the Scar, sealed by the founders")
			DM.end()
			ok(Q.current_objective("under_the_glass").begins_with("Get past the ward"), "next: the ward", Q.current_objective("under_the_glass"))
			# The Sovereign's Due.
			talk("Samira"); pick("What happened?"); pick("I'll get your tally back")
			ok(Q.status("the_sovereigns_due")["state"] == "active", "Samira starts The Sovereign's Due")
			DM.end()
			gold_before = I.gold
			match mode:
				"college":
					talk("Amir")
					ok(autoload("Reputation").known("oasis_thrones"), "the Oasis Thrones are known (Amir)")
					pick("Samira's household"); pick("Here's sixty")
					ok(GS.has_flag("due_paid") and I.gold == gold_before - 60 and I.count("water_tally") == 1, "paid: the tally-stone")
				"mercy":
					talk("Amir"); pick("Samira's household"); pick("Hand it over")
					ok(GS.has_flag("due_scared") and I.gold == gold_before and I.count("water_tally") == 1, "leaned on: the tally-stone, free")
				"sight":
					var chest = n("TallyChest")
					ok(chest.belongs_to == "Collector Amir Tahan" and chest.contents.has("water_tally"), "a tally-stone in Amir's chest")
					chest.unlock()
					chest.interact(p)
					ok(I.count("water_tally") == 1 and autoload("Crime").stolen_count("water_tally", "glass_coast") == 1, "taken, and stolen")
			DM.end()
			talk("Samira"); pick("Here's your tally-stone")
			ok(GS.has_flag("due_done") and I.count("water_tally") == 0, "Samira's tally-stone, home")
			DM.end()
			ok(Q.status("the_sovereigns_due")["state"] == "completed", "The Sovereign's Due done (%s)" % mode)
			# The ward.
			n("WardUp/UnderGlassWard").interact(p)
			ok(offered("Look at it through the ward-glass") == (mode != "mercy"), "the ward-glass, if Ophira gave it")
			ok(offered("Find the Mercy's cut") == (mode == "mercy"), "the Mercy's cut, if Ammara told you")
			ok(not offered("(Sight.)"), "no seam to See at Sight %d" % autoload("Skills").levels.get("sight", 0))
			DM.end()
			match mode:
				"college":
					n("WardUp/UnderGlassWard").interact(p); pick("Look at it through the ward-glass")
					ok(GS.has_flag("ward_lifted") and I.count("ward_glass") == 0, "the ward parts for the lens, and it cracks")
				"mercy":
					n("WardUp/UnderGlassWard").interact(p); pick("Find the Mercy's cut")
					ok(GS.has_flag("mercy_way"), "through the Mercy's cut")
				"sight":
					autoload("Skills").levels["sight"] = 40
					n("WardUp/UnderGlassWard").interact(p); pick("(Sight.)")
					ok(GS.has_flag("ward_seen") and I.count("ward_glass") == 1, "Sight 40: the old seam (and the lens unused)")
			ok(GS.has_flag("vault_open"), "past the ward")
			DM.end()
			ok(n("WardDown").is_present() and not n("WardUp").is_present(), "a stair of black glass")
			GS.set_flag("stones_quest_done")   # one well already dealt with
			n("WardDown/UnderGlassStair").interact(p)
			wait = 30
		5:
			ok(current_scene.name == "UnderGlass", "down under the glass", current_scene.name)
			wait = 5
		6:
			ok(GS.has_flag("discovered_under_glass_vault"), "the Under-Glass found")
			ok(n("SocketLit1").is_present(), "a socket lit for the Vale's stones")
			ok(not n("SocketLit2").is_present() and not n("SocketLit5").is_present(), "dark for the wells you haven't dealt with")
			ok(not n("SocketLit6").is_present(), "and dark for this one, while its keeper stands")
			ok(range(1, 13).all(func(k): return n("Socket%d" % k) != null), "twelve sockets in the seal")
			n("TheSeal").interact(p)
			ok(DM._choices.size() == 1 and DM._choices[0]["text"] == "(Step back.)", "the seal can't be studied past the Sentinel")
			DM.end()
			var sentinel = n("GlassSentinel")
			ok(sentinel != null and sentinel.display_name == "The Glass Sentinel", "the Glass Sentinel keeps the vault")
			sentinel.wake(p)
			sentinel.take_hit(9999.0, p.global_position, 0.0, 0.0)
			wait = 10
		7:
			ok(GS.has_flag("glass_sentinel_down"), "the Sentinel falls")
			ok(n("SocketLit6").is_present(), "and the deepest well's socket lights")
			n("TheSeal").interact(p); pick("Work the card free")
			ok(GS.has_flag("seal_read") and I.count("seal_card") == 1, "A.'s card, from the seam of the door")
			DM.end()
			n("TheSeal").interact(p)
			ok(DM._node == DM._nodes["read"], "it won't open until every well answers")
			DM.end()
			n("GlassStair").interact(p)
			wait = 30
		8:
			ok(current_scene.name == "GlassCoast" and p.global_position.distance_to(n("FromVault").global_position) < 1.5, "back up on the Scar")
			gold_before = I.gold
			match mode:
				"college":
					talk("Ophira"); pick("The vault opens only when all twelve")
					ok(GS.has_flag("glass_told") and I.gold == gold_before + 150, "Ophira knows everything, and pays")
				"mercy":
					var potions: int = I.count("minor_healing_potion")
					talk("Ammara"); pick("It wants all twelve")
					ok(GS.has_flag("glass_mercy") and I.count("minor_healing_potion") == potions + 2, "Ammara knows, and gives you something for the grey")
				"sight":
					talk("Ophira")
					ok(not offered("(Wear an honest face.)"), "no honest face at Glamour %d" % autoload("Skills").levels.get("glamour", 0))
					DM.end()
					autoload("Skills").levels["glamour"] = 40
					talk("Ophira"); pick("(Wear an honest face.)")
					ok(GS.has_flag("glass_lied") and I.gold == gold_before + 50, "a dead end, Ophira believes")
			DM.end()
			ok(Q.status("under_the_glass")["state"] == "completed", "Under the Glass done (%s)" % mode)
			# Glass That Sings: quiet by day, singing at night.
			talk("Jamila"); pick("Need anything?"); pick("Three singing shards")
			ok(Q.status("glass_that_sings")["state"] == "active", "Jamila starts Glass That Sings")
			DM.end()
			n("SingingGlass1").interact(p)
			ok(DM._choices.size() == 1 and DM._choices[0]["text"] == "(Leave it.)", "by day it's only glass")
			DM.end()
			autoload("WorldClock").hour = 23.0
			for i in [1, 2, 3]:
				n("SingingGlass%d" % i).interact(p); pick("Work the singing shard free"); DM.end()
			ok(I.count("singing_glass") == 3, "three singing shards, in the dark")
			autoload("WorldClock").hour = 13.0
			wait = 5
		9:
			var magicka: int = I.count("potion_restore_magicka_1")
			talk("Jamila"); pick("I've brought singing glass")
			ok(GS.has_flag("sing_done") and I.count("singing_glass") == 0 and I.count("potion_restore_magicka_1") == magicka + 2, "Jamila pays in coin and the seers' blue")
			DM.end()
			ok(Q.status("glass_that_sings")["state"] == "completed", "Glass That Sings done")
			# The trainer, the merchant, the bed.
			ok(autoload("Training").TRAINERS["ophira"]["skill"] == "sight", "Ophira teaches Sight")
			talk("Rafiq"); pick("I need a bed"); pick("Here's ten")
			ok(n("CisternBed").is_present(), "an alcove at the back of the Cistern House")
			DM.end()
			talk("Nadira"); pick("Let's trade.")
			wait = 5
		10:
			ok(autoload("TradeScreen").is_open and autoload("TradeScreen").merchant == "nadira", "Nadira's stall by the oasis")
			autoload("TradeScreen").close()
			n("ShipHome").interact(p)
			wait = 40
		11:
			ok(current_scene.name == "Ilunhall", "the ship sails back to Ilunhall")
			ok(p.global_position.distance_to(n("FromGlassCoast").global_position) < 1.5, "on Ilunhall's quay")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
