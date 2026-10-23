class_name StatusEffectData
extends Resource

# One kind of status effect (bleeding, burning, blessed...). Each is a .tres in
# res://effects/ - double-click to edit. Register new files in EFFECT_FILES in
# systems/effect_library.gd.

enum Stacking {
	REFRESH,   # applying again resets the timer
	STACK,     # applying again adds a stack (up to max_stacks) and resets the timer
	IGNORE,    # applying again does nothing while it's active
}

## Unique name used in code and save files. Don't change it once saves exist.
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Harmful effects show red on the HUD; helpful ones green.
@export var is_harmful: bool = true
## Seconds. 0 = lasts until removed by code.
@export var duration: float = 5.0
@export var stacking: Stacking = Stacking.REFRESH
@export var max_stacks: int = 1

@export_group("Per second, per stack")
## Negative = damage over time. Ignores armour.
@export var health_per_second: float = 0.0
@export var stamina_per_second: float = 0.0
@export var magicka_per_second: float = 0.0

@export_group("Modifiers")
## Multipliers other systems ask for, e.g. {"move_speed": 0.8, "damage_taken": 1.2}.
## Applied once per stack. Keys used so far: move_speed, damage_taken,
## damage_dealt, health_regen, stamina_regen, magicka_regen.
@export var modifiers: Dictionary = {}
