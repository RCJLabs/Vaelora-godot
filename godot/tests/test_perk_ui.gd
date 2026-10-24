extends "res://tests/test_base.gd"
# Character menu: identity line, spending an attribute point with "+", and taking a perk.
var f := 0
var started := false

func _perk_rows(M) -> Array:
	return M.get_node("%PerkList").get_children().map(func(row): return row.get_children().map(
			func(c): return c.text + (" [off]" if c is Button and c.disabled else "")))

func _physics_process(_d: float) -> bool:
	var C = autoload("Character"); var M = autoload("CharacterMenu")
	if not started:
		started = true
		C.create(load("res://races/orc.tres"), "Grukka", "soldier", ["quick_learner", "charming"], {}, {"hardcore": true})
		var level = load("res://levels/test_level.tscn").instantiate()
		root.add_child(level); current_scene = level
		return false
	f += 1
	if f == 3:
		C.attribute_points = 2; M.open()
	if f == 5:
		var identity: String = M.get_node("%IdentityLabel").text
		ok(identity.begins_with("Grukka  -  Orc Soldier  -  Quick Learner, Charming  -  Hardcore"), "identity line", identity)
		var row: Array = M.get_node("%AttributeRow").get_children().map(func(c): return c.text)
		ok(row[0] == "2 points:" and row[1] == "Strength  14" and row.count("+") == 6, "attribute row with 2 points and six + buttons", row)
		ok(M.get_node("%PerksLabel").text == "Perks  -  1 point to spend", "perk points label", M.get_node("%PerksLabel").text)
		var rows := _perk_rows(M)
		ok(rows.size() == 9, "nine perk trees listed", rows.size())
		ok(rows[0] == ["One-Handed", "Take: Armsman", "Take: Fighting Rhythm", "Armsman II (needs One-Handed 35) [off]"],
				"one-handed row: two takeable, one locked", rows[0])
		ok(rows[3][0] == "Block" and rows[3].slice(1).all(func(t): return t.ends_with("[off]")), "block perks all locked", rows[3])
		for c in M.get_node("%AttributeRow").get_children():
			if c is Button: c.emit_signal("pressed"); break
		for r in M.get_node("%PerkList").get_children():
			for c in r.get_children():
				if c is Button and c.text.begins_with("Take: Armsman"): c.emit_signal("pressed")
	if f == 7:
		var row: Array = M.get_node("%AttributeRow").get_children().map(func(c): return c.text)
		ok(row[0] == "1 point:" and row[1] == "Strength  15", "after +: one point left, strength 15", row)
		ok(M.get_node("%PerksLabel").text == "Perks  -  0 points to spend", "perk point spent", M.get_node("%PerksLabel").text)
		var one_handed: Array = M.get_node("%PerkList").get_child(0).get_children().map(func(c): return c.text)
		ok(one_handed[1] == "✓ Armsman" and one_handed[2] == "Fighting Rhythm (no perk points)", "one-handed row after taking Armsman", one_handed)
		ok(autoload("Attributes").value("strength") == 15, "strength is 15")
		ok(C.perks == ["armsman_1"], "perks list", C.perks)
		return done()
	return false
