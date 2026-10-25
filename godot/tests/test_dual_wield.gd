extends "res://tests/test_base.gd"
# Dual-wielding (PlayerCombat Hand.DUAL, Inventory.equip_off_hand): a one-handed
# weapon in the left hand swings on the left button for three-quarters damage
# (full with Dual Savagery); holding it as you attack lands both (a twin strike,
# which staggers with Twin Strike). Only one-handed melee weapons go in the off
# hand, one copy can't be in both hands, and a two-handed weapon takes both.
var f := 0
var step := 0
var wait := 0
var p
var I
var S
var C
var w1

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func face_wolf() -> void:
	p.global_position = w1.global_position + Vector3(0, 0.2, 1.4)
	p.rotation.y = 0.0
	p.head.rotation.x = deg_to_rad(-25)
	w1.stats.max_health = 1000.0; w1.stats.health = 1000.0
	w1.effects.clear()
	w1.state = w1.State.CHASE   # aware: no sneak attack
	p.stats.stamina = p.stats.max_stamina
	S.levels["one_handed"] = 20

func lost() -> float:
	return 1000.0 - w1.stats.health

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	I = autoload("Inventory"); S = autoload("Skills"); C = autoload("Character")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			w1 = n("GreyfangPack/Wolf1")
			I.add("iron_sword"); I.remove("iron_sword", I.count("iron_sword") - 1)   # just the one
			I.add("hunting_dagger"); I.add("steel_greatsword"); I.add("hunting_bow")
			I.equip("iron_sword")
			ok(I.why_not_off_hand("steel_greatsword") != "", "a greatsword can't go in the off hand")
			ok(I.why_not_off_hand("hunting_bow") != "", "nor a bow")
			ok(not I.equip_off_hand("iron_sword") and I.why_not_off_hand("iron_sword") == "You'd need two of them.", "one sword can't be in both hands", I.count("iron_sword"))
			ok(I.equip_off_hand("hunting_dagger"), "a dagger goes in the off hand")
			wait = 3
		1:
			ok(p.combat.left_hand() == p.combat.Hand.DUAL, "sword and dagger: dual-wielding", p.combat.left_hand())
			ok(p.combat.off_item and p.combat.off_item.id == "hunting_dagger" and p.combat.shield_item == null, "the dagger is the off-hand weapon, not a shield")
			ok(not p.combat._wants_block(), "no blocking with a weapon in each hand")
			ok(not p.magic.right_hand_free(), "and no spell in the left hand")
			near(p.stats.modifier("attack_speed"), 1.0, 0.001, "no Dual Flurry yet")
			C.perks.append("dual_flurry")
			near(p.stats.modifier("attack_speed"), 1.2, 0.001, "Dual Flurry: 20% faster, dual-wielding")
			face_wolf()
			p.combat._start_off()
			ok(p.combat.is_off and p.combat.state == p.combat.State.WINDUP, "the left button swings the off-hand weapon")
			wait = 60
		2:
			set_meta("off", lost())
			ok(get_meta("off") > 0.0, "the dagger cuts the wolf", get_meta("off"))
			C.perks.append("dual_savagery")
			face_wolf()
			p.combat._start_off()
			wait = 60
		3:
			near(lost() / float(get_meta("off")), 1.0 / 0.75, 0.02, "Dual Savagery: off-hand blows at full damage (%s, %s)" % [get_meta("off"), lost()])
			C.perks.erase("dual_savagery")
			face_wolf()
			p.combat.attack_pressed(); p.combat.attack_released()
			wait = 60
		4:
			set_meta("main", lost())
			ok(not p.combat.is_off and get_meta("main") > 0.0, "the right button: the sword alone", get_meta("main"))
			face_wolf()
			Input.action_press("cast")
			p.combat.attack_pressed(); p.combat.attack_released()
			ok(p.combat._twin_pending, "the left button held as you attack: a twin strike")
			wait = 60
		5:
			Input.action_release("cast")
			near(lost(), float(get_meta("main")) + float(get_meta("off")), 1.0, "both weapons land (%s + %s = %s)" % [get_meta("main"), get_meta("off"), lost()])
			C.perks.append("dual_savagery"); C.perks.append("twin_strike")
			face_wolf()
			Input.action_press("cast")
			p.combat.attack_pressed(); p.combat.attack_released()
			wait = 30
		6:
			Input.action_release("cast")
			ok(w1.is_staggered(), "Twin Strike staggers")
			wait = 60
		7:
			# Equipment rules.
			I.equip("steel_greatsword")
			ok(not I.equipped.has("off_hand"), "a greatsword takes both hands")
			I.equip("iron_sword")
			I.add("iron_sword")
			ok(I.equip_off_hand("iron_sword"), "with two swords, one in each hand")
			I.equip_off_hand("hunting_dagger")
			I.equip_off_hand("iron_sword")
			I.remove("iron_sword")
			ok(I.equipped.get("main_hand", "") == "iron_sword" and not I.equipped.has("off_hand"), "one sword left: it stays in the right hand", I.equipped)
			I.equip_off_hand("hunting_dagger")
			I.equip("steel_greatsword")
			I.equip_off_hand("hunting_dagger")
			ok(I.equipped.get("off_hand", "") == "hunting_dagger" and not I.equipped.has("main_hand"), "the off hand over a greatsword: the greatsword comes off", I.equipped)
			wait = 3
		8:
			ok(p.combat.left_hand() == p.combat.Hand.DUAL, "a dagger alone in the left hand: still dual (the right fist)")
			near(p.stats.modifier("attack_speed"), 1.2, 0.001, "Dual Flurry applies")
			I.unequip("off_hand")
			wait = 3
		9:
			ok(p.combat.left_hand() != p.combat.Hand.DUAL and p.combat.off_item == null, "off hand empty: not dual")
			near(p.stats.modifier("attack_speed"), 1.0, 0.001, "and Dual Flurry is off")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
