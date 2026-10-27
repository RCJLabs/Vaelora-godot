extends "res://tests/test_base.gd"
# Enemy awareness (systems/stealth.gd, enemies/bandit.gd): bandits hunt by sight and
# sound. Standing up, one notices you in front of it, or right beside it, but not
# behind it; it hears footsteps (walking near, sprinting further, crouched not at all)
# and fights, comes to look, searches, and gives up and goes home. Searching, it
# notices you further off, and a sneak attack still lands. Chasing, it goes to where
# it last saw you once you're out of sight. Starting a fight it shouts, and anyone near
# comes to look; a dead friend in view sets it searching. Wolves still go by scent.
# The HUD says SEARCHING. docs/godot-starter/SNEAK.md, "Hearing and searching".
var f := 0
var steps := []
var p; var level; var b1; var b2; var lead; var ST; var wolf
var wall: StaticBody3D
const HOME := Vector3(-40, 0, -40)

func add(k: int, cb: Callable) -> void: steps.append([k, cb])

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	level = load("res://levels/test_level.tscn").instantiate(); root.add_child(level); current_scene = level

func bst(b) -> String: return b.State.keys()[b.state]

## Back to standing watch at `at`, facing north (-z), knowing nothing.
func reset(b, at := HOME) -> void:
	b.state = b.State.IDLE
	b.global_position = at
	b.home = at
	b.rotation.y = 0.0
	b.velocity = Vector3.ZERO
	b._bodies_seen.clear()
	ST._awareness.clear()

