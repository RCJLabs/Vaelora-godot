extends "res://tests/test_base.gd"
# Weapon types: axe/mace/greatsword/bow setup, hand rules, axe bleed, mace stagger, cleave, shield block/bash, bow.
var f := 0
var steps := []
var wait := 0
var p; var c; var w; var w2; var level; var I; var SB
var n := 0; var bleeds := 0; var h0 := 0.0; var h1 := 0.0

const WEAPONS := {
	"iron_axe": [3, true, false, "SPELL", "one_handed", "IronAxe"],
	"iron_mace": [2, true, false, "SPELL", "one_handed", "IronMace"],
	"steel_greatsword": [3, true, true, "TWO_HANDED", "two_handed", "SteelGreatsword"],
	"hunting_bow": [0, false, true, "BOW", "archery", "HuntingBow"],
}

func add(k: int, cb: Callable) -> void: steps.append([k, cb])

func _initialize() -> void:
	level = load("res://levels/test_level.tscn").instantiate(); root.add_child(level); current_scene = level

func freeze_wolves() -> void:
	for i in [1, 2, 3]:
		var wolf = level.get_node("GreyfangPack/Wolf%d" % i); wolf.set_physics_process(false); wolf.global_position = Vector3(40 + i * 3, 0, 40)
		wolf.stats.max_health = 10000; wolf.stats.health = 10000

func place() -> void:
	p.global_position = Vector3(8, 0, -20); p.rotation.y = 0; p.head.rotation.x = -0.6; p.stats.stamina = p.stats.max_stamina
	w.global_position = Vector3(8, 0, -21.5); w._knockback = Vector3.ZERO

func tap() -> void: c.attack_pressed(); c.attack_released()
func hand() -> String: return c.Hand.keys()[c.left_hand()]
func wolf_state(wolf) -> String: return wolf.State.keys()[wolf.state]

