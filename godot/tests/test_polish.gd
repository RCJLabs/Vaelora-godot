extends "res://tests/test_base.gd"
# Loose ends from the companion, Lanternfast and camera work: Zora's fire is a
# bolt you can see fly, not an instant hit; a companion's health goes with them
# from level to level and into the save (down when you left means getting up as
# they arrive; sent home means rested); Ilun, the old white moon, is in the sky
# with its own slower phases, and the moonlight comes from it; and camera shake
# reaches the third-person camera.
var f := 0
var step := 0
var wait := 0
var p
var C
var W
var c
var w

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func place(node, at: Vector3) -> void:
	node.global_position = at
	node.velocity = Vector3.ZERO

func bolts() -> Array:
	return current_scene.get_children().filter(func(x): return x.scene_file_path == "res://combat/spell_bolt.tscn")

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	C = autoload("Companions"); W = autoload("WorldClock")
	match step:
		0:
			n("GreyfangPack").can_break = false
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			autoload("GameState").set_flag("companion_zora")
			wait = 20
		1:
			# Zora's fire: a bolt that flies, and hurts when it lands.
			c = C.body()
			ok(c != null and c.ranged, "Zora throws fire")
			w = n("GreyfangPack/Wolf1")
			var base: Vector3 = w.global_position
			c.set_physics_process(false)
			place(c, base + Vector3(0, 0.05, 6))
			place(p, base + Vector3(0, 0.05, 12))
			c.look_at(base, Vector3.UP)
			w.set_meta("h", w.stats.health)
			c._attack_left = 0.0
			c._strike(w)
			ok(bolts().size() == 1, "a bolt leaves her hand", bolts().size())
			ok(w.stats.health == w.get_meta("h"), "nothing yet: it has to get there")
			var b = bolts()[0] if bolts().size() > 0 else null
			ok(b != null and b.shooter == c and b.global_position.y > base.y + 1.0, "from her, at chest height", b.global_position if b else null)
			wait = 30
		2:
			ok(w.stats.health < w.get_meta("h"), "it lands: the wolf is burned", [w.get_meta("h"), w.stats.health])
			ok(bolts().is_empty(), "and the bolt is spent")
			ok(w.has_meta("foe") and w.get_meta("foe") == c, "the wolf turns on her")
			ok(p.stats.health == p.stats.max_health, "you're not hit")
			c.set_physics_process(true)
			w.remove_meta("foe")
			place(w, w.global_position + Vector3(80, 0, 0))
			# Hurt, she stays hurt into the next level.
			c.health = 40.0
			wait = 2
		3:
			between(C.health.get("zora", -1.0), 40.0, 42.0, "her health is kept (healing slowly)")
			ok(autoload("SaveSystem").save_game(), "saved")
			near(float(C.to_dict()["health"]["zora"]), C.health["zora"], 0.001, "in the save")
			autoload("SaveSystem").travel("res://levels/waystation_cellar.tscn", "")
			wait = 40
		4:
			c = C.body()
			between(c.health if c else -1.0, 40.0, 44.0, "still about 40 in the cellar")
			# From the save: a fresh start, then load.
			var data: Dictionary = C.to_dict()
			C.reset()
			ok(C.health.is_empty(), "reset: nobody hurt")
			C.from_dict(data)
			near(C.health.get("zora", -1.0), data["health"]["zora"], 0.001, "loaded back")
			# Down when you leave: she gets up as she arrives.
			c.health = 0.0
			c._go_down()
			wait = 2
		5:
			ok(C.health.get("zora", -1.0) == 0.0, "down, kept as down")
			autoload("SaveSystem").travel("res://levels/test_level.tscn", "")
			wait = 40
		6:
			c = C.body()
			between(c.health if c else -1.0, c.max_health * c.GOT_UP, c.max_health * c.GOT_UP + 2.0, "she arrives getting up (30%)")
			ok(not c.is_down, "on her feet")
			# Sent home: rested by the time you see her again.
			autoload("GameState").set_flag("companion_cmd_dismiss")
			wait = 3
		7:
			ok(not C.health.has("zora"), "sent home: health forgotten", C.health)
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			# Ilun.
			W.day = 1; W.hour = 22.0
			wait = 2
		8:
			var ilun = n("IlunMoon")
			var wanderer = n("WandererMoon")
			ok(ilun != null and ilun.moon == "ilun", "Ilun is in the sky")
			near(W.ilun_phase(), 0.5, 0.03, "full on the first night")
			ok(ilun.lit() > 0.95 and ilun._disc.visible, "drawn full", ilun.lit())
			ok(ilun.lit() != wanderer.lit(), "its own phase, not the Wanderer's", [ilun.lit(), wanderer.lit()])
			ok(ilun._disc.material_override.get_shader_parameter("color").b < 0.95 and ilun._disc.material_override.get_shader_parameter("color").g > 0.9, "white, not green")
			ok(ilun.size > wanderer.size, "bigger than the Wanderer")
			var cam: Camera3D = root.get_camera_3d()
			var to_i: Vector3 = ilun._disc.global_position - cam.global_position
			var to_w: Vector3 = wanderer._disc.global_position - cam.global_position
			ok(rad_to_deg(to_i.angle_to(to_w)) > 90.0, "the other side of the sky", rad_to_deg(to_i.angle_to(to_w)))
			# The night light shines from Ilun, and the sky draws no second moon for it.
			var sun: DirectionalLight3D = n("Sun")
			ok(rad_to_deg((-sun.global_transform.basis.z).angle_to(-ilun.direction)) < 2.0, "moonlight comes from Ilun", -sun.global_transform.basis.z)
			ok(sun.sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_ONLY, "no extra disc in the sky")
			set_meta("full_light", sun.light_energy)
			W.day = 8; W.hour = 22.5
			wait = 2
		9:
			ok(ilun_dark(), "a week later: dark", n("IlunMoon").lit())
			ok(n("Sun").light_energy < get_meta("full_light") * 0.7, "and the night is darker", [n("Sun").light_energy, get_meta("full_light")])
			W.hour = 12.0
			wait = 2
		10:
			ok(not n("IlunMoon")._disc.visible, "not by day")
			ok(n("Sun").sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY, "the sun is in the sky by day")
			# Camera shake in third person.
			autoload("Settings").set_option("third_person", true)
			wait = 3
		11:
			var V = p.get_node("View")
			ok(V.third_person and V.camera.current, "third person")
			ok(V.camera.rotation.length() < 0.001, "steady to start", V.camera.rotation)
			p.camera_kick(Vector3(4, 2, 0))
			wait = 1
		12:
			var V = p.get_node("View")
			var kick: Vector3 = p._camera_kick
			ok(kick.length() > 0.5, "still shaking", kick)
			ok(V.camera.rotation.is_equal_approx(Vector3(deg_to_rad(kick.x), deg_to_rad(kick.y), deg_to_rad(kick.z))), "the third-person camera shakes too", [V.camera.rotation, kick])
			wait = 40
		13:
			ok(p.get_node("View").camera.rotation.length() < 0.01, "and settles", p.get_node("View").camera.rotation)
			autoload("Settings").set_option("third_person", false)
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false

func ilun_dark() -> bool:
	return n("IlunMoon").lit() < 0.05
