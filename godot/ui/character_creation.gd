extends Control

# Title screen and character creator: five steps (race, background, traits,
# attributes, name & mode), then "Begin journey" calls Character.create() and
# loads the starting level.
# To add a race: create a new .tres in res://races/ and add it to RACE_FILES.
# Backgrounds and traits are read from res://character/*.json.

const RACE_FILES := [
	"res://races/human.tres",
	"res://races/elf.tres",
	"res://races/orc.tres",
]
const START_LEVEL := "res://levels/test_level.tscn"
const GOLD := Color(0.95, 0.8, 0.45)
const BLUE := Color(0.75, 0.85, 1)
const GREY := Color(0.65, 0.65, 0.7)
const RED := Color(1, 0.55, 0.5)
const STEPS := [
	{"title": "Choose your people", "hint": "Your race sets your starting attributes, Health, Stamina and Magicka, and a power (Z)."},
	{"title": "Choose your past", "hint": "Your background decides your starting skills, gear, gold, how Riverwatch sees you, and a second power (X)."},
	{"title": "Strengths and flaws", "hint": "Pick up to 2 strengths. Taking 1 flaw lets you pick a 3rd strength. Traits are permanent."},
	{"title": "Attributes", "hint": "Spend %d points. You get one more at every level-up (Tab → Skills)."},
	{"title": "Who are you?", "hint": "Name your character and choose how hard the world should be. Modes can't be changed later."},
]

@onready var title_label: Label = %Title
@onready var step_label: Label = %StepLabel
@onready var hint_label: Label = %Hint
@onready var choices: VBoxContainer = %Choices
@onready var details: VBoxContainer = %DetailBox
@onready var back_button: Button = %BackButton
@onready var next_button: Button = %NextButton

var races: Array[RaceData] = []
var step := 0

# The character being built.
var race: RaceData
var background_id := ""
var trait_ids: Array = []
var spend := {}              # attribute id -> points spent here
var player_name := ""
var modes := {"survival": false, "hardcore": false}


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for path in RACE_FILES:
		races.append(load(path))
	race = races[0]
	background_id = Character.backgrounds.keys()[0]
	back_button.pressed.connect(_go.bind(-1))
	next_button.pressed.connect(_go.bind(1))
	%ContinueButton.pressed.connect(func(): SaveSystem.load_game())   # most recent save
	%LoadButton.pressed.connect(PauseMenu.open_page.bind("load"))
	%SettingsButton.pressed.connect(PauseMenu.open_page.bind("settings"))
	_show_step()


func _go(direction: int) -> void:
	if direction > 0 and step == STEPS.size() - 1:
		begin()
		return
	step = clampi(step + direction, 0, STEPS.size() - 1)
	_show_step()


func _show_step() -> void:
	title_label.text = STEPS[step]["title"]
	hint_label.text = STEPS[step]["hint"].replace("%d", str(Character.CREATION_ATTRIBUTE_POINTS))
	step_label.text = "Step %d of %d" % [step + 1, STEPS.size()]
	# Load / Continue / Settings only on the first step, so they read as the title screen.
	%ContinueButton.visible = step == 0 and SaveSystem.has_save()
	%LoadButton.visible = step == 0 and SaveSystem.has_save()
	%SettingsButton.visible = step == 0
	back_button.visible = step > 0
	next_button.text = "Begin journey" if step == STEPS.size() - 1 else "Next"
	for child in choices.get_children():
		child.queue_free()
	match step:
		0: _build_race_step()
		1: _build_background_step()
		2: _build_traits_step()
		3: _build_attributes_step()
		4: _build_final_step()
	_refresh_details()


func _refresh_details() -> void:
	for child in details.get_children():
		child.queue_free()
	match step:
		0: _race_details()
		1: _background_details()
		2: _traits_details()
		3: _attributes_details()
		4: _final_details()
	next_button.disabled = step == 3 and _points_left() > 0


