extends CanvasLayer

# Choosing a new class, after Aurel's rite (the paid respec). Autoloaded as
# "ClassScreen".
#   ClassScreen.open()   (a dialogue choice does it with "open_class_screen")
# The twelve classes down the left; the one picked, its skills and power on the
# right; "Take this road" changes class (Character.change_class), "Keep" or Esc
# closes. Pauses the game. The classes are systems/classes.gd.

var is_open := false
var picked := ""
var _panel: PanelContainer
var _list: VBoxContainer
var _info: Label
var _take: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(760, 0)
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
	var title := Label.new()
	title.text = "Choose your calling"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	box.add_child(row)
	_list = VBoxContainer.new()
	_list.custom_minimum_size.x = 200
	row.add_child(_list)
	var group := ButtonGroup.new()
	for id in Classes.classes:
		var button := Button.new()
		button.text = Classes.name_of(id)
		button.toggle_mode = true
		button.button_group = group
		button.set_meta("class", id)
		button.pressed.connect(func(): pick(id))
		_list.add_child(button)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size.x = 500
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	row.add_child(_info)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	box.add_child(buttons)
	_take = Button.new()
	_take.pressed.connect(func(): take())
	buttons.add_child(_take)
	var keep := Button.new()
	keep.text = "Keep my class (Esc)"
	keep.pressed.connect(close)
	buttons.add_child(keep)


func _input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.is_dead or is_open:
		return
	is_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.hud.hide()
	pick(Character.class_id if Character.class_id != "" else Classes.classes.keys()[0])
	_panel.visible = true
	_panel.reset_size()
	_panel.position = (get_viewport().get_visible_rect().size - _panel.size) / 2.0
	for button in _list.get_children():
		if button.get_meta("class") == picked:
			button.grab_focus()


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


func pick(id: String) -> void:
	picked = id
	for button in _list.get_children():
		button.set_pressed_no_signal(button.get_meta("class") == id)
	var data: Dictionary = Classes.classes[id]
	var power: Dictionary = Character.ability_list.get(data.get("ability", ""), {})
	_info.text = "%s\n\n%s\n\nSkills (+20%% XP): %s\n\nPower (%s): %s - %s" % [data["name"], data["description"],
			Classes.skills_text(id), InputHints.label("power_class"), power.get("name", ""), power.get("description", "")]
	_take.text = "Your road now" if id == Character.class_id else "Take this road"
	_take.disabled = id == Character.class_id


## Becomes the picked class and closes (tests call it too).
func take() -> void:
	Character.change_class(picked)
	close()
