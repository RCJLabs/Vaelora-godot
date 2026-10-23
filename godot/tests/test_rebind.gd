extends "res://tests/test_base.gd"
# Key rebinding (Settings > Controls): rebind, conflicts, device filtering, cancel, saving, reset.
var f := 0
var steps := []
var wait := 0
var PM; var KB; var IH
var finished := false
func add(k: int, cb: Callable) -> void: steps.append([k, cb])
func key(k: Key) -> void:
	var e := InputEventKey.new(); e.physical_keycode = k; e.keycode = k; e.pressed = true; Input.parse_input_event(e)
	var r := InputEventKey.new(); r.physical_keycode = k; r.keycode = k; r.pressed = false; Input.parse_input_event(r)
func pad(b: int) -> void:
	var e := InputEventJoypadButton.new(); e.button_index = b; e.pressed = true; Input.parse_input_event(e)
	var r := InputEventJoypadButton.new(); r.button_index = b; r.pressed = false; Input.parse_input_event(r)
func row_button(label: String, gamepad: bool) -> Button:
	var grid = PM.content.find_children("*", "GridContainer", true, false)[0]
	var kids = grid.get_children()
	for i in kids.size():
		if kids[i] is Label and kids[i].text == label: return kids[i + (2 if gamepad else 1)]
	return null
func names(action: String) -> String: return "%s / %s" % [KB.event_name(KB.binding(action, false)), KB.event_name(KB.binding(action, true))]
func _initialize() -> void:
	root.add_child(load("res://levels/test_level.tscn").instantiate())
func _process(_d: float) -> bool:
	f += 1
	if f == 5:
		PM = autoload("PauseMenu"); KB = autoload("KeyBindings"); IH = autoload("InputHints")
		KB.reset()
		PM.open_page("settings")
		add(2, func():
			PM._show("controls")
			ok(names("jump") == "Space / A", "default jump", names("jump"))
			ok(names("attack") == "Left-click / RT", "default attack", names("attack"))
			ok(names("dodge") == "Alt / B", "default dodge", names("dodge"))
			ok(names("switch_spell") == "Q / Y", "default switch spell", names("switch_spell")))
		add(2, func(): row_button("Jump / climb", false).emit_signal("pressed"))
		add(3, func(): key(KEY_K))
		add(3, func():
			ok(names("jump") == "K / A", "jump rebound to K", names("jump"))
			ok(row_button("Jump / climb", false).text == "K", "row button shows K")
			ok(IH.label("jump") == "K", "prompt label follows", IH.label("jump")))
		add(2, func(): row_button("Attack (right hand)", false).emit_signal("pressed"))
		add(3, func(): key(KEY_K))
		add(3, func():
			ok(names("attack") == "K / RT", "attack takes K", names("attack"))
			ok(names("jump") == "- / A", "jump loses K", names("jump"))
			ok(PM.content.get_child(1).text == 'K was also used by "Jump / climb", which is now unbound there.', "conflict warning", PM.content.get_child(1).text))
		add(2, func(): row_button("Dodge", true).emit_signal("pressed"))
		add(3, func(): key(KEY_L))   # wrong device: ignored, still waiting
		add(3, func(): pad(JOY_BUTTON_Y))
		add(3, func():
			ok(names("dodge") == "Alt / Y", "dodge pad rebound to Y, the key in between ignored", names("dodge"))
			ok(names("switch_spell") == "Q / -", "switch spell loses Y", names("switch_spell")))
		add(2, func(): row_button("Use / talk", false).emit_signal("pressed"))
		add(3, func(): key(KEY_ESCAPE))
		add(3, func():
			ok(names("interact") == "E / X", "Esc cancels without changing interact", names("interact"))
			ok(PM.is_open, "menu still open after Esc cancels"))
		add(2, func():
			var cfg := ConfigFile.new(); cfg.load("user://controls.cfg")
			ok(cfg.get_value("bindings", "jump") == [{"button": 0, "type": "pad_button"}], "saved file: jump", cfg.get_value("bindings", "jump"))
			ok({"code": 75, "type": "key"} in cfg.get_value("bindings", "attack", []), "saved file: attack has K", cfg.get_value("bindings", "attack"))
			KB.reset()
			ok(names("jump") == "Space / A" and names("attack") == "Left-click / RT" and names("dodge") == "Alt / B", "reset restores defaults", [names("jump"), names("attack"), names("dodge")])
			ok(not FileAccess.file_exists("user://controls.cfg"), "reset deletes the file"))
		add(2, func(): finished = true)
	if finished: return done()
	if f < 5 or steps.is_empty(): return false
	wait += 1
	if wait >= steps[0][0]:
		wait = 0
		steps.pop_front()[1].call()
	return false
