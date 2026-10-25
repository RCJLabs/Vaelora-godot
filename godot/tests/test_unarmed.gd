extends "res://tests/test_base.gd"
# Unarmed: fists train their own skill (Strength), not One-Handed, and hit 1%
# harder per level. Perks marked "when_unarmed" work only bare-handed (checked
# live); the mechanics: Combination (a run of punches builds), Knockout (power
# punch on a staggered foe x3), Quivering Palm (finishes the nearly beaten),
# Spirit Fist / Brawler's Recovery (punches give back), Martial Guard (fists
# block more).
var f := 0
var step := 0
var wait := 0
var p
var S
var C
var I
var w
var level := 15   # Unarmed is held here for each punch (punching trains it, which would drift the numbers)

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

## One punch on the wolf (heavy or not); returns the damage it did.
func punch(heavy: bool = false) -> float:
	var c = p.combat
	c.is_heavy = heavy
	c.charge = 1.0
	c.current_attack = c.heavy_attack if heavy else c.light_attacks[0]
	c.is_bash = false
	w.stats.health = w.stats.max_health
	S.levels["unarmed"] = level
	S.xp["unarmed"] = 0.0
	var before: float = w.stats.health
	c._land_hit(w)
	return before - w.stats.health

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	S = autoload("Skills"); C = autoload("Character"); I = autoload("Inventory")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			w = n("GreyfangPack/Wolf1")
			I.unequip("main_hand")
			wait = 5
		1:
			ok(S.SKILLS["unarmed"]["attribute"] == "strength", "an Unarmed skill (Strength)")
			ok(p.combat.weapon_skill == "unarmed" and p.combat.main_item == null, "bare fists use it")
			var one: float = S.xp["one_handed"] + S.levels["one_handed"] * 1000
			var base := punch()
			ok(base > 0.0 and S.xp["unarmed"] > 0.0, "a punch lands and trains Unarmed", [base, S.xp["unarmed"]])
			ok(S.xp["one_handed"] + S.levels["one_handed"] * 1000 == one, "not One-Handed any more")
			level = 65
			near(punch(), base * 1.5, 0.01, "Unarmed 65: +50%")
			level = 15
			C.perks.append("iron_fist_1")
			near(punch(), base * 1.25, 0.01, "Iron Fist: +25%")
			C.perks.clear()
			# Combination: a quick run on one target builds.
			C.perks.append("combination")
			p.combat._combo_left = 0.0
			var first := punch()
			var second := punch()
			var third := punch()
			near(first, base, 0.01, "Combination: the first punch is plain")
			near(second, base * 1.15, 0.01, "the second +15%")
			near(third, base * 1.30, 0.01, "the third +30%")
			C.perks.clear()
			# Knockout: a power punch on a staggered foe.
			var power := punch(true)
			C.perks.append("knockout")
			w.state = w.State.STAGGER
			near(punch(true), power * 3.0, 0.01, "Knockout: x3 on a staggered wolf")
			w.state = w.State.IDLE
			near(punch(true), power, 0.01, "not when it's steady")
			C.perks.clear()
			# Quivering Palm.
			C.perks.append("quivering_palm")
			w.stats.health = w.stats.max_health * 0.1
			var before: float = w.stats.health
			p.combat.is_heavy = true; p.combat.charge = 1.0; p.combat.current_attack = p.combat.heavy_attack
			p.combat._land_hit(w)
			ok(w.stats.is_dead, "Quivering Palm: a power punch finishes a wolf at 10%", [before, w.stats.health])
			C.perks.clear()
			w = n("GreyfangPack/Wolf2")
			# Giving back.
			C.perks.append("spirit_fist"); C.perks.append("brawlers_recovery")
			p.stats.magicka = 10.0; p.stats.stamina = 10.0
			punch()
			ok(is_equal_approx(p.stats.magicka, 13.0) and is_equal_approx(p.stats.stamina, 12.0), "Spirit Fist +3 Magicka, Brawler's Recovery +2 Stamina", [p.stats.magicka, p.stats.stamina])
			C.perks.clear()
			# when_unarmed: only bare-handed.
			C.perks.append("flurry"); C.perks.append("martial_guard")
			near(p.stats.modifier("attack_stamina"), 0.5, 0.001, "Flurry bare-handed")
			near(p.combat.guard_share(), 0.5, 0.01, "Martial Guard: fists block 50%")
			I.equip("iron_sword")
			near(p.stats.modifier("attack_stamina"), 1.0, 0.001, "not with a sword in hand")
			I.unequip("main_hand")
			C.perks.clear()
			var perks: Array = C.perk_list.keys().filter(func(k): return C.perk_list[k]["skill"] == "unarmed")
			ok(perks.size() >= 20, "20+ Unarmed perks", perks.size())
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
