extends "res://tests/test_base.gd"
# Melee against the Greyfang pack with a bot that swings at the nearest wolf, then the
# wolf quest hand-in with Maren, and that the cleared pack stays cleared after F5/F9.
# Argument: race (default human).
var f := 0
var noticed := false
var phase := "fight"
var pack
var swings := 0
var started := false
var xp_before := 0.0
var level_before := 0

func player(): return get_first_node_in_group("player")

func key(k: Key) -> void:
	var e := InputEventKey.new(); e.keycode = k; e.physical_keycode = k; e.pressed = true
	Input.parse_input_event(e)
	var r := InputEventKey.new(); r.keycode = k; r.physical_keycode = k; r.pressed = false
	Input.parse_input_event(r)

func living(p) -> Array:
	return p.get_children().filter(func(w): return w.state != w.State.DEAD)

func _setup() -> void:
	# autoloads are ready now, so the race choice sticks (like the start screen)
	autoload("SaveSystem").delete_save()
	var race_arg := arg("human")
	autoload("GameState").set_race(load("res://races/%s.tres" % race_arg))
	autoload("Skills").reset(autoload("GameState").race_data)
	var level = load("res://levels/test_level.tscn").instantiate()
	root.add_child(level); current_scene = level
	pack = level.get_node("GreyfangPack")
	level_before = autoload("Skills").levels["one_handed"]
	xp_before = autoload("Skills").xp["one_handed"]

func _physics_process(_d: float) -> bool:
	if not started:
		started = true; _setup(); return false
	f += 1
	var p = player()
	if phase == "fight":
		if f == 120:
			ok(pack.get_children().all(func(w): return w.state == w.State.IDLE), "wolves idle while the player is 30 m away")
		if f == 121: p.global_position = Vector3(8, 0, -18); p.rotation.y = 0   # 12 m south of pack, facing north
		# Within 3 s of the player arriving 12 m away, the pack notices (they wander, so not on a fixed frame).
		if f > 121 and f <= 300 and not noticed:
			noticed = pack.get_children().any(func(w): return w.state == w.State.CHASE or w.state == w.State.ATTACK)
		if f == 300:
			ok(noticed, "wolves chase once the player is near")
		if f > 200 and f % 36 == 0 and not p.is_dead:
			var best = null
			for w in living(pack):
				if best == null or w.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position): best = w
			if best:
				var d = best.global_position - p.global_position
				p.rotation.y = atan2(-d.x, -d.z)
				p.get_node("Head").rotation.x = deg_to_rad(-15)
				var before = p.combat.state
				p.combat.attack_pressed(); p.combat.attack_released()
				if p.combat.state != before: swings += 1
		if f > 200 and autoload("GameState").has_flag("wolves_cleared"):
			ok(living(pack).is_empty(), "all three wolves dead")
			between((f - 121) / 60.0, 1.0, 30.0, "seconds to clear the pack")
			between(swings, 3, 60, "swings taken")
			ok(not p.is_dead, "player survived")
			ok(p.hud.message_label.text.contains("Greyfang"), "pack-cleared message", p.hud.message_label.text)
			var skills = autoload("Skills")
			ok(skills.levels["one_handed"] > level_before or skills.xp["one_handed"] > xp_before, "one-handed skill gained XP")
			phase = "talk"; f = 0
		if p.is_dead and phase == "fight":
			ok(false, "player survived the pack"); return done()
		if f > 2400:
			ok(false, "pack cleared within 38 s", living(pack).size()); return done()
	elif phase == "talk":
		var dm = autoload("DialogueManager")
		if f == 1:
			for flag in ["met_maren", "heard_about_wolves", "wolf_quest_accepted"]: autoload("GameState").set_flag(flag)
			p.global_position = Vector3(2, 0, -2); p.rotation.y = 0; p.get_node("Head").rotation.x = 0
		if f == 20: key(KEY_E)
		if f == 25:
			var c: Array = dm.choices_box.get_children().map(func(b): return b.text)
			ok(c.size() > 0 and c[0].contains("Greyfang pack is dead"), "Maren offers the hand-in choice first", c)
			key(KEY_1)
		if f == 30:
			ok(autoload("GameState").has_flag("wolf_quest_done"), "wolf quest done after the hand-in")
			key(KEY_1)
		if f == 35: key(KEY_F5)
		if f == 40: key(KEY_F9)
		if f == 50:
			ok(living(current_scene.get_node("GreyfangPack")).is_empty(), "no living wolves after reload")
		if f == 52: key(KEY_E)
		if f == 56:
			ok(dm.line_label.text.contains("cleared the north road"), "Maren greets the wolf-slayer", dm.line_label.text)
			autoload("SaveSystem").delete_save()
			return done()
	return false
