extends CanvasLayer

# On-screen controls for phones and tablets. Autoloaded as "TouchControls".
# docs/godot-starter/CONTROLS.md, "Touch".
#
# Shown in play when Settings.touch_controls is on (on by default on a touch
# screen; Esc > Settings > Accessibility). The left half of the screen is a
# joystick wherever you put your thumb; dragging on the right half looks around.
# The buttons send the same input actions as the keyboard and gamepad, so nothing
# in the game needs to know it's being touched. While a menu is open the layer
# hides except for a ✕ that closes it; taps in menus are ordinary clicks.
#
# Touches also arrive as emulated mouse clicks; in play those are swallowed so a
# tap isn't also an attack.

const STICK_RADIUS := 90.0      # how far the thumb goes for full speed (at 720 px tall)
const LOOK_SCALE := 0.0045      # radians of turn per pixel dragged (times sensitivity)
const BUTTON_COLOR := Color(0.1, 0.1, 0.12, 0.45)
const BUTTON_PRESSED := Color(0.85, 0.7, 0.35, 0.6)

## The buttons: id -> [action, label, centre (fraction of the screen, from the
## bottom right), radius at 720 px tall]. Sizes scale with the screen's height, so
## a phone's many pixels don't make them tiny (scale()).
const BUTTONS := {
	"attack":   ["attack", "⚔", Vector2(0.11, 0.22), 64.0],
	"cast":     ["cast", "✋", Vector2(0.24, 0.17), 50.0],
	"jump":     ["jump", "⤒", Vector2(0.06, 0.42), 42.0],
	"dodge":    ["dodge", "↷", Vector2(0.17, 0.4), 42.0],
	"interact": ["interact", "E", Vector2(0.28, 0.33), 40.0],
	"crouch":   ["crouch", "▼", Vector2(0.36, 0.16), 36.0],
	"sprint":   ["sprint", "»", Vector2(0.36, 0.3), 36.0],
	"art":      ["weapon_art", "★", Vector2(0.05, 0.62), 34.0],
	"spell":    ["switch_spell", "✦", Vector2(0.14, 0.6), 34.0],
	"command":  ["command", "⚑", Vector2(0.23, 0.55), 30.0],
	"menu":     ["character_menu", "☰", Vector2(0.05, 0.9), 30.0],
	"pause":    ["pause", "Esc", Vector2(0.14, 0.9), 30.0],
	"race":     ["power_race", "Ⅰ", Vector2(0.95, 0.82), 30.0],         # top left: the two powers
	"background": ["power_background", "Ⅱ", Vector2(0.89, 0.82), 30.0],
}

var shown := false              # the play controls are up
var menu_open := false          # a menu is up: only the ✕
var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_now := Vector2.ZERO
var _look_finger := -1
var _held := {}                 # finger -> button id
var _sprint_on := false
var _canvas: Control
var screen_override := Vector2.ZERO   # tests: the headless window is 64 px and won't resize


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_controls)
	add_child(_canvas)


func enabled() -> bool:
	return Settings.touch_controls


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	var in_play: bool = enabled() and player != null and not player.is_dead
	var paused := get_tree().paused or DialogueManager.is_active
	var now_shown: bool = in_play and not paused and player.hud.visible
	var now_menu: bool = enabled() and player != null and paused
	if now_shown != shown or now_menu != menu_open:
		if not now_shown:
			_release_all()
		shown = now_shown
		menu_open = now_menu
	if _stick_finger != -1:
		# Every frame, not only on a drag: a thumb held still keeps you moving even
		# when a button's action event goes through Input in between.
		_set_stick((_stick_now - _stick_origin) / (STICK_RADIUS * scale()))
	_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if not enabled():
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION and shown:
		get_viewport().set_input_as_handled()   # a touch, as a click: not an attack
		return
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	if menu_open:
		if event is InputEventScreenTouch and event.pressed and _close_rect().has_point(event.position):
			_send(_close_action(), true)
			_send(_close_action(), false)
			get_viewport().set_input_as_handled()
		return
	if not shown:
		return
	if event is InputEventScreenTouch:
		_touch(event.index, event.position, event.pressed)
	else:
		_drag(event.index, event.position, event.relative)
	get_viewport().set_input_as_handled()


