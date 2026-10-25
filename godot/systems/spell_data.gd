class_name SpellData
extends Resource

# One spell. Each spell is a .tres file in res://spells/ - double-click to edit.
# Register new files in SPELL_FILES in systems/spellbook.gd.
#
# How it's cast (style):
#   STREAM  hold: drains Magicka every second you hold (Flames, Healing)
#   BOLT    hold to charge, release to fire a projectile (Firebolt)
#   AREA    hold to charge, release: a burst where you're aiming (Frost Burst)
#   WARD    hold: a barrier that stops most of a hit from the front (Healing Ward)
#   SELF    hold to charge, release: a status effect on yourself (Stoneflesh)
# Glamour spells are areas with a `glamour` instead of damage (systems/glamour.gd):
# a decoy of you where you aim, fear in the radius, or charm on whoever's nearest.
# Tidecraft spells are areas with a `tide` (systems/tidecraft.gd): pull the enemy
# you aim at to you, shove everything in front of you away, or a well that holds
# enemies where you aim. They're stronger or weaker by the moons.
# Charged spells only go off when fully charged; releasing early fizzles (free).
# With nothing in your right hand, both hands cast: hold both buttons to
# dual-cast for more power at a higher cost (can_dual_cast).

enum Style { STREAM, BOLT, AREA, WARD, SELF }
## What a STREAM does.
enum Effect { DAMAGE_STREAM, HEAL_SELF }

## Unique name used in code and save files. Don't change it once saves exist.
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var style: Style = Style.STREAM
@export var effect: Effect = Effect.DAMAGE_STREAM
## Skill that powers it and improves with use: "destruction", "restoration", "alteration", "glamour", "tidecraft".
@export var skill: String = "destruction"
## Colour of the hand glow, projectiles and bursts.
@export var color: Color = Color(1, 0.5, 0.15)
## Status effect id left on targets it hits (e.g. "burning"), or empty.
@export var applies_effect: String = ""
@export var can_dual_cast: bool = true

@export_group("Stream and ward (hold)")
@export var magicka_per_second: float = 12.0
## Damage or healing per second, before the skill bonus.
@export var power_per_second: float = 14.0
## How far a stream reaches.
@export var range: float = 6.0
## Wards: share of a hit from the front that the ward stops (0-1).
@export var ward_strength: float = 0.6

@export_group("Charged (bolt, area, self)")
## Seconds of holding before it can be released.
@export var charge_time: float = 0.6
@export var magicka_cost: float = 25.0
## Bolt and area damage, before the skill bonus.
@export var damage: float = 20.0
## Bolts: metres per second. Areas: how far away you can place the burst.
@export var projectile_speed: float = 28.0
@export var max_distance: float = 15.0
## Areas: radius of the burst (metres).
@export var radius: float = 3.0
## Self spells: the status effect it gives you (effects/*.tres).
@export var self_effect: String = ""

@export_group("Glamour")
## "decoy", "fear" or "charm": an area spell that does this instead of damage.
@export var glamour: String = ""
## Seconds it lasts, before the skill bonus (Glamour spells, and Tidecraft's well).
@export var duration: float = 10.0

@export_group("Tidecraft")
## "pull", "shove", "well" or "crush": an area spell that moves or crushes enemies (systems/tidecraft.gd).
@export var tide: String = ""


func is_charged() -> bool:
	return style == Style.BOLT or style == Style.AREA or style == Style.SELF


## Short "how to cast" for the HUD.
func cast_hint() -> String:
	match style:
		Style.STREAM: return "hold"
		Style.WARD: return "hold to ward"
		_: return "charge, release"
