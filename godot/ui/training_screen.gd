extends CanvasLayer

# A lesson with a trainer. Autoloaded as "TrainingScreen".
#   TrainingScreen.open("brannoc")   (a dialogue choice does it with "open_training")
# Shows the skill, the level you'd reach, the price and the lessons you have
# left this level; Train buys one, as many times as you like and can. Esc
# closes. Pauses the game. The rules are systems/training.gd.

var is_open := false
var trainer := ""
var _panel: PanelContainer
var _title: Label
var _info: Label
var _note: Label
var _train: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(460, 0)
	_panel.visible = false
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.07, 0.075, 0.09, 0.96)
	backing.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", backing)
	root.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	box.add_child(_title)
	_info = Label.new()
	_info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	box.add_child(_info)
	_train = Button.new()
	_train.pressed.connect(func(): train())
	box.add_child(_train)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.add_theme_color_override("font_color", Color(0.95, 0.65, 0.5))
	box.add_child(_note)
	var done := Button.new()
	done.text = "Done (Esc)"
	done.pressed.connect(close)
	box.add_child(done)
	for button in [_train, done]:
		for state in [["normal", 0.2], ["hover", 0.28], ["pressed", 0.34], ["focus", 0.24], ["disabled", 0.12]]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(state[1], state[1] + 0.01, state[1] + 0.04)
			style.set_corner_radius_all(4)
			style.content_margin_top = 6
			style.content_margin_bottom = 6
			button.add_theme_stylebox_override(state[0], style)


func _input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


func open(trainer_id: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.is_dead or is_open or not Training.TRAINERS.has(trainer_id):
		return
	trainer = trainer_id
	is_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.hud.hide()
	_note.text = ""
	_refresh()
	_panel.visible = true
	_panel.reset_size()
	_panel.position = (get_viewport().get_visible_rect().size - _panel.size) / 2.0
	_train.grab_focus()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.hud.show()


## Takes one lesson (tests call it too).
func train() -> bool:
	var reason := Training.why_not(trainer)
	if reason != "":
		_note.text = reason
		return false
	var skill: String = Training.TRAINERS[trainer]["skill"]
	var price := Training.cost(skill)
	Training.train(trainer)
	_note.text = "%s rises to %d (%d gold)." % [Skills.SKILLS[skill]["name"], Skills.levels[skill], price]
	_refresh()
	return true


func _refresh() -> void:
	var def: Dictionary = Training.TRAINERS[trainer]
	var skill: String = def["skill"]
	var skill_name: String = Skills.SKILLS[skill]["name"]
	_title.text = "%s teaches %s" % [def["name"], skill_name]
	_info.text = "%s: %d (they teach up to %d)\nLessons left this level: %d of %d\nYour gold: %d" % [
			skill_name, Skills.levels[skill], def["max"], Training.lessons_left(), Training.LESSONS_PER_LEVEL, Inventory.gold]
	_train.text = "Train to %d (%d gold)" % [Skills.levels[skill] + 1, Training.cost(skill)]
	_train.disabled = Training.why_not(trainer) != ""
	if _train.disabled and _note.text == "":
		_note.text = Training.why_not(trainer)
