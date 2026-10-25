extends "res://tests/test_base.gd"
# The magic perk trees (Ruin, Shaping, Mending, Glamour, Tidecraft) and
# systems/spellcraft.gd: one spell's perks (spell_power_<id>, spell_cost_<id>),
# a school's radius, crits and executions, Arc, Kindling, Lingering Elements,
# healing perks (Desperate Prayer, Respite, Cleansing Light), Ward Absorb,
# Last Breath, the always-on buffs (Deep Reserves, Stone Body), the moons
# (Steady Tide), and Glamour's Shade's Edge and Panic.
var f := 0
var step := 0
var wait := 0
var p
var SC
var C
var S
var w1
var w2

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func spell(id: String) -> SpellData:
	return load("res://spells/%s.tres" % id)

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	SC = autoload("Spellcraft"); C = autoload("Character"); S = autoload("Skills")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			w1 = n("GreyfangPack/Wolf1"); w2 = n("GreyfangPack/Wolf2")
			wait = 5
		1:
			for skill in ["destruction", "alteration", "restoration", "glamour", "tidecraft"]:
				var perks: Array = C.perk_list.keys().filter(func(k): return C.perk_list[k]["skill"] == skill)
				ok(perks.size() >= 20, "20+ %s perks" % skill, perks.size())
			# One spell's power and cost.
			p.magic.spell = spell("firebolt")
			var plain: float = p.magic._power_mult()
			C.perks.append("fire_mastery")
			near(p.magic._power_mult() / plain, 1.3, 0.001, "Fire Mastery: Firebolt +30%")
			p.magic.spell = spell("frost_burst")
			var frost: float = p.magic._power_mult()
			C.perks.clear()
			near(p.magic._power_mult(), frost, 0.001, "but not Frost Burst")
			p.magic.spell = spell("healing_ward")
			var cost: float = p.magic._cost_mult()
			C.perks.append("patient_ward")
			near(p.magic._cost_mult() / cost, 0.75, 0.001, "Patient Ward: the Healing Ward a quarter cheaper")
			C.perks.clear()
			C.perks.append("wide_blast")
			near(SC.scaled(spell("frost_burst"), p).radius, spell("frost_burst").radius * 1.3, 0.001, "Wide Blast: Ruin bursts 30% wider")
			ok(SC.scaled(spell("frost_burst"), p) != spell("frost_burst"), "a copy, not the spell itself")
			C.perks.clear()
			# Hits.
			w1.stats.max_health = 100.0; w1.stats.health = 20.0
			C.perks.append("annihilate")
			near(SC.hit_mult(w1, spell("firebolt")), 1.5, 0.001, "Annihilate: under a quarter health, +50%")
			near(SC.hit_mult(w1, spell("pull")), 1.0, 0.001, "a Ruin perk, not for Tidecraft")
			C.perks.clear()
			w1.stats.health = 100.0
			w2.global_position = w1.global_position + Vector3(2, 0, 0)
			w2.stats.health = w2.stats.max_health
			C.perks.append("arc")
			SC.landed(w1, spell("firebolt"), 20.0, p)
			near(w2.stats.max_health - w2.stats.health, 10.0, 0.5, "Arc: half of it strikes the wolf beside")
			C.perks.clear()
			w1.add_effect("burning")
			C.perks.append("lingering_elements")
			var burning: Dictionary = w1.effects.active["burning"]
			SC.landed(w1, spell("flames"), 1.0, p, true)
			near(burning["time_left"], burning["data"].duration * 2.0, 0.01, "Lingering Elements: burning twice as long")
			SC.landed(w1, spell("flames"), 1.0, p, true)
			near(burning["time_left"], burning["data"].duration * 2.0, 0.01, "and only once, not every frame")
			C.perks.clear()
			C.perks.append("kindling")
			p.stats.magicka = 0.0
			w2.stats.health = 1.0
			w2.take_hit(5.0, p.global_position)
			SC.landed(w2, spell("firebolt"), 5.0, p)
			near(p.stats.magicka, 15.0, 0.01, "Kindling: a Ruin kill gives 15 Magicka")
			C.perks.clear()
			# Healing.
			p.stats.health = p.stats.max_health * 0.2
			C.perks.append("desperate_prayer")
			ok(SC.heal_mult(p, "restoration") >= 1.5, "Desperate Prayer: under a quarter health, half as strong again", SC.heal_mult(p, "restoration"))
			C.perks.clear()
			C.perks.append("respite"); C.perks.append("cleansing_light")
			p.stats.stamina = 0.0
			p.effects.apply("poisoned")
			SC.healed(20.0, p, "restoration")
			near(p.stats.stamina, 10.0, 0.01, "Respite: half of it as Stamina")
			ok(not p.effects.has("poisoned"), "Cleansing Light: no more poison")
			C.perks.clear()
			C.perks.append("ward_absorb")
			p.stats.magicka = 0.0
			SC.ward_stopped(40.0, p, "restoration")
			near(p.stats.magicka, 10.0, 0.01, "Ward Absorb: a quarter of what it stopped")
			C.perks.clear()
			# Always-on.
			C.perks.append("deep_reserves"); C.perks.append("last_breath")
			p.stats.magicka = 0.0
			p.stats.health = 5.0
			wait = 2
		2:
			ok(p.effects.has("deep_reserves"), "Deep Reserves: low on Magicka, it's on")
			ok(p.stats.health > 50.0, "Last Breath: held up", p.stats.health)
			C.perks.clear()
			C.perks.append("stone_body")
			p.effects.apply("stoneflesh")
			near(SC.poise_taken_mult(p), 0.0, 0.001, "Stone Body: in Stoneflesh, nothing staggers you")
			p.effects.remove("stoneflesh")
			near(SC.poise_taken_mult(p), 1.0, 0.001, "out of it, as usual")
			C.perks.clear()
			# The moons.
			var W = autoload("WorldClock")
			C.perks.append("steady_tide")
			var weakest := 9.9
			for day in range(1, 40):
				W.day = day
				weakest = minf(weakest, SC.power_mult(spell("pull"), p))
			ok(weakest >= 1.0, "Steady Tide: the moons never weaken it", weakest)
			C.perks.clear()
			# Glamour, in blows.
			var A = autoload("Arms")
			C.perks.append("shades_edge"); C.perks.append("panic")
			w1.stats.health = 100.0
			p.effects.apply("invisible")
			near(A.hit_mult(w1, p), 1.5, 0.001, "Shade's Edge: from Invisibility, +50%")
			p.effects.remove("invisible")
			w1._afraid = true
			near(A.hit_mult(w1, p), 1.25, 0.001, "Panic: a fleeing enemy takes 25% more")
			w1._afraid = false
			C.perks.clear()
			var score: int = autoload("Speech").score("persuade")
			C.perks.append("honeyed_words")
			ok(autoload("Speech").score("persuade") == score + 10, "Honeyed Words: +10 to checks")
			C.perks.clear()
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