## The player stands still `offset` from bandit 1's post.
func stand(offset: Vector3) -> void:
	p.global_position = HOME + offset
	p.velocity = Vector3.ZERO

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		p = level.get_node("Player"); ST = autoload("Stealth")
		for i in [1, 2, 3]:
			var w = level.get_node("GreyfangPack/Wolf%d" % i); w.set_physics_process(false); w.global_position = Vector3(60, 0, 60 + i * 3)
		b1 = level.get_node("BanditCamp/Bandit1"); b2 = level.get_node("BanditCamp/Bandit2"); lead = level.get_node("BanditCamp/Leader")
		for b in [b2, lead]:
			b.set_physics_process(false); b.global_position = Vector3(-70, 0, -70 + randf())
		p.stats.max_health = 900; p.stats.health = 900
		reset(b1)
		ok(b1.hunts_by_sight, "bandits hunt by sight")
		stand(Vector3(0, 0, 6))   # behind it (it faces north, -z)
		add(20, func(): ok(bst(b1) == "IDLE", "standing 6 m behind it: not noticed", bst(b1)))
		add(1, func(): stand(Vector3(0, 0, -6)))
		add(10, func():
			ok(bst(b1) != "IDLE", "6 m in front of it: noticed at once", bst(b1))
			reset(b1); stand(Vector3(0, 0, 1.5)))
		add(10, func():
			ok(bst(b1) != "IDLE", "right behind it (1.5 m): noticed anyway", bst(b1))
			reset(b1); stand(Vector3(0, 0, 2.8)))
		# Footsteps.
		add(5, func():
			ok(bst(b1) == "IDLE", "2.8 m behind, still: not noticed", bst(b1))
			ST.step(p.global_position, "walk"))
		add(1, func():
			ok(bst(b1) == "INVESTIGATE" and b1._goal.distance_to(p.global_position) < 0.1, "a footstep behind it: it comes to look", bst(b1))
			ok(b1.is_alert() and b1.is_unaware(), "looking, not yet found (a sneak attack would land)"))
		add(90, func():
			ok(bst(b1) in ["CHASE", "ENGAGE", "ATTACK", "GUARD"], "and turning round, it sees you", bst(b1))
			reset(b1); stand(Vector3(0, 0, 6)))
		add(2, func():
			ST.step(p.global_position, "walk")
			ok(bst(b1) == "IDLE", "a walking step 6 m behind: not heard", bst(b1))
			ST.step(p.global_position, "run")
			ok(bst(b1) == "INVESTIGATE", "a sprinting step: heard", bst(b1))
			reset(b1); stand(Vector3(0, 0, 2.8))
			p.is_sneaking = true
			ST.step(p.global_position, "walk")
			ok(bst(b1) == "IDLE", "crouched, light armour: silent", bst(b1))
			p.is_sneaking = false)
		# Searching, then giving up.
		add(1, func():
			reset(b1); stand(Vector3(0, 0, 25))   # out of its reach (16.8 m searching), inside the HUD's 40 m
			b1.hear(HOME + Vector3(3, 0, 0)))
		add(120, func():
			ok(bst(b1) == "SEARCH", "at the spot: searching round", bst(b1))
			ok(b1.global_position.distance_to(HOME + Vector3(3, 0, 0)) < 6.0, "near where the noise was")
			ok(ST.status()["searching"], "Stealth knows something's searching")
			p.is_sneaking = true)
		add(3, func():
			ok(p.hud.sneak_label.text.contains("SEARCHING"), "the HUD says SEARCHING", p.hud.sneak_label.text)
			p.is_sneaking = false
			b1._search_left = 0.1)
		add(240, func():
			ok(bst(b1) == "IDLE" and b1.global_position.distance_to(HOME) < 1.5, "nothing found: back to its post", [bst(b1), b1.global_position])
			reset(b1); stand(Vector3(0, 0, -15)))
		add(5, func():
			ok(bst(b1) == "IDLE", "15 m in front, at rest: too far (12 m)", bst(b1))
			b1._investigate(b1.global_position); b1.state = b1.State.SEARCH; b1._search_left = 5.0; b1._look_left = 5.0)
		add(3, func(): ok(bst(b1) != "SEARCH" and bst(b1) != "IDLE", "searching: noticed at 15 m (x%.1f range)" % ST.ALERT_MULT, bst(b1)))
		# Out of sight while chasing: it goes to where it last saw you.
		add(1, func():
			reset(b1); stand(Vector3(0, 0, -7))
			b1._start_fight())
		add(10, func():
			wall = StaticBody3D.new()
			var shape := CollisionShape3D.new(); var box := BoxShape3D.new(); box.size = Vector3(2, 8, 40)
			shape.shape = box; wall.add_child(shape); level.add_child(wall)
			wall.global_position = HOME + Vector3(6, 4, 0))
		add(2, func():   # (the wall is in the physics world now)
			set_meta("seen_at", p.global_position)
			p.global_position = HOME + Vector3(14, 0, -7))
		add(30, func(): ok(bst(b1) in ["CHASE", "ENGAGE"], "just out of sight: still after you", bst(b1)))
		add(200, func():
			ok(bst(b1) in ["INVESTIGATE", "SEARCH"], "out of sight %.1f s: it goes to look" % b1.LOSE_SIGHT, bst(b1))
			ok(b1._goal.distance_to(get_meta("seen_at")) < 1.0, "where it last saw you, not where you are",
					[b1._goal, get_meta("seen_at"), p.global_position])
			wall.queue_free())
		# A noise standing up carries further.
		add(1, func():
			reset(b1); stand(Vector3(0, 0, 8.5))
			ST.make_noise(p.global_position, "melee"))
		add(1, func():
			ok(bst(b1) == "INVESTIGATE", "a swing 8.5 m behind it, standing: heard (%d m)" % int(ST.NOISE["melee"] * ST.LOUD_MULT), bst(b1)))
		# A shout: someone not in its band comes to look.
		add(1, func():
			reset(b1); stand(Vector3(0, 0, 40))
			b2.reparent(level); b2.set_physics_process(true); reset(b2, HOME + Vector3(12, 0, 0)))
		add(3, func():   # (it's on watch now)
			b1._start_fight()
			ok(bst(b2) == "INVESTIGATE" and b2._goal.distance_to(b1.global_position) < 0.5, "bandit 1 shouts: bandit 2, 12 m off and not in its band, comes to look", [bst(b2), b2._goal]))
		# A dead friend.
		add(1, func():
			b2.set_physics_process(false); b2.global_position = Vector3(-75, 0, -75)
			reset(b1); stand(Vector3(0, 0, 40))
			lead.set_physics_process(true); reset(lead, HOME + Vector3(0, 0, 9))
			b1.set_physics_process(false)
			b1.stats.take_damage(9999.0))
		add(45, func():
			ok(bst(b1) == "DEAD", "bandit 1 is dead")
			ok(bst(lead) == "INVESTIGATE" and lead._goal.distance_to(b1.global_position) < 0.5, "the leader sees the body and comes to look", bst(lead)))
		# Wolves go by scent.
		add(1, func():
			lead.set_physics_process(false)
			wolf = level.get_node("GreyfangPack/Wolf1"); wolf.set_physics_process(true)
			wolf.state = wolf.State.IDLE; wolf.global_position = Vector3(20, 0, 20); wolf.home = wolf.global_position; wolf.rotation.y = 0.0
			p.global_position = Vector3(20, 0.2, 27))
		add(10, func():
			ok(wolf.state != wolf.State.IDLE, "a wolf smells you behind it, as before")
			ok(not wolf.has_method("hear"), "and doesn't come looking for noises (yet)"))
		add(1, func(): autoload("SaveSystem").delete_save())
	if steps.is_empty():
		return f > 3 and done()
	steps[0][0] -= 1
	if steps[0][0] <= 0:
		var s = steps.pop_front()
		s[1].call()
	return false
