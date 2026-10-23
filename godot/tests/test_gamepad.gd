extends "res://tests/test_base.gd"
# Gamepad: analog movement and look, A jumps, prompts follow the last device used,
# dialogue with the D-pad, RT/LT/B in combat, Menu and View open the menus, LB/RB tabs.
var f := 0
var steps := []
var wait := 0
var finished := false
var p; var level; var DM; var PM; var CM
var v0 := Vector3.ZERO; var r0 := 0.0; var maxy := 0.0; var full_speed_dist := 0.0
func add(k: int, cb: Callable) -> void: steps.append([k, cb])
func axis(a: int, v: float) -> void:
	var e := InputEventJoypadMotion.new(); e.axis = a; e.axis_value = v; Input.parse_input_event(e)
func button(b: int, down: bool = true) -> void:
	var e := InputEventJoypadButton.new(); e.button_index = b; e.pressed = down; Input.parse_input_event(e)
func tap(b: int) -> void: button(b, true); button(b, false)
func key(k: Key) -> void:
	var e := InputEventKey.new(); e.physical_keycode = k; e.keycode = k; e.pressed = true; Input.parse_input_event(e)
	var r := InputEventKey.new(); r.physical_keycode = k; r.keycode = k; r.pressed = false; Input.parse_input_event(r)
func combat_state() -> String: return p.combat.State.keys()[p.combat.state]

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	level = load("res://levels/test_level.tscn").instantiate(); root.add_child(level); current_scene = level

func _physics_process(_d: float) -> bool:
	f += 1
	if finished: return done()
	if f > 1 and p: maxy = maxf(maxy, p.global_position.y)
	if f == 3:
		p = level.get_node("Player"); DM = autoload("DialogueManager"); PM = autoload("PauseMenu"); CM = autoload("CharacterMenu")
		for i in [1, 2, 3]: level.get_node("GreyfangPack/Wolf%d" % i).set_physics_process(false)
		add(2, func(): axis(JOY_AXIS_LEFT_Y, -1.0))
		add(20, func(): v0 = p.global_position)
		add(60, func():
			full_speed_dist = v0.z - p.global_position.z
			between(full_speed_dist, 4.0, 5.3, "metres moved in 1 s with the left stick fully up")
			axis(JOY_AXIS_LEFT_Y, -0.4))
		add(20, func(): v0 = p.global_position)
		add(60, func():
			between(v0.z - p.global_position.z, 0.5, full_speed_dist * 0.6, "metres moved in 1 s at 40% stick (slower)")
			axis(JOY_AXIS_LEFT_Y, 0.0))
		add(20, func(): axis(JOY_AXIS_RIGHT_X, 1.0))
		add(5, func(): r0 = p.rotation.y)
		add(30, func():
			between(rad_to_deg(r0 - p.rotation.y), 70, 115, "degrees turned in 0.5 s, right stick full right")
			axis(JOY_AXIS_RIGHT_X, 0.3))
		add(5, func(): r0 = p.rotation.y)
		add(30, func():
			between(rad_to_deg(r0 - p.rotation.y), 0.5, 10, "degrees turned at 30% stick (response curve: much finer)")
			axis(JOY_AXIS_RIGHT_X, 0.0))
		add(5, func(): maxy = 0.0; tap(JOY_BUTTON_A))
		add(40, func(): between(maxy, 0.9, 1.2, "A jumps"))
		# prompts follow the device
		add(5, func(): p.global_position = Vector3(2, 0, -2); p.rotation.y = 0; p.head.rotation.x = 0; axis(JOY_AXIS_LEFT_X, 0.0); button(JOY_BUTTON_DPAD_LEFT, false))
		add(5, func():
			ok(p.hud.prompt_label.text == "[X] Talk to Maren", "gamepad interact prompt", p.hud.prompt_label.text)
			ok(p.hud.powers_label.text.begins_with("LB"), "gamepad power prompt", p.hud.powers_label.text)
			ok(p.hud.spell_label.text.contains("[Y] switch"), "gamepad switch-spell prompt", p.hud.spell_label.text)
			key(KEY_SHIFT))
		add(3, func():
			ok(p.hud.prompt_label.text == "[E] Talk to Maren", "keyboard prompt after a key press", p.hud.prompt_label.text)
			ok(p.hud.spell_label.text.contains("[Q] switch"), "keyboard switch-spell prompt", p.hud.spell_label.text)
			tap(JOY_BUTTON_X))
		add(5, func():
			ok(DM.is_active, "X talks")
			ok(DM.choices_box.get_child(0).modulate != Color.WHITE, "first choice highlighted")
			tap(JOY_BUTTON_DPAD_DOWN))
		add(3, func(): ok(DM._selected == 1, "D-pad down selects the next choice", DM._selected); tap(JOY_BUTTON_DPAD_UP))
		add(3, func(): ok(DM._selected == 0, "D-pad up goes back", DM._selected); tap(JOY_BUTTON_A))
		add(5, func():
			ok(DM.line_label.text.begins_with("The Greyfang pack"), "A picks the choice", DM.line_label.text.substr(0, 50))
			tap(JOY_BUTTON_B))
		add(5, func(): ok(not DM.is_active, "B closes the dialogue"))
		# combat on the triggers
		add(10, func(): axis(JOY_AXIS_TRIGGER_RIGHT, 1.0))
		add(4, func(): axis(JOY_AXIS_TRIGGER_RIGHT, 0.0))
		add(3, func(): ok(combat_state() in ["WINDUP", "ACTIVE"], "RT attacks", combat_state()))
		add(40, func(): autoload("Spellbook").ready_block(); axis(JOY_AXIS_TRIGGER_LEFT, 1.0))
		add(10, func(): ok(combat_state() == "BLOCKING", "LT blocks with Block ready", combat_state()); axis(JOY_AXIS_TRIGGER_LEFT, 0.0))
		add(10, func(): tap(JOY_BUTTON_B))
		add(4, func():
			ok(combat_state() == "DODGING", "B dodges in the game", combat_state())
			ok(not PM.is_open, "B doesn't pause"))
		add(30, func(): tap(JOY_BUTTON_START))
		add(5, func():
			var focus = root.gui_get_focus_owner()
			ok(PM.is_open, "Menu pauses")
			ok(focus is Button and focus.text == "Resume", "Resume has focus", focus)
			tap(JOY_BUTTON_B))
		add(5, func(): ok(not PM.is_open, "B closes the pause menu"); tap(JOY_BUTTON_BACK))
		add(5, func():
			var focus = root.gui_get_focus_owner()
			ok(CM.is_open and CM.tabs.current_tab == 0, "View opens the Tab menu", [CM.is_open, CM.tabs.current_tab])
			ok(focus != null, "something has focus in the Tab menu")
			tap(JOY_BUTTON_RIGHT_SHOULDER))
		add(5, func():
			var focus = root.gui_get_focus_owner()
			ok(CM.tabs.current_tab == 1, "RB next tab", CM.tabs.current_tab)
			ok(focus is ItemList, "inventory list has focus", focus)
			tap(JOY_BUTTON_LEFT_SHOULDER))
		add(5, func(): ok(CM.tabs.current_tab == 0, "LB previous tab", CM.tabs.current_tab); tap(JOY_BUTTON_B))
		add(5, func(): ok(not CM.is_open, "B closes the Tab menu"); finished = true)
	if steps.is_empty() or f < 3: return false
	wait += 1
	if wait >= steps[0][0]:
		wait = 0
		steps.pop_front()[1].call()
	return false
