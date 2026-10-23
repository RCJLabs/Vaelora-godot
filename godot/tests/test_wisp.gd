extends "res://tests/test_base.gd"
# Wisps: night spawning, charge telegraph, bolts vs block/parry/dodge/ward, blink, damage types,
# heavy-hit knockdown, no resting mid-fight, essence drop, fading at dawn.
var f := 0
var steps := []
var wait := 0
var p; var level; var W; var spawner; var w; var c
var h0 := 0.0; var defend := ""; var results := []
var watch_bolt := false
# The first bolt of each defence is judged on its own: the wisp circles and throws again within the
# hold window, sometimes from the side, so later bolts would muddy the numbers.
var snap_at := -1
var first_lost := 0.0
var first_results := []

func add(k: int, cb: Callable) -> void: steps.append([k, cb])
func bolts() -> Array: return level.find_children("*", "Node3D", false, false).filter(func(n): return n.get("hits_player") != null)

func _initialize() -> void:
	level = load("res://levels/test_level.tscn").instantiate(); root.add_child(level); current_scene = level

func setup_duel() -> void:
	p.global_position = Vector3(-30, 0, 18); p.rotation.y = 0; p.head.rotation.x = deg_to_rad(4)
	# Home moved to the duel spot: from its real home by the stone circle (~30 m away) the wisp is at
	# the edge of its leash and sometimes breaks off to fly home mid-test.
	w.home = Vector3(-30, 0, 12)
	w.global_position = Vector3(-30, 1.8, 10); w.state = w.State.ENGAGE; w._cast_left = 0.0; w.set_physics_process(true)
	p.stats.health = p.stats.max_health

