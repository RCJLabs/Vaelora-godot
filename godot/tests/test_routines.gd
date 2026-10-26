extends "res://tests/test_base.gd"
# NPC daily routines (interactables/npc.gd, Routine): by day at their spot, in the
# evening at the Gathering, at night home (in at their own door), out again in the
# morning; a jump in the clock (sleep, fast travel) puts them straight where they
# should be; they walk there otherwise, but not mid-conversation; people without a
# routine stay put. docs/godot-starter/ROUTINES.md.
var f := 0
var step := 0
var wait := 0
var W
var spot := Vector3.ZERO
var walked_from := Vector3.ZERO
var budget := 0

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/weirholt.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	W = autoload("WorldClock")
	var wenna = n("Wenna")
	match step:
		0:
			W.hour = 10.0
			wait = 10
		1:
			ok(wenna.routine and not n("Hedda").routine, "Wenna keeps a routine; Hedda keeps the inn")
			ok(wenna._home != null and wenna._home.get_meta("home_of") == "Wenna", "Wenna has a door of her own")
			var doors := get_nodes_in_group("home_door").filter(func(d): return d.has_meta("home_of")).map(func(d): return d.get_meta("home_of"))
			var unique := {}
			for who in doors:
				unique[who] = true
			ok(doors.size() == 5 and unique.size() == 5, "five people, five different doors", doors)
			spot = wenna._spot
			ok(wenna.phase == wenna.Phase.DAY and flat(wenna.global_position, spot) <= wenna.wander + 0.6, "by day she's at her stall (wandering a little)")
			W.hour = 19.0   # a jump: straight there
			wait = 3
		2:
			ok(wenna.phase == wenna.Phase.GATHER and flat(wenna.global_position, n("Gathering").global_position) < 3.0, "in the evening, at the inn with the others")
			W.hour = 23.0
			wait = 3
		3:
			ok(wenna.inside and not wenna.visible and wenna.collision_layer == 0, "at night she's gone in")
			ok(flat(wenna.global_position, wenna.door_step()) < 0.1, "at her own door")
			ok(n("Hedda").visible and n("Hedda").global_position.distance_to(Vector3(-12, 0, -17.5)) < 0.1, "Hedda's still up, at the inn")
			# Morning: out again, at the stall.
			W.hour = 8.0
			wait = 3
		4:
			ok(not wenna.inside and wenna.visible and wenna.collision_layer == 1 and flat(wenna.global_position, spot) < 0.1, "in the morning she's back")
			# Walking: no jump this time, from the evening to bedtime.
			W.hour = 21.3
			wait = 3
		5:
			W.hour = 21.45   # a small step: no jump
			wait = 1
		6:
			W.hour = wenna.sleep_hour + 0.01
			wait = 2
		7:
			ok(wenna.phase == wenna.Phase.HOME and not wenna._path.is_empty() and not wenna.inside, "at bedtime she walks home", wenna._path.size())
			walked_from = wenna.global_position
			# Not while you're talking to her.
			wenna.interact(get_first_node_in_group("player"))
			wait = 30
		8:
			ok(wenna.global_position.distance_to(walked_from) < 0.01, "but not in the middle of a conversation")
			autoload("DialogueManager").end()
			Engine.time_scale = 8.0   # let her walk
			budget = 1200
			step = 9
			return false
		9:
			budget -= 1
			if wenna.inside or budget <= 0:
				Engine.time_scale = 1.0
				ok(wenna.inside and flat(wenna.global_position, wenna.door_step()) < 0.5, "and goes in at her door", [wenna.global_position, wenna.door_step()])
				change_scene_to_file("res://levels/ilunhall.tscn")
				wait = 20
				step = 10
			return false
		10:
			var karra = n("Karra")
			ok(karra.routine and karra._home != null and karra._home.global_position.y < 2.0, "Karra in Ilunhall lives down on the quay")
			ok(not n("Odo").routine, "Odo keeps the Long Table open")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
