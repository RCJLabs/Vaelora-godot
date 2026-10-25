extends "res://tests/test_base.gd"
# Dialogue with Maren: prompt, number-key choices, flags, no moving while talking, Goodbye, Esc, race-specific choices.
var f := 0
var p: CharacterBody3D
var dm

func _initialize() -> void:
	var level = load("res://levels/test_level.tscn").instantiate()
	root.add_child(level)
	p = level.get_node("Player")
	p.position = Vector3(2, 0, -2)
	dm = autoload("DialogueManager")

func key(k: Key) -> void:
	var e := InputEventKey.new(); e.keycode = k; e.physical_keycode = k; e.pressed = true
	Input.parse_input_event(e)
	var r := InputEventKey.new(); r.keycode = k; r.physical_keycode = k; r.pressed = false
	Input.parse_input_event(r)

func choices() -> Array: return dm.choices_box.get_children().map(func(b): return b.text)

func _physics_process(_d: float) -> bool:
	f += 1
	var flags = autoload("GameState").flags
	match f:
		20:
			ok(p.get_node("HUD").prompt_label.text == "[E] Talk to Maren", "talk prompt", p.get_node("HUD").prompt_label.text)
			key(KEY_E)
		25:
			ok(dm.is_active and dm.speaker_label.text == "Maren", "E starts talking to Maren")
			ok(dm.line_label.text.begins_with("A traveller!"), "greeting line", dm.line_label.text)
			ok(choices() == ["1. Why don't people come this way?", "2. Goodbye."], "first choices", choices())
			Input.action_press("move_forward")
		60:
			ok(p.global_position.distance_to(Vector3(2, 0, -2)) < 0.05, "can't walk while talking", p.global_position)
			Input.action_release("move_forward"); key(KEY_1)
		65:
			ok(dm.line_label.text.begins_with("The Greyfang pack."), "key 1 picks the first choice", dm.line_label.text)
			ok(choices().size() == 2 and choices()[0] == "1. I'll deal with them.", "wolf choices", choices())
			key(KEY_1)
		70:
			ok(dm.line_label.text.begins_with("Truly?"), "accepting the wolves", dm.line_label.text)
			ok(flags.get("met_maren") and flags.get("heard_about_wolves") and flags.get("wolf_quest_accepted"), "dialogue sets the flags", flags)
			key(KEY_1)
		72:
			ok(not dm.is_active, "Goodbye closes the dialogue")
			key(KEY_E)
		75:
			ok(dm.line_label.text == "Back again? The kettle's still warm.", "second talk uses the met_maren line", dm.line_label.text)
			ok(choices().size() == 5 and "Who else comes up this road?" in choices()[1] and "Let's trade." in choices()[2] and "[Persuade 30" in choices()[3], "second talk choices (and a Speech check)", choices())
		76: key(KEY_ESCAPE)
		80: ok(not dm.is_active, "Esc closes the dialogue")
		81: autoload("GameState").race = "Orc"; autoload("GameState").flags = {}; key(KEY_E)
		85:
			ok(choices().size() == 3 and choices()[1] == "2. You're not afraid of an orc on your doorstep?", "an orc gets a race-specific choice", choices())
			return done()
	return false
