extends "res://tests/test_base.gd"
# Phase 1c melee: windup timing, combos, heavy charge + stagger, block, parry,
# dodge, guard break, wolf telegraph, spells still working.
var f := 0
var steps := []
var wait := 0
var p; var c; var w; var level
var log_hp := 0.0
var t0 := 0
var finished := false
var defended_results := []
var light_damage := 0.0
func add(n: int, cb: Callable) -> void: steps.append([n, cb])
func _initialize() -> void:
	level = load("res://levels/test_level.tscn").instantiate(); root.add_child(level); current_scene = level
func setup() -> void:
	p = level.get_node("Player"); c = p.combat
	for i in [1, 2, 3]:
		var wolf = level.get_node("GreyfangPack/Wolf%d" % i)
		wolf.set_physics_process(false)
		wolf.global_position = Vector3(40 + i * 3, 0, 40)
	w = level.get_node("GreyfangPack/Wolf1")
	p.global_position = Vector3(8, 0, -20); p.rotation.y = 0; p.head.rotation.x = -0.6
	w.global_position = Vector3(8, 0, -21.5)
	w.stats.max_health = 10000; w.stats.health = 10000
	p.stats.max_stamina = 500; p.stats.stamina = 500
func hp() -> float: return w.stats.health
func st() -> String: return c.State.keys()[c.state]
func tap() -> void: c.attack_pressed(); c.attack_released()
func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		setup()
		ok(c.light_attacks.size() == 3 and c.heavy_attack != null, "sword moveset: 3 lights + a heavy")
		near(c.block_reduction, 0.6, 0.001, "sword block reduction")
		# 1) a tap starts a windup; the damage lands only after the windup
		add(5, func(): log_hp = hp(); t0 = f; tap(); ok(st() == "WINDUP" and c.combo_index == 1, "a tap starts the windup", [st(), c.combo_index]))
		add(1, func(): near(log_hp - hp(), 0.0, 0.001, "no damage during the windup"))
		add(30, func():
			light_damage = log_hp - hp()
			near(light_damage, 15.0, 0.5, "light hit damage")
			ok(st() == "RECOVERY", "recovering after the hit", st()))
		# 2) combo: three quick taps -> 3 swings, third is the 1.4x finisher
		add(60, func():
			w.stats.health = 10000; log_hp = hp(); w.stats.poise = 999
			tap())
		add(14, func(): tap())
		add(22, func(): tap())
		add(45, func(): near(log_hp - hp(), light_damage * 3.4, 1.5, "combo of 3 (x + x + 1.4x)"))
		add(60, func(): ok(c.combo_index == 0, "combo resets after the grace period", c.combo_index))
		# 3) heavy: hold 0.7 s, release
		add(5, func():
			w.stats.health = 10000; w.stats.poise = 20; log_hp = hp()
			c.attack_pressed())
		add(15, func(): ok(st() == "CHARGING", "holding charges a heavy", st()))
		add(30, func(): between(c.charge, 0.7, 1.0, "charge after 0.75 s"); c.attack_released())
		add(20, func():
			between(log_hp - hp(), 25.0, 40.0, "heavy damage")
			ok(w.State.keys()[w.state] == "STAGGER", "heavy staggers the wolf (25 poise > 20)", w.State.keys()[w.state]))
		# 4) block
		add(60, func(): root.get_node("Spellbook").ready_block(); Input.action_press("cast"))
		add(30, func():
			log_hp = p.stats.health; var s0 = p.stats.stamina
			var r = p.receive_attack(10.0, w, 6.0)
			ok(r == "blocked", "held block blocks", r)
			between(log_hp - p.stats.health, 2.0, 4.5, "health lost through a block of 10")
			between(s0 - p.stats.stamina, 6.0, 12.0, "stamina spent blocking")
			ok(st() == "BLOCKING", "still blocking", st()))
		# 5) parry: block right before the hit
		add(5, func(): Input.action_release("cast"))
		add(5, func(): Input.action_press("cast"))
		add(5, func():
			log_hp = p.stats.health
			var r = p.receive_attack(10.0, w, 6.0)
			ok(r == "parried", "a late block parries", r)
			near(log_hp - p.stats.health, 0.0, 0.001, "no damage from a parried hit")
			ok(c._riposte_left > 1.5, "riposte window opened", c._riposte_left))
		add(5, func():
			var behind = level.get_node("GreyfangPack/Wolf2"); behind.global_position = p.global_position + Vector3(0, 0, 2)
			log_hp = p.stats.health
			var r = p.receive_attack(10.0, behind, 0.0)
			ok(r == "hit", "attack from behind ignores the block", r)
			between(log_hp - p.stats.health, 6.0, 10.0, "damage from behind"))
		add(5, func(): Input.action_release("cast"))
		# 6) dodge
		add(20, func():
			t0 = 0; log_hp = p.global_position.x
			c.dodge_pressed(Vector2(1, 0))
			ok(st() == "DODGING" and c._iframes_left > 0.1, "dodge starts with i-frames", [st(), c._iframes_left]))
		add(3, func():
			var h = p.stats.health
			ok(p.receive_attack(10.0, w, 0.0) == "dodged", "a hit during i-frames is dodged")
			near(h - p.stats.health, 0.0, 0.001, "no damage while dodging"))
		add(25, func():
			between(p.global_position.x - log_hp, 2.5, 4.5, "dodge distance to the right")
			ok(st() == "READY", "ready after the dodge", st()))
		# 7) guard break
		add(10, func():
			Input.action_press("cast"); p.global_position = Vector3(8, 0, -20))
		add(20, func():
			p.stats.stamina = 2.0
			ok(p.receive_attack(20.0, w, 0.0) == "guard_broken", "blocking with no stamina breaks the guard")
			ok(st() == "STAGGERED", "staggered by the guard break", st()))
		add(70, func(): ok(st() == "BLOCKING", "back to blocking after the stagger", st()); Input.action_release("cast"); p.stats.stamina = 500)
		# 8) wolf telegraph -> parry it
		add(10, func():
			p.global_position = Vector3(8, 0, -20); w.global_position = Vector3(8, 0, -21.4)
			w.stats.poise = 20; w._knockback = Vector3.ZERO; w.state = w.State.ATTACK; w._bite_left = 0.0; w.set_physics_process(true)
			root.get_node("Spellbook").ready_block())
		add(1, func(): p.combat.defended.connect(func(r): defended_results.append(r)))
		var eyes := [0.0]
		add(1, func():
			ok(w._windup_left > 0.3, "wolf telegraphs its bite", w._windup_left)
			eyes[0] = w._eyes.emission_energy_multiplier)
		add(18, func(): ok(w._eyes.emission_energy_multiplier > eyes[0] + 3.0, "eyes brighten during the windup", [eyes[0], w._eyes.emission_energy_multiplier]); Input.action_press("cast"))
		add(15, func():
			ok(defended_results == ["parried"], "a late block parries the bite", defended_results)
			ok(w.State.keys()[w.state] == "STAGGER", "parried wolf is staggered", w.State.keys()[w.state])
			Input.action_release("cast"))
		add(30, func(): near(Engine.time_scale, 1.0, 0.001, "hit-stop ends"))
		# 9) spells still cast with the left hand
		add(80, func(): root.get_node("Spellbook").select("healing"); p.stats.health = 50; Input.action_press("cast"))
		add(30, func():
			ok(p.is_casting, "spells still cast with the left hand")
			ok(p.stats.health > 52.0, "healing restored health", p.stats.health)
			Input.action_release("cast"))
		add(5, func(): finished = true)
	if finished: return done()
	if steps.is_empty(): return false
	wait += 1
	if wait >= steps[0][0]:
		wait = 0
		var s = steps.pop_front()
		s[1].call()
	return false
