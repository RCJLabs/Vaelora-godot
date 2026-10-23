extends Control

# Race selection screen. Shown first; "Begin" loads the starting level.
# To add a race: create a new .tres in res://races/ and add it to RACE_FILES.

const RACE_FILES := [
	"res://races/human.tres",
	"res://races/elf.tres",
	"res://races/orc.tres",
]
const START_LEVEL := "res://levels/test_level.tscn"

@onready var race_buttons: VBoxContainer = %RaceButtons
@onready var name_label: Label = %RaceName
@onready var description_label: Label = %Description
@onready var stats_label: Label = %Stats
@onready var traits_label: Label = %Traits
@onready var ability_label: Label = %Ability
@onready var begin_button: Button = %BeginButton
@onready var continue_button: Button = %ContinueButton

var races: Array[RaceData] = []
var selected: RaceData


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var group := ButtonGroup.new()   # only one race button can be pressed at a time
	for path in RACE_FILES:
		var race: RaceData = load(path)
		races.append(race)
		var button := Button.new()
		button.text = race.display_name
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(220, 56)
		button.add_theme_font_size_override("font_size", 22)
		button.pressed.connect(select_race.bind(race))
		race_buttons.add_child(button)
	begin_button.pressed.connect(begin)
	continue_button.visible = SaveSystem.has_save()
	continue_button.pressed.connect(func(): SaveSystem.load_game())   # most recent save
	%LoadButton.visible = SaveSystem.has_save()
	%LoadButton.pressed.connect(PauseMenu.open_page.bind("load"))
	%SettingsButton.pressed.connect(PauseMenu.open_page.bind("settings"))
	race_buttons.get_child(0).button_pressed = true
	select_race(races[0])


func select_race(race: RaceData) -> void:
	selected = race
	name_label.text = race.display_name
	description_label.text = race.description
	var attrs := []
	for id in Attributes.ATTRIBUTES:
		attrs.append("%s %d" % [Attributes.ATTRIBUTES[id]["short"], Attributes.BASE + int(race.attribute_bonuses.get(id, 0))])
	var end := int(race.attribute_bonuses.get("endurance", 0))
	var intl := int(race.attribute_bonuses.get("intellect", 0))
	stats_label.text = "Health %d    Stamina %d    Magicka %d\nSpeed %s    Jump %s\n%s" % [
		race.health + end * 5, race.stamina + end * 3, race.magicka + intl * 5,
		_percent(race.move_speed_mult), _percent(race.jump_height_mult), "   ".join(attrs)]
	traits_label.text = race.traits
	ability_label.text = "%s - %s" % [race.signature_ability, race.signature_description]


func begin() -> void:
	GameState.set_race(selected)
	GameState.flags = {}   # new game: forget the previous character's story
	GameState.play_time = 0.0
	Skills.reset(selected)
	Attributes.reset(selected)
	Inventory.reset()
	Inventory.give_starting_gear()
	Spellbook.reset(selected)
	Reputation.reset()
	QuestLog.reset_baseline()
	get_tree().change_scene_to_file(START_LEVEL)


# 1.08 -> "+8%", 0.95 -> "-5%", 1.0 -> "normal"
func _percent(mult: float) -> String:
	var diff := roundi((mult - 1.0) * 100.0)
	if diff == 0:
		return "normal"
	return "%+d%%" % diff
