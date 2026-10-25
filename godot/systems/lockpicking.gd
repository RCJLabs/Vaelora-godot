extends Node

# Lockpicking: setting a lock's pins one by one. Autoloaded as "Lockpicking". The
# screen is ui/lockpick_screen.gd; locked containers (loot_container.gd, lock_level)
# open it. docs/godot-starter/LOCKPICKING.md.
#
# A marker sweeps back and forth along the lock; press when it's in the sweet spot
# to set a pin. Set them all and it opens. Miss and a pin drops back (Quick Hands:
# not), and your pick may snap (half the time; Sturdy Picks: a quarter). A snapped
# pick makes noise (Stealth). Harder locks have more pins, a narrower spot and a
# faster marker; your skill widens the spot and slows the marker.
#
#   attempt() -> "set", "open", "miss", "broke" or "no_picks"

signal opened(target: Node)

enum Level { NOVICE, APPRENTICE, ADEPT, EXPERT, MASTER }
const LEVEL_NAMES := ["Novice", "Apprentice", "Adept", "Expert", "Master"]
const PINS := [2, 3, 4, 5, 6]
const SPOT := [0.24, 0.2, 0.16, 0.12, 0.09]          # the sweet spot, as a share of the lock
const SPEED := [0.7, 0.85, 1.0, 1.2, 1.45]           # lock-widths a second
const BREAK_CHANCE := 0.5
const XP_PER_LEVEL := 6.0                            # opening: x (level + 1)
const LOCKSMITH_PERKS := ["locksmith_apprentice", "locksmith_adept", "locksmith_expert", "locksmith_master"]

var level := 0
var pins := 0                  # how many to set
var set_pins := 0
var marker := 0.0              # 0..1
var spot_center := 0.5
var _phase := 0.0              # 0..2: out along the lock, then back
var target: Node = null        # what we're picking
var springs_used_day := -1     # Spring the Lock: the day it was last used


## The pins a lock of `lvl` needs after the locksmith perks (one fewer each, from Apprentice up).
func pins_for(lvl: int) -> int:
	var n: int = PINS[lvl]
	if lvl >= Level.APPRENTICE and LOCKSMITH_PERKS[lvl - 1] in Character.perks:
		n -= 1
	return maxi(n, 1)


## How wide the sweet spot is now (a share of the lock).
func spot_width() -> float:
	var skill: int = Skills.levels.get("lockpicking", Skills.START_LEVEL)
	var width: float = SPOT[level] * (1.0 + (skill - Skills.START_LEVEL) * 0.01) * Character.modifier("lock_spot")
	if "lampless_way" in Character.perks and WorldClock.wanderer_dark():
		width *= 1.25
	if "under_pressure" in Character.perks:
		var player := get_tree().get_first_node_in_group("player")
		if player and player.is_sneaking and Stealth.status()["awareness"] <= 0.0:   # sneaking, and nobody's noticed
			width *= 1.25
	return minf(width, 0.6)


func speed() -> float:
	var skill: int = Skills.levels.get("lockpicking", Skills.START_LEVEL)
	return SPEED[level] / (1.0 + (skill - Skills.START_LEVEL) * 0.005) * Character.modifier("lock_speed")


func start(lvl: int, what: Node = null) -> void:
	level = clampi(lvl, 0, Level.MASTER)
	target = what
	pins = pins_for(level)
	set_pins = 1 if "locksense" in Character.perks and pins > 1 else 0
	marker = 0.0
	_phase = 0.0
	_new_spot()


func _new_spot() -> void:
	var half := spot_width() / 2.0
	spot_center = randf_range(half, 1.0 - half)


## Moves the marker (the screen calls it every frame).
func tick(delta: float) -> void:
	_phase = fposmod(_phase + speed() * delta, 2.0)   # any frame length, even a hitch
	marker = _phase if _phase <= 1.0 else 2.0 - _phase


func in_spot() -> bool:
	return absf(marker - spot_center) <= spot_width() / 2.0


## Tries to set a pin where the marker is now.
func attempt() -> String:
	if Inventory.count("lockpick") <= 0:
		return "no_picks"
	if in_spot():
		set_pins += 1
		Skills.add_xp("lockpicking", 1.0)
		if set_pins >= pins:
			_open()
			return "open"
		_new_spot()
		return "set"
	if not "quick_hands" in Character.perks:
		set_pins = maxi(set_pins - 1, 0)
	if "unbreakable_picks" in Character.perks:
		return "miss"
	var chance := BREAK_CHANCE * (0.5 if "sturdy_picks" in Character.perks else 1.0)
	if randf() < chance:
		Inventory.remove("lockpick")
		if not "silent_picking" in Character.perks:
			var player := get_tree().get_first_node_in_group("player")
			if player:
				Stealth.make_noise(player.global_position, "lockpick")
		if "lucky_break" in Character.perks and randf() < 1.0 / 3.0:
			set_pins += 1   # it snapped, but the pin went up with it
			if set_pins >= pins:
				_open()
				return "open"
		return "broke"
	return "miss"


## Spring the Lock: once a day, open any lock outright.
func can_spring() -> bool:
	return "spring_the_lock" in Character.perks and springs_used_day != WorldClock.day


func spring() -> bool:
	if not can_spring():
		return false
	springs_used_day = WorldClock.day
	set_pins = pins
	_open()
	return true


func _open() -> void:
	Skills.add_xp("lockpicking", XP_PER_LEVEL * (level + 1))
	if target and target.has_method("unlock"):
		target.unlock()
	opened.emit(target)


func reset() -> void:
	target = null
	springs_used_day = -1


func to_dict() -> Dictionary:
	return {"springs_used_day": springs_used_day}


func from_dict(data: Dictionary) -> void:
	springs_used_day = int(data.get("springs_used_day", -1))
