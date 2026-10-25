extends "res://tests/test_base.gd"
# Touch controls (ui/touch_controls.gd): the left-half joystick moves (and keeps
# moving while a button is pressed), dragging on the right looks, buttons send the
# same actions as keys (attack, jump, the sprint toggle), a touch's emulated mouse
# click isn't also an attack, and in a menu a ✕ closes it. Touches go through
# Input.parse_input_event like a real screen's.
# (Waits are generous: touches are flushed, and the layer updates, on rendered
# frames, which can lag physics ticks headless.)
var f := 0
var step := 0
var wait := 0
var p
var TC

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func touch(finger: int, at: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = finger; e.position = at; e.pressed = pressed
	Input.parse_input_event(e)

func drag(finger: int, at: Vector2, relative: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = finger; e.position = at; e.relative = relative
	Input.parse_input_event(e)

func tap(finger: int, at: Vector2) -> void:
	touch(finger, at, true)
	touch(finger, at, false)

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	TC = autoload("TouchControls")
	var size: Vector2 = TC._size()
	var thumb := Vector2(size.x * 0.2, size.y * 0.6)
	match step:
		0:
			for i in [1, 2, 3]: current_scene.get_node("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			ok("touch_controls" in autoload("Settings").KEYS, "a Touch controls setting")
			autoload("Settings").touch_controls = false
			TC.screen_override = Vector2(1600, 900)   # a screen to lay the buttons out on (headless has a 64 px one)
			wait = 10
		1:
			ok(not TC.shown, "off by default on a screen without touch")
			autoload("Settings").touch_controls = true
			wait = 10
		2:
			ok(TC.shown and not TC.menu_open, "on: the controls are up in play")
			touch(0, thumb, true)
			drag(0, thumb + Vector2(90, 0) * TC.scale(), Vector2(90, 0) * TC.scale())
			wait = 10
		3:
			near(Input.get_action_strength("move_right"), 1.0, 0.05, "the left thumb pushed right: full speed right")
			ok(Input.get_vector("move_left", "move_right", "move_forward", "move_back").x > 0.9, "and the player's movement reads it")
			tap(7, TC.center("jump"))   # a button while the thumb holds still
			wait = 10
		4:
			near(Input.get_action_strength("move_right"), 1.0, 0.05, "a button pressed meanwhile doesn't stop the stick")
			touch(0, thumb + Vector2(90, 0) * TC.scale(), false)
			wait = 10
		5:
			ok(Input.get_action_strength("move_right") == 0.0, "let go: it stops")
			set_meta("turn", p.rotation.y)
			touch(1, Vector2(size.x * 0.55, size.y * 0.3), true)
			drag(1, Vector2(size.x * 0.55 + 100.0, size.y * 0.3), Vector2(100, 0))
			touch(1, Vector2(size.x * 0.55 + 100.0, size.y * 0.3), false)
			wait = 10
		6:
			ok(not is_equal_approx(p.rotation.y, get_meta("turn")), "a drag on the right turns you", [get_meta("turn"), p.rotation.y])
			touch(2, TC.center("jump"), true)
			wait = 10
		7:
			ok(Input.is_action_pressed("jump"), "the jump button holds Jump")
			touch(2, TC.center("jump"), false)
			tap(3, TC.center("sprint"))
			wait = 10
		8:
			ok(Input.is_action_pressed("sprint"), "sprint: one tap and it stays on")
			tap(3, TC.center("sprint"))
			wait = 10
		9:
			ok(not Input.is_action_pressed("sprint"), "and another turns it off")
			var click := InputEventMouseButton.new()
			click.device = InputEvent.DEVICE_ID_EMULATION
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = true
			click.position = Vector2(size.x * 0.55, size.y * 0.3)
			Input.parse_input_event(click)
			wait = 10
		10:
			ok(p.combat.state == p.combat.State.READY, "a touch's emulated click isn't an attack", p.combat.state)
			tap(4, TC.center("attack"))
			wait = 3
		11:
			ok(p.combat.state != p.combat.State.READY, "the attack button swings", p.combat.state)
			wait = 30
		12:
			tap(5, TC.center("menu"))
			wait = 10
		13:
			ok(autoload("CharacterMenu").is_open, "the menu button opens the character menu")
			ok(TC.menu_open and not TC.shown, "in a menu, only the ✕")
			tap(6, TC._close_rect().get_center())
			wait = 10
		14:
			ok(not autoload("CharacterMenu").is_open, "the ✕ closes it")
			ok(TC.shown, "and the controls are back")
			autoload("Settings").touch_controls = false
			TC.screen_override = Vector2.ZERO
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
