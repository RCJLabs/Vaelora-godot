extends "res://tests/test_base.gd"
# Enemies fight companions (systems/targeting.gd, companions/companion.gd): a
# wolf goes for Brannoc when he's the nearer, and sticks with him unless you're
# clearly closer; told to wait, he still hits back; at 0 health he's down (the
# wolf leaves him for you), you can help him up, or he gets up on his own; and
# out of a fight he heals. A bandit fights him too.
var f := 0
var step := 0
var wait := 0
var p
var GS
var T
var c
var w
var base := Vector3.ZERO

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func place(node, at: Vector3) -> void:
	node.global_position = at
	node.velocity = Vector3.ZERO

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	GS = autoload("GameState"); T = autoload("Targeting")
	match step:
		0:
			n("GreyfangPack").can_break = false
			w = n("GreyfangPack/Wolf1")
			base = w.global_position
			for i in [2, 3]:
				var other = n("GreyfangPack/Wolf%d" % i)
				other.set_physics_process(false)
				place(other, base + Vector3(60 + i * 10, 0, 0))
			w.set_physics_process(false)
			GS.set_flag("companion_brannoc")
			wait = 20
		1:
			c = autoload("Companions").body()
			ok(c != null and c.max_health == 150.0 and c.health == 150.0, "Brannoc has 150 health")
			ok(not c._label.visible, "no health label while unhurt")
			# Told to wait between you and the wolf: it goes for him.
			c.order(c.State.WAIT)
			place(c, base + Vector3(0, 0.05, 4))
			place(p, base + Vector3(0, 0.05, 14))
			w.home = base
			w.set_physics_process(true)
			w.join_hunt()
			wait = 2
		2:
			ok(T.foe_for(w, p) == c, "the wolf goes for the nearer: Brannoc")
			w.set_meta("h", w.stats.health)
			wait = 240
		3:
			ok(c.health < c.max_health, "it bites him", c.health)
			ok(p.stats.health == p.stats.max_health, "not you", p.stats.health)
			ok(w.stats.health < w.get_meta("h"), "waiting, he still hits back", [w.get_meta("h"), w.stats.health])
			ok(c._label.visible and c._label.text.begins_with("Brannoc  "), "his health shows once he's hurt", c._label.text)
			ok(c.state == c.State.WAIT and c.global_position.distance_to(base + Vector3(0, 0, 4)) < 1.5, "and he keeps his place", c.global_position)
			# Sticking with him: you 1 m closer isn't enough to turn it, 4 m is.
			w.set_physics_process(false)
			c.set_physics_process(false)
			place(w, base)
			place(c, base + Vector3(0, 0, 5))
			w.set_meta("foe", c)
			place(p, base + Vector3(0, 0, -4))
			wait = 1
		4:
			ok(T.foe_for(w, p) == c, "it sticks with him when you're only a little closer")
			place(p, base + Vector3(0, 0, -1.5))
			wait = 1
		5:
			ok(T.foe_for(w, p) == p, "and turns to you when you're much closer")
			place(p, base + Vector3(0, 0.05, 14))
			c.set_physics_process(true)
			# Down.
			c.receive_attack(1000.0, w)
			ok(c.is_down and c.health == 0.0, "at 0 health he's down")
			ok(c.prompt == "Help Brannoc up", "prompt", c.prompt)
			ok(T.foe_for(w, p) == p, "and the wolf leaves him for you")
			ok(p.hud.notices.get_children().any(func(l): return l.text.begins_with("Brannoc is down!")), "a notice says so")
			ok(c._find_target(p) == null or c.is_down, "he's out of the fight")
			wait = 30
		6:
			ok(c.is_down, "still down a moment later")
			c.interact(p)
			ok(not c.is_down and c.health == 75.0, "helped up, with half his health", c.health)
			ok(c.state == c.State.WAIT, "and still waiting, as told", c.State.keys()[c.state])
			# Getting up on his own.
			c.receive_attack(1000.0, w)
			c._down_left = 0.05
			wait = 5
		7:
			ok(not c.is_down and c.health == 45.0, "gets up on his own, with less", c.health)
			c._since_hit = 100.0
			wait = 60
		8:
			between(c.health - 45.0, 2.0, 4.0, "out of a fight, he heals (3 a second)")
			# A bandit fights him the same way (its own attack code).
			w.set_physics_process(false)
			var b = n("BanditCamp/Bandit1")
			for other in n("BanditCamp").get_children():
				if other != b and other.has_method("join_hunt"):
					other.set_physics_process(false)
			c.health = c.max_health
			place(c, b.global_position + Vector3(0, 0.05, 3))
			place(p, b.global_position + Vector3(0, 0.05, 16))
			b.join_hunt()
			wait = 360
		9:
			var b = n("BanditCamp/Bandit1")
			ok(T.foe_for(b, p) == c, "a bandit goes for him too")
			ok(c.health < c.max_health, "and its swings land on him", c.health)
			ok(p.stats.health == p.stats.max_health, "not on you", p.stats.health)
			GS.clear_flag("companion_brannoc")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
