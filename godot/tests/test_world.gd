extends "res://tests/test_base.gd"
# World state and interiors: health, effects and gold carry through the cellar hatch;
# a looted chest, an open door and a dead wolf stay that way across scene changes and
# a save/load; clearing the pack sets the flag.
var f := 0
var started := false
var steps := []
var wait := 0
var I; var GS; var SS
func player(): return get_first_node_in_group("player")
func add(guard: Callable, action: Callable) -> void: steps.append([guard, action])
func always() -> bool: return true
func level_is(n: String) -> bool: return current_scene != null and current_scene.name == n and player() != null
func aim_at(target: Vector3) -> void:
	var p = player(); var eye = p.global_position + Vector3(0, 1.6, 0); var d = target - eye
	p.rotation.y = atan2(-d.x, -d.z); p.get_node("Head").rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
func press_e() -> void: Input.action_press("interact")
func release_e() -> void: Input.action_release("interact")
func pack_alive() -> int: return current_scene.get_node("GreyfangPack")._alive
func prompt() -> String: return player().hud.prompt_label.text

func _physics_process(_d: float) -> bool:
	if not started:
		started = true
		I = autoload("Inventory"); GS = autoload("GameState"); SS = autoload("SaveSystem")
		SS.delete_save(); autoload("WorldState").reset()
		var level = load("res://levels/test_level.tscn").instantiate()
		root.add_child(level); current_scene = level
		_build(); return false
	f += 1
	if wait > 0: wait -= 1; return false
	if steps.is_empty(): return done()
	if steps[0][0].call():
		var s = steps.pop_front(); s[1].call(); wait = 4
	elif f > 3000:
		ok(false, "test got stuck waiting for a scene", current_scene.name if current_scene else "none")
		return done()
	return false

func _build() -> void:
	add(always, func():
		for w in current_scene.get_node("GreyfangPack").get_children(): w.aggro_range = 0.0
		var p = player(); p.stats.take_damage(30, true); p.effects.apply("bleeding"); I.add_gold(7)
		current_scene.get_node("GreyfangPack/Wolf1").stats.take_damage(999)
		current_scene.get_node("Door").interact(p)
		ok(pack_alive() == 2, "one wolf killed, two alive", pack_alive())
		p.global_position = Vector3(5.2, 0, -0.6); aim_at(Vector3(5.2, 0.05, -2.2)))
	add(always, func(): ok(prompt() == "[E] Climb down into the waystation cellar", "hatch prompt", prompt()); press_e())
	add(always, release_e)
	add(func(): return level_is("WaystationCellar"), func():
		var p = player()
		near(p.stats.health, 70, 3, "health carried into the cellar")
		ok(p.effects.has("bleeding"), "bleeding carried into the cellar")
		ok(I.gold == 7, "gold carried", I.gold)
		ok(p.hud.effects_row.get_children().any(func(l): return l.visible and l.text.begins_with("Bleeding")), "effect shown on the HUD")
		p.global_position = Vector3(0.5, 0, -2.5); aim_at(Vector3(0.5, 0.3, -4.4)))
	add(always, func(): ok(prompt() == "[E] Search old chest", "chest prompt", prompt()); press_e())
	add(always, release_e)
	add(always, func():
		ok(I.count("iron_helmet") == 1 and I.count("minor_healing_potion") == 1, "chest loot taken", I.items)
		ok(I.gold == 22, "chest gold", I.gold)
		ok(prompt() == "[E] Old Chest (empty)", "chest shows empty", prompt())
		var p = player(); p.global_position = Vector3(2.0, 0.05, 2.5); aim_at(Vector3(2.8, 2.4, 3.2)))
	add(always, func(): ok(prompt() == "[E] Climb up to the waystation", "exit prompt", prompt()); press_e())
	add(always, release_e)
	add(func(): return level_is("TestLevel"), func():
		var p = player(); var w1 = current_scene.get_node_or_null("GreyfangPack/Wolf1")
		ok(p.global_position.distance_to(Vector3(5.2, 0, -0.6)) < 0.5, "arrive back at the hatch", p.global_position)
		ok(current_scene.get_node("Door").is_open, "door still open")
		ok(w1 != null and w1.state == w1.State.DEAD, "Wolf1 still a corpse")
		ok(pack_alive() == 2, "two wolves still alive", pack_alive())
		for w in current_scene.get_node("GreyfangPack").get_children(): w.aggro_range = 0.0
		if w1: w1.interact(p))
	add(always, func(): SS.save_game("slot_1"))
	add(always, func(): SS.load_game("slot_1"))
	add(func(): return level_is("TestLevel"), func():
		ok(not current_scene.has_node("GreyfangPack/Wolf1"), "skinned corpse gone after load")
		ok(current_scene.get_node("Door").is_open, "door open after load")
		ok(pack_alive() == 2, "two wolves alive after load", pack_alive())
		ok(I.count("wolf_pelt") == 1, "pelt kept", I.count("wolf_pelt"))
		for w in current_scene.get_node("GreyfangPack").get_children(): w.stats.take_damage(999))
	add(always, func():
		ok(GS.has_flag("wolves_cleared"), "killing the rest sets wolves_cleared")
		SS.travel("res://levels/waystation_cellar.tscn", "FromWaystation"))
	add(func(): return level_is("WaystationCellar"), func(): var p = player(); p.global_position = Vector3(0.5, 0, -2.5); aim_at(Vector3(0.5, 0.3, -4.4)))
	add(always, func(): ok(prompt() == "[E] Old Chest (empty)", "chest still empty on a later visit", prompt()); SS.delete_save())
