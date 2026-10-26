class_name PowersPage
extends ScrollContainer

# Tab → Powers: your four active powers, and the earned ones to choose from for
# the fourth slot (systems/earned_powers.gd). Built in code by CharacterMenu.

const GOLD := Color(0.95, 0.8, 0.45)
const GREY := Color(0.6, 0.6, 0.65)

var _box: VBoxContainer


func _init() -> void:
	name = "Powers"
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 8)
	add_child(_box)


func refresh() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	_label("Your powers", 22, GOLD)
	var slots := [["power_race", "Race"], ["power_background", "Background"], ["power_class", "Class"], ["power_earned", "Earned"]]
	var ids: Array = Character.powers()
	for i in slots.size():
		var id: String = ids[i]
		var text := "%s  (%s):  " % [slots[i][1], InputHints.label(slots[i][0])]
		text += "%s  -  %s" % [Character.ability_list[id]["name"], Character.ability_list[id]["description"]] if id != "" else "none"
		_label(text, 16, Color.WHITE if id != "" else GREY)
	_label("Earned powers  -  hold one in the fourth slot", 22, GOLD)
	for id in EarnedPowers.all():
		var power: Dictionary = Character.ability_list[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		_box.add_child(row)
		if EarnedPowers.has(id):
			var button := Button.new()
			button.custom_minimum_size = Vector2(110, 36)
			var held: bool = Character.earned_power == id
			button.text = "Held" if held else "Hold"
			button.disabled = held
			button.set_meta("power", id)
			button.pressed.connect(func(): EarnedPowers.choose(id))   # Character.changed redraws the menu
			row.add_child(button)
			_label("%s  -  %s  (every %ds)" % [power["name"], power["description"], int(power["cooldown"])], 16, Color.WHITE, row)
		else:
			_label("%s  -  %s" % [power["name"], EarnedPowers.how_to_earn(id)], 16, GREY, row)


func _label(text: String, size: int, color: Color, parent: Node = null) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	(parent if parent else _box).add_child(label)
	return label
