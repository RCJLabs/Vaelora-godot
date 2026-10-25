extends CanvasLayer

# The forge. Autoloaded as "SmithingScreen". A forge in the world opens it
# (props/forge.gd); a smith's hammer does too with Field Smith, for improving
# only. Three tabs: Forge (make something from a recipe), Improve (raise what
# you carry a quality step) and Salvage (with the perk). Pick an item, then the
# button. Esc closes. Pauses the game. The rules are systems/smithing.gd.

var is_open := false
var at_forge := true            # false: the hammer in the field, improving only
var mode := "forge"             # "forge", "improve" or "salvage"
var selected := ""
var _panel: PanelContainer
var _title: Label
var _tabs: HBoxContainer
var _list: GridContainer
var _detail: Label
var _note: Label
var _act: Button
var _done: Button


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(660, 0)
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
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 8)
	box.add_child(_tabs)
	for tab in [["forge", "Forge"], ["improve", "Improve"], ["salvage", "Salvage"]]:
		var button := Button.new()
		button.text = tab[1]
		button.toggle_mode = true
		button.set_meta("mode", tab[0])
		button.pressed.connect(set_mode.bind(tab[0]))
		_style(button)
		_tabs.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 250)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_list = GridContainer.new()
	_list.columns = 2
	_list.add_theme_constant_override("h_separation", 8)
	_list.add_theme_constant_override("v_separation", 6)
	scroll.add_child(_list)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(620, 0)   # a wrapping label needs a width to size the panel by
	_detail.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	box.add_child(_detail)
	_act = Button.new()
	_act.pressed.connect(func(): act())
	box.add_child(_act)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(620, 0)
	_note.add_theme_color_override("font_color", Color(0.95, 0.65, 0.5))
	box.add_child(_note)
	_done = Button.new()
	_done.text = "Done (Esc)"
	_done.pressed.connect(close)
	box.add_child(_done)
	for button in [_act, _done]:
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


## `forge`: at a forge (everything), or the hammer in the field (improving only).
func open(forge: bool = true) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.is_dead or is_open:
		return
	if CharacterMenu.is_open:
		CharacterMenu.close()   # the hammer, used from the pack
	is_open = true
	at_forge = forge
	mode = "forge" if forge else "improve"
	selected = ""
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.hud.hide()
	_note.text = ""
	_panel.visible = true
	_refresh()
	var first: Control = _list.get_child(0) if _list.get_child_count() > 0 else _done
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


func set_mode(new_mode: String) -> void:
	mode = new_mode
	selected = ""
	_note.text = ""
	_refresh()


## The ids the current tab lists.
func entries() -> Array:
	var out := []
	match mode:
		"forge":
			out = Smithing.RECIPES.keys()
		"improve":
			for id in Inventory.items:
				var item := Inventory.get_item(id)
				if item and Smithing.MATERIALS.has(item.material):
					out.append(id)
		"salvage":
			for id in Inventory.items:
				if not Smithing.salvage_yield(id).is_empty():
					out.append(id)
	out.sort_custom(func(a, b): return Inventory.get_item(a).display_name < Inventory.get_item(b).display_name)
	return out


func select(id: String) -> void:
	selected = id
	_note.text = ""
	_refresh()


## Does the tab's action to the selected item (tests call it too).
func act() -> bool:
	var reason := _why_not()
	if reason != "":
		_note.text = reason
		return false
	var before := Smithing.display_name(selected)
	match mode:
		"forge":
			Smithing.forge(selected)
			_note.text = "You forged %s%s." % [Inventory.get_item(selected).display_name,
					" ×%d" % Smithing.makes(selected) if Smithing.makes(selected) > 1 else ""]
		"improve":
			Smithing.improve(selected)
			_note.text = "%s is now %s." % [before, Smithing.QUALITY_NAMES[Smithing.quality_of(selected)]]
		"salvage":
			Smithing.salvage(selected)
			_note.text = "You broke down %s." % before
			if Inventory.count(selected) == 0:
				selected = ""
	_refresh()
	return true


