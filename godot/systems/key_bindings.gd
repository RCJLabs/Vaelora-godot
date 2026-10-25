extends Node

# Player key / button bindings, changed in Settings > Controls and saved to
# user://controls.cfg (separate from save games: they apply to every character).
# Autoloaded as "KeyBindings". Each action has one keyboard-or-mouse binding and
# one gamepad binding that the player can change; the defaults come from the
# project's Input Map.
#   KeyBindings.rebind("jump", false, event)   -> "" or the action it was taken from
#   KeyBindings.reset()
# Prompts (InputHints) read the Input Map, so they follow changes by themselves.

signal changed

const PATH := "user://controls.cfg"
## The actions the player can rebind, in the order the Controls page lists them.
## (Mouse/stick look, the pause button and menu navigation stay fixed.)
const ACTIONS := [
	["move_forward", "Move forward"], ["move_back", "Move back"],
	["move_left", "Move left"], ["move_right", "Move right"],
	["sprint", "Sprint"], ["crouch", "Sneak (crouch)"], ["jump", "Jump / climb"], ["dodge", "Dodge"],
	["attack", "Attack (right hand)"], ["cast", "Left hand (cast / block / aim)"],
	["switch_spell", "Switch spell"], ["interact", "Use / talk"], ["toggle_view", "First / third person"],
	["power_race", "Race power"], ["power_background", "Background power"], ["power_class", "Class power"],
	["weapon_art", "Weapon art"], ["command", "Command (point out a target)"],
	["character_menu", "Character menu"], ["journal", "Journal"], ["map", "Map"],
	["quicksave", "Quicksave"], ["quickload", "Load latest save"],
]

var _defaults := {}   # action -> Array of event dictionaries, as the project shipped


func _ready() -> void:
	for pair in ACTIONS:
		_defaults[pair[0]] = InputMap.action_get_events(pair[0]).map(_to_dict)
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return
	for pair in ACTIONS:
		var action: String = pair[0]
		if config.has_section_key("bindings", action):
			_set_events(action, config.get_value("bindings", action, []).map(_from_dict).filter(func(e): return e != null))


## The action's current binding for keyboard & mouse (gamepad false) or gamepad, or null.
func binding(action: String, gamepad: bool) -> InputEvent:
	for event in InputMap.action_get_events(action):
		if is_gamepad(event) == gamepad:
			return event
	return null


## A short name for an event: "E", "Left-click", "A", "RT"...
func event_name(event: InputEvent) -> String:
	if event == null:
		return "-"
	if event is InputEventKey:
		return OS.get_keycode_string(event.physical_keycode if event.physical_keycode else event.keycode)
	if event is InputEventMouseButton:
		return InputHints.MOUSE_BUTTONS.get(event.button_index, "Mouse %d" % event.button_index)
	if event is InputEventJoypadButton:
		return InputHints.PAD_BUTTONS.get(event.button_index, "Button %d" % event.button_index)
	if event is InputEventJoypadMotion:
		if InputHints.PAD_AXES.has(event.axis):
			return InputHints.PAD_AXES[event.axis]
		var stick := "Left stick" if event.axis <= JOY_AXIS_LEFT_Y else "Right stick"
		var direction := ["left", "right"] if event.axis % 2 == 0 else ["up", "down"]
		return "%s %s" % [stick, direction[0] if event.axis_value < 0.0 else direction[1]]
	return event.as_text()


## Can `event` be bound (and is it a press, not a release or a small stick wobble)?
func is_bindable(event: InputEvent) -> bool:
	if event is InputEventKey:
		return event.pressed and not event.echo and event.physical_keycode != KEY_ESCAPE
	if event is InputEventMouseButton:
		return event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2]
	if event is InputEventJoypadButton:
		return event.pressed
	if event is InputEventJoypadMotion:
		return absf(event.axis_value) > 0.6
	return false


func is_gamepad(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion


## Binds `event` to `action` (replacing its keyboard/mouse or gamepad binding).
## If another action already used it, that action loses it: returns its label.
func rebind(action: String, gamepad: bool, event: InputEvent) -> String:
	var clean := _from_dict(_to_dict(event))   # a tidy copy: device -1, pressed state etc.
	var taken_from := ""
	for pair in ACTIONS:
		var other: String = pair[0]
		if other == action:
			continue
		for existing in InputMap.action_get_events(other):
			if _same(existing, clean):
				InputMap.action_erase_event(other, existing)
				taken_from = pair[1]
	for existing in InputMap.action_get_events(action):
		if is_gamepad(existing) == gamepad:
			InputMap.action_erase_event(action, existing)
	InputMap.action_add_event(action, clean)
	_save()
	return taken_from


func reset() -> void:
	for action in _defaults:
		_set_events(action, _defaults[action].map(_from_dict))
	DirAccess.remove_absolute(PATH)
	changed.emit()
	InputHints.device_changed.emit()   # prompts re-read the names


func _set_events(action: String, events: Array) -> void:
	InputMap.action_erase_events(action)
	for event in events:
		InputMap.action_add_event(action, event)


func _save() -> void:
	var config := ConfigFile.new()
	for pair in ACTIONS:
		config.set_value("bindings", pair[0], InputMap.action_get_events(pair[0]).map(_to_dict))
	config.save(PATH)
	changed.emit()
	InputHints.device_changed.emit()


func _same(a: InputEvent, b: InputEvent) -> bool:
	return _to_dict(a) == _to_dict(b)


# Events are saved as small dictionaries (not Godot objects) so the file stays readable.
func _to_dict(event: InputEvent) -> Dictionary:
	if event is InputEventKey:
		return {"type": "key", "code": event.physical_keycode if event.physical_keycode else event.keycode}
	if event is InputEventMouseButton:
		return {"type": "mouse", "button": event.button_index}
	if event is InputEventJoypadButton:
		return {"type": "pad_button", "button": event.button_index}
	if event is InputEventJoypadMotion:
		return {"type": "pad_axis", "axis": event.axis, "sign": 1 if event.axis_value > 0.0 else -1}
	return {}


func _from_dict(data: Dictionary) -> InputEvent:
	match data.get("type", ""):
		"key":
			var key := InputEventKey.new()
			key.physical_keycode = int(data["code"])
			return key
		"mouse":
			var mouse := InputEventMouseButton.new()
			mouse.button_index = int(data["button"])
			return mouse
		"pad_button":
			var button := InputEventJoypadButton.new()
			button.button_index = int(data["button"])
			return button
		"pad_axis":
			var motion := InputEventJoypadMotion.new()
			motion.axis = int(data["axis"])
			motion.axis_value = float(data["sign"])
			return motion
	return null
