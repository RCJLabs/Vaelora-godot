extends "res://tests/test_base.gd"
# Hardcore defeat: captured by bandits (gear to their stash, locked in the cage,
# work the lock, get your gear back), found (taken to the refuge, a gold fee),
# left for dead, the real death sequence, Wounded until you sleep, and the barrow
# boss resetting. Normal mode still reloads.
var f := 0
var step := 0
var wait := 0
var p
var D
var C
var level
var bandit
var hour_before := 0.0
var spot := Vector3.ZERO

func _initialize() -> void:
	seed(3)
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node(path)

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	D = autoload("Defeat"); C = autoload("Character")
	var inv = autoload("Inventory")
	match step:
		0:
			wait = 20
		1:
			C.modes["hardcore"] = false
			ok(not D.applies(), "Normal mode: defeat doesn't apply (it reloads, as before)")
			C.modes["hardcore"] = true
			ok(D.applies(), "Hardcore: defeat applies")
			# --- captured ---
			bandit = n("BanditCamp/Bandit1")
			ok(D.choose(bandit) == "captured", "beaten by a bandit here: captured")
			inv.add("minor_healing_potion", 2); inv.add_gold(50)
			ok(inv.equipped.size() > 0, "wearing gear before", inv.equipped)
			var items_before: int = inv.items.size()
			bandit.global_position += Vector3(5, 0, 5); bandit.state = bandit.State.CHASE   # mid-fight
			hour_before = autoload("WorldClock").hour + autoload("WorldClock").day * 24.0
			D.wake(p, "captured")
			var stash = n("BanditCage/CaptorStash")
			ok(inv.items.is_empty() and inv.equipped.is_empty() and inv.gold == 0, "your gear and gold are taken", [inv.items, inv.gold])
			ok(stash.contents.size() == items_before and stash.gold >= 50, "and put in the bandits' stash", [stash.contents, stash.gold])
			ok(p.global_position.distance_to(n("BanditCage/CaptiveCell").global_position) < 0.3, "you wake in the cage")
			ok(p.effects.has("wounded"), "Wounded")
			near(p.stats.health, p.stats.max_health * 0.3, 0.5, "at 30% health")
			ok(not p.is_dead, "alive")
			var now: float = autoload("WorldClock").hour + autoload("WorldClock").day * 24.0
			near(now - hour_before, 6.0, 0.05, "6 hours passed")
			ok(bandit.global_position.distance_to(bandit.home) < 0.01 and bandit.state == bandit.State.IDLE, "bandits are back at their camp, calm")
			ok(autoload("SaveSystem").has_save("autosave"), "the defeat is autosaved (no reloading it away)")
			ok(n("BanditCage/CageDoor").tries_left == 4, "the cage is locked")
			# Try to walk out through the door side (west).
			p.rotation.y = deg_to_rad(90); p.head.rotation.x = 0.0
			Input.action_press("move_forward")
			wait = 60
		2:
			Input.action_release("move_forward")
			var cell: Vector3 = n("BanditCage/CaptiveCell").global_position
			ok(p.global_position.distance_to(cell) < 1.4, "the locked door holds you in", p.global_position.distance_to(cell))
			var door = n("BanditCage/CageDoor")
			for i in 3:
				door.interact(p)
			ok(door.tries_left == 1 and not door.get_node("Shape").disabled, "three tries: still locked")
			door.interact(p)
			ok(door.get_node("Shape").disabled, "the fourth try opens it")
			p.global_position = n("BanditCage/CaptiveCell").global_position
			Input.action_press("move_forward")
			wait = 60
		3:
			Input.action_release("move_forward")
			ok(p.global_position.x < n("BanditCage").global_position.x - 1.6, "you walk out of the cage", p.global_position.x)
			n("BanditCage/CaptorStash").interact(p)
			ok(inv.count("minor_healing_potion") >= 2 and inv.gold >= 50, "searching the stash gets your things back", [inv.items, inv.gold])
			ok(inv.count("iron_sword") == 1, "your weapon too (re-equip it yourself)")
			# --- found ---
			inv.gold = 100
			D.wake(p, "found")
			ok(p.global_position.distance_to(n("Refuge").global_position) < 0.3, "found: you wake at the waystation")
			ok(inv.gold == 80, "it cost a fifth of your gold", inv.gold)
			near(p.stats.health, p.stats.max_health * 0.4, 0.5, "at 40% health")
			# --- left for dead ---
			spot = Vector3(20, 0.05, 20)
			p.global_position = spot
			D.wake(p, "left")
			ok(p.global_position.distance_to(spot) < 0.1, "left for dead: you wake where you fell")
			# --- choices without a captor ---
			var outcomes := {}
			for i in 200:
				outcomes[D.choose(n("GreyfangPack/Wolf1"))] = true
			ok(outcomes.has("found") and outcomes.has("left") and not outcomes.has("captured"), "beaten by a wolf: found or left, never captured", outcomes.keys())
			ok(D.choose(null) != "captured", "no killer (a fall, hunger): never captured")
			# --- sleeping heals Wounded ---
			autoload("RestMenu")._pass_time(8.0)
			paused = false   # _pass_time expects the rest menu (which pauses) to be open
			ok(not p.effects.has("wounded"), "sleeping 8 hours heals Wounded")
			# --- the real death sequence ---
			p.global_position = Vector3(20, 0.05, 20)
			p.note_attacker(n("GreyfangPack/Wolf1"))
			p.stats.take_damage(99999.0)
			wait = 5
		4:
			ok(p.is_dead, "the killing blow: you fall")
			wait = 260
		5:
			ok(not p.is_dead and current_scene.name == "TestLevel", "Hardcore: you wake up in the same world, no reload")
			ok(D.last_outcome in ["found", "left"], "beaten by a wolf: found or left", D.last_outcome)
			ok(p.effects.has("wounded"), "and Wounded again")
			# --- the barrow boss resets ---
			autoload("SaveSystem").travel("res://levels/test_dungeon.tscn", "FromOutside")
			wait = 30
		6:
			n("LeverGate").open()
			p.global_position = Vector3(0, 0.05, -51.5)
			wait = 20
		7:
			var g = n("Guardian")
			ok(g.state != 0 and not n("LeverGate").is_open, "the fight starts and the gate shuts")
			g.stats.health = 150.0
			D.wake(p, "found")
			ok(g.state == 0 and is_equal_approx(g.stats.health, g.stats.max_health), "beaten: the guardian is a statue again, healed")
			ok(n("LeverGate").is_open and not n("VaultGate").is_open, "and the gates are as they were")
			ok(not p.hud._boss_bar.visible, "boss bar hidden")
			ok(p.global_position.distance_to(n("Refuge").global_position) < 0.3, "you wake in the barrow's entrance hall")
			return done()
	step += 1
	return false