func begin() -> void:
	Character.create(race, player_name, background_id, trait_ids, spend, modes)
	get_tree().change_scene_to_file(START_LEVEL)


# --- step 1: race -------------------------------------------------------------------------

func _build_race_step() -> void:
	var group := ButtonGroup.new()   # only one can be pressed at a time
	for r in races:
		var button := _choice_button(r.display_name, group)
		button.button_pressed = r == race
		button.pressed.connect(func(): race = r; _refresh_details())


func _race_details() -> void:
	_label(race.display_name, 30)
	_label(race.description, 18)
	var attrs := Character.preview_attributes(race, "", [], {})
	_label("%s\nSpeed %s    Jump %s\n%s" % [_pools_text(attrs), _percent(race.move_speed_mult),
			_percent(race.jump_height_mult), _attributes_text(attrs)], 18, BLUE)
	_label(race.traits, 18)
	_label(_power_text(race.ability_id, "Z"), 18, GOLD)


# --- step 2: background -------------------------------------------------------------------

func _build_background_step() -> void:
	var group := ButtonGroup.new()
	for id in Character.backgrounds:
		var button := _choice_button(Character.backgrounds[id]["name"], group)
		button.button_pressed = id == background_id
		button.pressed.connect(func(): background_id = id; _refresh_details())


func _background_details() -> void:
	var bg: Dictionary = Character.backgrounds[background_id]
	_label(bg["name"], 30)
	_label(bg["description"], 18)
	var lines := []
	if bg.has("attributes"):
		lines.append("Attributes: " + _bonus_list(bg["attributes"], func(id): return Attributes.ATTRIBUTES[id]["name"]))
	if bg.has("skills"):
		lines.append("Skills: " + _bonus_list(bg["skills"], func(id): return Skills.SKILLS[id]["name"]))
	var kit := []
	for id in bg.get("gear", []):
		kit.append(Inventory.get_item(id).display_name)
	for id in bg.get("items", {}):
		kit.append("%s x%d" % [Inventory.get_item(id).display_name, int(bg["items"][id])])
	if not kit.is_empty():
		lines.append("Starts with: " + ", ".join(kit))
	lines.append("Gold: %d" % int(bg.get("gold", 0)))
	for id in bg.get("spells", []):
		lines.append("Knows the spell %s" % Spellbook.get_spell(id).display_name)
	for id in bg.get("reputation", {}):
		lines.append("%s: %+d reputation" % [Reputation.factions[id]["name"], int(bg["reputation"][id])])
	_label("\n".join(lines), 18, BLUE)
	_label(_power_text(bg.get("ability", ""), "X"), 18, GOLD)


# --- step 3: traits -----------------------------------------------------------------------

func _build_traits_step() -> void:
	for positive in [true, false]:
		_label("Strengths" if positive else "Flaws", 22, GOLD if positive else RED, choices)
		for id in Character.trait_list:
			var data: Dictionary = Character.trait_list[id]
			if data["positive"] != positive:
				continue
			var box := _check_box("%s  -  %s" % [data["name"], data["description"]])
			box.button_pressed = id in trait_ids
			box.toggled.connect(_toggle_trait.bind(id))
			box.set_meta("trait", id)
			choices.add_child(box)
	_update_trait_boxes()


func _toggle_trait(on: bool, id: String) -> void:
	if on and not id in trait_ids:
		trait_ids.append(id)
	elif not on:
		trait_ids.erase(id)
		# Dropping the flaw can leave one strength too many: drop the newest.
		while Character.traits_blocker(trait_ids) != "":
			var last_positive = trait_ids.filter(func(t): return Character.trait_list[t]["positive"]).back()
			trait_ids.erase(last_positive)
	_update_trait_boxes()
	_refresh_details()


## Disables the boxes that can't be ticked right now.
func _update_trait_boxes() -> void:
	for box in choices.get_children():
		if not box is CheckBox:
			continue
		var id: String = box.get_meta("trait")
		box.set_pressed_no_signal(id in trait_ids)
		box.disabled = not id in trait_ids and Character.traits_blocker(trait_ids + [id]) != ""


