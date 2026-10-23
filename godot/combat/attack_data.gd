class_name AttackData
extends Resource

# One swing of a weapon: how long it winds up, how long it can hit, how long
# you're stuck recovering, and what it does when it lands.
# Weapons (items/*.tres) list their light combo and one heavy attack.
#
# The poses are names from the weapon animator (player/weapon_animator.gd):
# the weapon moves to `windup_pose` during the windup and sweeps to
# `strike_pose` while it can hit. With real animations later, these names
# become animation clip names instead.

@export var windup_pose: String = "high_right"
@export var strike_pose: String = "low_left"

@export_group("Timing (seconds)")
## Before it can hit. Enemies (and later, players) read this as the telegraph.
@export var windup: float = 0.15
## While the swing can hit. Every enemy in reach during this window is hit once.
@export var active: float = 0.12
## After the swing, before you can do anything else. Pressing attack here
## queues the next swing of the combo.
@export var recovery: float = 0.3
## Heavy attacks only: holding the button this long gives full damage.
@export var charge_time: float = 0.0

@export_group("Effect")
## Times the weapon's damage.
@export var damage_mult: float = 1.0
## Times the weapon's stamina cost.
@export var stamina_mult: float = 1.0
## Breaks the target's poise: enough of it staggers them.
@export var poise_damage: float = 10.0
## How hard the target is pushed back (m/s).
@export var knockback: float = 4.0
## Steps you forward while the swing is active (m/s). Good for heavy attacks.
@export var lunge: float = 0.0
## Hits every enemy in reach instead of just the first.
@export var cleave: bool = false
