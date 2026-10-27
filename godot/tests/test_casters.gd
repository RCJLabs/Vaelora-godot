extends "res://tests/test_base.gd"
# Mercy casters (enemies/cultist.gd, caster): they keep their distance and cast. A bolt
# (the hands glow violet first) that hurts; a Draw, a beam that takes your Health and
# gives half to the caster, and stops when you get out of reach; a Mend over a badly
# hurt friend. A hit breaks a cast. Cornered, a caster fights hand to hand. And each
# Mercy group in the builders has one.
var f := 0
var steps := []
var p; var level; var band; var drawer; var friend
const SPOT := Vector3(-40, 0, -40)

func add(k: int, cb: Callable) -> void: steps.append([k, cb])

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	level = load("res://levels/test_level.tscn").instantiate(); root.add_child(level); current_scene = level

func bst(b) -> String: return b.State.keys()[b.state]

func flat(a: Vector3, b: Vector3) -> float: return Vector2(a.x - b.x, a.z - b.z).length()

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		p = level.get_node("Player")
		for i in [1, 2, 3]:
			var w = level.get_node("GreyfangPack/Wolf%d" % i); w.set_physics_process(false); w.global_position = Vector3(60, 0, 60 + i * 3)
		for m in level.get_node("MercyCell/Merciful").get_children(): m.position.z += 60.0
		for b in level.get_node("BanditCamp").get_children():
			if b.has_method("take_hit"): b.set_physics_process(false); b.global_position += Vector3(-60, 0, -60)
		p.stats.max_health = 5000; p.stats.health = 5000
		p.global_position = SPOT; p.rotation.y = 0.0
		band = Node3D.new(); band.name = "TestMercy"
		band.set_script(load("res://enemies/wolf_pack.gd"))
		band.cleared_flag = "test_mercy_cleared"; band.driven_off_flag = "test_mercy_off"
		for i in 2:
			var c = load("res://enemies/bandit.tscn").instantiate()
			c.set_script(load("res://enemies/cultist.gd"))
			c.name = "Drawer" if i == 0 else "Friend"
			c.caster = i == 0
			band.add_child(c)
		level.add_child(band)
		drawer = band.get_node("Drawer"); friend = band.get_node("Friend")
		friend.set_physics_process(false); friend.global_position = SPOT + Vector3(-4, 0, -8)
		drawer.global_position = SPOT + Vector3(0, 0, -14); drawer.home = drawer.global_position
		ok(drawer.ranged() and not friend.ranged(), "a caster fights from a distance, out of the ring")
		drawer._start_fight()
		add(180, func():
			ok(drawer.is_hunting() and flat(drawer.global_position, p.global_position) > 5.0, "it keeps its distance",
					[bst(drawer), flat(drawer.global_position, p.global_position)])
			ok(get_meta("cast_seen", false), "and casts at you on its own")
			# A bolt, from a standstill.
			drawer._cast_cooldown = 99.0
			set_meta("hp", p.stats.health)
			set_meta("glow", 0.0)
			drawer._begin_cast("bolt", p))
		add(90, func():
			ok(get_meta("glow") > 1.0, "the hands glow before a cast", get_meta("glow"))
			ok(p.stats.health < get_meta("hp"), "and the bolt hurts", get_meta("hp") - p.stats.health)
			# A Draw, close enough.
			p.global_position = drawer.global_position + Vector3(0, 0, 6)
			drawer.stats.take_damage(20.0)
			set_meta("hp", p.stats.health); set_meta("its", drawer.stats.health)
			drawer._begin_cast("draw", p))
		add(70, func():
			ok(drawer._beam.visible, "a Draw is a beam from its hand to you")
			ok(p.stats.health < get_meta("hp") - 5.0, "it takes your Health", get_meta("hp") - p.stats.health)
			ok(drawer.stats.health > get_meta("its"), "and the caster gets some of it", drawer.stats.health - get_meta("its"))
			p.global_position = drawer.global_position + Vector3(0, 0, 14)
			set_meta("hp", p.stats.health))
		add(40, func():
			ok(not drawer._beam.visible and p.stats.health >= get_meta("hp") - 0.01, "out of reach, the Draw stops", [bst(drawer), get_meta("hp") - p.stats.health])
			# A hit breaks a cast.
			p.global_position = drawer.global_position + Vector3(0, 0, 7.5)
			drawer.state = drawer.State.ENGAGE
			drawer._begin_cast("bolt", p)
			set_meta("hp", p.stats.health))
		add(20, func():
			drawer.take_hit(1.0, p.global_position, 0.0, 0.0)
			ok(bst(drawer) == "STAGGER", "a hit breaks the cast: it reels", bst(drawer)))
		add(80, func():
			ok(p.stats.health >= get_meta("hp") - 0.01, "and the bolt never comes", get_meta("hp") - p.stats.health)
			# A Mend over a badly hurt friend.
			drawer._cast_cooldown = 0.0
			friend.stats.take_damage(friend.stats.max_health * 0.7)
			set_meta("friend", friend.stats.health))
		add(150, func():
			ok(friend.stats.health >= get_meta("friend") + 24.0, "it mends a badly hurt friend", friend.stats.health - get_meta("friend"))
			# Cornered.
			drawer._cast_cooldown = 0.0
			p.global_position = drawer.global_position + Vector3(0, 0, 1.6))
		add(30, func():
			ok(bst(drawer) != "CAST", "cornered, it doesn't stand there casting", bst(drawer)))
		add(1, func():
			# Each Mercy group has a caster.
			for spot in [["res://levels/weirholt.tscn", "Acolytes/Acolyte3"], ["res://levels/grieving_deep_ring.tscn", "Mercy/Acolyte3"],
					["res://levels/ilunhall_undercroft.tscn", "Mercy/Acolyte3"], ["res://levels/ilunhall_undercroft.tscn", "VessaFights/VessaPack/VessaFoe"],
					["res://levels/ithmarren_rootwell.tscn", "Takers/Taker1"]]:
				var scene: Node = load(spot[0]).instantiate()
				var who = scene.get_node_or_null(spot[1])
				ok(who != null and who.caster, "%s: %s casts" % [spot[0].get_file(), spot[1]])
				scene.free()
			autoload("SaveSystem").delete_save())
	if drawer != null and is_instance_valid(drawer) and drawer.state == drawer.State.CAST:
		set_meta("cast_seen", true)
	if drawer != null and is_instance_valid(drawer) and drawer._hand_glow:
		set_meta("glow", maxf(get_meta("glow", 0.0), drawer._hand_glow.emission_energy_multiplier))
	if steps.is_empty():
		return f > 3 and done()
	steps[0][0] -= 1
	if steps[0][0] <= 0:
		var s = steps.pop_front()
		s[1].call()
	return false
