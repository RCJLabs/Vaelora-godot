extends "res://tests/test_base.gd"
# Bandit camp: aggro, telegraphed swings, parrying them, guards (light bounces, heavy breaks), leader parries,
# spells ignore guards, loot and chest, Brannoc's bounty, and the camp staying cleared after save/load.
var f := 0
var steps := []
var wait := 0
var p; var c; var level; var b1; var b2; var lead; var I; var GS; var SB
var h0 := 0.0

func add(k: int, cb: Callable) -> void: steps.append([k, cb])

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	level = load("res://levels/test_level.tscn").instantiate(); root.add_child(level); current_scene = level

func bst(b) -> String: return b.State.keys()[b.state]

## Puts a frozen bandit 1.8 m in front of the player, facing them (its AI would normally turn it).
func face_player(b) -> void:
	b.global_position = p.global_position + Vector3(0, 0, -1.8)
	b.rotation.y = 0.0
	if not b._facing(p.global_position):
		b.rotation.y = PI
	ok(b._facing(p.global_position), "%s faces the player" % b.name)

func freeze(list: Array) -> void:
	for b in list: b.set_physics_process(false)

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		p = level.get_node("Player"); c = p.combat; I = autoload("Inventory"); GS = autoload("GameState"); SB = autoload("Spellbook")
		for i in [1, 2, 3]: var w = level.get_node("GreyfangPack/Wolf%d" % i); w.set_physics_process(false); w.global_position = Vector3(50, 0, 50 + i * 3)
		b1 = level.get_node("BanditCamp/Bandit1"); b2 = level.get_node("BanditCamp/Bandit2"); lead = level.get_node("BanditCamp/Leader")
		ok([b1.display_name, b2.display_name, lead.display_name] == ["Bandit", "Bandit", "Bandit Leader"], "camp has two bandits and a leader")
		ok([b1.stats.max_health, b2.stats.max_health, lead.stats.max_health] == [60.0, 60.0, 90.0], "bandit health 60/60/90")
		ok([str(b1.weapon_holder.get_child(0).name), str(b2.weapon_holder.get_child(0).name), str(lead.weapon_holder.get_child(0).name)] == ["IronAxe", "IronSword", "IronMace"],
				"bandit weapons axe/sword/mace")
		p.global_position = Vector3(-34, 0, -20); p.rotation.y = 0; p.stats.max_health = 500; p.stats.health = 500; p.stats.max_stamina = 500; p.stats.stamina = 500
		add(30, func(): ok([bst(b1), bst(b2), bst(lead)] == ["IDLE", "IDLE", "IDLE"], "player 14 m away: camp stays idle", [bst(b1), bst(b2), bst(lead)]))
		add(1, func(): p.global_position = Vector3(-34, 0, -26))
		add(120, func():
			var states := [bst(b1), bst(b2), bst(lead)]
			ok(not states.has("IDLE"), "player 8 m away: the whole camp joins the fight", states)
			# MAX_ATTACKERS = 1: at most one bandit swings at a time
			ok(states.count("ATTACK") <= 1, "at most one bandit attacking at once", states)
			between(b1.global_position.distance_to(p.global_position), 1.0, 4.0, "bandit 1 closed in"))
		# isolate bandit 2 for the duel checks
		add(1, func():
			freeze([b1, lead]); b1.global_position = Vector3(-50, 0, -50); lead.global_position = Vector3(-52, 0, -50)
			b2.global_position = p.global_position + Vector3(0, 0, -1.8); b2.rotation.y = 0.0; b2.state = b2.State.ENGAGE
			p.rotation.y = 0; p.head.rotation.x = -0.15; h0 = p.stats.health
			b2._start_attack(false))
		add(10, func():
			ok(b2.Phase.keys()[b2._phase] == "WINDUP", "bandit telegraphs: wind-up phase")
			ok(b2._glint.emission_energy_multiplier > 1.0, "weapon glint during wind-up", b2._glint.emission_energy_multiplier))
		add(40, func(): between(h0 - p.stats.health, 5.0, 11.0, "undefended swing damage"))
		# parry it: block just before the swing lands
		add(60, func(): b2.state = b2.State.ENGAGE; b2._start_attack(false); b2._combo_left = 1)
		add(int(b2.attacks[0].windup * 60) - 7 if b2 else 26, func(): SB.ready_block(); Input.action_press("cast"))
		add(14, func(): ok(bst(b2) == "STAGGER", "parrying the swing staggers the bandit", bst(b2)); Input.action_release("cast"))
		# hit a raised guard with a light attack -> bounce. Bandit 2 is frozen in front of the player
		# for the guard checks: with its AI running it sometimes steps out of reach.
		add(80, func():
			freeze([b2]); face_player(b2)
			b2.state = b2.State.ENGAGE; b2._start_guard(3.0); h0 = b2.stats.health
			c.attack_pressed(); c.attack_released())
		add(18, func():
			between(h0 - b2.stats.health, 1.5, 3.0, "light attack into a guard: 85% stopped")
			ok(bst(b2) == "GUARD", "guard holds against a light attack", bst(b2))
			ok(c.State.keys()[c.state] == "RECOVERY", "player bounces into recovery", c.State.keys()[c.state]))
		# heavy breaks the guard
		add(60, func():
			face_player(b2)
			b2._start_guard(3.0); b2.stats.stamina = 60; h0 = b2.stats.health; c.attack_pressed())
		add(45, func(): c.attack_released())
		add(25, func():
			near(h0 - b2.stats.health, 18.9, 1.5, "heavy attack damage through the guard")
			ok(bst(b2) == "STAGGER", "heavy attack breaks the guard", bst(b2)))
		# leader parries
		add(80, func():
			freeze([b2]); b2.global_position = Vector3(-54, 0, -50)
			face_player(lead)   # stays frozen, like bandit 2 above
			lead.parry_chance = 1.0; lead.state = lead.State.ENGAGE; lead._start_guard(3.0)
			c.attack_pressed(); c.attack_released())
		add(18, func():
			ok(c.State.keys()[c.state] == "STAGGERED", "the leader's parry staggers the player", c.State.keys()[c.state])
			lead.parry_chance = 0.3)
		# spells ignore the guard. The leader stays frozen in front of the player: with its AI running
		# it sidesteps out of the stream's line about half the time, which tests the AI, not this.
		add(80, func():
			if not SB.knows("flames"): SB.learn("flames")
			SB.select("flames")
			face_player(lead)
			lead.state = lead.State.GUARD; lead._guard_left = 3.0; h0 = lead.stats.health
			p.stats.magicka = p.stats.max_magicka
			Input.action_press("cast"))
		add(30, func():
			between(h0 - lead.stats.health, 5.0, 16.0, "flames into a raised guard: not blocked")
			Input.action_release("cast"))
		# kill them all
		add(30, func():
			for b in [b1, b2, lead]: b.set_physics_process(true); b.stats.take_damage(9999))
		add(10, func():
			ok(GS.has_flag("bandits_cleared"), "bandits_cleared flag set")
			ok(p.hud.message_label.text == "The bandit camp falls silent.", "camp cleared message", p.hud.message_label.text)
			ok(lead.prompt == "Search bandit leader", "dead leader can be searched", lead.prompt))
		add(5, func():
			var g = I.gold
			lead.interact(p); b1.interact(p)
			ok(I.gold - g == 42, "searched gold +42", I.gold - g)
			ok(I.count("iron_mace") == 1 and I.count("iron_axe") == 1, "looted the mace and axe")
			ok(lead.prompt == "Bandit Leader (searched)", "searched prompt", lead.prompt))
		add(5, func():
			var chest = level.get_node("BanditChest")
			ok(chest.prompt == "Search bandit chest", "chest prompt", chest.prompt)
			chest.interact(p)
			ok(I.count("steel_greatsword") == 1 and I.count("arrow") == 12, "chest holds a greatsword and 12 arrows", [I.count("steel_greatsword"), I.count("arrow")]))
		# bounty
		add(5, func():
			var dm = autoload("DialogueManager"); GS.set_flag("met_brannoc"); var g = I.gold
			dm.start("res://dialogue/brannoc.json", "Brannoc")
			var labels = dm.choices_box.get_children().map(func(b): return b.text)
			var offered: bool = labels.any(func(t): return t.contains("bandit camp"))
			ok(offered, "Brannoc can be told the camp is cleared", labels)
			for k in labels.size(): if labels[k].contains("bandit camp"): dm.choose(k)
			ok(dm.line_label.text.begins_with("All three?"), "Brannoc's bounty line", dm.line_label.text.substr(0, 40))
			ok(I.gold - g == 75, "bounty pays 75 gold", I.gold - g)
			ok(autoload("Reputation").value("riverwatch") == 13, "Riverwatch reputation +", autoload("Reputation").value("riverwatch"))
			ok(autoload("QuestLog").status("bandit_camp")["state"] == "completed", "bandit quest completed")
			dm.end())
		add(5, func(): autoload("SaveSystem").save_game("quicksave"))
		add(5, func(): autoload("SaveSystem").load_game("quicksave"))
		add(20, func():
			var l = current_scene.get_node("BanditCamp/Leader")
			ok(l.State.keys()[l.state] == "DEAD", "leader still dead after load", l.State.keys()[l.state])
			ok(l.prompt == "Bandit Leader (searched)", "leader still searched after load", l.prompt)
			autoload("SaveSystem").delete_save(); done(); quit())
	if steps.is_empty() or f < 3: return false
	wait += 1
	if wait >= steps[0][0]:
		wait = 0
		steps.pop_front()[1].call()
	return false
