extends Node

# Drawing: taking life and power from living things. The forbidden school.
# Autoloaded as "Drawing". docs/godot-starter/DRAWING.md; the lore is
# docs/lore/MAGIC.md ("Drawing") and docs/CORRUPTION.md.
#
#   Draw              a stream: it hurts what's in front of you and half of what it
#                     takes comes back to you as Health
#   Siphon Magic      a stream: it hurts less, and what it takes comes back as Magicka
#   Hollowing Touch   up close: 25, and they're hollowed (slow, and take a quarter
#                     more) for 10 s; you take 25 Health back
#   The Great Drawing the mastery: every living enemy within 8 m gives up 20, all of
#                     it yours
#
# It's the only school that corrupts you: everything you take adds corruption
# (CORRUPTION_PER_POINT of it per point), and the more corrupted you are the
# stronger it gets (+15% per tier). No college teaches it. Halina of the Mercy
# does, if you're Stained; a book in the Barrow does; and at Hollowing, Draw comes
# to you on its own. At Drawing 75, the Great Drawing does too.

const CORRUPTION_PER_POINT := 0.05
const POWER_PER_TIER := 0.15
const DRAIN_SHARE := 0.5      # Draw: health back per point taken
const SIPHON_SHARE := 1.5     # Siphon Magic: Magicka back per point taken
const TOUCH_HEAL := 25.0
const TOUCH_CORRUPTION := 2.0
const GREAT_RADIUS := 8.0
const GREAT_CORRUPTION := 5.0
const MASTERY_LEVEL := 75


func _ready() -> void:
	Corruption.tier_changed.connect(_on_tier_changed)
	Skills.skill_increased.connect(_on_skill_increased)


## Drawing's power: +15% per corruption tier (Embrace the Stain: +30%).
func power_mult() -> float:
	var per := POWER_PER_TIER * (2.0 if "embrace_the_stain" in Character.perks else 1.0)
	return 1.0 + per * Corruption.tier()


## A Draw or Siphon stream took `dealt` this frame from `targets`.
func drained(dealt: float, spell: SpellData, player: Node) -> void:
	if dealt <= 0.0:
		return
	var stats: Stats = player.stats
	if spell.effect == SpellData.Effect.SIPHON_STREAM:
		stats.magicka = minf(stats.magicka + dealt * SIPHON_SHARE * Character.modifier("siphon_share"), stats.max_magicka)
	else:
		_heal(player, dealt * DRAIN_SHARE * Character.modifier("drain_share"))
	if "stolen_breath" in Character.perks:
		stats.stamina = minf(stats.stamina + dealt * 0.25, stats.max_stamina)
	_corrupt(dealt * CORRUPTION_PER_POINT, "")


## Something you were drawing from died.
func killed(player: Node) -> void:
	if "feast" in Character.perks:
		player.stats.magicka = minf(player.stats.magicka + 10.0, player.stats.max_magicka)
		player.stats.stamina = minf(player.stats.stamina + 10.0, player.stats.max_stamina)


## The charged Drawing spells (SpellData.drawing): "touch" or "great". Returns how
## many it drew from.
func cast(spell: SpellData, center: Vector3, power: float, caster: Node3D) -> int:
	match spell.drawing:
		"touch":
			var targets := Binding._enemies_near(caster, center, spell.radius)
			if targets.is_empty():
				return 0
			var target: Node3D = targets[0]
			target.take_hit(spell.damage * power, caster.global_position, 1.0, 10.0)
			Glamour.struck(target, caster)
			Sight._apply(target, "hollowed", 10.0 * Character.modifier("hollowed_duration"))
			if "gnawing" in Character.perks and target.has_method("add_effect"):
				target.add_effect("bleeding")
			_heal(caster, TOUCH_HEAL * Character.modifier("drain_share"))
			_corrupt(TOUCH_CORRUPTION, "")
			Skills.add_xp("drawing", spell.damage * power / 5.0)
			return 1
		"great":
			var targets := Binding._enemies_near(caster, caster.global_position, GREAT_RADIUS * Character.modifier("great_draw_radius"))
			var total := 0.0
			for target in targets:
				var stats = target.get("stats")
				var before: float = stats.health if stats else 0.0
				target.take_hit(spell.damage * power, caster.global_position, 2.0, 15.0)
				total += before - (stats.health if stats else 0.0)
				if "hunts_echo" in Character.perks:
					Sight._apply(target, "hollowed", 10.0)
			_heal(caster, total * Character.modifier("drain_share"))
			_corrupt(GREAT_CORRUPTION, "")
			Skills.add_xp("drawing", total / 5.0)
			return targets.size()
	return 0


func _heal(player: Node, amount: float) -> void:
	var stats: Stats = player.stats
	if stats.health < stats.max_health * 0.25 and "desperate_hunger" in Character.perks:
		amount *= 2.0
	var room := stats.max_health - stats.health
	stats.heal(amount)
	if amount > room and "bloodbound" in Character.perks:   # what overflows feeds your Stamina
		stats.stamina = minf(stats.stamina + (amount - room), stats.max_stamina)


func _corrupt(amount: float, what: String) -> void:
	Corruption.add(amount * Character.modifier("drawing_corruption"), what)


func _on_tier_changed(tier: int, old_tier: int) -> void:
	if tier >= 3 and old_tier < 3 and not Spellbook.knows("draw"):
		Spellbook.learn("draw")
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.hud.notify("The light in you has learned to take. (You know Draw.)")


func _on_skill_increased(skill: String, level: int) -> void:
	if skill == "drawing" and level >= MASTERY_LEVEL and not Spellbook.knows("great_drawing"):
		Spellbook.learn("great_drawing")
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.hud.notify("Everything near you is full of light, and you could take it all. (You know the Great Drawing.)")
