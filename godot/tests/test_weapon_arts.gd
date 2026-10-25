extends "res://tests/test_base.gd"
# Weapon arts (systems/weapon_arts.gd, PlayerCombat.weapon_art_pressed): one
# special attack per weapon, learned at 25, stronger at 50 and 75, with a
# Stamina cost and a cooldown. And the spell combinations (systems/combos.gd):
# Shatter (fire on a chilled enemy), Undertow (Moon-Crush in a well), Riptide
# (hitting what you just pulled).
var f := 0
var step := 0
var wait := 0
var p
var WA
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

func face_wolf() -> void:
	p.global_position = w1.global_position + Vector3(0, 0.2, 1.4)
	p.rotation.y = 0.0
	p.head.rotation.x = deg_to_rad(-25)
	w1.stats.max_health = 1000.0; w1.stats.health = 1000.0
	w1.effects.clear()
	p.stats.stamina = p.stats.max_stamina
	WA.cooldown_left = 0.0

func art(kind_expected: String) -> String:
	var kind: String = p.combat.weapon_art_pressed()
	ok(kind == kind_expected, "the %s art goes off" % kind_expected, kind)
	return kind

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	WA = autoload("WeaponArts"); I = autoload("Inventory"); S = autoload("Skills")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			w1 = n("GreyfangPack/Wolf1"); w2 = n("GreyfangPack/Wolf2")
			ok(InputMap.has_action("weapon_art"), "a Weapon Art key")
			I.equip("iron_sword")
			wait = 3
		1:
			face_wolf()
			S.levels["one_handed"] = 15
			ok(p.combat.weapon_art_pressed() == "", "not at One-Handed 15")
			S.levels["one_handed"] = 25
			ok(WA.knows("sword") and WA.tier("sword") == 1, "learned at 25")
			var stamina: float = p.stats.stamina
			art("sword")
			ok(w1.stats.health < 1000.0, "Flurry cuts the wolf", w1.stats.health)
			near(stamina - p.stats.stamina, WA.STAMINA, 0.5, "it costs Stamina")
			ok(p.combat.weapon_art_pressed() == "" and WA.cooldown_left > 0.0, "and then it has to wait")
			S.levels["one_handed"] = 75
			near(WA.power("sword"), 1.5, 0.001, "at 75: half as strong again")
			S.levels["one_handed"] = 25
			I.add("iron_axe"); I.equip("iron_axe")
			wait = 3
		2:
			face_wolf()
			art("axe")
			ok(w1.effects.stacks("bleeding") == 3, "Rend: bleeding three times over", w1.effects.stacks("bleeding"))
			I.add("iron_mace"); I.equip("iron_mace")
			wait = 3
		3:
			face_wolf()
			art("mace")
			ok(w1.is_staggered(), "Skull Crack staggers")
			I.add("hunting_dagger"); I.equip("hunting_dagger")
			wait = 30
		4:
			face_wolf()
			w1.state = w1.State.IDLE
			ok(w1.is_unaware(), "a wolf that hasn't noticed you")
			art("dagger")
			var unaware: float = 1000.0 - w1.stats.health
			ok(w1.effects.has("bleeding"), "Gutting Strike: it bleeds")
			face_wolf()
			w1.state = w1.State.CHASE
			art("dagger")
			var aware: float = 1000.0 - w1.stats.health
			near(unaware / aware, 1.5, 0.05, "triple on an unaware enemy, double otherwise")
			I.add("steel_greatsword"); I.equip("steel_greatsword")
			S.levels["two_handed"] = 25
			wait = 3
		5:
			face_wolf()
			w2.global_position = p.global_position + Vector3(-1.2, 0, 0.5)
			w2.stats.max_health = 1000.0; w2.stats.health = 1000.0
			art("greatsword")
			ok(w1.stats.health < 1000.0 and w2.stats.health < 1000.0, "Whirlwind hits both wolves around you")
			I.add("hunting_bow"); I.add("arrow", 5); I.equip("hunting_bow")
			S.levels["archery"] = 25
			wait = 3
		6:
			face_wolf()
			var arrows: int = I.count("arrow")
			art("bow")
			ok(I.count("arrow") == arrows - 3, "Volley: three arrows", I.count("arrow"))
			I.unequip("main_hand")
			S.levels["unarmed"] = 25
			wait = 3
		7:
			face_wolf()
			art("unarmed")
			ok(w1.is_staggered(), "Palm Strike staggers")
			# Combinations.
			var CB = autoload("Combos")
			var SC = autoload("Spellcraft")
			face_wolf()
			w1.add_effect("chilled")
			SC.landed(w1, load("res://spells/firebolt.tres"), 10.0, p)
			ok(not w1.effects.has("chilled") and w1.stats.health <= 1000.0 - 30.0, "Shatter: fire on frost cracks for 30", w1.stats.health)
			var TC = autoload("Tidecraft")
			near(CB.crush_mult(w1, p), 1.0, 0.001, "no well: Moon-Crush as usual")
			TC.cast(load("res://spells/gravity_well.tres"), w1.global_position, 1.0, p)
			ok(TC.in_well(w1), "a well under the wolf")
			near(CB.crush_mult(w1, p), 2.0, 0.001, "Undertow: Moon-Crush in a well, double")
			CB.pulled(w1)
			near(CB.riptide_mult(w1, p), 1.5, 0.001, "Riptide: hit what you just pulled")
			near(CB.riptide_mult(w1, p), 1.0, 0.001, "once")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
