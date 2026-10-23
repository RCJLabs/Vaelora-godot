extends "res://tests/test_base.gd"
# Survival mode: needs rising over time, eating and drinking, cold at night and by a
# fire, cooking and sleeping at a campfire, no resting near enemies, raw-meat poisoning,
# needs and clock in saves, Hardcore saves only by resting, needs off without the mode.
var f := 0
var steps := []
var wait := 0
var finished := false
var p; var level; var S; var C; var I; var W; var RM; var SS
func add(k: int, cb: Callable) -> void: steps.append([k, cb])
func eff() -> Array: return p.effects.active.keys().filter(func(id): return id.begins_with("survival_") or id == "well_rested")

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 2:
		S = autoload("Survival"); C = autoload("Character"); I = autoload("Inventory"); W = autoload("WorldClock"); RM = autoload("RestMenu"); SS = autoload("SaveSystem")
		SS.delete_save()
		C.create(load("res://races/human.tres"), "Tess", "hunter", [], {}, {"survival": true})
		level = load("res://levels/test_level.tscn").instantiate(); root.add_child(level); current_scene = level
		return false
	if f == 4:
		p = level.get_node("Player")
		for i in [1, 2, 3]: level.get_node("GreyfangPack/Wolf%d" % i).set_physics_process(false)
		ok(W.text() == "Day 1, 08:00", "new game starts Day 1, 08:00", W.text())
		ok(S.values.values().all(func(v): return v == 0.0), "needs start at zero", S.values)
		ok(I.count("bread") == 2 and I.count("water_flask") == 2, "starts with 2 bread and 2 water")
		add(2, func():
			W.hour = 12.0; S.tick(8.0, false)
			near(S.values["hunger"], 24, 1, "hunger after 8 h")
			near(S.values["thirst"], 32, 1, "thirst after 8 h")
			near(S.values["fatigue"], 28, 1, "fatigue after 8 h")
			ok(eff().has("survival_thirsty") and eff().has("survival_tired"), "thirsty and tired after 8 h", eff()))
		add(2, func():
			S.tick(6.0, false)
			ok(eff().has("survival_parched") and eff().has("survival_peckish"), "parched and peckish after 14 h", eff())
			near(p.stats.modifier("stamina_regen"), 0.85, 0.01, "stamina regen with the needs"))
		add(2, func():
			I.use("bread"); I.use("water_flask")
			near(S.values["hunger"], 12, 1, "hunger after bread")
			near(S.values["thirst"], 16, 1, "thirst after water")
			ok(not eff().has("survival_parched") and not eff().has("survival_peckish"), "eating and drinking clear those stages", eff()))
		add(2, func():
			W.hour = 23.0; p.global_position = Vector3(-20, 0, 8)
			S.tick(4.0, false)
			between(S.values["cold"], 30, 70, "cold after 4 h outdoors at night")
			ok(eff().has("survival_chilly"), "chilly", eff())
			ok(not S.sheltered(), "not sheltered away from fires"))
		add(2, func():
			p.global_position = Vector3(6.5, 0, 3.6)
			ok(S.sheltered(), "sheltered by the waystation fire")
			S.tick(1.0, false)
			near(S.values["cold"], 0, 0.5, "cold after 1 h by the fire"))
		# cooking + resting at the fire
		add(2, func():
			I.add("raw_wolf_meat", 2); p.stats.health = 40; p.effects.apply("bleeding")
			RM.open(level.get_node("WaystationFire"), true)
			var labels: Array = RM._buttons.get_children().map(func(b): return b.text)
			ok(RM.is_open and paused, "rest menu opens and pauses")
			ok(labels == ["Cook raw wolf meat (2)", "Rest 1 hour", "Rest 4 hours", "Sleep 8 hours", "Sleep until dawn (7 h)", "Leave"], "rest menu options", labels)
			RM._buttons.get_child(0).emit_signal("pressed")
			ok(I.count("raw_wolf_meat") == 0 and I.count("cooked_wolf_meat") == 2, "cooked both pieces of meat")
			labels = RM._buttons.get_children().map(func(b): return b.text)
			S.values["fatigue"] = 70.0
			W.hour = 22.0
			RM._buttons.get_child(labels.find("Sleep 8 hours")).emit_signal("pressed"))
		add(120, func():
			ok(W.text() == "Day 2, 06:00", "8 h sleep from 22:00 ends at Day 2, 06:00", W.text())
			near(S.values["fatigue"], 0, 0.5, "fatigue after sleeping")
			near(p.stats.health, p.stats.max_health, 0.5, "health full after sleeping")
			ok(not p.effects.has("bleeding"), "sleeping clears bleeding")
			ok(eff().has("well_rested"), "well rested", eff())
			ok(SS.has_save(SS.AUTOSAVE), "sleeping autosaves")
			ok(not RM.is_open, "menu closes after sleeping"))
		# can't rest with a wolf hunting you
		add(5, func():
			var w = level.get_node("GreyfangPack/Wolf1"); w.global_position = p.global_position + Vector3(5, 0, 0); w.state = w.State.CHASE
			RM.open(level.get_node("WaystationFire"), true)
			ok(not RM.is_open, "can't rest with a wolf chasing 5 m away")
			ok(p.hud.message_label.text.contains("enemies nearby"), "says why", p.hud.message_label.text)
			w.state = w.State.IDLE; w.global_position = Vector3(8, 0, -30))
		# eating raw meat sometimes poisons (35%): 40 tries
		add(5, func():
			I.add("raw_wolf_meat", 40); var sick := 0
			for i in 40:
				p.effects.remove("poisoned"); I.use("raw_wolf_meat")
				if p.effects.has("poisoned"): sick += 1
			between(sick, 3, 27, "raw meat poisonings in 40 meals (35% expected)")
			p.effects.remove("poisoned"))
		# save/load keeps clock + needs
		add(5, func(): S.values["thirst"] = 66.0; W.hour = 15.25; SS.save_game("slot_1"))
		add(5, func(): S.values["thirst"] = 0.0; W.hour = 1.0; SS.load_game("slot_1"))
		add(20, func():
			p = current_scene.get_node("Player")
			ok(W.text() == "Day 2, 15:15", "clock restored by load", W.text())
			near(S.values["thirst"], 66, 0.5, "thirst restored by load")
			ok(eff().has("survival_parched"), "need stage effect restored", eff()))
		# hardcore: saves only by resting
		add(5, func():
			C.modes["hardcore"] = true
			ok(not SS.save_game(SS.QUICKSAVE), "Hardcore refuses F5")
			ok(p.hud.message_label.text.begins_with("Hardcore"), "Hardcore explains the refusal", p.hud.message_label.text))
		add(5, func():
			RM.open(current_scene.get_node("WaystationFire"), true); RM._rest(1.0))
		add(90, func():
			ok(SS.most_recent_slot() == SS.AUTOSAVE, "Hardcore rest autosaves")
			C.modes["hardcore"] = false)
		# non-survival characters don't get needs
		add(5, func():
			C.modes["survival"] = false; S.reset(); S.tick(30.0, false)
			ok(S.values.values().all(func(v): return v == 0.0), "no needs without Survival mode", S.values))
		add(5, func():
			var w = current_scene.get_node("GreyfangPack/Wolf1"); w.stats.take_damage(999)
			var m = I.count("raw_wolf_meat"); w.interact(p)
			ok(I.count("raw_wolf_meat") == m + 1, "skinning a wolf gives raw meat"))
		add(5, func(): SS.delete_save(); finished = true)
	if finished: return done()
	if f < 4 or steps.is_empty(): return false
	wait += 1
	if wait >= steps[0][0]:
		wait = 0
		steps.pop_front()[1].call()
	return false