func _traits_details() -> void:
	_label("Chosen", 30)
	if trait_ids.is_empty():
		_label("No traits yet. That's allowed: you can begin without any.", 18, GREY)
	for id in trait_ids:
		var data: Dictionary = Character.trait_list[id]
		_label("%s  -  %s" % [data["name"], data["description"]], 18, BLUE if data["positive"] else RED)
	var positive := trait_ids.filter(func(t): return Character.trait_list[t]["positive"]).size()
	var negative := trait_ids.size() - positive
	_label("Strengths %d / %d    Flaws %d / %d" % [positive, Character.MAX_POSITIVE_TRAITS + negative,
			negative, Character.MAX_NEGATIVE_TRAITS], 18, GREY)
	_label(_attributes_text(Character.preview_attributes(race, background_id, trait_ids, {})), 18, BLUE)


# --- step 4: attributes -------------------------------------------------------------------

func _build_attributes_step() -> void:
	for id in Attributes.ATTRIBUTES:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		choices.add_child(row)
		var name_label := _label("", 20, Color.WHITE, row)
		name_label.custom_minimum_size.x = 200
		name_label.set_meta("attribute", id)
		name_label.tooltip_text = Attributes.ATTRIBUTES[id]["description"]
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		for change in [-1, 1]:
			var button := Button.new()
			button.text = "-" if change < 0 else "+"
			button.custom_minimum_size = Vector2(48, 40)
			button.add_theme_font_size_override("font_size", 20)
			button.pressed.connect(_spend.bind(id, change))
			button.set_meta("attribute", id)
			button.set_meta("change", change)
			row.add_child(button)
	_update_attribute_rows()


func _spend(id: String, change: int) -> void:
	spend[id] = int(spend.get(id, 0)) + change
	if spend[id] <= 0:
		spend.erase(id)
	_update_attribute_rows()
	_refresh_details()


func _points_left() -> int:
	var used := 0
	for id in spend:
		used += int(spend[id])
	return Character.CREATION_ATTRIBUTE_POINTS - used


func _update_attribute_rows() -> void:
	var attrs := Character.preview_attributes(race, background_id, trait_ids, spend)
	for row in choices.get_children():
		for child in row.get_children():
			var id: String = child.get_meta("attribute")
			if child is Label:
				var spent := int(spend.get(id, 0))
				child.text = "%s  %d%s" % [Attributes.ATTRIBUTES[id]["name"], attrs[id], "  (+%d)" % spent if spent > 0 else ""]
			elif child.get_meta("change") < 0:
				child.disabled = int(spend.get(id, 0)) <= 0
			else:
				child.disabled = _points_left() <= 0


func _attributes_details() -> void:
	var left := _points_left()
	_label("%d point%s left" % [left, "" if left == 1 else "s"], 30, GOLD if left > 0 else Color.WHITE)
	var attrs := Character.preview_attributes(race, background_id, trait_ids, spend)
	_label(_pools_text(attrs), 20, BLUE)
	for id in Attributes.ATTRIBUTES:
		_label("%s: %s" % [Attributes.ATTRIBUTES[id]["name"], Attributes.ATTRIBUTES[id]["description"]], 16, GREY)


# --- step 5: name and mode ----------------------------------------------------------------

func _build_final_step() -> void:
	_label("Name", 22, GOLD, choices)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Traveller"
	name_edit.text = player_name
	name_edit.max_length = 24
	name_edit.custom_minimum_size = Vector2(0, 48)
	name_edit.add_theme_font_size_override("font_size", 20)
	name_edit.text_changed.connect(func(text): player_name = text; _refresh_details())
	choices.add_child(name_edit)

	_label("Mode", 22, GOLD, choices)
	var mode_texts := {
		"survival": "Survival  -  hunger, thirst, sleep and cold. Not in the game yet: ticking it now turns them on when they arrive.",
		"hardcore": "Hardcore  -  you take 50% more damage, deal 20% more, and Health regenerates at a quarter of the speed.",
	}
	for mode in mode_texts:
		var box := _check_box(mode_texts[mode])
		box.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.custom_minimum_size.x = 360
		box.button_pressed = modes[mode]
		box.toggled.connect(func(on): modes[mode] = on; _refresh_details())
		choices.add_child(box)
	name_edit.grab_focus.call_deferred()


