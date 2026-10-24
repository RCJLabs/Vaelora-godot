extends "res://tests/test_base.gd"
# Save slots and the pause menu: old-save migration, quicksave/F9, save-page
# overwrite confirmation, settings saving, Esc routing, delete, Quit to Title and Continue.
var f := 0
var started := false
var steps := []
var wait := 0
var SS; var PM; var GS; var DM; var CM; var ST
func player(): return get_first_node_in_group("player")
func key(k: Key) -> void:
	var e := InputEventKey.new(); e.keycode = k; e.physical_keycode = k; e.pressed = true
	Input.parse_input_event(e)
	var r := InputEventKey.new(); r.keycode = k; r.physical_keycode = k; r.pressed = false
	Input.parse_input_event(r)
func add(guard: Callable, action: Callable) -> void: steps.append([guard, action])
func always() -> bool: return true
func buttons() -> Array:
	var out := []
	for c in PM.content.get_children():
		if c is Button: out.append(c.text)
		elif c is HBoxContainer: out.append(" | ".join(c.get_children().filter(func(x): return x is Button).map(func(x): return x.text)))
	return out
func press(start: String) -> void:
	for c in PM.content.get_children():
		var bs = [c] if c is Button else (c.get_children() if c is HBoxContainer else [])
		for b in bs:
			if b is Button and b.text.begins_with(start):
				b.emit_signal("pressed"); return
	ok(false, "button '%s' present" % start, buttons())
func _physics_process(_d: float) -> bool:
	if not started:
		started = true
		SS = root.get_node("SaveSystem"); PM = root.get_node("PauseMenu"); GS = root.get_node("GameState"); DM = root.get_node("DialogueManager"); CM = root.get_node("CharacterMenu"); ST = root.get_node("Settings")
		SS.delete_save()
		# an old-style save from before slots, to check it becomes the quicksave
		var old = FileAccess.open("user://savegame.json", FileAccess.WRITE); old.store_string('{"version": 5}'); old.close()
		SS._ready()
		ok(SS.has_save("quicksave"), "old savegame.json migrated to the quicksave")
		ok(not FileAccess.file_exists("user://savegame.json"), "old save file removed")
		SS.delete_save()
		var level = load("res://levels/test_level.tscn").instantiate()
		root.add_child(level); current_scene = level
		_build()
		return false
	f += 1
	if wait > 0:
		wait -= 1; return false
	if steps.is_empty(): return done()
	var s = steps.pop_front()
	s[1].call()
	wait = 4
	return false
