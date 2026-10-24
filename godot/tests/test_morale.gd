extends "res://tests/test_base.gd"
# Driving off the Greyfang pack (wolf_pack.gd can_break): damage and deaths add
# to the pack's fear; at 100 it breaks, the living run and are gone, and the
# quest counts it as done ("driven off"), with Maren's own reply and reward.
# (Killing every wolf, runners included, is still a plain kill: test_combat.)
# Argument: melee (kill one, then one more hit) or fire (burn two, kill none).
var f := 0
var step := 0
var wait := 0
var mode := ""
var p
var DM
var GS
var pack
var w1
var w2
var w3

func _initialize() -> void:
	mode = arg("melee")
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func texts() -> Array:
	return DM._choices.map(func(c): return c["text"])

func pick(starts: Array) -> bool:
	var t := texts()
	for i in t.size():
		for start in starts:
			if t[i].begins_with(start):
				DM.choose(i)
				return true
	return false

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	DM = autoload("DialogueManager"); GS = autoload("GameState")
	match step:
		0:
			wait = 5
		1:
			pack = current_scene.get_node("GreyfangPack")
			w1 = pack.get_node("Wolf1"); w2 = pack.get_node("Wolf2"); w3 = pack.get_node("Wolf3")
			ok(pack.can_break, "the Greyfang pack can be driven off")
			p.stats.max_health = 9999; p.stats.health = 9999
			p.global_position = pack.global_position + Vector3(0, 0.05, 8)
			# Fear fades when the pack has given up and gone home.
			pack.fear = 40.0
			wait = 2
		2:
			near(pack.fear, 0.0, 0.01, "fear fades while the whole pack is at rest")
			if mode == "melee":
				w1.take_hit(35.0, p.global_position, 0.0)
				ok(w1.state == w1.State.DEAD, "one wolf killed")
				near(pack.fear, 95.0, 0.5, "35 damage plus a death: 95 fear")
				ok(not pack.broken and w2.state != w2.State.FLEE, "not broken yet")
				w2.take_hit(5.0, p.global_position, 0.0)
			else:
				for w in [w2, w3]:
					w.add_effect("burning")
					w.take_hit(25.0, p.global_position, 0.0)
				ok(w2.state != w2.State.DEAD and w3.state != w3.State.DEAD, "no wolf killed")
			ok(pack.broken, "the pack breaks", pack.fear)
			ok(p.hud.message_label.text.contains("breaks and scatters"), "and says so", p.hud.message_label.text)
			ok(not GS.has_flag("wolves_cleared"), "not cleared while they're still running")
			var living := [w2, w3] if mode == "melee" else [w1, w2, w3]
			ok(living.all(func(w): return w.state == w.State.FLEE), "the living run", living.map(func(w): return w.State.keys()[w.state]))
			# A fleeing wolf doesn't turn back when hit, and doesn't bite.
			w2.take_hit(1.0, p.global_position, 5.0, 100.0)
			ok(w2.state == w2.State.FLEE, "hit while fleeing: keeps running", w2.State.keys()[w2.state])
			if mode == "melee":
				# Run one down: still not cleared while the other is getting away.
				w3.take_hit(100.0, p.global_position, 0.0)
				ok(w3.state == w3.State.DEAD and not GS.has_flag("wolves_cleared"), "one runner killed, one still going")
			pack.set_meta("h", p.stats.health)
			wait = 60
		3:
			var gaps: Array = pack.get_children().filter(func(w): return w.state == w.State.FLEE).map(func(w): return w.global_position.distance_to(p.global_position))
			ok(gaps.all(func(d): return d > 9.0), "running away from you", gaps)
			ok(p.stats.health == pack.get_meta("h"), "no bites while fleeing")
			wait = 60 * 12
		4:
			var left: Array = pack.get_children().filter(func(w): return w.state != w.State.DEAD)
			ok(left.is_empty(), "gone within 12 s", left.map(func(w): return w.name))
			ok(GS.has_flag("wolves_driven_off") and GS.has_flag("wolves_cleared"), "driven off, and that counts as cleared")
			# Maren.
			GS.set_flag("wolf_quest_accepted"); GS.set_flag("heard_about_wolves"); GS.set_flag("met_maren")
			var gold: int = autoload("Inventory").gold
			DM.start("res://dialogue/maren.json", "maren")
			while DM.is_active and not pick(["The Greyfang pack ran", "I drove off the wolves"]):
				if not pick(["Goodbye", "(Leave)", "Glad"]):
					break
			ok(DM.is_active and DM.line_label.text.begins_with("Ran?"), "Maren's driven-off reply", DM.line_label.text)
			ok(GS.has_flag("wolf_quest_done"), "quest done")
			ok(autoload("Inventory").gold == gold + 50, "same reward", autoload("Inventory").gold - gold)
			DM.end()
			var q: Dictionary = autoload("QuestLog").status("greyfang")
			ok(q["state"] == "completed" and q["outcome"].begins_with("I drove the Greyfang pack off"), "journal outcome", q)
			# Saved: the pack stays gone.
			ok(autoload("SaveSystem").save_game(autoload("SaveSystem").QUICKSAVE), "saved")
			ok(autoload("SaveSystem").load_game(autoload("SaveSystem").QUICKSAVE), "loading")
			wait = 15
		5:
			pack = current_scene.get_node("GreyfangPack")
			var alive: Array = pack.get_children().filter(func(w): return w.has_signal("died") and w.state != w.State.DEAD)
			ok(alive.is_empty(), "after a load: no wolves back", alive.map(func(w): return w.name))
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
