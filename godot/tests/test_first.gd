extends "res://tests/test_base.gd"
# Main quest 5, "What They Made": the Hollow Oak is empty by day; at night the
# ritual starts (the boss and cultists appear), the arena wakes The First, it
# leaks rings of light, it dies into a stream of light north, the slab gives the
# letter, and telling someone ends the demo with a closing card.
# Argument: who you tell. maren (freed the wisp), brannoc (kept the shards),
# mirela (took the wisp's essence).
const LEVEL := "res://levels/test_level.tscn"
var f := 0
var step := 0
var wait := 0
var who := ""
var p
var GS
var Q
var DM
var boss

func _initialize() -> void:
	who = arg("maren")
	autoload("SaveSystem").delete_save()
	change_scene_to_file(LEVEL)

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func pick(start: String) -> void:
	var t: Array = DM._choices.map(func(c): return c["text"])
	for i in t.size():
		if t[i].begins_with(start):
			DM.choose(i)
			return
	ok(false, "choice '%s' offered" % start, t)

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	GS = autoload("GameState"); Q = autoload("QuestLog"); DM = autoload("DialogueManager")
	var clock = autoload("WorldClock")
	boss = n("TheFirst")
	match step:
		0:
			wait = 5
		1:
			var flags := ["taken:test_dungeon/CultNotes", "met_maren", "met_brannoc", "met_mirela", "saw_dunya", "wisp_choice_made"]
			flags.append({"maren": "freed_wisp", "brannoc": "shards_kept", "mirela": "took_wisp_essence"}[who])
			for flag in flags:
				GS.set_flag(flag)
			ok(Q.status("what_they_made")["state"] == "active", "the notes start What They Made")
			ok(not boss.visible and boss.collision_layer == 0, "by day there's no creature")
			ok(n("RitualCultists").get_children().all(func(c): return not c.visible or not n("RitualCultists").visible), "and no cultists")
			ok(not n("FirstArena").monitoring, "the arena is disarmed")
			ok(n("RitualAltar").prompt == "", "nothing on the slab yet")
			clock.advance(clock.hours_until(12.0))
			p.global_position = Vector3(22, 0.05, -38)
			wait = 10
		2:
			ok(GS.has_flag("ritual_site_seen_by_day"), "visited by day")
			ok(p.hud.message_label.text.contains("Come back after nightfall"), "told to come back at night", p.hud.message_label.text)
			ok(not GS.has_flag("ritual_started"), "nothing happens by day")
			clock.advance(clock.hours_until(22.5))
			wait = 10
		3:
			ok(GS.has_flag("ritual_started"), "at night the ritual is under way")
			ok(Q.current_objective("what_they_made") == "Stop what they're making.", "objective: stop it", Q.current_objective("what_they_made"))
			ok(boss.visible and boss.collision_layer != 0, "the creature appears")
			ok(n("RitualCultists").get_children().all(func(c): return c.is_physics_processing()), "the cultists wake")
			ok(n("FirstArena").monitoring, "the arena is armed")
			ok(boss.state == boss.State.DORMANT, "not fighting until you step in")
			p.global_position = Vector3(22, 0.05, -45.5)
			wait = 10
		4:
			ok(boss.state != boss.State.DORMANT, "stepping in wakes The First", boss.state)
			ok(p.hud._boss_bar != null and p.hud._boss_bar.visible, "boss health bar")
			ok(p.hud._boss_bar.get_node("BossName").text == "The First", "its name", p.hud._boss_bar.get_node("BossName").text)
			# It leaks rings of stolen light.
			var rings_before: int = current_scene.get_children().filter(func(c): return c.get("max_radius") != null).size()
			boss.leak()
			var rings: int = current_scene.get_children().filter(func(c): return c.get("max_radius") != null).size()
			ok(rings == rings_before + 1, "a ring of light rolls out", [rings_before, rings])
			# Deal with the cultists and the creature.
			for c in n("RitualCultists").get_children():
				c.stats.take_damage(10000.0, true)
			boss.take_hit(boss.stats.max_health * 0.6, p.global_position)
			ok(boss.phase == 2, "phase two at half health")
			boss.take_hit(10000.0, p.global_position)
			p.stats.refill()
			wait = 30
		5:
			ok(GS.has_flag("first_slain"), "The First is dead")
			ok(n("FirstStream").visible, "its light streams away north")
			var top: Vector3 = n("FirstStream").point(1.0)
			ok(top.z < n("FirstStream").global_position.z - 30.0 and top.y > 10.0, "north and up into the sky", top)
			ok(not p.hud._boss_bar.visible, "boss bar gone")
			ok(n("RitualAltar").prompt == "Take the sealed letter", "a letter on the slab", n("RitualAltar").prompt)
			n("RitualAltar").interact(p)
			ok(autoload("Inventory").count("cult_letter") == 1, "the sealed letter")
			ok(autoload("Inventory").get_item("cult_letter").description.contains("Pale Gate"), "it names the Pale Gate")
			ok(n("RitualAltar").prompt == "", "only one letter")
			ok(Q.current_objective("what_they_made").begins_with("Tell someone"), "objective: tell someone", Q.current_objective("what_they_made"))
			var file: String = who
			DM.start("res://dialogue/%s.json" % file, who)
			pick("(Show")
			match who:
				"maren":
					pick("It followed me out of the barrow.")
					ok(DM.line_label.text.contains("not everything's gone"), "Maren and the wisp", DM.line_label.text)
					pick("What do I do now?")
				"brannoc":
					pick("You still think I should have handed over the shards?")
					ok(DM.line_label.text.begins_with("I still think you're a thief."), "Brannoc remembers the shards", DM.line_label.text)
					pick("What happens now?")
				"mirela":
					pick("Dunya?")
					pick("What will the Free do?")
					ok(DM.line_label.text.contains("You did what they do, once."), "Mirela remembers the essence", DM.line_label.text)
			DM.end()
			ok(GS.has_flag("demo_finished") and GS.has_flag("told_%s_end" % who), "the demo's ending")
			ok(Q.status("what_they_made")["state"] == "completed", "What They Made completed")
			ok(Q.status("what_they_made")["outcome"].contains("Pale Gate"), "outcome", Q.status("what_they_made")["outcome"])
			var O = autoload("Openings")
			var labels: Array = O._card.find_children("*", "Label", true, false) if O._card else []
			ok(labels.size() == 2 and labels[0].text == "To be continued", "the closing card", labels.map(func(l): return l.text))
			# Coming back: no creature, the stream still flows, the slab is empty.
			change_scene_to_file(LEVEL)
			wait = 15
		6:
			ok(n("TheFirst") == null, "The First stays dead")
			ok(n("FirstStream").visible, "the stream still flows")
			ok(n("RitualAltar").prompt == "", "the slab is empty")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
