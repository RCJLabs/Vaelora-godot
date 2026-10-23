class_name SpellData
extends Resource

# One spell. Each spell is a .tres file in res://spells/ - double-click to edit.
# Register new files in SPELL_FILES in systems/spellbook.gd.
# All spells are "hold to cast": they drain Magicka every second you hold.

enum Effect { DAMAGE_STREAM, HEAL_SELF }

## Unique name used in code and save files. Don't change it once saves exist.
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var effect: Effect = Effect.DAMAGE_STREAM
## Skill that powers it and improves with use, e.g. "destruction".
@export var skill: String = "destruction"
@export var magicka_per_second: float = 12.0
## Damage or healing per second, before the skill bonus.
@export var power_per_second: float = 14.0
## How far a stream reaches (DAMAGE_STREAM only).
@export var range: float = 6.0
## Colour of the hand glow and particles.
@export var color: Color = Color(1, 0.5, 0.15)
