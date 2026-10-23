extends "res://tests/test_base.gd"
# Health/Stamina/Magicka: sprint drain and regen, fall damage, death and respawn, quicksave/quickload, death reloads the save.
var f := 0
var p

func player(): return get_first_node_in_group("player")

func key(k: Key) -> void:
	var e := InputEventKey.new(); e.keycode = k; e.physical_keycode = k; e.pressed = true
	Input.parse_input_event(e)
	var r := InputEventKey.new(); r.keycode = k; r.physical_keycode = k; r.pressed = false
	Input.parse_input_event(r)

func full() -> bool:
	var s = player().stats
	return s.health >= s.max_health - 0.01 and s.stamina >= s.max_stamina - 0.01 and s.magicka >= s.max_magicka - 0.01

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	var level = load("res://levels/test_level.tscn").instantiate()
	root.add_child(level); current_scene = level

func _physics_process(_d: float) -> bool:
	f += 1
	p = player()
	match f:
		60:
			ok(full(), "starts with full pools")
			near(p.hud.health_bar.max_value, 100, 0.01, "health bar max")
			Input.action_press("move_forward"); Input.action_press("sprint")
		180: between(p.stats.stamina, 75.0, 95.0, "stamina after sprinting (into the closed door)")
		420:
			# Sprinting against the door doesn't move, so it doesn't drain: stamina refills.
			near(p.stats.stamina, 100.0, 0.5, "no stamina drain while blocked by the door")
			Input.action_release("sprint"); Input.action_release("move_forward")
		790: p.global_position = Vector3(0, 10, 0); p.velocity = Vector3.ZERO
		900:
			between(p.stats.health, 50.0, 70.0, "health after a 10 m fall")
			ok(not p.is_dead, "a 10 m fall isn't fatal")
		910: p.global_position = Vector3(0, 30, 0); p.velocity = Vector3.ZERO
		1120:
			ok(p.is_dead, "a 30 m fall kills")
			ok(p.hud.message_label.text == "You have died.", "death message", p.hud.message_label.text)
		1300:
			ok(not p.is_dead and full(), "respawned with full pools (no save)")
			ok(p.global_position.distance_to(Vector3.ZERO) < 0.5, "respawned at the start", p.global_position)
		1310:
			autoload("GameState").set_flag("met_maren")
			p.global_position = Vector3(5, 0, 5); p.rotation.y = 1.0
		1330: key(KEY_F5)
		1332:
			ok(autoload("SaveSystem").has_save(), "F5 saved")
			ok(p.hud.message_label.text == "Game saved (Quicksave).", "save message", p.hud.message_label.text)
		1340: p.global_position = Vector3(-5, 0, -5); autoload("GameState").flags = {}
		1350: key(KEY_F9)
		1360:
			ok(current_scene.name == "TestLevel", "F9 reloads the level")
			ok(p.global_position.distance_to(Vector3(5, 0, 5)) < 0.1, "position restored", p.global_position)
			near(p.rotation.y, 1.0, 0.01, "facing restored")
			ok(autoload("GameState").flags.get("met_maren", false), "flags restored", autoload("GameState").flags)
		1370: p.global_position = Vector3(0, 30, 0); p.velocity = Vector3.ZERO
		1720:
			ok(not p.is_dead and full(), "after dying with a save: reloaded with full pools")
			ok(p.global_position.distance_to(Vector3(5, 0, 5)) < 0.1, "reloaded at the saved position", p.global_position)
			autoload("SaveSystem").delete_save()
			return done()
	return false