func equip(id: String) -> void:
	if I.count(id) == 0: I.add(id)
	I.equip(id)

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		p = level.get_node("Player"); c = p.combat; I = autoload("Inventory"); SB = autoload("Spellbook")
		freeze_wolves(); w = level.get_node("GreyfangPack/Wolf1"); w2 = level.get_node("GreyfangPack/Wolf2"); place()
		p.stats.max_stamina = 2000; p.stats.stamina = 2000
		add(2, func():
			for id in WEAPONS:
				equip(id)
				var e: Array = WEAPONS[id]
				var got := [c.light_attacks.size(), c.heavy_attack != null, c.main_item.two_handed, hand(), c.weapon_skill,
						str(p.weapon.get_child(0).name) if p.weapon.get_child_count() else "-"]
				ok(got == e, "%s: attacks, hands, skill and model" % id, got))
		# hand rules
		add(2, func():
			equip("steel_greatsword"); equip("wooden_shield")
			ok(I.equipped.get("main_hand", "none") == "none" and I.equipped.get("off_hand") == "wooden_shield" and hand() == "SHIELD",
					"a shield unequips the greatsword", I.equipped)
			equip("iron_sword"); equip("wooden_shield")
			ok(I.equipped.get("main_hand") == "iron_sword" and hand() == "SHIELD" and p.off_hand.visible, "sword and shield together")
			ok(p.hud.spell_label.text.begins_with("Shield"), "HUD shows the shield", p.hud.spell_label.text)
			equip("steel_greatsword")
			ok(I.equipped.get("off_hand", "none") == "none" and hand() == "TWO_HANDED", "the greatsword unequips the shield", I.equipped))
		# axe bleed rate
		add(2, func(): equip("iron_axe"); place(); n = 0; bleeds = 0)
		for i in 40:
			add(1, func(): w.effects.clear(); w.stats.poise = 999; tap())
			add(40, func():
				n += 1
				if w.effects.has("bleeding"): bleeds += 1)
		add(1, func():
			ok(n == 40, "40 axe hits")
			between(bleeds, 3, 20, "axe light hits that made the wolf bleed, of 40"))
		# mace poise: 2 light hits break 25
		add(10, func():
			equip("iron_mace"); place(); w.stats.poise = 25; w.state = w.State.CHASE
			tap())
		add(30, func():
			ok(wolf_state(w) == "CHASE" and w.stats.poise < 25, "first mace hit chips poise, no stagger", [w.stats.poise, wolf_state(w)])
			tap())
		add(45, func(): ok(wolf_state(w) == "STAGGER", "second mace hit staggers", wolf_state(w)))
		# greatsword cleave
		add(60, func():
			equip("steel_greatsword"); place(); w.state = w.State.IDLE
			w2.global_position = Vector3(8.7, 0, -21.4); w2._knockback = Vector3.ZERO
			h0 = w.stats.health; h1 = w2.stats.health; tap())
		add(40, func():
			near(h0 - w.stats.health, 26.0, 1.0, "greatsword damage to wolf 1")
			near(h1 - w2.stats.health, 26.0, 1.0, "greatsword cleaves wolf 2")
			w2.global_position = Vector3(50, 0, 50))
		add(60, func(): SB.select("healing"); Input.action_press("cast"))
		add(10, func():
			ok(c.is_blocking() and not p.is_casting, "two-handed: right-click blocks instead of casting", [c.is_blocking(), p.is_casting])
			Input.action_release("cast"))
		# shield
		add(20, func(): equip("iron_sword"); equip("wooden_shield"); place(); Input.action_press("cast"))
		add(30, func():
			var h = p.stats.health
			ok(p.receive_attack(20.0, w, 0.0) == "blocked", "shield blocks the attack")
			near(h - p.stats.health, 2.24, 0.3, "shield block lets little through")
			ok(not p.is_casting, "not casting while holding the shield up")
			h0 = w.stats.health; w.stats.poise = 25; w.state = w.State.CHASE
			c.attack_pressed(); c.attack_released())
		add(30, func():
			near(h0 - w.stats.health, 5.0, 0.5, "shield bash damage")
			ok(c.is_blocking(), "still blocking after the bash"))
		add(5, func(): Input.action_release("cast"))
		# bow
		add(30, func():
			I.unequip("off_hand"); equip("hunting_bow"); I.add("arrow", 3)
			p.global_position = Vector3(8, 0, -6); p.head.rotation.x = deg_to_rad(-2.5)
			w.global_position = Vector3(8, 0, -21.5); h0 = w.stats.health
			ok(I.count("arrow") == 3 and hand() == "BOW", "bow equipped with 3 arrows")
			ok(p.hud.spell_label.text.begins_with("3 arrows"), "HUD shows arrows", p.hud.spell_label.text)
			c.attack_pressed())
		add(55, func():
			ok(c.State.keys()[c.state] == "DRAWING", "drawing the bow")
			near(c.charge, 1.0, 0.01, "full draw after ~0.9 s")
			c.attack_released())
		add(40, func():
			near(h0 - w.stats.health, 16.0, 1.0, "arrow hits the wolf 15.5 m away")
			ok(I.count("arrow") == 2, "one arrow used")
			between(autoload("Skills").xp["archery"], 3.0, 6.5, "archery xp from the hit"))
		add(10, func(): c.attack_pressed())
		add(3, func(): c.attack_released())
		add(5, func(): ok(I.count("arrow") == 2 and c.State.keys()[c.state] == "READY", "a tiny draw is cancelled without using an arrow"))
		add(5, func(): Input.action_press("cast"))
		add(30, func():
			ok(p.camera.fov < autoload("Settings").fov - 15.0, "aiming zooms in", p.camera.fov)
			Input.action_release("cast"))
		add(5, func():
			I.remove("arrow", I.count("arrow")); c.attack_pressed()
			var notice: String = p.hud.notices.get_child(-1).text if p.hud.notices.get_child_count() else ""
			ok(c.State.keys()[c.state] == "READY" and notice == "No arrows", "no arrows: can't draw, says so", notice))
		add(5, func(): c.attack_released(); done(); quit())
	if steps.is_empty() or f < 3: return false
	wait += 1
	if wait >= steps[0][0]:
		wait = 0
		steps.pop_front()[1].call()
	return false