func _why_not() -> String:
	if selected == "":
		return "Choose something first."
	match mode:
		"forge":
			return Smithing.why_not_forge(selected) if at_forge else "You need a forge."
		"improve":
			return Smithing.why_not_improve(selected)
		"salvage":
			return Smithing.why_not_salvage(selected) if at_forge else "You need a forge."
	return ""


func _refresh() -> void:
	for tab in _tabs.get_children():
		var tab_mode: String = tab.get_meta("mode")
		tab.button_pressed = tab_mode == mode
		tab.visible = (at_forge or tab_mode == "improve") and (tab_mode != "salvage" or "salvage" in Character.perks)
	var focused := get_viewport().gui_get_focus_owner()
	var focused_id: String = focused.get_meta("entry", "") if focused else ""
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for id in entries():
		var button := Button.new()
		button.toggle_mode = true
		button.button_pressed = id == selected
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(300, 0)
		var label := Smithing.display_name(id) if mode != "forge" else Inventory.get_item(id).display_name
		button.text = "%s%s%s" % ["▸ " if id == selected else "", label, "" if mode == "forge" else " ×%d" % Inventory.count(id)]
		button.set_meta("entry", id)
		button.pressed.connect(select.bind(id))
		_style(button)
		_list.add_child(button)
		if id == focused_id:
			(func(): if button.is_inside_tree(): button.grab_focus()).call_deferred()   # unless refreshed again first
	_detail.text = _describe()
	_act.text = {"forge": "Forge", "improve": "Improve", "salvage": "Break down"}[mode]
	_act.disabled = _why_not() != ""
	_title.text = "%s (Smithing %d)" % ["Forge" if at_forge else "Smith's Hammer", Skills.levels.get("smithing", Skills.START_LEVEL)]
	_panel.reset_size()
	_panel.position = (get_viewport().get_visible_rect().size - _panel.size) / 2.0


func _describe() -> String:
	if selected == "":
		match mode:
			"forge":
				return "Choose something to make. Ingots, wood and strips are at Maren's; pelts come from wolves."
			"improve":
				return "Choose something to improve. Each step uses one of what it's made of. You can reach %s." % \
						Smithing.QUALITY_NAMES[Smithing.max_quality()]
			"salvage":
				return "Choose something to break down for half its materials."
	var item := Inventory.get_item(selected)
	match mode:
		"forge":
			var parts := []
			var need := Smithing.needs(selected)
			for material in need:
				parts.append("%d %s (you have %d)" % [need[material], Inventory.get_item(material).display_name, Inventory.count(material)])
			return "%s%s: %s" % [item.display_name, " ×%d" % Smithing.makes(selected) if Smithing.makes(selected) > 1 else "", ", ".join(parts)]
		"improve":
			var q := Smithing.quality_of(selected)
			var material := Inventory.get_item(Smithing.MATERIALS[item.material])
			var now := "%s: %s" % [Smithing.display_name(selected), _stat(item)]
			if q >= mini(Smithing.max_quality(item), Smithing.MAX_QUALITY):
				return now
			return "%s. Next: %s, for 1 %s (you have %d)." % [now, Smithing.QUALITY_NAMES[q + 1], material.display_name, Inventory.count(material.id)]
		"salvage":
			var back := Smithing.salvage_yield(selected)
			return "Breaking down %s gives back %s." % [item.display_name,
					", ".join(back.keys().map(func(m): return "%d %s" % [back[m], Inventory.get_item(m).display_name]))]
	return ""


func _stat(item: ItemData) -> String:
	if item.type == ItemData.Type.ARMOR:
		return "armour %d (base %d)" % [roundi(Armor.piece_armor(item)), roundi(item.armor)]
	if item.slot_name() == "off_hand":
		return "blocks %d%% (base %d%%)" % [roundi(Smithing.block_reduction(item) * 100), roundi(item.block_reduction * 100)]
	return "damage %.1f (base %.0f)" % [item.damage * Smithing.damage_mult(item), item.damage]