func _final_details() -> void:
	var bg: Dictionary = Character.backgrounds[background_id]
	var shown_name := player_name.strip_edges() if player_name.strip_edges() != "" else "Traveller"
	_label(shown_name, 30)
	_label("%s %s" % [race.display_name, bg["name"]], 20, GOLD)
	var trait_names := trait_ids.map(func(id): return Character.trait_list[id]["name"])
	_label("Traits: " + (", ".join(trait_names) if not trait_names.is_empty() else "none"), 18)
	var attrs := Character.preview_attributes(race, background_id, trait_ids, spend)
	_label("%s\n%s" % [_pools_text(attrs), _attributes_text(attrs)], 18, BLUE)
	_label("%s\n%s" % [_power_text(race.ability_id, "Z"), _power_text(bg.get("ability", ""), "X")], 18, GOLD)
	var mode_names := []
	for mode in modes:
		if modes[mode]:
			mode_names.append(mode.capitalize())
	_label("Mode: " + (" + ".join(mode_names) if not mode_names.is_empty() else "Standard"), 18,
			RED if modes["hardcore"] else Color.WHITE)


# --- helpers ------------------------------------------------------------------------------

func _choice_button(text: String, group: ButtonGroup) -> Button:
	var button := Button.new()
	button.text = text
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(240, 52)
	button.add_theme_font_size_override("font_size", 22)
	choices.add_child(button)
	return button


# The default theme's empty check box is nearly invisible on this background,
# so each option gets a faint panel to show it can be clicked.
func _check_box(text: String) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.add_theme_font_size_override("font_size", 17)
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.09 if state.begins_with("hover") else 0.04)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(6)
		box.add_theme_stylebox_override(state, style)
	return box


func _label(text: String, size: int, color: Color = Color.WHITE, parent: Node = null) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	(parent if parent else details).add_child(label)
	return label


# Same formulas as the player (player_first_person.gd, Attributes).
func _pools_text(attrs: Dictionary) -> String:
	var end: int = attrs["endurance"] - Attributes.BASE
	var intl: int = attrs["intellect"] - Attributes.BASE
	return "Health %d    Stamina %d    Magicka %d" % [race.health + end * 5, race.stamina + end * 3, race.magicka + intl * 5]


func _attributes_text(attrs: Dictionary) -> String:
	var parts := []
	for id in Attributes.ATTRIBUTES:
		parts.append("%s %d" % [Attributes.ATTRIBUTES[id]["short"], attrs[id]])
	return "   ".join(parts)


func _power_text(ability_id: String, key: String) -> String:
	if ability_id == "" or not Character.ability_list.has(ability_id):
		return ""
	var power: Dictionary = Character.ability_list[ability_id]
	return "Power (%s): %s  -  %s  (every %s)" % [key, power["name"], power["description"], _duration(int(power["cooldown"]))]


func _bonus_list(bonuses: Dictionary, name_of: Callable) -> String:
	var parts := []
	for id in bonuses:
		parts.append("%s %+d" % [name_of.call(id), int(bonuses[id])])
	return ", ".join(parts)


func _duration(seconds: int) -> String:
	return "%d min" % (seconds / 60) if seconds % 60 == 0 else "%d s" % seconds


# 1.08 -> "+8%", 0.95 -> "-5%", 1.0 -> "normal"
func _percent(mult: float) -> String:
	var diff := roundi((mult - 1.0) * 100.0)
	if diff == 0:
		return "normal"
	return "%+d%%" % diff
