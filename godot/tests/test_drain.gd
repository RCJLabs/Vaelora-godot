extends "res://tests/test_base.gd"
# The Waking Stones, reframed: something is draining the stone circle's wisps
# (one calm wisp a night drifts into the crystal and streaks north, but only once
# main quest 1 has started), and once the shards are dealt with the crystal shows
# the drain-line north. Brannoc reacts to it.
var f := 0
var step := 0
var wait := 0
var p
var spawner
var line
var GS
var drained
var spawned := 0

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	change_scene_to_file("res://levels/test_level.tscn")

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	spawner = current_scene.get_node("StoneWisps")
	line = current_scene.get_node("DrainLine")
	GS = autoload("GameState")
	var clock = autoload("WorldClock")
	match step:
		0:
			wait = 5
		1:
			ok(not line.visible, "drain-line hidden at first")
			ok(not spawner.draining(), "no draining before the main quest")
			# Night, without the main quest: nothing is drained.
			spawner.drain_delay = 0.2
			clock.advance(clock.hours_until(22.0))
			wait = 40
		2:
			spawned = spawner.get_child_count()
			ok(spawned == spawner.count, "wisps out at night", spawned)
			ok(spawner.get_children().all(func(w): return w.state != w.State.DEAD), "none drained without the main quest")
			# Start the night over with the flag set.
			for w in spawner.get_children():
				w.queue_free()
			clock.advance(clock.hours_until(12.0))
			wait = 10
		3:
			GS.set_flag("wrong_things_started")
			ok(spawner.draining(), "draining once the main quest has started")
			# Close enough to see it (witness_range 25 m), too far for the wisps to pick a fight (16 m).
			p.global_position = spawner.global_position + Vector3(0, 0, 24)
			clock.advance(clock.hours_until(22.0))
			wait = 3
		4:
			ok(spawner.get_child_count() == spawner.count, "a fresh night of wisps", spawner.get_child_count())
			wait = 30   # past drain_delay (0.2 s)
		5:
			var gone: Array = spawner.get_children().filter(func(w): return w.state == w.State.DEAD)
			ok(gone.size() == 1, "one wisp drained", gone.size())
			drained = gone[0] if gone.size() > 0 else null
			ok(GS.has_flag("saw_wisp_drained"), "the player saw it")
			ok(p.hud.message_label.text.begins_with("A wisp drifts into the crystal"), "message", p.hud.message_label.text)
			ok(drained != null and drained.collision_layer == 0, "a drained wisp can't be hit")
			wait = 260
		6:
			ok(not is_instance_valid(drained), "the drained wisp is gone after its streak north")
			ok(spawner.get_child_count() == spawner.count - 1, "only one a night", spawner.get_child_count())
			# A fighting wisp is never drained.
			for w in spawner.get_children():
				w.state = w.State.ENGAGE
			ok(spawner.drain_one() == null, "fighting wisps aren't drained")
			# The drain-line, via the crystal (Riverwatch ending).
			for flag in ["touched_crystal", "stones_quest_started", "shards_decided", "shards_given", "stones_quest_done"]:
				GS.set_flag(flag)
			ok(autoload("QuestLog").status("waking_stones")["state"] == "active", "waking stones waits on the crystal")
			current_scene.get_node("StoneCircle/Crystal").interact(p)
			ok(GS.has_flag("saw_drain_line") and line.visible, "the crystal shows the drain-line")
			ok(autoload("QuestLog").status("waking_stones")["state"] == "completed", "waking stones complete")
			var far: Vector3 = line.point(1.0)
			ok(far.z < -50.0 and absf(far.x - line.global_position.x) < 0.01, "it runs north to the level's edge", far)
			wait = 10
		7:
			var motes: Array = line.get_children().filter(func(m): return m.mesh is SphereMesh)
			ok(motes.size() == line.mote_count, "motes on the line", motes.size())
			ok(motes.all(func(m): return m.position.z <= 0.0 and m.position.z >= -line.length), "motes run along it")
			# Brannoc.
			var DM = autoload("DialogueManager")
			DM.start("res://dialogue/brannoc.json", "Brannoc")
			var texts: Array = DM._choices.map(func(c): return c["text"])
			ok(texts.size() > 0 and texts[0].begins_with("The crystal showed me"), "Brannoc asks about the line", texts)
			DM.choose(0)
			ok(DM.line_label.text.begins_with("North. Into the Thornwood."), "Brannoc on the Thornwood", DM.line_label.text)
			ok(GS.has_flag("told_brannoc_drain"), "told Brannoc")
			DM.end()
			DM.start("res://dialogue/brannoc.json", "Brannoc")
			texts = DM._choices.map(func(c): return c["text"])
			ok(not texts.any(func(t): return t.begins_with("The crystal showed me")), "not asked twice", texts)
			DM.end()
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
