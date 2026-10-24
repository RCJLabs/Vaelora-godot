extends "res://tests/test_base.gd"
# The First, the demo's final boss, fought by a bot (balance check, like
# test_bandit_fight). Starting gear and 100 Health, no potions.
# mode "naive": walk up and swing, never get out of the way.
# mode "skilled": back out of a slam or sweep while it winds up, jump the rings,
#   and hit it while it's recovering, staggered, or just walking.
# The fight isn't exactly repeatable (same seed, different outcomes), so these are
# guards against a big balance change, not exact targets. Tuning sweep at 550 Health
# (24 Oct 2026, ~10 runs each): skilled wins 9 in 10, in about 40 s, on 21-78 Health;
# naive dies in about 15 s with The First at roughly half Health.
var f := 0
var p
var c
var boss
var mode := "naive"
var started := false
var hits_taken := 0
var rings_jumped := 0
var jump_left := 0
var last_ring_jumped: Node = null

func _initialize() -> void:
	mode = arg("naive")
	autoload("SaveSystem").delete_save()
	var args := OS.get_cmdline_user_args()
	seed(int(args[1]) if args.size() > 1 else 7)   # a second argument picks another seed, for tuning
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func rings() -> Array:
	return current_scene.get_children().filter(func(x): return x.get("max_radius") != null)

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if f < 5:
		return false
	if not started:
		started = true
		p = get_first_node_in_group("player"); c = p.combat
		for w in n("GreyfangPack").get_children():
			w.queue_free()
		for b in n("BanditCamp").get_children():
			b.queue_free()
		var clock = autoload("WorldClock")
		clock.advance(clock.hours_until(22.0))
		n("RitualSite").start(p)
		for cu in n("RitualCultists").get_children():
			cu.stats.take_damage(100000.0, true)
		boss = n("TheFirst")
		p.global_position = Vector3(22, 0.05, -46.0)
		p.stats.damaged.connect(func(a): if a >= 1.0: hits_taken += 1)
		f = 5
		return false
	if boss.state == boss.State.DEAD:
		var secs := (f - 5) / 60.0
		print("%s: The First dead at %.1fs, player H=%.0f/%.0f, hits taken=%d, rings jumped=%d" % [mode, secs, p.stats.health, p.stats.max_health, hits_taken, rings_jumped])
		if mode == "skilled":
			ok(true, "skilled bot kills The First")
			between(secs, 25.0, 90.0, "a real fight, not a slog (seconds)")
		else:
			between(p.stats.health, 0.0, 35.0, "naive bot (never defends) wins only barely, if at all")
		return done()
	if p.is_dead or p.stats.is_dead:
		print("%s: PLAYER DIED at %.1fs, The First at %.0f/%.0f, phase %d, hits taken=%d" % [mode, (f - 5) / 60.0, boss.stats.health, boss.stats.max_health, boss.phase, hits_taken])
		if mode == "naive":
			ok(true, "naive bot (never defends) dies, or wins only barely")
			ok(boss.stats.health < boss.stats.max_health * 0.75, "but it gets a fair way first", boss.stats.health)
		else:
			# It's meant to be close: the skilled bot loses about 1 fight in 10, but only just.
			ok(boss.stats.health <= boss.stats.max_health * 0.15, "skilled bot loses only narrowly", boss.stats.health)
		return done()
	if f > 60 * 200:
		ok(false, "%s fight ends within 200 s" % mode, [boss.stats.health, p.stats.health])
		return done()
	_drive()
	return false


func _drive() -> void:
	var d: Vector3 = boss.global_position - p.global_position
	d.y = 0.0
	var dist := d.length()
	p.rotation.y = atan2(-d.x, -d.z)
	p.head.rotation.x = 0.1
	var forward := false
	var back := false
	if jump_left > 0:
		jump_left -= 1
		if jump_left == 0:
			Input.action_release("jump")
	if mode == "skilled":
		# Rings: jump when one is about to pass under you.
		for ring in rings():
			var flat := Vector2(p.global_position.x - ring.global_position.x, p.global_position.z - ring.global_position.z).length()
			var gap: float = flat - ring._radius
			if ring != last_ring_jumped and gap > 0.0 and gap < 0.9 and p.is_on_floor():
				Input.action_press("jump"); jump_left = 6
				last_ring_jumped = ring
				rings_jumped += 1
		var winding: bool = boss.state == boss.State.WINDUP or boss.state == boss.State.STRIKE
		var safe: float = 6.2 if boss._attack == "slam" else 4.4
		if winding and dist < safe:
			back = true
		elif boss.state in [boss.State.RECOVER, boss.State.STAGGER, boss.State.CHASE]:
			forward = dist > 2.0
	else:
		forward = dist > 2.0
	_hold("move_forward", forward)
	_hold("move_back", back)
	if not back and dist < 2.6 and f % 20 == 0:
		c.attack_pressed(); c.attack_released()


func _hold(action: String, on: bool) -> void:
	if on and not Input.is_action_pressed(action):
		Input.action_press(action)
	elif not on and Input.is_action_pressed(action):
		Input.action_release(action)
