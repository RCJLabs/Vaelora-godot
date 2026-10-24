extends "res://tests/test_base.gd"
# Race choice in the creator carries into the game: walk/sprint/jump from the race data (and Agility), and race-specific dialogue.
# Argument: human (default), elf or orc.
# Maren's race-specific choice for each race ("" = none).
const RACE_LINE := {"human": "", "elf": "My people still sing of these hills.", "orc": "You're not afraid of an orc on your doorstep?"}
const BASE_JUMP_PEAK := 1.07   # metres, at jump_height_mult 1.0
var f := 0
var cc
var p
var race_id: String
var race: Resource
var max_y := 0.0

func _initialize() -> void:
	race_id = arg("human")
	race = load("res://races/%s.tres" % race_id)
	autoload("SaveSystem").delete_save()
	cc = load("res://ui/character_creation.tscn").instantiate()
	root.add_child(cc)
	current_scene = cc

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		for b in cc.choices.get_children():
			if b is Button and b.text.to_lower() == race_id: b.button_pressed = true; b.emit_signal("pressed")
	if f == 5:
		var details = cc.details.get_children()
		ok(details.size() > 0 and details[0].text == race.display_name, "creator shows the chosen race", details[0].text if details.size() > 0 else "")
		cc.begin()
	if f == 10:
		p = current_scene.get_node("Player")
		ok(current_scene.name == "TestLevel", "Begin loads the level", current_scene.name)
		ok(autoload("GameState").race == race.display_name, "GameState.race", autoload("GameState").race)
		var speed_mult: float = race.move_speed_mult * autoload("Attributes").move_speed_mult()   # race x Agility
		near(p.walk_speed, 5.0 * speed_mult, 0.01, "walk speed")
		near(p.sprint_speed, 8.0 * speed_mult, 0.01, "sprint speed")
		ok(race_id != "elf" or p.walk_speed > 5.4, "elves walk faster than humans", p.walk_speed)
		ok(race_id != "orc" or p.walk_speed < 4.9, "orcs walk slower than humans", p.walk_speed)
		near(p.jump_velocity, 4.5 * sqrt(race.jump_height_mult), 0.01, "jump velocity")
	if f == 80:
		near(p.global_position.y, 0.0, 0.05, "landed")
		Input.action_press("jump")
	if f == 82: Input.action_release("jump")
	if f > 80: max_y = max(max_y, p.global_position.y)
	if f == 160:
		near(max_y, BASE_JUMP_PEAK * race.jump_height_mult, 0.06, "jump peak")
		p.position = Vector3(2, 0, -2)
		p.rotation.y = 0.0   # face Maren (the background's opening may have turned you)
	if f == 170: Input.action_press("interact")
	if f == 171: Input.action_release("interact")
	if f == 175:
		var dm = autoload("DialogueManager")
		var choices: Array = dm.choices_box.get_children().map(func(b): return b.text)
		ok(dm.is_active and choices.size() >= 2 and choices[-1].ends_with("Goodbye."), "talking to Maren", choices)
		var line: String = RACE_LINE[race_id]
		if line == "":
			ok(not choices.any(func(c): return c.ends_with(RACE_LINE["elf"]) or c.ends_with(RACE_LINE["orc"])), "no other race's choice", choices)
		else:
			ok(choices.any(func(c): return c.ends_with(line)), "race-specific choice: " + line, choices)
		autoload("SaveSystem").delete_save()
		return done()
	return false
