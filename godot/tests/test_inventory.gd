extends "res://tests/test_base.gd"
# Loot and items: taking a potion and a coin purse, skinning a wolf, drinking a potion
# from the Tab menu, the wolf-quest reward, selling pelts to Maren, and that the
# inventory and taken pickups survive F5/F9.
var f := 0
var started := false
var I; var GS; var DM
func player(): return get_first_node_in_group("player")
func key(k: Key) -> void:
	var e := InputEventKey.new(); e.keycode = k; e.physical_keycode = k; e.pressed = true
	Input.parse_input_event(e)
	var r := InputEventKey.new(); r.keycode = k; r.physical_keycode = k; r.pressed = false
	Input.parse_input_event(r)
func look(pos: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	var p = player(); p.global_position = pos; p.velocity = Vector3.ZERO
	p.rotation.y = deg_to_rad(yaw_deg); p.get_node("Head").rotation.x = deg_to_rad(pitch_deg)
func choices() -> Array: return DM.choices_box.get_children().map(func(b): return b.text)

func _physics_process(_d: float) -> bool:
	if not started:
		started = true
		I = autoload("Inventory"); GS = autoload("GameState"); DM = autoload("DialogueManager")
		autoload("SaveSystem").delete_save()
		var level = load("res://levels/test_level.tscn").instantiate()
		root.add_child(level); current_scene = level
		return false
	f += 1
	var p = player()
	match f:
		60: look(Vector3(3.6, 0, -3.6), 0, -14)
		64:
			ok(p.hud.prompt_label.text == "[E] Take Minor Healing Potion", "potion prompt", p.hud.prompt_label.text)
			Input.action_press("interact")
		65: Input.action_release("interact")
		68:
			ok(I.count("minor_healing_potion") == 1, "potion taken")
			ok(not current_scene.has_node("Potion"), "potion removed from the world")
			ok(p.hud.notices.get_children().any(func(l): return l.text == "Minor Healing Potion added"), "pickup notice")
			look(Vector3(-11, 0, -6.6), 0, -19.5)
		72:
			ok(p.hud.prompt_label.text == "[E] Take coin purse", "purse prompt", p.hud.prompt_label.text)
			Input.action_press("interact")
		73: Input.action_release("interact")
		76: ok(I.gold == 20, "purse gives 20 gold", I.gold)
		80:
			var w = current_scene.get_node("GreyfangPack/Wolf1")
			w.aggro_range = 0.0
			# Just this wolf: hitting it alerts its pack, and Wolf2 and Wolf3 used to come for the
			# player and jostle them off the corpse before the skinning check (the "ray hits
			# nothing" failure, with Wolf2 attacking and Wolf3 chasing). This test is about loot.
			for other in current_scene.get_node("GreyfangPack").get_children():
				if other != w:
					other.global_position += Vector3(40, 0, 0)
					other.set_physics_process(false)
			while w.stats.health > 0: w.take_hit(20, w.global_position + Vector3(0, 0, 1))
		120:
			var w = current_scene.get_node("GreyfangPack/Wolf1")
			look(w.global_position + Vector3(0, 0, 1.8), 0, -38)
		124:
			# (On failure, say what the player was looking at. These details showed the old
			# flake's cause: the other wolves, alerted by Wolf1, jostling the player.)
			var ray = p.interact_ray
			var seen = ray.get_collider() if ray.is_colliding() else null
			ok(p.hud.prompt_label.text == "[E] Skin wolf", "corpse prompt", [p.hud.prompt_label.text, "player", p.global_position, "corpse", current_scene.get_node("GreyfangPack/Wolf1").global_position, "ray hits", seen.name if seen else "nothing", "wolves", current_scene.get_node("GreyfangPack").get_children().map(func(w): return [w.name, w.State.keys()[w.state], w.global_position])])
			Input.action_press("interact")
		125: Input.action_release("interact")
		128:
			ok(I.count("wolf_pelt") == 1 and I.count("raw_wolf_meat") == 1, "skinning gives a pelt and raw meat", I.items)
			ok(p.hud.prompt_label.text == "", "no prompt after skinning", p.hud.prompt_label.text)
			I.add("wolf_pelt")   # pretend we skinned a second one
		130: p.stats.take_damage(60); key(KEY_TAB)
		134:
			var m = autoload("CharacterMenu")
			m.get_node("%Tabs").current_tab = 1
			var rows := []
			for i in m.item_list.item_count: rows.append(m.item_list.get_item_text(i))
			ok(rows == ["Iron Sword   (equipped)", "Leather Boots   (equipped)", "Leather Cuirass   (equipped)", "Minor Healing Potion", "Raw Wolf Meat", "Wolf Pelt  (2)"], "inventory tab rows", rows)
			ok(m.get_node("%GoldLabel").text.begins_with("Gold: 20"), "gold label", m.get_node("%GoldLabel").text)
			var potion_row = m._item_ids.find("minor_healing_potion")
			m.item_list.select(potion_row); m._show_selected_item()
			ok(m.use_button.visible and m.use_button.text == "Drink", "potion selected shows Drink")
			var before: float = p.stats.health
			m.use_button.emit_signal("pressed")
			near(p.stats.health - before, 40, 1, "potion heals")
			ok(I.count("minor_healing_potion") == 0, "potion used up")
		138: key(KEY_TAB)
		142:
			for fl in ["met_maren", "heard_about_wolves", "wolf_quest_accepted", "wolves_cleared"]: GS.set_flag(fl)
			look(Vector3(2, 0, -2), 0, 0)
		146: key(KEY_E)
		150:
			ok(choices() == ["1. The Greyfang pack is dead.", "2. I have a wolf pelt to sell.", "3. Who else comes up this road?", "4. Let's trade.", "5. Goodbye."], "Maren's choices with pelts and the quest done", choices())
			key(KEY_1)
		154:
			ok(I.gold == 70, "quest reward 50 gold", I.gold)
			ok(I.count("minor_healing_potion") == 1, "quest reward potion")
			key(KEY_1)
		158: key(KEY_E)
		162:
			ok(choices().size() > 0 and choices()[0] == "1. I have a wolf pelt to sell.", "pelt sale offered", choices())
			key(KEY_1)
		166:
			ok(I.gold == 85 and I.count("wolf_pelt") == 1, "first pelt sold for 15", I.gold)
			ok(choices().has("1. I have another."), "offers to buy the second", choices())
			key(KEY_1)
		170:
			ok(I.gold == 100 and I.count("wolf_pelt") == 0, "second pelt sold", I.gold)
			key(KEY_1)
		174:
			ok(not DM.is_active, "dialogue closed")
			key(KEY_F5)
		178: I.reset(); key(KEY_F9)
		190:
			ok(I.gold == 100, "gold restored by load", I.gold)
			ok(I.count("minor_healing_potion") == 1 and I.count("raw_wolf_meat") == 1 and I.count("iron_sword") == 1, "items restored by load", I.items)
			ok(not current_scene.has_node("Potion") and not current_scene.has_node("CoinPurse"), "taken pickups don't respawn")
			autoload("SaveSystem").delete_save()
			return done()
	return false
