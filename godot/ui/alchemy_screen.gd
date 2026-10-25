extends CanvasLayer

# Brewing. Autoloaded as "AlchemyScreen". Using a mortar and pestle from the pack
# opens it (Inventory.use). Lists the ingredients you carry; pick two or three
# and it shows what they'd make, then Brew. Esc closes. Pauses the game. The
# rules are systems/alchemy.gd.

var is_open := false
var chosen: Array = []          # ingredient ids
var _panel: PanelContainer
var _title: Label
var _list: GridContainer
var _preview: Label
var _note: Label
var _brew: Button
var _done: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(620, 0)
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
	_title.text = "Brewing"
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	box.add_child(_title)
	_list = GridContainer.new()
	_list.columns = 2
	_list.add_theme_constant_override("h_separation", 8)
	_list.add_theme_constant_override("v_separation", 6)
	box.add_child(_list)
	_preview = Label.new()
	_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview.custom_minimum_size = Vector2(580, 0)   # a wrapping label needs a width to size the panel by
	_preview.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	box.add_child(_preview)
	_brew = Button.new()
	_brew.text = "Brew"
	_brew.pressed.connect(func(): brew())
	box.add_child(_brew)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(580, 0)
	_note.add_theme_color_override("font_color", Color(0.95, 0.65, 0.5))
	box.add_child(_note)
	_done = Button.new()
	_done.text = "Done (Esc)"
	_done.pressed.connect(close)
	box.add_child(_done)
	for button in [_brew, _done]:
		_style(button)


func _style(button: Button) -> void:
	for state in [["normal", 0.2], ["hover", 0.28], ["pressed", 0.34], ["focus", 0.24], ["disabled", 0.12]]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(state[1], state[1] + 0.01, state[1] + 0.04)
		style.set_corner_radius_all(4)
		style.content_margin_top = 6
		style.content_margin_bottom = 6
		style.content_margin_left = 8
		style.content_margin_right = 8
		button.add_theme_stylebox_override(state[0], style)


func _input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.is_dead or is_open:
		return
	if CharacterMenu.is_open:
		CharacterMenu.close()   # used from the pack: brewing takes over the screen
	is_open = true
	chosen.clear()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.hud.hide()
	_note.text = ""
	_panel.visible = true
	_refresh()
	var first := _list.get_child(0) if _list.get_child_count() > 0 else _done
	first.grab_focus()


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


## The ingredients you carry, by name.
func ingredients() -> Array:
	var out := []
	for id in Inventory.items:
		var item := Inventory.get_item(id)
		if item and not item.alchemy_effects.is_empty() and Inventory.count(id) > 0:
			out.append(id)
	out.sort_custom(func(a, b): return Inventory.get_item(a).display_name < Inventory.get_item(b).display_name)
	return out


## Picks or puts back an ingredient (tests call it too).
func toggle(id: String) -> void:
	if id in chosen:
		chosen.erase(id)
	elif chosen.size() < 3:
		chosen.append(id)
	_note.text = ""
	_refresh()


## Brews what's chosen (tests call it too). Returns the potion ids made.
func brew() -> Array:
	var reason := Alchemy.why_not(chosen)
	if reason != "":
		_note.text = reason
		return []
	var made := Alchemy.brew(chosen)
	var counts := {}
	for id in made:
		counts[id] = counts.get(id, 0) + 1
	_note.text = "You brewed " + ", ".join(counts.keys().map(func(id):
			return "%s%s" % [Inventory.get_item(id).display_name, " ×%d" % counts[id] if counts[id] > 1 else ""])) + "."
	chosen = chosen.filter(func(id): return Inventory.count(id) > 0)
	_refresh()
	return made


func _refresh() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var focused_id: String = focused.get_meta("ingredient", "") if focused else ""
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var have := ingredients()
	for id in have:
		var item := Inventory.get_item(id)
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = id in chosen
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(285, 0)
		button.text = "%s%s ×%d" % ["✓ " if id in chosen else "", item.display_name, Inventory.count(id)]
		button.tooltip_text = _effect_names(id)
		button.set_meta("ingredient", id)
		button.pressed.connect(toggle.bind(id))
		_style(button)
		_list.add_child(button)
		if id == focused_id:
			(func(): if button.is_inside_tree(): button.grab_focus()).call_deferred()   # unless refreshed again first
	if have.is_empty():
		_preview.text = "You have no ingredients. Herbs grow wild, Maren sells some, and wolves give fangs."
	elif chosen.size() < 2:
		_preview.text = "Choose two or three ingredients. Those that share an effect make a potion of it."
		for id in chosen:
			_preview.text += "\n%s: %s" % [Inventory.get_item(id).display_name, _effect_names(id)]
	else:
		var shared := Alchemy.shared_effects(chosen)
		if shared.is_empty():
			_preview.text = "They have nothing in common."
		else:
			var t := Alchemy.tier()
			_preview.text = "Makes: " + ", ".join(shared.map(func(e):
					return Inventory.get_item(Alchemy.potion_id(e, t)).display_name))
	_brew.disabled = Alchemy.why_not(chosen) != ""
	_title.text = "Brewing (Alchemy %d)" % Skills.levels.get("alchemy", Skills.START_LEVEL)
	_panel.reset_size()
	_panel.position = (get_viewport().get_visible_rect().size - _panel.size) / 2.0


func _effect_names(id: String) -> String:
	return ", ".join(Inventory.get_item(id).alchemy_effects.map(func(e): return Alchemy.EFFECTS[e]["name"]))
