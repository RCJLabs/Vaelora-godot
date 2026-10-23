extends CanvasLayer

# Shows conversations stored as JSON in res://dialogue/.
# Autoloaded as "DialogueManager", so an NPC only has to call:
#   DialogueManager.start("res://dialogue/maren.json", "Maren")
# File format: docs/godot-starter/DIALOGUE.md
#
# Pick a choice with the mouse or number keys 1-9. Esc leaves.

signal finished

@onready var panel: Control = $Panel
@onready var speaker_label: Label = $Panel/Margin/VBox/Speaker
@onready var line_label: Label = $Panel/Margin/VBox/Line
@onready var choices_box: VBoxContainer = $Panel/Margin/VBox/Choices

var is_active := false
var _nodes: Dictionary = {}
var _choices: Array = []   # the choices currently on screen (after conditions)


func _ready() -> void:
	panel.hide()


func start(file_path: String, speaker: String) -> void:
	var data = _load_dialogue(file_path)
	if data == null:
		return
	_nodes = data.get("nodes", {})
	speaker_label.text = speaker
	is_active = true
	panel.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_node(_pick_start(data.get("start", "start")))


func end() -> void:
	is_active = false
	panel.hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	finished.emit()


func choose(index: int) -> void:
	if not is_active or index < 0 or index >= _choices.size():
		return
	var choice: Dictionary = _choices[index]
	_run_actions(choice)
	_show_node(choice.get("next", "end"))


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event.is_action_pressed("ui_cancel"):
		end()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode >= KEY_1 and event.keycode <= KEY_9:
		choose(event.keycode - KEY_1)
		get_viewport().set_input_as_handled()


func _show_node(node_id: String) -> void:
	if node_id == "" or node_id == "end":
		end()
		return
	if not _nodes.has(node_id):
		push_error("Dialogue: no node called '%s'. Check the \"next\" values in the JSON." % node_id)
		end()
		return

	var node: Dictionary = _nodes[node_id]
	_run_actions(node)
	line_label.text = node.get("text", "")

	for old_button in choices_box.get_children():
		choices_box.remove_child(old_button)
		old_button.queue_free()

	_choices = node.get("choices", []).filter(_conditions_met)
	if _choices.is_empty():
		_choices = [{"text": "(Leave)", "next": "end"}]

	for i in _choices.size():
		var button := Button.new()
		button.text = "%d. %s" % [i + 1, _choices[i].get("text", "...")]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE   # so Space (jump) can't click it
		button.pressed.connect(choose.bind(i))
		choices_box.add_child(button)


# Things a node (when shown) or a choice (when picked) can do:
#   "set_flag": "name" or ["a", "b"]   "give_gold": 50     "take_gold": 10
#   "give_item": "id" or {"id": "id", "count": 2}          "take_item": same
func _run_actions(entry: Dictionary) -> void:
	for flag in Conditions.as_list(entry.get("set_flag", [])):
		GameState.set_flag(flag)
	if entry.has("give_gold"):
		Inventory.add_gold(int(entry["give_gold"]))
	if entry.has("take_gold"):
		Inventory.add_gold(-mini(int(entry["take_gold"]), Inventory.gold))
	if entry.has("give_item"):
		var give := Conditions.item_and_count(entry["give_item"])
		Inventory.add(give[0], give[1])
	if entry.has("take_item"):
		var take := Conditions.item_and_count(entry["take_item"])
		Inventory.remove(take[0], take[1])


# "start" is either a node id, or a list of {"node": id, <conditions>}
# where the first entry whose conditions pass is used.
func _pick_start(start) -> String:
	if start is String:
		return start
	for option in start:
		if _conditions_met(option):
			return option.get("node", "")
	push_error("Dialogue: no \"start\" option matched. Add one with no conditions as the last entry.")
	return ""


# Condition rules live in systems/conditions.gd (shared with quests).
func _conditions_met(entry: Dictionary) -> bool:
	return Conditions.met(entry)


func _load_dialogue(file_path: String):
	if not FileAccess.file_exists(file_path):
		push_error("Dialogue: file not found: %s" % file_path)
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(file_path)) != OK:
		push_error("Dialogue: %s line %d: %s" % [file_path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data
