extends "res://tests/test_base.gd"
# Pause menu > Report a Bug: the report holds the diagnostics, and the page
# focuses a button (not the text box) for gamepads.
var f := 0

func _initialize() -> void:
	var level = load("res://levels/test_level.tscn").instantiate()
	root.add_child(level); current_scene = level

func _process(_d: float) -> bool:
	f += 1
	var pm = autoload("PauseMenu")
	if f == 10:
		pm.open_page("main")
		ok(pm.content.get_children().any(func(c): return c is Button and c.text == "Report a Bug"), "pause menu has Report a Bug")
		pm._show("report")
	if f == 14:
		var boxes = pm.content.find_children("*", "TextEdit", true, false)
		ok(boxes.size() == 1, "report page shows the text")
		var text: String = boxes[0].text if boxes.size() > 0 else ""
		for start in ["Game: High Fantasy Sandbox RPG ", "Engine: Godot 4.", "System: ", "GPU: ", "Graphics: ",
				"Scene: res://levels/test_level.tscn", "Player: (", "Time: Day ", "--- last 40 log lines ---"]:
			ok(text.contains("\n" + start) or text.begins_with(start), "report has '%s'" % start.strip_edges())
		var labels = pm.content.get_children().filter(func(c): return c is Button).map(func(c): return c.text)
		ok(labels == ["Copy again", "Back"], "buttons (no URL set)", labels)
		ok(root.gui_get_focus_owner() is Button, "focus on a button", root.gui_get_focus_owner())
		return done()
	return false
