extends "res://tests/test_base.gd"
# Sneak (systems/stealth.gd): crouching (C) slows you and lowers the camera;
# sprinting or jumping stands you up. Standing, a wolf notices you at once
# inside its range, as always. Crouched, its range shrinks (Sneak skill, the dark,
# standing still, perks), it has to see you (a wall hides you), and noticing takes
# time. Sneaking near it trains Sneak. Noise (a swing, a spell) is heard through
# walls. Sneak attacks: arrows x2, melee x3, more with perks (a dagger x15 with
# Backstab and Assassin's Blade). Master of Shadows loses a hunter. The HUD says
# HIDDEN / NOTICED / SEEN. Companions don't sneak.
var f := 0
var step := 0
var wait := 0
var t := 0
var p
var w
var S
var C
var ST
var wall: StaticBody3D

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

## Puts the player `metres` south of the wolf, facing it.
func place(metres: float) -> void:
	p.global_position = w.global_position + Vector3(0, 0.2, metres)
	p.velocity = Vector3.ZERO
	p.rotation.y = 0.0

func reset_wolf() -> void:
	w.state = w.State.IDLE
	w.global_position = w.home
	w.velocity = Vector3.ZERO
	w.stats.refill()
	ST._awareness.clear()

func _physics_process(delta: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	S = autoload("Skills"); C = autoload("Character"); ST = autoload("Stealth")
	match step:
		0:
			for i in [2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			w = n("GreyfangPack/Wolf1")
			w.wander_speed = 0.0
			autoload("WorldClock").hour = 12.0
			ok(autoload("KeyBindings").ACTIONS.any(func(a): return a[0] == "crouch"), "Sneak (crouch) can be rebound")
			ok(S.SKILLS.has("sneak") and S.SKILLS["sneak"]["attribute"] == "agility" and S.levels["sneak"] == 15, "a Sneak skill (Agility), from 15")
			reset_wolf()
			place(10.0)
			var press := InputEventAction.new(); press.action = "crouch"; press.pressed = true
			p._unhandled_input(press)
			ok(p.is_sneaking, "C crouches")
			set_meta("xp", S.xp["sneak"])
			wait = 120
		1:
			# Crouched at 10 m in daylight, still: 14 x 0.65 x 0.7 = 6.4 m. Unseen.
			near(ST.range_mult(), 0.65 * 0.7, 0.01, "range: 65%, x0.7 standing still")
			ok(w.state == w.State.IDLE and ST.awareness(w) == 0.0, "crouched at 10 m: the wolf doesn't notice", [w.state, ST.awareness(w)])
			ok(S.xp["sneak"] > get_meta("xp"), "sneaking inside its usual range trains Sneak", S.xp["sneak"] - get_meta("xp"))
			ok(p.head.position.y < 1.2, "the camera is lower", p.head.position.y)
			place(4.0)
			t = 0
			step = 2; return false
		2:
			# Inside range: it takes a moment.
			t += 1
			if t == 10:
				ok(w.state == w.State.IDLE and ST.awareness(w) > 0.0 and ST.awareness(w) < 1.0, "at 4 m: noticing, not yet", ST.awareness(w))
				ok(p.hud.sneak_label.visible and p.hud.sneak_label.text.contains("hidden?"), "the HUD shows it", p.hud.sneak_label.text)
			if w.state != w.State.IDLE:
				ok(t > 20 and t < 180, "then it notices (%.1f s)" % (t / 60.0), t)
				wait = 3
				step = 3
			elif t > 240:
				ok(false, "it never noticed at 4 m")
				step = 3
			return false
		3:
			ok(p.hud.sneak_label.text.contains("SEEN"), "SEEN once it's after you", p.hud.sneak_label.text)
			# Standing, at 10 m: at once (as before Sneak existed).
			reset_wolf()
			var press := InputEventAction.new(); press.action = "crouch"; press.pressed = true
			p._unhandled_input(press)
			ok(not p.is_sneaking, "C again stands up")
			place(10.0)
			wait = 2
		4:
			ok(w.state != w.State.IDLE, "standing at 10 m: it notices at once")
			ok(not p.hud.sneak_label.visible, "no sneak marker standing")
			# A wall between you: crouched at 4 m, it can't see you.
			reset_wolf()
			p.set_sneaking(true)
			wall = StaticBody3D.new()
			var shape := CollisionShape3D.new(); shape.shape = BoxShape3D.new(); shape.shape.size = Vector3(6, 4, 0.4)
			wall.add_child(shape)
			current_scene.add_child(wall)
			wall.global_position = w.global_position + Vector3(0, 1, 2)
			place(4.0)
			wait = 90
		5:
			ok(w.state == w.State.IDLE and ST.awareness(w) == 0.0, "behind a wall at 4 m: unseen", [w.state, ST.awareness(w)])
			# But it hears a swing at 4 m (heard to 6 m)...
			ST.make_noise(p.global_position, "melee")
			ok(ST.awareness(w) >= 0.5, "a swing is heard through the wall", ST.awareness(w))
			ST._awareness.clear()
			# ...not with Quiet Blade (heard to 2.4 m).
			C.perks.append("quiet_blade")
			ST.make_noise(p.global_position, "melee")
			ok(ST.awareness(w) == 0.0, "Quiet Blade: not at 4 m", ST.awareness(w))
			# Master of Shadows: a hunting wolf behind a wall loses you after 4 s.
			ok(not ST.lost_track(w, 5.0), "no trail lost without Master of Shadows")
			C.perks.append("master_of_shadows")
			ok(not ST.lost_track(w, 2.0) and ST.lost_track(w, 2.1), "Master of Shadows: lost after 4 s unseen")
			wall.queue_free()
			# Sneak attacks.
			reset_wolf()
			place(6.0)
			var health: float = w.stats.health
			var arrow = load("res://combat/arrow.tscn").instantiate()
			arrow.shooter = p
			arrow.damage = 5.0
			arrow.poise_damage = 0.0
			arrow.sneaking = true
			current_scene.add_child(arrow)
			arrow.launch(p.global_position + Vector3(0, 0.6, -0.8), (w.global_position + Vector3.UP * 0.5) - (p.global_position + Vector3(0, 0.6, -0.8)), 40.0)
			set_meta("health", health)
			set_meta("sxp", S.xp["sneak"] + S.levels["sneak"] * 1000)
			wait = 20
		6:
			near(get_meta("health") - w.stats.health, 10.0, 0.01, "an arrow sneak attack: x2")
			ok(w.state != w.State.IDLE, "and now it knows")
			ok(S.xp["sneak"] + S.levels["sneak"] * 1000 > get_meta("sxp"), "sneak attacks train Sneak")
			reset_wolf()
			var dagger: ItemData = load("res://items/hunting_dagger.tres")
			ok(dagger.dagger, "the hunting dagger is a dagger")
			near(ST.sneak_attack_mult(w, "melee", dagger), 3.0, 0.001, "melee: x3")
			C.perks.append("backstab")
			near(ST.sneak_attack_mult(w, "melee", load("res://items/iron_sword.tres")), 6.0, 0.001, "Backstab: x6")
			C.perks.append("assassins_blade")
			near(ST.sneak_attack_mult(w, "melee", dagger), 15.0, 0.001, "Assassin's Blade: a dagger x15")
			p.set_sneaking(false)
			near(ST.sneak_attack_mult(w, "melee", dagger), 1.0, 0.001, "standing: no sneak attack")
			p.set_sneaking(true)
			w.state = w.State.CHASE
			near(ST.sneak_attack_mult(w, "melee", dagger), 1.0, 0.001, "on a wolf that's after you: none")
			reset_wolf()
			# Perks and the dark.
			var base: float = ST.range_mult()
			C.perks.append("stealthy_1")
			near(ST.range_mult(), base * 0.9, 0.001, "Stealthy: 10% less")
			autoload("WorldClock").hour = 0.0
			near(ST.range_mult(), base * 0.9 * 0.75, 0.001, "at midnight: x0.75")
			autoload("WorldClock").hour = 12.0
			S.levels["sneak"] = 100
			near(ST.range_mult(), 0.65 * 0.575 * 0.7 * 0.9, 0.001, "Sneak 100: 57.5% of the base")
			# Companions don't sneak.
			ok(ST.notices(w, n("GreyfangPack/Wolf2"), 14.0, 10.0, delta), "a wolf after a companion: its usual range")
			var perks: Array = C.perk_list.keys().filter(func(k): return C.perk_list[k]["skill"] == "sneak")
			ok(perks.size() >= 20, "20+ Sneak perks", perks.size())
			ok(perks.all(func(k): return not C.perk_list[k].has("requires") or C.perk_list[C.perk_list[k]["requires"]]["skill"] == "sneak"), "each requires a Sneak perk")
			# Moving crouched: 55% speed. Sprinting stands you up.
			C.perks.clear()
			place(20.0)
			Input.action_press("move_forward")
			wait = 40
		7:
			var speed := Vector2(p.velocity.x, p.velocity.z).length()
			near(speed, p.walk_speed * p.SNEAK_SPEED, 0.2, "crouched: 55% of walking speed")
			Input.action_press("sprint")
			wait = 3
		8:
			ok(not p.is_sneaking, "sprinting stands you up")
			Input.action_release("sprint"); Input.action_release("move_forward")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
