extends "res://tests/test_base.gd"
# Command (systems/command.gd): your companion does more and has more health
# with the skill; the Command key sends them at the enemy you aim at, even one
# that hasn't noticed you; and the perks: Marked Target, Coordinated Strike,
# Hold the Line, Battlefield Aid, Bodyguard, Battle-Brothers, Beloved, Pack Leader.
var f := 0
var step := 0
var wait := 0
var p
var CM
var C
var S
var CO
var c
var w1

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	CM = autoload("Command"); C = autoload("Character"); S = autoload("Skills"); CO = autoload("Companions")
	match step:
		0:
			for i in [1, 2, 3]: current_scene.get_node("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			w1 = current_scene.get_node("GreyfangPack/Wolf1")
			S.levels["command"] = 15; S.xp["command"] = 0.0
			autoload("GameState").set_flag("companion_brannoc")
			wait = 5
		1:
			if CO.body() == null:
				return false   # arriving
			ok(S.SKILLS["command"]["attribute"] == "presence", "a Command skill (Presence)")
			ok(InputMap.has_action("command") and autoload("KeyBindings").ACTIONS.any(func(a): return a[0] == "command"), "a Command key, rebindable")
			c = CO.body()
			ok(c != null, "Brannoc's with you")
			near(c.max_health, 150.0, 0.01, "at Command 15: his usual 150")
			S.levels["command"] = 65
			C.perks.append("leadership_1")
			near(CM.damage_mult(), 1.5 * 1.15, 0.001, "at 65 with Leadership: +72.5% damage")
			C.perks.clear()
			# Point out the wolf.
			p.global_position = w1.global_position + Vector3(0, 0.3, 6)
			c.global_position = p.global_position + Vector3(1.5, 0, 0)
			p.rotation.y = 0.0
			p.head.rotation.x = deg_to_rad(-5)
			wait = 3
		2:
			near(c.max_health, 225.0, 0.01, "at 65: 225 health")
			ok(CM.aimed_enemy(p) == w1, "aiming at the wolf", CM.aimed_enemy(p))
			C.perks.append("marked_target")
			ok(CM.point_out(p) == w1, "point it out")
			ok(w1.effects.has("commanded"), "Marked Target: it's marked")
			near(w1.stats.modifier("damage_taken"), 1.15, 0.001, "and takes 15% more")
			ok(S.xp["command"] > 0.0, "an order is Command XP")
			wait = 10
		3:
			ok(c.target == w1, "he goes for it, though it hasn't noticed you", c.target)
			# His blows.
			w1.stats.health = w1.stats.max_health
			w1.effects.clear()
			var before: float = w1.stats.health
			var xp: float = S.xp["command"]
			c._attack_left = 0.0
			c._strike(w1)
			near(before - w1.stats.health, 12.0 * 1.5, 0.5, "his blow: 12 x 1.5")
			ok(S.xp["command"] > xp, "his damage is Command XP")
			S.levels["command"] = 15   # a doubled blow at 65 would kill the wolf outright
			C.perks.append("coordinated_strike")
			CM.player_hit(w1)
			ok(c.next_blow_mult == 2.0, "Coordinated Strike: his next blow doubles")
			w1.stats.health = w1.stats.max_health
			before = w1.stats.health
			c._attack_left = 0.0
			c._strike(w1)
			near(before - w1.stats.health, 24.0, 0.5, "and it does")
			w1.stats.health = w1.stats.max_health
			ok(c.next_blow_mult == 1.0, "once")
			# Hold the Line.
			C.perks.append("hold_the_line")
			c.order(c.State.WAIT)
			var hp: float = c.health
			c.receive_attack(10.0, w1)
			near(hp - c.health, 5.0, 0.01, "Hold the Line: waiting, he takes half")
			c.order(c.State.FOLLOW)
			# Bodyguard.
			C.perks.append("bodyguard")
			wait = 2
		4:
			ok(p.effects.has("guarded"), "Bodyguard: guarded with him close")
			near(p.stats.modifier("damage_taken"), 0.9, 0.001, "10% less")
			# Battle-Brothers and Battlefield Aid.
			C.perks.append("battle_brothers"); C.perks.append("battlefield_aid")
			c.receive_attack(9999.0, w1)
			ok(c.is_down, "he's down")
			wait = 2
		5:
			ok(p.effects.has("avenging") and not p.effects.has("guarded"), "Battle-Brothers: avenging, and no longer guarded")
			c.interact(p)
			ok(not c.is_down and is_equal_approx(c.health, c.max_health), "Battlefield Aid: helped up to full")
			wait = 2
		6:
			ok(not p.effects.has("avenging"), "and the anger passes")
			# Beloved.
			C.perks.append("beloved")
			CO.add_approval("brannoc", -60)
			ok(CO.active() == "brannoc", "Beloved: -60 and he stays")
			CO.approval["brannoc"] = 0
			# Pack Leader.
			C.perks.append("pack_leader")
			ok(CM.order_for_bound() == w1, "Pack Leader: called things get the order too")
			C.perks.clear()
			ok(CM.order_for_bound() == null, "not without it")
			var perks: Array = C.perk_list.keys().filter(func(k): return C.perk_list[k]["skill"] == "command")
			ok(perks.size() >= 20, "20+ Command perks", perks.size())
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
