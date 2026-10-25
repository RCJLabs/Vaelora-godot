extends "res://tests/test_base.gd"
# Binding (systems/binding.gd): Call Wolf-Spirit brings a pale wolf that fights
# for you (charmed, never saved, never a captor) and enemies fight back; one
# called thing at a time (Twin Souls: two), the oldest sent back; it's gone when
# its time is up or when it falls (no pelt left behind); a stray hit doesn't
# break it; with no fight it follows you. Bind roots an enemy (Firm Hold: longer).
# Raise the Dead stands a corpse back up and lays it down again after. Summon
# Guardian: a heavy stone echo. 20+ perks; Maren sells the tomes.
var f := 0
var step := 0
var wait := 0
var p
var B
var C
var w1
var w2
var w3
var first
var risen
var corpse_hp := 0.0

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
	B = autoload("Binding"); C = autoload("Character")
	match step:
		0:
			w1 = n("GreyfangPack/Wolf1"); w2 = n("GreyfangPack/Wolf2"); w3 = n("GreyfangPack/Wolf3")
			for w in [w1, w2, w3]: w.set_physics_process(false)
			p.global_position = w1.global_position + Vector3(0, 0.2, 20)
			wait = 5
		1:
			var S = autoload("Skills")
			ok(S.SKILLS["binding"]["attribute"] == "willpower", "a Binding skill (Willpower)")
			for id in ["call_wolf", "bind", "summon_guardian", "raise_dead"]:
				ok(spell(id).binding != "" and ("res://spells/%s.tres" % id) in autoload("Spellbook").SPELL_FILES, "%s exists and is registered" % id)
			var stock: Dictionary = autoload("Trade").stock("maren")
			ok(["tome_call_wolf", "tome_bind", "tome_summon_guardian", "tome_raise_dead"].all(func(t): return stock.has(t)), "Maren sells the four tomes")
			# Call a wolf-spirit beside the pack.
			ok(B.cast(spell("call_wolf"), w1.global_position + Vector3(0, 0, 5), 1.0, p, 55.0) == 1, "Call Wolf-Spirit")
			first = B.summons[0]["node"]
			ok(first.is_in_group("bound") and not first.is_in_group("persistent") and autoload("Glamour").is_charmed(first), "it's yours: bound, charmed, never saved")
			ok(first.fur_color == B.SPIRIT and first._fur.emission_enabled, "pale and glowing")
			ok(autoload("Glamour").target_for(first, p) == w1 or autoload("Glamour").target_for(first, p) in [w2, w3], "it goes for the wolves")
			ok(autoload("Targeting").foe_for(w1, p) == first, "and the nearest wolf goes for it (it's closer than you)")
			autoload("Glamour").struck(first, p)
			ok(autoload("Glamour").is_charmed(first), "a stray hit from you doesn't break it")
			w1.set_physics_process(true)
			corpse_hp = w1.stats.health
			wait = 240
		2:
			ok(w1.stats.health < corpse_hp or first.stats.health < first.stats.max_health, "they fight", [w1.stats.health, first.stats.health])
			w1.set_physics_process(false)
			# One at a time: a second call sends the first back.
			B.cast(spell("call_wolf"), p.global_position + Vector3(2, 0, 0), 1.0, p, 55.0)
			ok(B.summons.size() == 1 and B.summons[0]["node"] != first, "one at a time: the oldest goes back")
			C.perks.append("twin_souls")
			B.cast(spell("call_wolf"), p.global_position + Vector3(-2, 0, 0), 1.0, p, 55.0)
			ok(B.summons.size() == 2, "Twin Souls: two")
			C.perks.clear()
			# Its time runs out.
			B.summons[1]["left"] = 0.01
			first = B.summons[1]["node"]
			wait = 3
		3:
			ok(not is_instance_valid(first) and B.summons.size() == 1, "gone when its time is up")
			# It falls: no body left.
			first = B.summons[0]["node"]
			first.stats.take_damage(10000.0, true)
			wait = 70
		4:
			ok(not is_instance_valid(first) and B.summons.is_empty(), "gone when it falls: no pelt to skin")
			# Bind.
			w2.set_physics_process(true)
			ok(B.cast(spell("bind"), w2.global_position, 1.0, p, 30.0) == 1 and w2.effects.has("bound"), "Bind roots a wolf")
			ok(is_equal_approx(w2.stats.modifier("move_speed"), 0.0), "it can't move")
			near(w2.effects.active["bound"]["time_left"], 6.0, 0.01, "for 6 seconds (at power 1)")
			w2.effects.clear()
			C.perks.append("firm_hold")
			B.cast(spell("bind"), w2.global_position, 1.0, p, 30.0)
			near(w2.effects.active["bound"]["time_left"], 9.0, 0.01, "Firm Hold: 9")
			C.perks.clear()
			w2.effects.clear()
			w2.set_physics_process(false)
			# Raise the dead.
			w3.stats.take_damage(10000.0, true)
			wait = 5
		5:
			ok(autoload("Glamour")._dead(w3), "a dead wolf")
			ok(B.cast(spell("raise_dead"), w3.global_position, 1.0, p, 70.0) == 1, "Raise the Dead")
			risen = B.summons[0]["node"]
			ok(not w3.visible and risen.global_position.distance_to(w3.global_position) < 0.5 and not autoload("Glamour")._dead(risen), "the body gets up")
			B._dismiss(B.summons[0])
			ok(w3.visible and autoload("Glamour")._dead(w3), "and lies back down after")
			ok(B.cast(spell("raise_dead"), p.global_position + Vector3(30, 0, 30), 1.0, p, 70.0) == 0, "nothing to raise: nothing happens")
			# Summon Guardian.
			B.cast(spell("summon_guardian"), p.global_position + Vector3(3, 0, 0), 1.0, p, 90.0)
			var echo = B.summons[0]["node"]
			ok(echo.stats.max_health == 160.0 and echo.scale.x > 1.2 and not echo.is_in_group("captors"), "a heavy stone echo, no captor", [echo.stats.max_health, echo.scale])
			wait = 30
		6:
			# No fight: it comes to heel.
			var echo = B.summons[0]["node"]
			ok(echo.home.distance_to(p.global_position) < 3.0, "with nothing to fight, it follows you", echo.home.distance_to(p.global_position))
			B.reset()
			var perks: Array = C.perk_list.keys().filter(func(k): return C.perk_list[k]["skill"] == "binding")
			ok(perks.size() >= 20, "20+ Binding perks", perks.size())
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
