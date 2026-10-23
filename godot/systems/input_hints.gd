extends Node

# Knows whether the player is on keyboard & mouse or a gamepad (whichever was
# used last), and names the button for an action, so prompts can say
# "[E] Talk" or "[X] Talk". Autoloaded as "InputHints".
#   InputHints.label("interact")    -> "E" or "X"
# Names come from the Input Map, so rebinding an action changes the prompt too.
# Gamepad names use the Xbox layout.

signal device_changed

const PAD_BUTTONS := {
	JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu", JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
	JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right",
}
const PAD_AXES := {JOY_AXIS_TRIGGER_LEFT: "LT", JOY_AXIS_TRIGGER_RIGHT: "RT"}
const MOUSE_BUTTONS := {MOUSE_BUTTON_LEFT: "Left-click", MOUSE_BUTTON_RIGHT: "Right-click", MOUSE_BUTTON_MIDDLE: "Middle-click"}

var using_gamepad := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # notice the switch in menus too


func _input(event: InputEvent) -> void:
	var pad: bool = event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5)
	var desk: bool = event is InputEventKey or event is InputEventMouseButton \
			or (event is InputEventMouseMotion and event.relative.length() > 3.0)
	if pad and not using_gamepad:
		using_gamepad = true
		device_changed.emit()
	elif desk and using_gamepad:
		using_gamepad = false
		device_changed.emit()


## The name of the key / button bound to `action` on the current device.
func label(action: String) -> String:
	if not InputMap.has_action(action):
		return action
	for event in InputMap.action_get_events(action):
		if using_gamepad:
			if event is InputEventJoypadButton:
				return PAD_BUTTONS.get(event.button_index, "Button %d" % event.button_index)
			if event is InputEventJoypadMotion and PAD_AXES.has(event.axis):
				return PAD_AXES[event.axis]
		else:
			if event is InputEventKey:
				return OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode)
			if event is InputEventMouseButton:
				return MOUSE_BUTTONS.get(event.button_index, "Mouse %d" % event.button_index)
	return action
