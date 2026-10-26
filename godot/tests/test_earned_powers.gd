extends "res://tests/test_base.gd"
# Earned powers (systems/earned_powers.gd): won by quests and by releasing Wisp
# Essences at the stones, announced once, held one at a time in the fourth slot
# (T), exchanged in Tab → Powers. Then what each does.
var f := 0
var step := 0
var wait := 0
var p
var C
var EP
var GS
var w1

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {}, "warrior")
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func face_wolf(distance: float = 1.4) -> void:
	p.global_position = w1.global_position + Vector3(0, 0.2, distance)
	p.rotation.y = 0.0
	p.head.rotation.x = deg_to_rad(-25)
	w1.stats.max_health = 1000.0; w1.stats.health = 1000.0
	w1.effects.clear()

## Hold `id` and use it.
func use(id: String) -> bool:
	C.earned_power = id
	C.cooldowns.clear()
	return C.use_power(3)

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	C = autoload("Character"); EP = autoload("EarnedPowers"); GS = autoload("GameState")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			w1 = n("GreyfangPack/Wolf1")
			n("GreyfangPack/Wolf2").global_position = w1.global_position + Vector3(-25, 0, 0)
			n("GreyfangPack/Wolf3").global_position = w1.global_position + Vector3(25, 0, 0)
			ok(EP.all().size() == 8, "eight earned powers", EP.all())
			ok(EP.owned().is_empty() and C.powers()[3] == "", "none at the start; the fourth slot is empty")
			ok(InputMap.has_action("power_earned"), "an Earned power key")
			ok(EP.how_to_earn("shrines_peace") == "Complete Silent Shrine", "it says how to earn one", EP.how_to_earn("shrines_peace"))
			for i in 3: EP.essence_released()
			ok(EP.essences_released() == 3 and EP.has("stone_skin") and not EP.has("wisp_step"), "three essences released: Stone-Skin")
			ok(C.earned_power == "stone_skin" and C.powers()[3] == "stone_skin", "the first earned goes in the empty slot")
			ok(C.use_power(3) and p.effects.has("stone_skin"), "T: Stone-Skin")
			near(p.stats.modifier("damage_taken"), 0.5, 0.001, "half damage")
			near(p.stats.modifier("move_speed"), 0.7, 0.001, "but slower")
			p.effects.remove("stone_skin")
			for i in 3: EP.essence_released()
			ok(EP.has("wisp_step") and C.earned_power == "stone_skin", "six: Wisp-Step, and the slot keeps what you hold")
			ok(not EP.choose("kindle") and C.earned_power == "stone_skin", "can't hold one you haven't earned")
			ok(EP.choose("wisp_step") and C.powers()[3] == "wisp_step", "exchange it for Wisp-Step")
			var saved: Dictionary = C.to_dict()
			ok(saved["earned_power"] == "wisp_step" and "stone_skin" in saved["earned_seen"], "the slot is saved")
			# Wisp-Step, in open air.
			p.global_position += Vector3(0, 30, 0)
			p.rotation.y = 0.0
			var from: Vector3 = p.global_position
			ok(use("wisp_step"), "Wisp-Step")
			near(from.distance_to(p.global_position), 6.0, 0.05, "6 m the way you face")
			# Quests.
			for flag in ["shrine_answered", "wrong_things_done", "barrow_lead", "readings_delivered", "jory_settled", "brannoc_told_zora"]:
				GS.set_flag(flag)
			ok(EP.owned().size() == 8, "the six quests done: all eight earned", EP.owned())
			ok(C.earned_seen.size() == 8, "each announced once")
			face_wolf()
			ok(use("shrines_peace") and autoload("Glamour").kind_of(w1) == "calm", "Shrine's Peace calms the wolf")
			ok(autoload("Glamour").target_for(w1, p) == null, "it goes after nobody")
			autoload("Glamour").struck(w1, p)
			ok(autoload("Glamour").kind_of(w1) == "", "strike it and the peace breaks")
			autoload("Glamour").calm(w1, 3.0)
			w1.set_physics_process(true)
			w1.state = w1.State.CHASE
			p.stats.health = p.stats.max_health
			wait = 120
		1:
			ok(is_equal_approx(p.stats.health, p.stats.max_health), "a calmed wolf beside you doesn't bite", p.stats.health)
			w1.set_physics_process(false)
			autoload("Glamour").reset()
			face_wolf()
			var w2 = n("GreyfangPack/Wolf2")
			w2.global_position = p.global_position + Vector3(0, -0.2, 2.0)   # behind you
			ok(use("lanterns_glare") and w1.is_staggered(), "Lantern's Glare: the wolf in front reels")
			ok(not w2.is_staggered(), "not one behind you")
			w2.global_position = w1.global_position + Vector3(-25, 0, 0)
			wait = 10
		2:
			ok(use("greenward") and p.effects.has("greenward"), "Greenward")
			p.stats.health = 50.0
			wait = 60
		3:
			ok(p.stats.health > 52.0, "it heals over time", p.stats.health)
			p.effects.remove("greenward")
			ok(use("wanderers_eye") and p.effects.has("true_sight"), "Wanderer's Eye: True Sight")
			p.effects.remove("true_sight")
			ok(use("roadwise") and is_equal_approx(p.stats.modifier("sprint_stamina"), 0.0), "Roadwise: free sprinting")
			p.effects.remove("roadwise")
			face_wolf(6.0)
			p.head.rotation.x = deg_to_rad(-9)
			ok(use("kindle") and w1.effects.has("burning"), "Kindle: what you aim at catches fire")
			# The Powers tab.
			var menu = autoload("CharacterMenu")
			menu.open()
			wait = 5
		4:
			var menu = autoload("CharacterMenu")
			ok(menu.tabs.get_tab_title(menu.POWERS_TAB) == "Powers", "a Powers tab", menu.tabs.get_tab_title(menu.POWERS_TAB))
			var hold: Button = null
			for b in menu.powers_page.find_children("*", "Button", true, false):
				if b.get_meta("power", "") == "greenward": hold = b
			ok(hold != null and hold.text == "Hold", "Greenward has a Hold button")
			hold.pressed.emit()
			ok(C.earned_power == "greenward", "Hold: it's in the slot now")
			menu.close()
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
