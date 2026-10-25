extends "res://tests/test_base.gd"
# The martial perk trees (One-Handed, Two-Handed, Block, Archery, Athletics) and
# systems/arms.gd: perks that only count with the right weapon in hand
# ("when_skill", "when_weapon", "when_shield"), and the mechanics: crits,
# bleeding, executions, momentum, cleave, Stamina on a kill, attack speed,
# Shield Wall and Unbroken Guard, long shots, carry weight and jumping.
var f := 0
var step := 0
var wait := 0
var p
var A
var C
var I
var S
var w1
var w2

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

## One blow on `target` with what's in hand; returns the damage.
func strike(target: Node, heavy: bool = false) -> float:
	var c = p.combat
	c.is_heavy = heavy
	c.charge = 1.0
	c.current_attack = c.heavy_attack if heavy else c.light_attacks[0]
	c.is_bash = false
	c._from_sprint = false
	for s in ["one_handed", "two_handed"]:
		S.levels[s] = 15; S.xp[s] = 0.0
	var before: float = target.stats.health
	c._land_hit(target)
	return before - target.stats.health

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	A = autoload("Arms"); C = autoload("Character"); I = autoload("Inventory"); S = autoload("Skills")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			w1 = n("GreyfangPack/Wolf1"); w2 = n("GreyfangPack/Wolf2")
			wait = 5
		1:
			for skill in ["one_handed", "two_handed", "block", "archery", "athletics"]:
				var perks: Array = C.perk_list.keys().filter(func(k): return C.perk_list[k]["skill"] == skill)
				ok(perks.size() >= 20, "20+ %s perks" % skill, perks.size())
			# Conditions: what's in your hand.
			I.add("iron_axe")
			I.equip("iron_sword")
			C.perks.append("bladesman_1"); C.perks.append("hack_and_slash")
			near(A.sum("crit"), 0.1, 0.001, "a sword: Bladesman counts")
			near(A.sum("bleed"), 0.0, 0.001, "but not the axe perk")
			I.equip("iron_axe")
			near(A.sum("crit"), 0.0, 0.001, "an axe: Bladesman doesn't")
			near(A.sum("bleed"), 0.33, 0.001, "Hack and Slash does")
			C.perks.clear()
			C.perks.append("quick_blades_1")
			near(p.stats.modifier("attack_speed"), 1.15, 0.001, "Quick Blades with a one-handed weapon")
			I.add("steel_greatsword"); I.equip("steel_greatsword")
			near(p.stats.modifier("attack_speed"), 1.0, 0.001, "not with a greatsword")
			C.perks.clear()
			I.equip("iron_sword")
			# Real blows: execution and momentum.
			w1.stats.max_health = 1000.0; w1.stats.health = 1000.0
			var plain := strike(w1)
			w1.stats.health = 200.0
			C.perks.append("executioner")
			var low := strike(w1)
			near(low / plain, 1.5, 0.01, "Executioner: under a quarter health, half as much again")
			C.perks.clear()
			A.reset()
			C.perks.append("flowing_strikes")
			w1.stats.health = 1000.0
			var first := strike(w1)
			w1.stats.health = 1000.0
			var second := strike(w1)
			near(second / first, 1.05, 0.01, "Flowing Strikes: the second blow in a row +5%")
			A.hurt()
			w1.stats.health = 1000.0
			near(strike(w1) / first, 1.0, 0.01, "a hit on you ends it")
			C.perks.clear()
			A.reset()
			# Cleave and Bloodlust (two-handed).
			I.equip("steel_greatsword")
			w2.global_position = w1.global_position + Vector3(1.5, 0, 0)
			w2.stats.health = w2.stats.max_health
			C.perks.append("cleave")
			A.landed(w1, 20.0, p, true)
			near(w2.stats.max_health - w2.stats.health, 10.0, 0.5, "Cleave: half a heavy blow hits the wolf beside it")
			C.perks.clear()
			C.perks.append("bloodlust")
			p.stats.stamina = 0.0
			w2.stats.health = 1.0
			A.landed(w2, 5.0, p, false)   # (Bloodlust needs Berserker, but counts as soon as it's taken)
			w2.take_hit(5.0, p.global_position)
			A.landed(w2, 5.0, p, false)
			ok(p.stats.stamina >= 25.0, "Bloodlust: a kill gives back 25 Stamina", p.stats.stamina)
			C.perks.clear()
			# Block.
			I.equip("iron_sword")
			C.perks.append("shield_wall_1")
			near(p.stats.modifier("block_share"), 1.1, 0.001, "Shield Wall: blocks stop 10% more")
			C.perks.append("unbroken_guard")
			p.combat._set_state(p.combat.State.BLOCKING)
			p.combat._state_time = 5.0
			p.stats.stamina = 0.0
			var result: String = p.combat.receive_attack(10.0, null)
			ok(result == "blocked", "Unbroken Guard: out of Stamina, still blocked", result)
			p.combat._to_ready()
			C.perks.clear()
			# Archery.
			I.add("hunting_bow"); I.equip("hunting_bow")
			C.perks.append("long_shot"); C.perks.append("hunter")
			near(A.hit_mult(w1, p, false, 30.0), 1.25 * 1.25, 0.001, "Long Shot and Hunter: a wolf at 30 m")
			near(A.hit_mult(w1, p, false, 10.0), 1.25, 0.001, "close by, only Hunter")
			C.perks.clear()
			# Athletics.
			var carry: float = autoload("Attributes").carry_capacity()
			C.perks.append("pack_mule_1")
			near(autoload("Attributes").carry_capacity() - carry, 25.0, 0.001, "Pack Mule: 25 more")
			C.perks.append("high_jump")
			near(p.stats.modifier("jump_height"), 1.2, 0.001, "High Jump")
			C.perks.clear()
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
