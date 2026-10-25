extends "res://tests/test_base.gd"
# Skills: race starting levels, Athletics from sprinting, forced level-ups, the level-up bonus menu, saving.
var f := 0
var S

func player(): return get_first_node_in_group("player")

func key(k: Key) -> void:
	var e := InputEventKey.new(); e.keycode = k; e.physical_keycode = k; e.pressed = true
	Input.parse_input_event(e)
	var r := InputEventKey.new(); r.keycode = k; r.physical_keycode = k; r.pressed = false
	Input.parse_input_event(r)

func notices() -> Array: return player().hud.notices.get_children().map(func(l): return l.text)

func _initialize() -> void:
	S = autoload("Skills")
	autoload("SaveSystem").delete_save()
	for r in [["human", 15, 15], ["elf", 15, 25], ["orc", 25, 15]]:
		S.reset(load("res://races/%s.tres" % r[0]))
		ok(S.levels["one_handed"] == r[1] and S.levels["athletics"] == r[2], "%s starts with One-Handed %d, Athletics %d" % r, [S.levels["one_handed"], S.levels["athletics"]])
	autoload("GameState").set_race(load("res://races/human.tres")); S.reset(load("res://races/human.tres"))
	var level = load("res://levels/test_level.tscn").instantiate()
	root.add_child(level); current_scene = level
	level.get_node("Player").position = Vector3(-55, 1, 20); level.get_node("Player").rotation.y = deg_to_rad(-90)

func _physics_process(_d: float) -> bool:
	f += 1
	var p = player()
	match f:
		60: Input.action_press("move_forward"); Input.action_press("sprint")
		480:
			Input.action_release("move_forward"); Input.action_release("sprint")
			ok(S.levels["athletics"] == 16, "7 s of sprinting raises Athletics to 16", S.levels["athletics"])
			ok("Athletics increased to 16" in notices(), "notice for the Athletics increase", notices())
		490:
			for i in 5: S.add_xp("one_handed", S.xp_needed("one_handed") / 1.15 + 0.01)
			ok(S.levels["one_handed"] == 20, "5 forced One-Handed increases reach 20", S.levels["one_handed"])
			ok(S.character_level == 2, "character level 2", S.character_level)
			ok(S.unspent_level_ups == 1, "one unspent level-up", S.unspent_level_ups)
			near(S.one_handed_damage_mult(), 1.05, 0.001, "One-Handed damage multiplier")
			ok(notices().any(func(t): return t.begins_with("Level 2!")), "level-up notice", notices())
		500: key(KEY_TAB)
		505:
			var m = autoload("CharacterMenu")
			ok(m.is_open and paused, "Tab opens the menu and pauses")
			ok(m.level_label.text.begins_with("Level 2"), "level label", m.level_label.text)
			ok(m.level_up_box.visible, "level-up choice shown")
			var rows = m.skill_list.get_children().filter(func(c): return c is Label).map(func(c): return c.text)
			ok(rows.size() >= 3 and rows[0] == "One-Handed  (STR)" and rows[1] == "20", "skill list shows One-Handed (STR) 20", rows.slice(0, 3))
			near(p.stats.max_health, 100, 0.01, "max health before the bonus")
			m.get_node("%HealthButton").emit_signal("pressed")
			near(p.stats.max_health, 110, 0.01, "+Health raises max health to 110")
			near(p.stats.health, 110, 0.01, "and fills it")
			near(p.hud.health_bar.max_value, 110, 0.01, "health bar follows")
			ok(S.unspent_level_ups == 0 and not m.level_up_box.visible, "level-up spent and choice hidden")
		510: key(KEY_TAB)
		515: ok(not autoload("CharacterMenu").is_open and not paused, "Tab closes the menu and unpauses")
		520: key(KEY_F5)
		525: S.reset(load("res://races/human.tres")); key(KEY_F9)
		540:
			ok(S.levels["one_handed"] == 20 and S.levels["athletics"] == 16 and S.character_level == 2, "after load: skills and level restored", [S.levels["one_handed"], S.levels["athletics"], S.character_level])
			ok(S.bonus["health"] == 10, "after load: health bonus kept", S.bonus["health"])
			near(player().stats.max_health, 110, 0.01, "after load: player max health")
			autoload("SaveSystem").delete_save()
			return done()
	return false
