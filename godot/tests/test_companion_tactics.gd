extends "res://tests/test_base.gd"
# How companions fight (companions/companion.gd): they pick what's on you over what's
# merely nearer, Zora goes for an archer where Brannoc takes what's in front of him,
# and they stick with a target. Brannoc goes round an enemy fighting you to its far
# side, guards against a blow he sees coming, and falls back behind you when badly hurt.
# Zora jumps back from blows and keeps her distance.
var f := 0
var steps := []
var p; var level; var band; var c; var GS; var CO
var foe; var blocks := 0; var dodges := 0
const SPOT := Vector3(-40, 0, -40)

func add(k: int, cb: Callable) -> void: steps.append([k, cb])

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	level = load("res://levels/test_level.tscn").instantiate(); root.add_child(level); current_scene = level

func flat(a: Vector3, b: Vector3) -> float: return Vector2(a.x - b.x, a.z - b.z).length()

func angle_at(at: Vector3, a: Vector3, b: Vector3) -> float:
	return rad_to_deg(Vector2(a.x - at.x, a.z - at.z).angle_to(Vector2(b.x - at.x, b.z - at.z)))

func spawn(at: Vector3, archer := false) -> Node:
	var b = load("res://enemies/bandit.tscn").instantiate()
	b.archer = archer
	band.add_child(b)
	b.global_position = at; b.home = at
	return b

## A bandit standing still, in the fight, after `who`.
func posed(at: Vector3, who: Node3D, state_name := "ENGAGE", archer := false) -> Node:
	var b = spawn(at, archer)
	b.set_physics_process(false)
	b.state = b.State[state_name]
	b.set_meta("foe", who)
	return b

