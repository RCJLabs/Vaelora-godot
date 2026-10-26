extends "res://tests/test_base.gd"
# Theft and the law (systems/crime.gd): taking what's someone's in front of them
# is a bounty; at night, with nobody about, it isn't, but the goods are stolen
# either way and the region's merchants won't buy them (others will); picking
# pockets (crouched; a better chance from behind; once a day); guards stop you
# while you're wanted: pay (they take the goods), the cells (days pass), or run
# (more bounty, a minute's peace); it all saves. docs/godot-starter/CRIME.md.
var f := 0
var step := 0
var wait := 0
var p
var C
var DM
var day_before := 0
var gold_before := 0

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/weirholt.tscn")

func n(path: String) -> Node:
	return current_scene.find_child(path, true, false)

func put(at: Vector3, yaw_deg := 0.0) -> void:
	p.global_position = at
	p.rotation.y = deg_to_rad(yaw_deg)
	p.velocity = Vector3.ZERO

func choice_with(key: String, value: String) -> int:
	for i in DM._choices.size():
		if str(DM._choices[i].get(key, "")) == value:
			return i
	return -1

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	C = autoload("Crime")
	DM = autoload("DialogueManager")
	var I = autoload("Inventory")
	var W = autoload("WorldClock")
	match step:
		0:
			for id in ["bread", "lockpick"]:
				if I.count(id) > 0:
					I.remove(id, I.count(id))
			W.hour = 13.0
			wait = 10
		1:
			ok(C.region() == "riverlands", "Weirholt is in the Riverlands")
			# Seen: Hedda's purse off her counter, in front of her.
			put(Vector3(-11, 0, -14.5), 180.0)
			var purse = n("HeddaPurse")
			ok(purse.prompt.begins_with("Steal") and purse.prompt.ends_with("(watched)"), "her purse: Steal, and you're watched", purse.prompt)
			gold_before = I.gold
			purse.interact(p)
			ok(I.gold == gold_before + 12 and C.bounty_here() == 12, "taken in front of her: the purse's worth in bounty", C.bounty)
			C.bounty.erase("riverlands")
			# Unseen: at night, with Wenna gone home and nobody near.
			W.hour = 23.0
			wait = 5
		2:
			ok(n("Wenna").inside, "Wenna's gone home")
			put(Vector3(-4, 0, 1.6), 0.0)
			var picks = n("WennaLockpicks")
			ok(not picks.prompt.ends_with("(watched)"), "behind the stall at night, nobody's watching", [picks.prompt, C.witnesses().map(func(w): return w.name)])
			picks.interact(p)
			n("WennaBread").interact(p)
			ok(C.stolen_count("bread", "riverlands") == 2 and I.count("bread") == 2, "her bread too")
			ok(C.bounty_here() == 0, "taken unseen: no bounty", C.bounty)
			ok(C.stolen_count("lockpick", "riverlands") == 3, "but they're stolen all the same")
			# Merchants.
			var T = autoload("Trade")
			ok("stolen" in T.why_not_sell("wenna", "lockpick"), "Wenna won't buy them back", T.why_not_sell("wenna", "lockpick"))
			ok(T.why_not_sell("marta", "lockpick") == "", "a merchant in the Fields will", T.why_not_sell("marta", "lockpick"))
			T.sell("marta", "lockpick")
			ok(C.stolen_count("lockpick") == 2, "sold one: two stolen left")
			I.add("lockpick", 1)   # bought honestly
			ok(T.why_not_sell("wenna", "lockpick") == "", "Wenna buys one you came by honestly")
			# Pickpocketing, by day.
			W.hour = 13.0
			wait = 5
		3:
			var hedda = n("Hedda")
			var forward: Vector3 = -hedda.global_basis.z
			put(hedda.global_position + forward * 1.2, 0.0)
			var front: float = C.pick_chance(hedda)
			put(hedda.global_position - forward * 1.0, 0.0)
			p.set_sneaking(true)
			var behind: float = C.pick_chance(hedda)
			ok(behind > front + 0.2, "a better chance from behind", [front, behind])
			ok(hedda.prompt.begins_with("Pickpocket Hedda Marrow ("), "crouched at Hedda: Pickpocket, with the chance", hedda.prompt)
			ok(not n("Varga").prompt.begins_with("Pickpocket"), "not a guard")
			gold_before = I.gold
			C.next_roll = 0.0
			hedda.interact(p)
			ok(I.gold > gold_before, "picked: her coin's yours", I.gold - gold_before)
			ok(hedda.prompt.begins_with("Nothing more"), "and not twice in a day", hedda.prompt)
			var was: int = C.bounty_here()
			C.next_roll = 0.99
			n("Tarle").interact(p)
			ok(C.bounty_here() == was + C.PICKPOCKET_CAUGHT, "caught with your hand in Tarle's pocket: a bounty", C.bounty)
			p.set_sneaking(false)
			# The guard: Varga sees you and stops you.
			I.add_gold(500)
			put(n("Varga").global_position + (-n("Varga").global_basis.z) * 4.0, 0.0)
			wait = 0
			step = 4
			return false
		4:
			if not DM.is_active:
				if f > 2000:
					ok(false, "Varga stops you")
					return done()
				return false
			ok(DM.is_active and "%d gold" % C.bounty_here() in DM.line_label.text, "Varga stops you and names the bounty", DM.line_label.text)
			gold_before = I.gold
			var owed: int = C.bounty_here()
			DM.choose(choice_with("crime", "pay"))
			ok(C.bounty_here() == 0 and I.gold == gold_before - owed, "paid")
			ok(I.count("bread") == 0 and I.count("lockpick") == 1, "and they took the stolen goods (not the honest pick)", [I.count("bread"), I.count("lockpick")])
			DM.end()
			# The cells.
			C._add_bounty("riverlands", 150, "Test.")
			day_before = W.day
			n("Varga").interact(p)
			DM.choose(choice_with("crime", "jail"))
			ok(W.day == day_before + 2, "150 gold: two days in the cells", W.day - day_before)
			ok(C.bounty_here() == 0 and p.global_position.distance_to(n("JailRelease").global_position) < 0.5, "and out at the barracks door, bounty served")
			DM.end()
			# Running.
			C._add_bounty("riverlands", 20, "Test.")
			n("Varga").interact(p)
			DM.choose(choice_with("crime", "resist"))
			ok(C.bounty_here() == 30 and not C.guards_may_stop(), "run: the bounty grows and they leave you be a while")
			wait = 40
		5:
			ok(not DM.is_active, "for now")
			var page: ScrollContainer = load("res://ui/world_page.gd").new()   # loaded, not named: it needs the autoloads
			get_root().add_child(page)
			page.refresh()
			var lines: Array = page.find_children("*", "Label", true, false).map(func(l): return l.text)
			ok(lines.has("Wanted") and lines.any(func(t): return t.begins_with("The Riverlands: 30 gold")), "Tab > World says where you're wanted", lines.slice(0, 3))
			page.free()
			# Saving.
			var saved: Dictionary = C.to_dict()
			C.reset()
			C.from_dict(JSON.parse_string(JSON.stringify(saved)))
			ok(C.bounty_in("riverlands") == 30 and C.picked.size() == 2, "bounties and picked pockets save")
			change_scene_to_file("res://levels/ilunhall.tscn")
			wait = 20
		6:
			ok(C.region() == "capital" and C.bounty_here() == 0, "Ilunhall's law is its own")
			ok(n("QuayWarden").role == "guard" and n("BridgeWarden").role == "guard", "Ilunhall has wardens")
			ok(n("OdoCask").belongs_to == "Hallmaster Odo" and n("BrunaIngots").belongs_to == "Bruna Deepseal", "and things that are someone's")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
