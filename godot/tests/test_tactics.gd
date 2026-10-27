extends "res://tests/test_base.gd"
# Enemy tactics (enemies/bandit.gd, enemies/wolf_pack.gd): a band fighting you hand to
# hand spreads round you instead of queueing in front, and the one behind you is the
# keener to swing. Archers keep their distance and shoot (a glinting draw, then an
# arrow that hurts), back off if you close in, and fight hand to hand when cornered.
# A band's morale: it breaks when its leader falls, or once it has lost half its number.
# Broken, the living run and are gone, and the camp is cleared and driven off; the
# leader never runs.
var f := 0
var steps := []
var p; var level; var b1; var b2; var lead; var archer; var camp
const SPOT := Vector3(-40, 0, -40)

func add(k: int, cb: Callable) -> void: steps.append([k, cb])

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	level = load("res://levels/test_level.tscn").instantiate(); root.add_child(level); current_scene = level

func bst(b) -> String: return b.State.keys()[b.state]

func flat_angle(a: Vector3, b: Vector3) -> float:
	return rad_to_deg(Vector2(a.x, a.z).angle_to(Vector2(b.x, b.z)))

func park(b, at: Vector3) -> void:
	b.set_physics_process(false); b.global_position = at; b.home = at

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		p = level.get_node("Player")
		for i in [1, 2, 3]:
			var w = level.get_node("GreyfangPack/Wolf%d" % i); w.set_physics_process(false); w.global_position = Vector3(60, 0, 60 + i * 3)
		for m in level.get_node("MercyCell/Merciful").get_children(): m.position.z += 60.0
		camp = level.get_node("BanditCamp")
		b1 = camp.get_node("Bandit1"); b2 = camp.get_node("Bandit2"); lead = camp.get_node("Leader")
		p.stats.max_health = 5000; p.stats.health = 5000
		p.global_position = SPOT; p.rotation.y = 0.0
		ok(lead.leader and camp.break_on_leader and camp.break_at_losses == 0.5 and camp.driven_off_flag == "bandits_driven_off", "the Vale camp: a leader, and a band that can break")
		# A ring: two bandits, side by side in front of you.
		park(lead, Vector3(-80, 0, -80))
		for b in [b1, b2]: b.set_physics_process(true)
		b1.global_position = SPOT + Vector3(-1, 0, -3); b2.global_position = SPOT + Vector3(1, 0, -3)
		b1.rotation.y = 0; b2.rotation.y = 0
		b1._start_fight(); b2._start_fight()
		# Averaged over 2.5 s: whoever swings steps in, and pulls the angle down for a moment.
		add(150, func(): set_meta("ring", []))
		add(150, func():
			var r: Array = get_meta("ring")
			var a: float = r.reduce(func(acc, x): return acc + x, 0.0) / maxf(r.size(), 1)
			remove_meta("ring")
			ok(a > 90.0, "they spread round you (side by side is about 40) (%.0f degrees apart on average)" % a, [r.min(), r.max()])
			p.rotation.y = 0.0
			b1.global_position = SPOT + Vector3(0, 0, 2); b2.global_position = SPOT + Vector3(0, 0, -2)
			ok(b1._behind(p) and not b2._behind(p), "it knows which of them is behind you"))
		# An archer.
		add(1, func():
			park(b1, Vector3(-80, 0, -76)); park(b2, Vector3(-80, 0, -72))
			for b in [b1, b2]: b.state = b.State.IDLE
			archer = load("res://enemies/bandit.tscn").instantiate()
			archer.name = "TestArcher"
			archer.archer = true
			archer.weapon_scene = load("res://items/models/hunting_bow_fp.tscn")
			var band := Node3D.new(); band.name = "ArcherBand"; level.add_child(band)
			band.add_child(archer)
			archer.global_position = SPOT + Vector3(0, 0, -11); archer.home = archer.global_position
			archer.rotation.y = PI   # facing you (+z)
			p.global_position = SPOT; p.rotation.y = PI
			set_meta("hp", p.stats.health))
		add(150, func():
			ok(archer.is_hunting() and archer.global_position.distance_to(p.global_position) > 7.0, "it sees you, and keeps its distance", [bst(archer), archer.global_position.distance_to(p.global_position)]))
		add(1, func(): set_meta("drew", false); set_meta("shots", 0))
		add(240, func():
			ok(get_meta("drew"), "it draws (the arrowhead glints)")
			ok(p.stats.health < get_meta("hp"), "and its arrows hurt", get_meta("hp") - p.stats.health)
			p.global_position = archer.global_position + Vector3(0, 0, 4.0)
			set_meta("near", archer.global_position.distance_to(p.global_position)))
		add(60, func():
			ok(archer.global_position.distance_to(p.global_position) > get_meta("near") + 0.5, "close in and it backs off",
					[get_meta("near"), archer.global_position.distance_to(p.global_position)])
			p.global_position = archer.global_position + Vector3(0, 0, 1.8))
		add(5, func(): ok(bst(archer) != "SHOOT", "cornered, it doesn't stand there drawing", bst(archer)))
		# Morale: the Vale camp (two and a leader).
		add(1, func():
			archer.get_parent().queue_free()
			p.global_position = SPOT
			for b in [b1, b2, lead]:
				b.set_physics_process(true); b.global_position = SPOT + Vector3(randf_range(-3, 3), 0, -3); b._start_fight()
			b1.stats.take_damage(9999.0))
		add(2, func():
			ok(not camp.broken and bst(b2) != "FLEE", "one of three dies: they fight on", bst(b2))
			lead.stats.take_damage(9999.0))
		add(2, func():
			ok(camp.broken, "the leader dies: the band breaks")
			ok(bst(b2) == "FLEE" and b2._routed, "the living run", bst(b2))
			p.global_position = SPOT + Vector3(0, 0, 60))
		add(30, func():
			ok(not is_instance_valid(b2), "and they're gone")
			ok(autoload("GameState").has_flag("bandits_cleared") and autoload("GameState").has_flag("bandits_driven_off"), "the camp's cleared, and driven off"))
		# Losses: a band of four loses two; the third runs, the leader stands.
		add(1, func():
			var band := Node3D.new(); band.name = "TestBand"
			band.set_script(load("res://enemies/wolf_pack.gd"))
			band.cleared_flag = "test_band_cleared"; band.driven_off_flag = "test_band_off"
			band.break_on_leader = true; band.break_at_losses = 0.5; band.yelp_on_break = false
			for i in 4:
				var b = load("res://enemies/bandit.tscn").instantiate()
				b.name = "Leader" if i == 0 else "Member%d" % i
				b.leader = i == 0
				band.add_child(b)
			level.add_child(band)
			p.global_position = SPOT
			for b in band.get_children():
				b.global_position = SPOT + Vector3(randf_range(-3, 3), 0, -3); b.home = b.global_position; b._start_fight()
			set_meta("band", band)
			band.get_node("Member1").stats.take_damage(9999.0))
		add(2, func():
			var band = get_meta("band")
			ok(not band.broken, "a quarter down: they fight on")
			band.get_node("Member2").stats.take_damage(9999.0))
		add(2, func():
			var band = get_meta("band")
			var l = band.get_node("Leader"); var m = band.get_node("Member3")
			ok(band.broken and bst(m) == "FLEE", "half of them down: the band breaks and the rest run", bst(m))
			ok(bst(l) != "FLEE" and not l._routed and l.is_hunting(), "but not the leader: it fights on", bst(l)))
		add(1, func(): autoload("SaveSystem").delete_save())
	if has_meta("ring"):
		get_meta("ring").append(absf(flat_angle(b1.global_position - p.global_position, b2.global_position - p.global_position)))
	if f > 3 and steps.size() > 0 and steps[0][1] != null and archer != null and is_instance_valid(archer) and archer.state == archer.State.SHOOT and archer._glint and archer._glint.emission_energy_multiplier > 1.0:
		set_meta("drew", true)
	if steps.is_empty():
		return f > 3 and done()
	steps[0][0] -= 1
	if steps[0][0] <= 0:
		var s = steps.pop_front()
		s[1].call()
	return false