func _touch(finger: int, at: Vector2, pressed: bool) -> void:
	if pressed:
		var id := _button_at(at)
		if id != "":
			_held[finger] = id
			if id == "sprint":
				_sprint_on = not _sprint_on
				_send("sprint", _sprint_on)   # held down until tapped again (an event, like the rest)
			else:
				_send(BUTTONS[id][0], true)
		elif at.x < _size().x * 0.5 and _stick_finger == -1:
			_stick_finger = finger
			_stick_origin = at
			_stick_now = at
		elif _look_finger == -1:
			_look_finger = finger
		return
	if _held.has(finger):
		var id: String = _held[finger]
		_held.erase(finger)
		if id != "sprint":
			_send(BUTTONS[id][0], false)
	elif finger == _stick_finger:
		_stick_finger = -1
		_set_stick(Vector2.ZERO)
	elif finger == _look_finger:
		_look_finger = -1


func _drag(finger: int, at: Vector2, relative: Vector2) -> void:
	if finger == _stick_finger:
		_stick_now = at
		_set_stick((at - _stick_origin) / (STICK_RADIUS * scale()))
	elif finger == _look_finger:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.look(relative * LOOK_SCALE)


## The stick, as -1..1 on each axis, into the movement actions (with strength).
func _set_stick(v: Vector2) -> void:
	v = v.limit_length(1.0)
	for pair in [["move_left", -v.x], ["move_right", v.x], ["move_forward", -v.y], ["move_back", v.y]]:
		if pair[1] > 0.05:
			Input.action_press(pair[0], pair[1])
		else:
			Input.action_release(pair[0])


## An action, as if its key went down or up (handlers that read events see it too).
func _send(action: String, pressed: bool) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	event.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(event)


func _release_all() -> void:
	for finger in _held:
		if _held[finger] != "sprint":
			_send(BUTTONS[_held[finger]][0], false)
	_held.clear()
	_stick_finger = -1
	_look_finger = -1
	_set_stick(Vector2.ZERO)


func _size() -> Vector2:
	return screen_override if screen_override != Vector2.ZERO else _canvas.get_viewport_rect().size


## Everything's sizes, by the screen's height (1 at 720 px).
func scale() -> float:
	return clampf(_size().y / 720.0, 0.6, 3.0)


func radius(id: String) -> float:
	return BUTTONS[id][3] * scale()


## A button's centre on screen.
func center(id: String) -> Vector2:
	var size := _size()
	var at: Vector2 = BUTTONS[id][2]
	return Vector2(size.x * (1.0 - at.x), size.y * (1.0 - at.y))


func _button_at(at: Vector2) -> String:
	for id in BUTTONS:
		if at.distance_to(center(id)) <= radius(id) * 1.15:   # a little generous for thumbs
			return id
	return ""


func _close_rect() -> Rect2:
	var side := 84.0 * scale()
	return Rect2(Vector2(_size().x - side - 12.0, 12.0), Vector2(side, side))


func _close_action() -> String:
	return "character_menu" if CharacterMenu.is_open else "ui_cancel"


func _draw_controls() -> void:
	var font := ThemeDB.fallback_font
	if menu_open:
		var r := _close_rect()
		_canvas.draw_circle(r.get_center(), r.size.x * 0.5, BUTTON_COLOR)
		var x_size := int(40 * scale())
		_canvas.draw_string(font, r.get_center() + Vector2(-x_size * 0.35, x_size * 0.35), "✕", HORIZONTAL_ALIGNMENT_LEFT, -1, x_size)
		return
	if not shown:
		return
	if _stick_finger != -1:
		var reach := STICK_RADIUS * scale()
		_canvas.draw_circle(_stick_origin, reach, Color(1, 1, 1, 0.08))
		_canvas.draw_arc(_stick_origin, reach, 0, TAU, 48, Color(1, 1, 1, 0.3), 2.0)
		_canvas.draw_circle(_stick_origin + (_stick_now - _stick_origin).limit_length(reach), 34.0 * scale(), Color(1, 1, 1, 0.35))
	var held_ids := _held.values()
	for id in BUTTONS:
		var on: bool = id in held_ids or (id == "sprint" and _sprint_on)
		var r := radius(id)
		_canvas.draw_circle(center(id), r, BUTTON_PRESSED if on else BUTTON_COLOR)
		_canvas.draw_arc(center(id), r, 0, TAU, 40, Color(1, 1, 1, 0.35), 2.0)
		var size := int(r * 0.7)
		var label: String = BUTTONS[id][1]
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		_canvas.draw_string(font, center(id) + Vector2(-width * 0.5, size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
