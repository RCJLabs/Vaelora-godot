extends "res://tests/test_base.gd"
# Character menu: identity line, spending an attribute point with "+", and the
# Perks tab (ui/perk_tree.gd): the skill list with counts, one skill's perks laid
# out by level with a line to what each requires, the details, taking a perk, and
# a 22-perk skill laid out with nothing on top of anything (the trees will grow).
var f := 0
var started := false

func _physics_process(_d: float) -> bool:
	var C = autoload("Character"); var M = autoload("CharacterMenu")
	if not started:
		started = true
		C.create(load("res://races/orc.tres"), "Grukka", "soldier", ["quick_learner", "charming"], {}, {"hardcore": true})
		var level = load("res://levels/test_level.tscn").instantiate()
		root.add_child(level); current_scene = level
		return false
	f += 1
	var T = M.perk_tree
	if f == 3:
		C.attribute_points = 2; M.open()
	if f == 5:
		var identity: String = M.get_node("%IdentityLabel").text
		ok(identity.begins_with("Grukka  -  Orc Soldier  -  Quick Learner, Charming  -  Hardcore"), "identity line", identity)
		var row: Array = M.get_node("%AttributeRow").get_children().map(func(c): return c.text)
		ok(row[0] == "2 points:" and row[1] == "Strength  14" and row.count("+") == 6, "attribute row with 2 points and six + buttons", row)
		ok(M.get_node("%PerksButton").text == "Perks  -  1 point to spend  >", "perk points button on the Skills tab", M.get_node("%PerksButton").text)
		ok(M.tabs.get_tab_control(M.PERKS_TAB) == T and M.tabs.get_tab_title(M.PERKS_TAB) == "Perks", "a Perks tab, last")
		var skills: Array = range(T._skills.item_count).map(func(i): return T._skills.get_item_text(i))
		ok(skills.size() == 10 and skills[0] == "One-Handed  0/3  •" and skills.back().begins_with("Tidecraft"), "ten skills with counts; • where a perk is ready", skills)
		ok(T._skills.get_item_text(3) == "Block  0/3", "nothing ready in Block", T._skills.get_item_text(3))
		# One-Handed: Armsman, Fighting Rhythm beside it a row down, Armsman II under Armsman.
		ok(T.skill_id == "one_handed", "One-Handed shown first")
		ok(T.layout("one_handed") == {"armsman_1": Vector2i(0, 0), "fighting_rhythm": Vector2i(1, 1), "armsman_2": Vector2i(0, 2)},
				"by level, Armsman II under Armsman with nothing between", T.layout("one_handed"))
		ok(T._buttons["armsman_1"].text == "Armsman  (15)", "a perk shows its name and level", T._buttons["armsman_1"].text)
		ok(T._buttons["armsman_1"].get_theme_color("font_color") == T.READY and T._buttons["armsman_2"].get_theme_color("font_color") == T.LOCKED, "ready bright, locked dim")
		ok(T._canvas.lines.size() == 1, "one line: Armsman to Armsman II", T._canvas.lines.size())
		T.select("armsman_2")
		ok(T._take.disabled and T._details.text.contains("Needs One-Handed 35, and Armsman") and T._details.text.contains("(needs One-Handed 35)"), "details say what it needs", T._details.text)
		T.show_skill("block")
		ok(T._buttons.size() == 3 and T._buttons.values().all(func(b): return b.get_theme_color("font_color") == T.LOCKED), "Block perks all locked")
		T.show_skill("one_handed")
		for c in M.get_node("%AttributeRow").get_children():
			if c is Button: c.emit_signal("pressed"); break
		T.select("armsman_1")
		ok(not T._take.disabled and T._take.text == "Take Armsman", "Take is ready", T._take.text)
		T._take.emit_signal("pressed")
	if f == 7:
		var row: Array = M.get_node("%AttributeRow").get_children().map(func(c): return c.text)
		ok(row[0] == "1 point:" and row[1] == "Strength  15", "after +: one point left, strength 15", row)
		ok(M.get_node("%PerksButton").text == "Perks  -  0 points to spend  >", "perk point spent", M.get_node("%PerksButton").text)
		M.tabs.current_tab = 0
		M.get_node("%PerksButton").emit_signal("pressed")
		ok(M.tabs.current_tab == M.PERKS_TAB, "the button opens the Perks tab", M.tabs.current_tab)
		ok(C.perks == ["armsman_1"], "perks list", C.perks)
		ok(T._skills.get_item_text(0) == "One-Handed  1/3", "1 of 3, nothing more to take now", T._skills.get_item_text(0))
		ok(T._buttons["armsman_1"].text.begins_with("✓") and T._buttons["armsman_1"].get_theme_color("font_color") == T.TAKEN, "taken: ✓ and gold")
		ok(T.selected_perk == "armsman_1" and T._details.text.contains("You have it."), "still selected, and says so", T._details.text)
		ok(T._canvas.lines[0][2] == T.TAKEN, "the line from a taken perk is gold")
		# A big tree: 22 perks in Athletics (8 roots, chains and branches, shared levels).
		var saved: Dictionary = C.perk_list.duplicate(true)
		for i in 22:
			var perk := {"name": "Test %d" % i, "skill": "athletics", "level": 10 + 5 * (i % 4), "description": "x"}
			if i >= 8:   # 8-15 require a root (some share one level), 16-21 one of those
				perk["requires"] = "test_%d" % (i % 8 if i < 16 else i - 8)
				perk["level"] = 30 + 5 * (i % 3) if i < 16 else 45 + 5 * (i % 2)
			C.perk_list["test_%d" % i] = perk
		T.show_skill("athletics")
		var spots: Dictionary = T.layout("athletics")
		ok(spots.size() == 25 and spots.values().size() == _unique(spots.values()).size(), "25 perks, no two in one spot", spots.size())
		var crossed := []
		for p in spots:
			var parent: String = C.perk_list[p].get("requires", "")
			if parent == "":
				continue
			ok(spots[p].y > spots[parent].y, "%s sits below %s" % [p, parent])
			if spots[p].x == spots[parent].x:
				for q in spots:
					if spots[q].x == spots[p].x and spots[q].y > spots[parent].y and spots[q].y < spots[p].y:
						crossed.append([parent, q, p])
		ok(crossed.is_empty(), "no line runs behind another perk", crossed)
		ok(T._canvas.custom_minimum_size.x > T._scroll.size.x, "wider than the view: it scrolls", [T._canvas.custom_minimum_size, T._scroll.size])
		C.perk_list = saved
		M.close()
		return done()
	return false

func _unique(values: Array) -> Array:
	var out := []
	for v in values:
		if not v in out:
			out.append(v)
	return out
