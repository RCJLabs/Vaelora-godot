class_name RaceData
extends Resource

# One playable race. Each race is a .tres file in res://races/ - double-click
# one in the FileSystem panel to edit its numbers in the Inspector.
# Numbers are first-pass placeholders; tune them once combat/magic exist.

@export var display_name: String = "Human"
@export_multiline var description: String = ""

@export_group("Starting stats")
@export var health: int = 100
@export var stamina: int = 100
@export var magicka: int = 100

@export_group("Modifiers")
## Multiplies walk and sprint speed.
@export var move_speed_mult: float = 1.0
## Multiplies how high you jump.
@export var jump_height_mult: float = 1.0
## Multiplies skill XP gained from use.
@export var skill_xp_mult: float = 1.0
## Multiplies melee damage.
@export var melee_damage_mult: float = 1.0
## Extra starting levels per skill id, e.g. {"one_handed": 10}. See systems/skills.gd.
@export var skill_bonuses: Dictionary = {}
## Spell ids known from the start. See systems/spellbook.gd.
@export var starting_spells: Array[String] = ["healing"]

@export_group("Flavour")
@export_multiline var traits: String = ""
@export var signature_ability: String = ""
@export_multiline var signature_description: String = ""