func _build() -> void:
	add(always, func(): player().global_position = Vector3(1, 0, 1))
	add(always, func(): SS.save_game("slot_2"); player().global_position = Vector3(2, 0, 2))
	for i in 15: add(always, func(): pass)
	add(always, func(): key(KEY_F5))
	add(always, func():
		ok(SS.list_saves().map(func(s): return s["slot"]) == ["quicksave", "slot_2"], "saves listed newest first", SS.list_saves().map(func(s): return s["slot"]))
		ok(SS.describe(SS.list_saves()[0]["meta"]).begins_with("Traveller (Human), level 1  -  Test Level  -  0h 00m played"), "save description", SS.describe(SS.list_saves()[0]["meta"])))
	add(always, func(): player().global_position = Vector3(9, 0, 9); key(KEY_F9))
	add(always, func(): ok(player().global_position.distance_to(Vector3(2, 0, 2)) < 0.2, "F9 loaded the quicksave position", player().global_position))
	add(always, func(): key(KEY_ESCAPE))
	add(always, func():
		ok(PM.is_open and PM._page == "main" and paused, "Esc opens the paused main page", [PM.is_open, PM._page, paused])
		ok(buttons() == ["Resume", "Save Game", "Load Game", "Settings", "Report a Bug", "Quit to Title", "Quit Game"], "pause menu buttons", buttons())
		press("Load Game"))
	add(always, func():
		var b = buttons()
		ok(b.size() == 3 and b[0].begins_with("Quicksave") and b[1].begins_with("Slot 2") and b[0].ends_with("| Delete"), "load page lists both saves with Delete", b)
		press("Back"))
	add(always, func(): press("Save Game"))
	add(always, func():
		var b = buttons()
		ok(b.size() == 6 and b[0] == "Slot 1  -  empty" and b[1].begins_with("Slot 2  -  Traveller") and b[5] == "Back", "save page: 5 slots + Back", b)
		press("Slot 2"))
	add(always, func(): ok(buttons()[1] == "Slot 2  -  click again to overwrite", "first click on a used slot asks to confirm", buttons()[1]); press("Slot 2"))
	add(always, func(): ok(buttons()[1].begins_with("Slot 2  -  Traveller (Human), level 1"), "second click overwrites", buttons()[1]); press("Slot 1"))
	add(always, func(): ok(buttons()[0].begins_with("Slot 1  -  Traveller (Human), level 1"), "empty slot saves in one click", buttons()[0]); press("Back"))
	add(always, func(): press("Settings"))
	add(always, func():
		ok(PM.content.get_child_count() == 9, "settings rows (incl. Graphics, Controls, Accessibility)", PM.content.get_child_count())
		near(player().camera.fov, 75.0, 0.5, "camera fov before")
		var fov_slider: HSlider = PM.content.get_child(2).get_child(1)
		fov_slider.value = 90.0
		var sens: HSlider = PM.content.get_child(0).get_child(1)
		sens.value = 1.5
		PM.content.get_child(1).button_pressed = true)
	add(always, func():
		var cfg := ConfigFile.new(); cfg.load("user://settings.cfg")
		near(player().camera.fov, 90.0, 0.5, "camera follows the fov slider")
		ok(cfg.get_value("settings", "mouse_sensitivity") == 1.5 and cfg.get_value("settings", "invert_y") == true and cfg.get_value("settings", "fov") == 90.0, "settings.cfg saved", [cfg.get_value("settings", "mouse_sensitivity"), cfg.get_value("settings", "invert_y"), cfg.get_value("settings", "fov")])
		key(KEY_ESCAPE))
	add(always, func(): ok(PM._page == "main" and PM.is_open, "Esc on settings goes back to main", [PM._page, PM.is_open]); key(KEY_ESCAPE))
	add(always, func(): ok(not PM.is_open and not paused, "Esc again closes and unpauses", [PM.is_open, paused]); player().global_position = Vector3(2, 0, -2); player().rotation.y = 0; player().get_node("Head").rotation.x = 0)
	add(always, func(): key(KEY_E))
	add(always, func(): ok(DM.is_active, "talking to Maren"); key(KEY_ESCAPE))
	add(always, func(): ok(not DM.is_active and not PM.is_open, "Esc in dialogue closes it without pausing", [DM.is_active, PM.is_open]); key(KEY_TAB))
	add(always, func(): key(KEY_ESCAPE))
	add(always, func(): ok(not CM.is_open and not PM.is_open, "Esc in the Tab menu closes it without pausing", [CM.is_open, PM.is_open]); key(KEY_ESCAPE))
	add(always, func(): press("Load Game"))
	add(always, func(): press("Delete"))
	add(always, func(): ok(buttons()[0].ends_with("| Sure?"), "Delete asks to confirm", buttons()[0]); press("Sure"))
	add(always, func(): ok(SS.list_saves().map(func(s): return s["slot"]) == ["slot_2", "quicksave"], "newest save (slot 1) deleted", SS.list_saves().map(func(s): return s["slot"])); press("Back"))
	add(always, func(): press("Quit to Title"))
	for i in 3: add(always, func(): pass)
	add(always, func():
		ok(current_scene.name == "TitleScreen" and not paused, "Quit to Title reaches the unpaused title", [current_scene.name, paused])
		ok(current_scene.get_node("%Buttons/ContinueButton").visible, "Continue shown with saves present")
		current_scene.get_node("%Buttons/ContinueButton").emit_signal("pressed"))
	for i in 3: add(always, func(): pass)
	add(always, func(): ok(current_scene.name == "TestLevel" and player().global_position.distance_to(Vector3(2, 0, 2)) < 0.2, "Continue loads the most recent save", [current_scene.name, player().global_position]))
	add(always, func(): SS.delete_save(); ST.set_option("fov", 75.0); ST.set_option("mouse_sensitivity", 1.0); ST.set_option("invert_y", false))