func _physics_process(_d: float) -> bool:
	f += 1
	# defend just before an incoming bolt arrives
	if watch_bolt and p:
		for b in bolts():
			if b.hits_player and b.global_position.distance_to(p.global_position + Vector3.UP * 1.3) < 2.2:
				watch_bolt = false
				match defend:
					"parry", "block": Input.action_press("cast")
					"dodge": c.dodge_pressed(Vector2(1, 0)); snap_at = f + 30
	if f == snap_at:
		first_lost = h0 - p.stats.health
		first_results = results.duplicate()
	if f == 3:
		p = level.get_node("Player"); W = autoload("WorldClock"); c = p.combat; spawner = level.get_node("StoneWisps")
		for i in [1, 2, 3]: level.get_node("GreyfangPack/Wolf%d" % i).set_physics_process(false)
		for b in level.get_node("BanditCamp").get_children(): b.set_physics_process(false)
		W.hour = 12.0
		add(5, func(): ok(spawner.get_child_count() == 0, "no wisps at midday", spawner.get_child_count()); W.hour = 21.0)
		add(5, func():
			ok(spawner.get_child_count() == 3, "three wisps at 21:00", spawner.get_child_count())
			w = spawner.get_child(0)
			for o in spawner.get_children().slice(1): o.set_physics_process(false); o.global_position = Vector3(60, 2, 60)
			setup_duel(); h0 = p.stats.health
			c.defended.connect(func(r):
				if results.is_empty(): snap_at = f + 20
				results.append(r)))
		add(10, func():
			ok(w.State.keys()[w.state] == "CHARGE", "wisp charges a bolt", w.State.keys()[w.state])
			ok(w.light.light_energy > 1.2 and w.halo.scale.x > 1.05, "charge telegraph: brighter light, bigger halo", [w.light.light_energy, w.halo.scale.x]))
		add(80, func(): near(h0 - p.stats.health, 9.5, 1.0, "undefended bolt damage"))
		# block, parry, dodge, ward
		for mode in ["block", "parry", "dodge", "ward"]:
			add(30, func():
				setup_duel(); results = []; defend = mode; h0 = p.stats.health; w.stats.health = w.stats.max_health
				snap_at = -1; first_lost = -1.0; first_results = []
				autoload("Spellbook").ready_block()
				if mode == "block": Input.action_press("cast")   # held early: a plain block
				if mode == "ward":
					autoload("Spellbook").learn("healing_ward"); autoload("Spellbook").select("healing_ward"); Input.action_press("cast")
				watch_bolt = mode == "parry" or mode == "dodge")
			add(400 if mode == "parry" else 140, func():
				Input.action_release("cast")
				var lost: float = first_lost
				match mode:
					"block":
						ok(first_results == ["blocked"], "block: bolt blocked", first_results)
						between(lost, 2.5, 4.5, "block: damage taken")
					"parry":
						ok(first_results == ["parried"], "parry: bolt parried", first_results)
						ok(lost < 0.5 and lost >= 0.0, "parry: no damage from the parried bolt", lost)
						# Used to fail now and then: the reflected bolt's homing bled its speed away and it
						# crawled to the wisp and missed. Fixed in spell_bolt.gd (it now flies straight at it).
						near(w.stats.health, 12.0, 0.5, "parry: the reflected bolt hits the wisp (x1.5)")
					"dodge":
						ok(first_results.is_empty() and lost < 0.01 and lost >= 0.0, "dodge: bolt passes through", [first_results, lost])
					"ward":
						ok(first_results == ["warded"], "ward: bolt warded", first_results)
						between(lost, 2.5, 4.5, "ward: damage taken")
				if mode != "parry":
					near(w.stats.health, w.stats.max_health, 0.01, "%s: wisp unhurt" % mode))
		# blink when you get close
		var spot := [Vector3.ZERO]
		add(20, func():
			w.global_position = Vector3(-30, 1.8, 15); w.state = w.State.ENGAGE; w._blink_left = 0.0; w._cast_left = 5.0
			p.global_position = Vector3(-30, 0, 17); spot[0] = w.global_position)
		add(10, func():
			between(w.global_position.distance_to(spot[0]), 4.5, 7.5, "player 2 m away: wisp blinks 5-7 m")
			between(Vector2(w.global_position.x - p.global_position.x, w.global_position.z - p.global_position.z).length(), 3.5, 10.0,
					"wisp ends up out of reach"))
		# damage types
		add(10, func():
			w.stats.health = 30; w.stats.poise = 15
			h0 = w.stats.health; w.take_hit(10.0, p.global_position, 0.0, 0.0)
			near(h0 - w.stats.health, 5.0, 0.01, "spell damage halved")
			h0 = w.stats.health; w.take_hit(10.0, p.global_position, 4.0, 5.0)
			near(h0 - w.stats.health, 10.0, 0.01, "weapon damage in full")
			w.take_hit(1.0, p.global_position, 4.0, 5.0, true))
		add(30, func():
			ok(w.State.keys()[w.state] == "STAGGER", "heavy hit staggers the wisp", w.State.keys()[w.state])
			between(w.global_position.y - w._ground_height(), 0.0, 0.8, "heavy hit knocks it down"))
		add(5, func():
			p.global_position = w.global_position + Vector3(0, -1.8, 8)
			w.state = w.State.ENGAGE
			var rm = autoload("RestMenu"); rm.open(level.get_node("WaystationFire"), true)
			ok(not rm.is_open, "can't rest with a wisp fighting 8 m away")
			w.stats.take_damage(999))
		add(5, func():
			var drop = level.find_children("*", "StaticBody3D", false, false).filter(func(n): return n.get("item_id") == "wisp_essence")
			ok(not is_instance_valid(w), "dead wisp is freed")
			ok(drop.size() == 1 and drop[0].prompt == "Take Wisp Essence", "dead wisp drops essence", drop.size())
			if drop: drop[0].interact(p)
			ok(autoload("Inventory").count("wisp_essence") == 1, "essence picked up"))
		add(5, func(): ok(spawner.get_child_count() == 2, "two wisps left before dawn", spawner.get_child_count()); W.hour = 6.5)
		add(120, func(): ok(spawner.get_child_count() == 0, "wisps gone after dawn", spawner.get_child_count()); done(); quit())
	if f < 3 or steps.is_empty(): return false
	wait += 1
	if wait >= steps[0][0]:
		wait = 0
		steps.pop_front()[1].call()
	return false
