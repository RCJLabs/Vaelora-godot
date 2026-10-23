extends "res://tests/test_base.gd"
# The character creator, clicked through: elf, scholar, the trait rules, spending the
# 4 attribute points, name and Hardcore; then the created character and the level.
var f := 0
var cc
func btn(parent: Node, text: String) -> BaseButton:
	for c in parent.find_children("*", "BaseButton", true, false):
		if c.text.begins_with(text): return c
	push_error("no button " + text); return null
func texts(parent: Node) -> Array:
	return parent.find_children("*", "Label", true, false).map(func(l): return l.text)

func _process(_d: float) -> bool:
	f += 1
	match f:
		2:
			cc = load("res://ui/character_creation.tscn").instantiate(); root.add_child(cc)
		6:
			ok(cc.title_label.text == "Choose your people", "step 1 is race", cc.title_label.text)
			ok(cc.back_button.text == "Title", "step 1 back button returns to the title", cc.back_button.text)
			btn(cc.choices, "Elf").emit_signal("pressed"); btn(cc.choices, "Elf").button_pressed = true
		8:
			var d := texts(cc.details)
			ok(d[0] == "Elf", "elf details shown", d[0])
			ok(d.any(func(t): return t.begins_with("Health 75    Stamina 94    Magicka 140")), "elf pools", d)
			ok(d.any(func(t): return t.contains("Innate Focus")), "elf power listed")
			cc.next_button.emit_signal("pressed")
		10:
			btn(cc.choices, "Scholar").button_pressed = true; btn(cc.choices, "Scholar").emit_signal("pressed")
		12:
			var d := texts(cc.details)
			ok(d[0] == "Scholar", "scholar details shown", d[0])
			ok(d.any(func(t): return t.contains("Intellect +2") and t.contains("Destruction +5")), "scholar bonuses listed")
			ok(d.any(func(t): return t.contains("Clarity")), "scholar power listed")
			cc.next_button.emit_signal("pressed")
		14:
			btn(cc.choices, "Bookish").button_pressed = true
			btn(cc.choices, "Arcane Spark").button_pressed = true
		16:
			ok(btn(cc.choices, "Hardy").disabled, "a third strength is blocked")
			ok(not btn(cc.choices, "Frail").disabled, "a flaw is still allowed")
			btn(cc.choices, "Frail").button_pressed = true
		18:
			ok(not btn(cc.choices, "Hardy").disabled, "taking a flaw allows a third strength")
			ok(btn(cc.choices, "Dim").disabled, "a second flaw is blocked")
			btn(cc.choices, "Quick Learner").button_pressed = true
		20:
			ok(cc.trait_ids == ["bookish", "arcane_spark", "frail", "quick_learner"], "four traits picked", cc.trait_ids)
			btn(cc.choices, "Frail").button_pressed = false
		22:
			ok(cc.trait_ids == ["bookish", "arcane_spark"], "dropping the flaw drops the third strength", cc.trait_ids)
			btn(cc.choices, "Frail").button_pressed = true
			btn(cc.choices, "Quick Learner").button_pressed = true
		24:
			ok(cc.trait_ids.size() == 4, "traits picked again", cc.trait_ids)
			cc.next_button.emit_signal("pressed")
		26:
			ok(cc.next_button.disabled, "Next disabled while points are left")
			var plus = cc.choices.get_child(3).get_child(2)   # intellect +
			for i in 3: plus.emit_signal("pressed")
			cc.choices.get_child(4).get_child(2).emit_signal("pressed")   # willpower +
		28:
			ok(cc.spend == {"intellect": 3, "willpower": 1}, "points spent", cc.spend)
			ok(not cc.next_button.disabled, "Next enabled once all points are spent")
			var rows := texts(cc.choices)
			ok(rows.has("Intellect  19  (+3)") and rows.has("Willpower  12  (+1)"), "attribute rows", rows)
			ok(texts(cc.details).has("0 points left"), "0 points left shown")
			cc.next_button.emit_signal("pressed")
		30:
			var edit: LineEdit = cc.choices.find_children("*", "LineEdit", true, false)[0]
			edit.text = "Ilyra"; edit.text_changed.emit("Ilyra")
			btn(cc.choices, "Hardcore").button_pressed = true
		32:
			var d := texts(cc.details)
			ok(d.has("Ilyra") and d.has("Elf Scholar") and d.has("Mode: Hardcore"), "summary", d)
			ok(cc.next_button.text == "Begin journey", "last step's button", cc.next_button.text)
			cc.next_button.emit_signal("pressed")
		45:
			var C = autoload("Character"); var A = autoload("Attributes")
			ok(C.player_name == "Ilyra" and C.background == "scholar", "name and background", [C.player_name, C.background])
			ok(C.traits == ["bookish", "arcane_spark", "frail", "quick_learner"], "traits", C.traits)
			ok(C.modes == {"survival": false, "hardcore": true}, "modes", C.modes)
			ok(A.values == {"strength": 9, "endurance": 6, "agility": 12, "intellect": 19, "willpower": 12, "presence": 10}, "attributes", A.values)
			ok(autoload("GameState").race_data.display_name == "Elf", "race")
			ok(autoload("Spellbook").known == ["healing", "flames", "firebolt", "candlelight"], "scholar spells", autoload("Spellbook").known)
			var p = get_first_node_in_group("player")
			if ok(p != null, "player spawned"):
				ok(is_equal_approx(p.stats.max_health, 65) and is_equal_approx(p.stats.max_stamina, 88) and is_equal_approx(p.stats.max_magicka, 175), "player pools", [p.stats.max_health, p.stats.max_stamina, p.stats.max_magicka])
			ok(current_scene != null and current_scene.name == "TestLevel", "started in the test level")
			return done()
	return false