func clear_band() -> void:
	for b in band.get_children(): b.free()

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		p = level.get_node("Player")
		GS = autoload("GameState"); CO = autoload("Companions")
		for i in [1, 2, 3]:
			var w = level.get_node("GreyfangPack/Wolf%d" % i); w.set_physics_process(false); w.global_position = Vector3(60, 0, 60 + i * 3)
		for m in level.get_node("MercyCell/Merciful").get_children(): m.position.z += 60.0
		for b in level.get_node("BanditCamp").get_children():
			if b.has_method("take_hit"): b.set_physics_process(false); b.global_position += Vector3(-60, 0, -60)
		band = Node3D.new(); band.name = "TestBand"; level.add_child(band)
		p.stats.max_health = 5000; p.stats.health = 5000
		p.global_position = SPOT; p.rotation.y = 0.0
		GS.set_flag("companion_brannoc")
		add(10, func():
			c = CO.body()
			ok(c != null, "Brannoc is with you")
			c.defended.connect(func(r): if r == "blocked": blocks += 1)
			c.global_position = SPOT + Vector3(0, 0, 3)
			# Choosing: one on you beats one merely nearer him.
			var on_you = posed(SPOT + Vector3(0, 0, -2), p)
			var nearer = posed(SPOT + Vector3(5, 0, 4), p)
			ok(c._find_target(p) == on_you, "he goes for the one on you, not the one nearer him",
					[flat(c.global_position, on_you.global_position), flat(c.global_position, nearer.global_position)])
			clear_band()
			# An archer drawing at range vs. a fighter close by: he takes the one in front of him.
			var close = posed(SPOT + Vector3(2, 0, 3), c)
			var shooter = posed(SPOT + Vector3(0, 0, 12), p, "SHOOT", true)
			ok(c._find_target(p) == close, "Brannoc takes the fighter in front of him over a distant archer")
			set_meta("close", close); set_meta("shooter", shooter)
			# Sticking: a slightly nearer one doesn't pull him off.
			c.target = close
			var closer = posed(SPOT + Vector3(1.5, 0, 3), c)
			ok(c._find_target(p) == close, "and he sticks with his target over one a little nearer")
			clear_band())
		# Flanking: a bandit fighting you; he goes round to its far side.
		add(1, func():
			foe = spawn(SPOT + Vector3(0, 0, -2.2))
			foe.stats.max_health = 5000; foe.stats.health = 5000   # it has to last the next steps too
			foe.set_meta("foe", p)
			foe._start_fight()
			c.global_position = SPOT + Vector3(0, 0, 3)
			set_meta("angle", -1.0)
			foe.stats.damaged.connect(func(_a):
				if get_meta("angle") < 0.0: set_meta("angle", absf(angle_at(foe.global_position, p.global_position, c.global_position)))))
		add(360, func():
			ok(get_meta("angle") > 90.0, "he goes round it: his first blow comes from its far side (%.0f degrees from you)" % get_meta("angle"), get_meta("angle"))
			# Guarding: the bandit turns on him (you're far off); he reads its swings.
			p.global_position = SPOT + Vector3(0, 0, 40)
			foe.set_meta("foe", c)
			c.health = c.max_health; c.max_health = 5000; c.base_max_health = 5000; c.health = 5000)
		add(900, func():
			ok(blocks >= 2, "he raises his guard against blows he sees coming", blocks)
			# Falling back: badly hurt, with it on him.
			p.global_position = c.global_position + Vector3(0, 0, 5)
			foe.global_position = c.global_position + Vector3(0, 0, -1.5)
			foe.set_meta("foe", c)
			c.base_max_health = 150.0; c.max_health = 150.0; c.health = 30.0; c._retreat_cooldown = 0.0
			set_meta("seen_retreat", false))
		add(90, func():
			ok(get_meta("seen_retreat"), "badly hurt, he falls back")
			ok(flat(c.global_position, p.global_position) < 4.0 and flat(foe.global_position, p.global_position) > flat(c.global_position, p.global_position) - 0.5,
					"behind you", [flat(c.global_position, p.global_position), flat(foe.global_position, p.global_position)])
			clear_band()
			GS.clear_flag("companion_brannoc"))
		# Zora.
		add(10, func(): GS.set_flag("companion_zora"))
		add(10, func():
			c = CO.body()
			ok(c != null and c.ranged, "Zora is with you")
			c.defended.connect(func(r): if r == "dodged": dodges += 1)
			c.global_position = SPOT + Vector3(0, 0, 3)
			var close = posed(SPOT + Vector3(2, 0, 3), c)
			var shooter = posed(SPOT + Vector3(0, 0, 12), p, "SHOOT", true)
			ok(c._find_target(p) == shooter, "Zora goes for the archer drawing at range over a fighter close by")
			clear_band()
			p.global_position = SPOT + Vector3(0, 0, 40)
			foe = spawn(c.global_position + Vector3(0, 0, -2))
			foe.stats.max_health = 5000; foe.stats.health = 5000
			foe.set_meta("foe", c)
			foe._start_fight()
			c.max_health = 5000; c.base_max_health = 5000; c.health = 5000
			c.order(c.State.WAIT))   # told to wait, so it can get at her
		add(900, func():
			ok(dodges >= 2, "she jumps back from blows she sees coming", dodges)
			c.order(c.State.FOLLOW)
			foe.global_position = c.global_position + Vector3(0, 0, -2)
			set_meta("near", 0); set_meta("frames", 0))
		add(600, func():
			var share: float = float(get_meta("near")) / maxf(get_meta("frames"), 1)
			ok(share < 0.5, "and keeps out of its reach most of the time (in reach %.0f%% of the time)" % (share * 100.0), share)
			clear_band()
			GS.clear_flag("companion_zora")
			autoload("SaveSystem").delete_save())
	if c != null and is_instance_valid(c):
		if c.state == c.State.RETREAT: set_meta("seen_retreat", true)
		if has_meta("frames") and foe != null and is_instance_valid(foe) and c.ranged:
			set_meta("frames", get_meta("frames") + 1)
			if flat(c.global_position, foe.global_position) < foe.reach: set_meta("near", get_meta("near") + 1)
	if steps.is_empty():
		return f > 3 and done()
	steps[0][0] -= 1
	if steps[0][0] <= 0:
		var s = steps.pop_front()
		s[1].call()
	return false
