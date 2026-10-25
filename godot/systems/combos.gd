extends Node

# Spell combinations: two things, one after the other, worth more than both.
# Autoloaded as "Combos". docs/godot-starter/MAGIC.md, "Combinations".
#
#   Shatter   fire (a spell that burns) on a chilled enemy: the frost cracks for
#             SHATTER_DAMAGE (by your Ruin) and staggers them; the chill is gone
#   Undertow  Moon-Crush on an enemy a gravity well is holding: double
#   Riptide   hit something you pulled (Tidecraft's Pull) within RIPTIDE_TIME:
#             half as much again (blades, arrows and spells alike)

signal combo(name: String, target: Node)

const SHATTER_DAMAGE := 30.0
const UNDERTOW_MULT := 2.0
const RIPTIDE_MULT := 1.5
const RIPTIDE_TIME := 1.5   # seconds after the pull


## A spell that burns has landed: if they were chilled, they shatter.
func spell_landed(target: Node, spell: SpellData, player: Node3D) -> void:
	if spell.applies_effect != "burning":
		return
	var effects = target.get("effects")
	if not (effects is StatusEffects and effects.has("chilled")) or Glamour._dead(target):
		return
	effects.remove("chilled")
	target.take_hit(SHATTER_DAMAGE * Skills.spell_power_mult("destruction"), player.global_position, 3.0, 999.0)
	if target.has_method("stagger") and not Glamour._dead(target):
		target.stagger(1.2)
	_announce("Shatter", target, player)


## Moon-Crush's damage on `target` (Tidecraft asks).
func crush_mult(target: Node3D, player: Node3D) -> float:
	if Tidecraft.in_well(target):
		_announce("Undertow", target, player)
		return UNDERTOW_MULT
	return 1.0


## Pull has hold of `target`.
func pulled(target: Node) -> void:
	target.set_meta("pulled_at", Time.get_ticks_msec())


## Anything of yours landing on `target`: Riptide if it was just pulled.
func riptide_mult(target: Node, player: Node3D) -> float:
	if not target.has_meta("pulled_at"):
		return 1.0
	if Time.get_ticks_msec() - int(target.get_meta("pulled_at")) > RIPTIDE_TIME * 1000.0:
		return 1.0
	target.remove_meta("pulled_at")   # once
	_announce("Riptide", target, player)
	return RIPTIDE_MULT


func _announce(name: String, target: Node, player: Node3D) -> void:
	combo.emit(name, target)
	Skills.add_xp("destruction" if name == "Shatter" else "tidecraft", 5.0)
	if player and player.get("hud"):
		player.hud.notify("%s!" % name)
