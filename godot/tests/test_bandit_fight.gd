extends "res://tests/test_base.gd"
# Bandit camp balance, played by a bot. mode "naive": swing at the nearest bandit, never defend.
# mode "skilled": block (parry if timed) incoming swings, heavy into raised guards.
var f := 0
var p; var c; var level; var mode := "naive"
var bandits := []
var parries := 0; var blocks := 0; var hits_taken := 0
var holding_heavy := 0
func _initialize() -> void:
	mode = arg("naive")
	autoload("SaveSystem").delete_save()
	level = load("res://levels/test_level.tscn").instantiate(); root.add_child(level); current_scene = level
func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		p = level.get_node("Player"); c = p.combat
		for i in [1, 2, 3]: var w = level.get_node("GreyfangPack/Wolf%d" % i); w.set_physics_process(false); w.global_position = Vector3(50, 0, 50 + i * 3)
		bandits = [level.get_node("BanditCamp/Bandit1"), level.get_node("BanditCamp/Bandit2"), level.get_node("BanditCamp/Leader")]
		p.global_position = Vector3(-34, 0, -26)
		autoload("Spellbook").ready_block()
		c.defended.connect(func(r):
			if r == "parried": parries += 1
			elif r == "blocked": blocks += 1)
		p.stats.damaged.connect(func(a): if a >= 1.0: hits_taken += 1)
		return false
	if f < 3: return false
	# Gone (the band broke and they ran: enemies/wolf_pack.gd morale) counts as beaten.
	var alive := bandits.filter(func(b): return is_instance_valid(b) and b.state != b.State.DEAD and not b._routed)
	if alive.is_empty():
		print("%s: camp cleared at %.1fs, player H=%.0f/%.0f, hits taken=%d blocks=%d parries=%d" % [mode, f / 60.0, p.stats.health, p.stats.max_health, hits_taken, blocks, parries])
		if mode == "skilled":
			ok(true, "skilled bot clears the camp")
			between(f / 60.0, 5.0, 45.0, "seconds to clear the camp")
			# Surrounding (enemies/bandit.gd _ring_spot) costs even a skilled bot about 20 HP here
			# (main before it: 81-100; with it: 57-94), and the bot never backs to a wall.
			between(p.stats.health, 45.0, 100.0, "skilled bot's health left")
			# Kill the leader and the rest run (wolf_pack.gd morale): short fights give few swings to parry.
			ok(parries >= 1, "skilled bot parried", parries)
		else:
			# Balance guard: never defending must not win comfortably.
			between(p.stats.health, 0.0, 50.0, "naive bot (never defends) wins only barely")
			ok(hits_taken >= 5, "naive bot takes at least 5 hits", hits_taken)
		return done()
	if p.is_dead or p.stats.is_dead:
		print("%s: PLAYER DIED at %.1fs, bandits left: %s" % [mode, f / 60.0, alive.map(func(b): return "%s %.0fhp" % [b.display_name, b.stats.health])])
		if mode == "naive":
			ok(true, "naive bot (never defends) dies or wins only barely")
			between(f / 60.0, 5.0, 90.0, "naive bot lasts a while before dying")
		else:
			ok(false, "skilled bot survives", "died")
		return done()
	if f > 60 * 90:
		ok(false, "%s fight ends within 90 s" % mode, alive.map(func(b): return "%s %.0fhp %s" % [b.display_name, b.stats.health, b.State.keys()[b.state]]))
		return done()
	# face the nearest
	alive.sort_custom(func(a, b): return a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position))
	var t = alive[0]
	var d: Vector3 = t.global_position - p.global_position
	p.rotation.y = atan2(-d.x, -d.z); p.head.rotation.x = -0.1
	# walk in if far
	if Vector2(d.x, d.z).length() > 2.0: Input.action_press("move_forward")
	else: Input.action_release("move_forward")
	var threat := false
	if mode == "skilled":
		for b in alive:
			if b.state == b.State.ATTACK and b._phase == b.Phase.WINDUP and b._phase_time > b._attack.windup - 0.18 and b.global_position.distance_to(p.global_position) < 3.0:
				threat = true
				# A skilled player turns to meet the swing (a block only covers your front).
				var bd: Vector3 = b.global_position - p.global_position
				p.rotation.y = atan2(-bd.x, -bd.z)
		if threat: Input.action_press("cast")
		elif Input.is_action_pressed("cast") and c.state == c.State.BLOCKING and c._state_time > 0.4: Input.action_release("cast")
	if threat or c.state == c.State.BLOCKING: return false
	if f % 20 == 0 and Vector2(d.x, d.z).length() < 2.4:
		if mode == "skilled" and (t.state == t.State.GUARD or t.state == t.State.STAGGER) and holding_heavy == 0:
			c.attack_pressed(); holding_heavy = 40
		elif holding_heavy == 0:
			c.attack_pressed(); c.attack_released()
	if holding_heavy > 0:
		holding_heavy -= 1
		if holding_heavy == 0: c.attack_released()
	return false
