extends "res://tests/test_base.gd"
# Equipment: pick up and equip a dagger, its stats and damage, unarmed, armour, save/load, old saves.
var f := 0
var started := false
var I; var p

func player(): return get_first_node_in_group("player")

func weapon() -> Dictionary:
	p = player()
	var a = p.combat.light_attacks[0]
	return {"dmg": p.combat.base_damage, "swing": a.windup + a.active + a.recovery, "combo": p.combat.light_attacks.size(),
		"stamina": p.combat.base_stamina_cost, "reach": -p.attack_cast.target_position.z,
		"model": p.weapon.get_child(0).name if p.weapon.get_child_count() > 0 else "none", "armor": p.stats.armor_rating}

func check_weapon(what: String, dmg: float, swing: float, combo: int, stamina: float, reach: float, model: String) -> void:
	var w := weapon()
	near(w["dmg"], dmg, 0.01, what + " damage")
	near(w["swing"], swing, 0.011, what + " swing time")
	ok(w["combo"] == combo, what + " combo length %d" % combo, w["combo"])
	near(w["stamina"], stamina, 0.01, what + " stamina per swing")
	near(w["reach"], reach, 0.02, what + " reach")
	ok(w["model"] == model, what + " model " + model, w["model"])

func _physics_process(_d: float) -> bool:
	if not started:
		started = true
		I = autoload("Inventory")
		autoload("SaveSystem").delete_save()
		var level = load("res://levels/test_level.tscn").instantiate()
		root.add_child(level); current_scene = level
		return false
	f += 1
	match f:
		3:
			for w in current_scene.get_node("GreyfangPack").get_children(): w.aggro_range = 0.0
			ok(I.equipped.get("main_hand") == "iron_sword" and I.equipped.get("body") == "leather_cuirass" and I.equipped.get("feet") == "leather_boots", "starts with sword, cuirass and boots", I.equipped)
			check_weapon("iron sword", 15, 0.52, 3, 10, 1.8, "IronSword")
			near(weapon()["armor"], 26, 0.01, "armour")
			p = player(); p.global_position = Vector3(10.5, 0, -25.5); p.rotation.y = 0; p.get_node("Head").rotation.x = atan2(0.03 - 1.6, 2.0)
		7:
			ok(player().hud.prompt_label.text == "[E] Take Hunting Dagger", "dagger prompt", player().hud.prompt_label.text)
			Input.action_press("interact")
		8: Input.action_release("interact")
		11:
			ok(I.count("hunting_dagger") == 1, "picked up the dagger")
			var m = autoload("CharacterMenu"); m.open(); m.tabs.current_tab = 1
			var row = m._item_ids.find("hunting_dagger"); m.item_list.select(row); m._show_selected_item()
			ok(m.use_button.text == "Equip", "menu button reads Equip", m.use_button.text)
			ok("Damage 9" in m.get_node("%ItemValue").text, "menu shows the dagger's damage", m.get_node("%ItemValue").text)
			m.use_button.emit_signal("pressed")
			ok(m.item_list.get_item_text(m._item_ids.find("hunting_dagger")).ends_with("(equipped)"), "dagger row marked equipped")
			ok(not m.item_list.get_item_text(m._item_ids.find("iron_sword")).ends_with("(equipped)"), "sword row no longer equipped")
			m.close()
		13: check_weapon("dagger", 9, 0.35, 3, 6, 1.35, "HuntingDagger")
		14:
			var w = current_scene.get_node("GreyfangPack/Wolf1"); p = player()
			p.global_position = w.global_position + Vector3(0, 0, 1.2); p.rotation.y = 0; p.get_node("Head").rotation.x = deg_to_rad(-25)
		16:
			var w = current_scene.get_node("GreyfangPack/Wolf1"); w.set_meta("h", w.stats.health)
			player().combat.attack_pressed(); player().combat.attack_released()
		30:
			var w = current_scene.get_node("GreyfangPack/Wolf1")
			near(w.get_meta("h") - w.stats.health, 9.0, 0.5, "dagger hit on a wolf")
		32:
			I.unequip("main_hand")
			check_weapon("unarmed", 4, 0.43, 1, 5, 1.3, "none")
		34:
			I.equip("iron_sword"); p = player(); var h = p.stats.health
			p.stats.take_damage(5.0)
			near(h - p.stats.health, 3.97, 0.02, "5 damage through 26 armour")
		36: I.equip("hunting_dagger"); autoload("SaveSystem").save_game("quicksave")
		38: I.equip("iron_sword"); autoload("SaveSystem").load_game("quicksave")
		52:
			ok(I.equipped.get("main_hand") == "hunting_dagger", "after load: dagger equipped again", I.equipped)
			check_weapon("dagger after load", 9, 0.35, 3, 6, 1.35, "HuntingDagger")
			I.remove("hunting_dagger")
			ok(not I.equipped.has("main_hand"), "removing the equipped dagger unequips it", I.equipped)
			check_weapon("unarmed after removal", 4, 0.43, 1, 5, 1.3, "none")
		54:
			I.from_dict({"items": {"wolf_pelt": 1}, "gold": 5})   # a save from before equipment
			ok(I.equipped.get("main_hand") == "iron_sword" and I.count("wolf_pelt") == 1 and I.count("iron_sword") == 1, "old save without equipment gets starting gear", [I.items, I.equipped])
			autoload("SaveSystem").delete_save()
			return done()
	return false
