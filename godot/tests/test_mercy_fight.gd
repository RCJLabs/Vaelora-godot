extends "res://tests/test_base.gd"
# Balance: a Mercy band with a caster (enemies/cultist.gd), two hand to hand (one leads)
# and a Drawer behind them, played by a bot. mode "naive": swing at the nearest, never
# defend. mode "skilled": the same, but block (parry if timed) swings and heavy into
# guards. Killing the leader breaks the band (enemies/wolf_pack.gd), the caster too.
# mode "hunter": go for the caster first. Only "skilled" runs in tools/run_tests.py; run
# the others by hand. What they gave when the casters went in: skilled 48-100 Health
# left; naive died about half the time, or won with 16-73 (killing the leader early is
# luck); hunter 25-70, worse than skilled: the caster backs off behind the other two
# while they hit you.
var f := 0
var p; var c; var level; var mode := "naive"
var bandits := []
var parries := 0; var blocks := 0; var hits_taken := 0
var holding_heavy := 0
var stuck_left := 0; var last_spot := Vector3.INF
func _initialize() -> void:
	mode = arg("naive")
	autoload("SaveSystem").delete_save()
	level = load("res://levels/test_level.tscn").instantiate(); root.add_child(level); current_scene = level
func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		p = level.get_node("Player"); c = p.combat
		for i in [1, 2, 3]: var w = level.get_node("GreyfangPack/Wolf%d" % i); w.set_physics_process(false); w.global_position = Vector3(50, 0, 50 + i * 3)
		for b in level.get_node("BanditCamp").get_children():
			if b.has_method("take_hit"): b.set_physics_process(false); b.global_position += Vector3(-80, 0, -80)
		var band := Node3D.new(); band.name = "TestMercy"
		band.set_script(load("res://enemies/wolf_pack.gd"))
		band.cleared_flag = "test_mercy_cleared"; band.driven_off_flag = "test_mercy_off"; band.break_on_leader = true; band.break_at_losses = 0.5; band.yelp_on_break = false
		for i in 3:
			var m = load("res://enemies/bandit.tscn").instantiate()
			m.set_script(load("res://enemies/cultist.gd"))
			m.name = "M%d" % i; m.caster = i == 2; m.leader = i == 0
			m.max_health = [90.0, 60.0, 45.0][i]
			band.add_child(m)
		level.add_child(band)
		var camp_at: Vector3 = level.get_node("BanditCamp/Leader").global_position + Vector3(80, 0, 80)
		for i in 3:   # the caster behind the other two
			var m = band.get_child(i)
			m.global_position = camp_at + [Vector3(-2, 0, 0), Vector3(2.5, 0, 0.5), Vector3(0, 0, -4)][i]; m.home = m.global_position
		bandits = band.get_children()
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
		if mode == "naive":
			between(p.stats.health, 0.0, 50.0, "never defending wins only barely: health left")
		else:
			between(p.stats.health, 40.0 if mode == "skilled" else 0.0, 100.0, "%s bot's health left" % mode)
		return done()
	if p.is_dead or p.stats.is_dead:
		print("%s: PLAYER DIED at %.1fs, bandits left: %s" % [mode, f / 60.0, alive.map(func(b): return "%s %.0fhp" % [b.display_name, b.stats.health])])
		if mode == "naive":
			ok(true, "naive bot (never defends) dies or wins only barely")
			between(f / 60.0, 5.0, 90.0, "naive bot lasts a while before dying")
		else:
			ok(false, "the %s bot survives" % mode, "died")
		return done()
	if f > 60 * 90:
		ok(false, "%s fight ends within 90 s" % mode, alive.map(func(b): return "%s %.0fhp %s" % [b.display_name, b.stats.health, b.State.keys()[b.state]]))
		return done()
	# face the nearest
	alive.sort_custom(func(a, b): return a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position))
	var t = alive[0]
	# The hunter goes for the caster, unless the others have it pinned: then it hits
	# whoever's in the way for a couple of seconds.
	if f % 60 == 0:
		if last_spot.is_finite() and p.global_position.distance_to(last_spot) < 0.3 and t.global_position.distance_to(p.global_position) < 2.4:
			stuck_left = 120
		last_spot = p.global_position
	stuck_left -= 1
	if mode == "hunter" and stuck_left <= 0 and alive.any(func(b): return b.is_hunting()):
		for b in alive:
			if b.caster: t = b
	var d: Vector3 = t.global_position - p.global_position
	p.rotation.y = atan2(-d.x, -d.z); p.head.rotation.x = -0.1
	# walk in if far
	if Vector2(d.x, d.z).length() > 2.0: Input.action_press("move_forward")
	else: Input.action_release("move_forward")
	var threat := false
	if mode != "naive":
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
		if mode != "naive" and (t.state == t.State.GUARD or t.state == t.State.STAGGER) and holding_heavy == 0:
			c.attack_pressed(); holding_heavy = 40
		elif holding_heavy == 0:
			c.attack_pressed(); c.attack_released()
	if holding_heavy > 0:
		holding_heavy -= 1
		if holding_heavy == 0: c.attack_released()
	return false
