extends "res://tests/test_base.gd"
# Spell-blades (systems/spellblade.gd, PlayerMagic.try_imbue): charge a damage
# spell in the left hand, press Attack, and it goes into the blade in the right.
# The next blows carry part of the spell and its effect (fire burns; fire on a
# chilled enemy shatters), then it's spent. And the perks: Spellsword, Lingering
# Charge, Battle Channelling, Arc Discharge.
var f := 0
var step := 0
var wait := 0
var p
var SB
var S
var C
var w1
var w2
var last_blow := 0.0   # what the last blow did (attack_landed), before any burning ticks

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
	for w in [w1, w2]:
		w.stats.max_health = 1000.0; w.stats.health = 1000.0
		w.effects.clear()
		w.state = w.State.CHASE   # aware: no sneak attack
	w2.global_position = w1.global_position + Vector3(10, 0, 0)
	p.stats.stamina = p.stats.max_stamina
	p.stats.magicka = p.stats.max_magicka
	S.levels["one_handed"] = 20; S.levels["destruction"] = 20

func lost(w = null) -> float:
	return 1000.0 - (w if w else w1).stats.health

func swing() -> void:
	p.combat.attack_pressed(); p.combat.attack_released()

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	SB = autoload("Spellblade"); S = autoload("Skills"); C = autoload("Character")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			w1 = n("GreyfangPack/Wolf1"); w2 = n("GreyfangPack/Wolf2")
			p.combat.attack_landed.connect(func(_t, dealt): last_blow = dealt)
			var book = autoload("Spellbook")
			book.learn("firebolt"); book.learn("frost_burst")
			ok(SB.can_hold(book.get_spell("firebolt")) and SB.can_hold(book.get_spell("frost_burst")), "Firebolt and Frost Burst can go into a blade")
			ok(not SB.can_hold(book.get_spell("fear")) and not SB.can_hold(book.get_spell("flames")) and not SB.can_hold(book.get_spell("moon_crush")), "Fear, Flames (a stream) and Moon-Crush can't")
			ok(SB.can_take(load("res://items/iron_sword.tres")) and not SB.can_take(load("res://items/hunting_bow.tres")) and not SB.can_take(null), "a sword takes a charge; a bow and bare hands don't")
			autoload("Inventory").equip("iron_sword")
			autoload("Inventory").unequip("off_hand")
			book.select("firebolt")
			wait = 3
		1:
			face_wolf()
			swing()
			wait = 60
		2:
			set_meta("plain", last_blow)
			face_wolf()
			Input.action_press("cast")   # charge Firebolt in the left hand
			wait = 60
		3:
			ok(p.magic.charge >= 1.0, "Firebolt fully charged", p.magic.charge)
			set_meta("magicka", p.stats.magicka)
			swing()   # Attack, instead of letting go
			Input.action_release("cast")
			ok(SB.active() and SB.spell.id == "firebolt" and SB.blows_left == 3, "Attack while it's charged: Firebolt goes into the blade, 3 blows", SB.blows_left)
			ok(p.combat.state == p.combat.State.READY, "that press doesn't also swing", p.combat.state)
			near(float(get_meta("magicka")) - p.stats.magicka, 25.0, 1.0, "it costs the spell's Magicka")
			ok(SB._glow and SB._glow.visible, "the blade glows")
			wait = 10
		4:
			swing()
			wait = 60
		5:
			near(last_blow - float(get_meta("plain")), SB._full * 0.6, 0.5, "a charged blow adds 60%% of the spell (%.1f vs %.1f)" % [last_blow, get_meta("plain")])
			ok(w1.effects.has("burning"), "a fire blade burns")
			ok(SB.blows_left == 2, "two blows left", SB.blows_left)
			face_wolf()
			w1.add_effect("chilled")
			swing()
			wait = 60
		6:
			ok(not w1.effects.has("chilled") and lost() > 30.0, "fire blade on a chilled wolf: Shatter", lost())
			face_wolf()
			swing()
			wait = 60
		7:
			ok(not SB.active() and not SB._glow.visible, "the third blow spends it")
			face_wolf()
			swing()
			wait = 60
		8:
			near(last_blow, float(get_meta("plain")), 0.5, "then blows are plain again")
			# Perks.
			C.perks.append_array(["spellsword", "lingering_charge", "battle_channelling", "arc_discharge"])
			face_wolf()
			w2.global_position = w1.global_position + Vector3(1.0, 0, 0)
			Input.action_press("cast")
			wait = 60
		9:
			set_meta("magicka", p.stats.magicka)
			swing()
			Input.action_release("cast")
			ok(SB.blows_left == 5, "Lingering Charge: 5 blows", SB.blows_left)
			near(float(get_meta("magicka")) - p.stats.magicka, 12.5, 1.0, "Battle Channelling: half the Magicka")
			near(SB.bonus(), SB._full * 0.6 * 1.5, 0.01, "Spellsword: half as much of the spell again")
			SB.blows_left = 1   # straight to the last blow
			wait = 10
		10:
			swing()
			wait = 60
		11:
			ok(not SB.active(), "spent")
			ok(lost(w2) >= SB._full - 0.5, "Arc Discharge: the last blow bursts on the wolf beside it (%.1f)" % lost(w2))
			# Unused, it fades.
			face_wolf()
			SB.imbue(autoload("Spellbook").get_spell("frost_burst"), 1.0, p)
			SB._time_left = 0.05
			wait = 10
		12:
			ok(not SB.active(), "unused, the charge fades")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
