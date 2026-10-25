extends "res://tests/test_base.gd"
# Lockpicking (systems/lockpicking.gd): set a lock's pins by pressing while the
# marker is in the sweet spot; a miss drops a pin and may snap a pick. Locked
# containers (loot_container.gd lock_level) open the screen; a key opens them
# outright. Harder locks have more pins; skill and perks widen the spot.
var f := 0
var step := 0
var wait := 0
var p
var L
var C
var I
var S
var box

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	L = autoload("Lockpicking"); C = autoload("Character"); I = autoload("Inventory"); S = autoload("Skills")
	match step:
		0:
			for i in [1, 2, 3]: current_scene.get_node("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			wait = 5
		1:
			ok(S.SKILLS["lockpicking"]["attribute"] == "agility", "a Lockpicking skill (Agility)")
			ok(autoload("Trade").stock("maren").has("lockpick"), "Maren sells lockpicks")
			# The rules.
			S.levels["lockpicking"] = 15; S.xp["lockpicking"] = 0.0
			ok(L.pins_for(0) == 2 and L.pins_for(4) == 6, "Novice 2 pins, Master 6")
			L.start(2)
			ok(L.pins == 4 and L.set_pins == 0, "an Adept lock: 4 pins")
			near(L.spot_width(), 0.16, 0.001, "an Adept sweet spot at 15")
			ok(L.attempt() == "no_picks", "no lockpick, no picking")
			I.add("lockpick", 20)
			L.marker = L.spot_center
			ok(L.attempt() == "set" and L.set_pins == 1, "in the spot: a pin sets")
			ok(S.xp["lockpicking"] > 0.0, "and Lockpicking improves")
			C.perks.append("unbreakable")
			L.marker = fposmod(L.spot_center + 0.5, 1.0)
			ok(L.attempt() == "miss" and L.set_pins == 0, "a miss drops the pin")
			C.perks.append("quick_hands")
			L.marker = L.spot_center
			L.attempt()
			L.marker = fposmod(L.spot_center + 0.5, 1.0)
			L.attempt()
			ok(L.set_pins == 1, "Nimble Fingers: not with it")
			C.perks.clear()
			# Picks snap.
			seed(7)
			var picks: int = I.count("lockpick")
			var broke := false
			for i in 20:
				L.marker = fposmod(L.spot_center + 0.5, 1.0)
				if L.attempt() == "broke":
					broke = true
					break
			ok(broke and I.count("lockpick") == picks - 1, "a miss can snap a pick", I.count("lockpick"))
			# Moving.
			L.start(0)
			L.tick(0.5)
			ok(L.marker > 0.0, "the marker moves", L.marker)
			L.tick(5.0)
			ok(L.marker >= 0.0 and L.marker <= 1.0, "and stays on the lock", L.marker)
			# Skill and perks.
			S.levels["lockpicking"] = 65
			near(L.spot_width(), 0.24 * 1.5, 0.001, "at 65: 50% wider")
			var slow: float = L.speed()
			S.levels["lockpicking"] = 15
			ok(slow < L.speed(), "and slower")
			C.perks.append("light_touch_1")
			near(L.spot_width(), 0.24 * 1.2, 0.001, "Light Touch: 20% wider")
			C.perks.append("locksmith_apprentice")
			ok(L.pins_for(1) == 2, "Apprentice Locks: one pin fewer")
			C.perks.append("locksense")
			L.start(1)
			ok(L.set_pins == 1, "Locksense: the first pin sets itself")
			C.perks.append("spring_the_lock")
			ok(L.spring() and not L.can_spring(), "Spring the Lock: once a day")
			C.perks.clear()
			# A locked box at the bandit camp.
			box = current_scene.get_node("BanditLockbox")
			ok(box.is_locked() and box.prompt == "Pick the lock (Apprentice)", "the bandits' lockbox is locked", box.prompt)
			I.remove("lockpick", I.count("lockpick"))
			box.interact(p)
			ok(box.is_locked() and not autoload("LockpickScreen").is_open, "no picks: it stays shut")
			I.add("lockpick", 5)
			box.interact(p)
			wait = 2
		2:
			var LS = autoload("LockpickScreen")
			ok(LS.is_open and paused, "the lockpick screen opens")
			var gold: int = I.gold
			var result := ""
			for i in 10:
				L.marker = L.spot_center
				result = LS.attempt()
				if result == "open":
					break
			ok(result == "open", "set every pin and it opens", result)
			ok(not box.is_locked() and I.gold == gold + 60, "and you take what's inside", I.gold - gold)
			ok(box.get_persist_state()["lock_level"] == -1, "it stays open")
			wait = 60
		3:
			var LS = autoload("LockpickScreen")
			ok(not LS.is_open and not paused, "the screen closes after")
			# A key.
			box.lock_level = 3
			box.key_id = "iron_ingot"
			box.contents = {"bread": 1}
			ok(box.prompt == "Unlock bandits' lockbox", "with the key: Unlock", box.prompt)
			box.interact(p)
			ok(not box.is_locked() and I.count("bread") >= 1, "the key opens it")
			# Treasure Hunter and Scavenger.
			C.perks.append("treasure_hunter"); C.perks.append("scavenger")
			box.lock_level = 0
			box.gold = 10
			box.unlock()
			ok(box.gold == 15 and box.contents.get("lockpick", 0) >= 1, "Treasure Hunter and Scavenger", [box.gold, box.contents])
			C.perks.clear()
			ok(FileAccess.get_file_as_string("res://levels/waystation_cellar.tscn").contains('container_name = "strongbox"'), "a Novice strongbox in the cellar")
			ok(FileAccess.get_file_as_string("res://levels/test_dungeon.tscn").contains('container_name = "cult coffer"'), "an Adept coffer in the Barrow")
			var perks: Array = C.perk_list.keys().filter(func(k): return C.perk_list[k]["skill"] == "lockpicking")
			ok(perks.size() >= 20, "20+ Lockpicking perks", perks.size())
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
