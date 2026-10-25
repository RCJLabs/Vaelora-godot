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
		# perks.json: no id twice (JSON keeps the last one silently), and every
		# "requires" is a perk of the same skill.
		var ids := []
		var raw := RegEx.create_from_string('^\\t"([a-z0-9_]+)": \\{')
		for line in FileAccess.get_file_as_string("res://character/perks.json").split("\n"):
			var m := raw.search(line)
			if m:
				ids.append(m.get_string(1))
		var twice: Array = ids.filter(func(id): return ids.count(id) > 1)
		ok(twice.is_empty() and ids.size() == C.perk_list.size(), "no perk id twice in perks.json", twice)
		var orphans: Array = C.perk_list.keys().filter(func(id):
				var parent: String = C.perk_list[id].get("requires", "")
				return parent != "" and (not C.perk_list.has(parent) or C.perk_list[parent]["skill"] != C.perk_list[id]["skill"]))
		ok(orphans.is_empty(), "every perk requires one of its own skill's", orphans)
		var identity: String = M.get_node("%IdentityLabel").text
		ok(identity.begins_with("Grukka  -  Orc Soldier  -  Quick Learner, Charming  -  Hardcore"), "identity line", identity)
		var row: Array = M.get_node("%AttributeRow").get_children().map(func(c): return c.text)
		ok(row[0] == "2 points:" and row[1] == "Strength  14" and row.count("+") == 6, "attribute row with 2 points and six + buttons", row)
		ok(M.get_node("%PerksButton").text == "Perks  -  1 point to spend  >", "perk points button on the Skills tab", M.get_node("%PerksButton").text)
		ok(M.tabs.get_tab_control(M.PERKS_TAB) == T and M.tabs.get_tab_title(M.PERKS_TAB) == "Perks", "a Perks tab, last")
		var skills: Array = range(T._skills.item_count).map(func(i): return T._skills.get_item_text(i))
		var SK = autoload("Skills")
		var count := func(skill: String) -> int: return C.perk_list.keys().filter(func(k): return C.perk_list[k]["skill"] == skill).size()
		ok(skills.size() == SK.SKILLS.size() and skills[0] == "One-Handed  0/%d  •" % count.call("one_handed") and skills.back().begins_with("Tidecraft"), "every skill with counts; • where a perk is ready", skills)
		# • exactly where a perk with no prerequisite is within the skill's level.
		var wrong := []
		for i in SK.SKILLS.size():
			var skill: String = T._skill_ids[i]
			var ready: bool = C.perk_list.values().any(func(perk): return perk["skill"] == skill and not perk.has("requires") and perk["level"] <= SK.levels[skill])
			if skills[i].ends_with("•") != ready:
				wrong.append(skills[i])
		ok(wrong.is_empty(), "• only where something's ready", wrong)
		# One-Handed: Armsman, Fighting Rhythm beside it a row down, Armsman II under Armsman.
		ok(T.skill_id == "one_handed", "One-Handed shown first")
		var one: Dictionary = T.layout("one_handed")
		ok(one["armsman_1"] == Vector2i(0, 0) and one["armsman_2"] == Vector2i(0, 1) and one["fighting_rhythm"] == Vector2i(1, 0),
				"Armsman II under Armsman; Fighting Rhythm its own column", one)
		ok(T._buttons["armsman_1"].text == "Armsman  (15)", "a perk shows its name and level", T._buttons["armsman_1"].text)
		ok(T._buttons["armsman_1"].get_theme_color("font_color") == T.READY and T._buttons["armsman_2"].get_theme_color("font_color") == T.LOCKED, "ready bright, locked dim")
		var links: int = C.perk_list.values().filter(func(perk): return perk["skill"] == "one_handed" and perk.has("requires")).size()
		ok(T._canvas.lines.size() == links, "a line for every perk that needs another", T._canvas.lines.size())
		T.select("armsman_2")
		ok(T._take.disabled and T._details.text.contains("Needs One-Handed 35, and Armsman") and T._details.text.contains("(needs One-Handed 35)"), "details say what it needs", T._details.text)
		T.show_skill("block")
		var above: Array = T._buttons.keys().filter(func(id): return C.perk_list[id]["level"] > SK.levels["block"])
		ok(T._buttons.size() == count.call("block") and not above.is_empty() and above.all(func(id): return T._buttons[id].get_theme_color("font_color") == T.LOCKED), "Block perks over your level locked")
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
		ok(T._skills.get_item_text(0) == "One-Handed  1/%d" % C.perk_list.keys().filter(func(k): return C.perk_list[k]["skill"] == "one_handed").size(), "1 taken, nothing more to take now", T._skills.get_item_text(0))
		ok(T._buttons["armsman_1"].text.begins_with("✓") and T._buttons["armsman_1"].get_theme_color("font_color") == T.TAKEN, "taken: ✓ and gold")
		ok(T.selected_perk == "armsman_1" and T._details.text.contains("You have it."), "still selected, and says so", T._details.text)
		ok(T._canvas.lines[0][1] == T.TAKEN, "the line from a taken perk is gold")
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
		var athletics: int = C.perk_list.keys().filter(func(k): return C.perk_list[k]["skill"] == "athletics").size()
		ok(spots.size() == athletics and spots.values().size() == _unique(spots.values()).size(), "every perk placed, no two in one spot", spots.size())
		var bad := []
		for p in spots:
			var parent: String = C.perk_list[p].get("requires", "")
			if parent != "" and (spots[p].y != spots[parent].y + 1 or spots[p].x < spots[parent].x):
				bad.append([parent, p])
		ok(bad.is_empty(), "each perk one row under, and not left of, what it requires", bad)
		# A column only ever holds one chain, so a straight line never passes another perk...
		var broken := []
		for p in spots:
			for q in spots:
				if spots[q].x == spots[p].x and spots[q].y == spots[p].y + 1 and C.perk_list[q].get("requires", "") != p:
					broken.append([p, q])
		ok(broken.is_empty(), "every column is one chain", broken)
		# ...and a branch's elbow runs in the gap under its row, over columns its own branch owns.
		var crossing := []
		for p in spots:
			var parent: String = C.perk_list[p].get("requires", "")
			if parent == "" or spots[p].x == spots[parent].x:
				continue
			for q in spots:
				if spots[q].y == spots[parent].y and spots[q].x > spots[parent].x and spots[q].x <= spots[p].x:
					crossing.append([parent, p, q])
		ok(crossing.is_empty(), "no elbow crosses another perk's line", crossing)
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
