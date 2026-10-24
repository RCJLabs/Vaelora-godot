extends "res://tests/test_base.gd"
# Background openings: each of the six backgrounds starts at its own marker,
# facing its own way, with its items, the intro card and main quest 1 started.
# A level loaded without a new game (F6, or a save) plays no opening, and the
# card can be skipped.
const LEVEL := "res://levels/test_level.tscn"
const ITEMS := {"soldier": "posting_orders", "scholar": "collegium_letter", "outlaw": "wanted_notice",
		"merchant": "wagon_manifest", "hunter": "", "acolyte": ""}
# What each start looks towards: the waystation through the gate, the stone circle,
# the waystation, the waystation, the shrine, up the road.
const LOOKS_AT := {"soldier": Vector3(0, 0, 0), "scholar": Vector3(-11, 0, -9), "outlaw": Vector3(3, 0, -2),
		"hunter": Vector3(3, 0, -2), "acolyte": Vector3(-3, 0, 9), "merchant": Vector3(1, 0, 0)}
var f := 0
var step := 0
var wait := 0
var bg_index := -1
var backgrounds: Array = ITEMS.keys()

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	change_scene_to_file(LEVEL)

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	var O = autoload("Openings")
	var p = get_first_node_in_group("player")
	match step:
		0:
			wait = 10
		1:
			ok(not O.card_visible(), "no card when a level loads without a new game")
			near(p.global_position.x, 0.0, 0.3, "F6: default spawn x")
			ok(not autoload("GameState").has_flag("wrong_things_started"), "F6: main quest not started")
			ok(O.starts.size() == 6, "six openings in openings.json", O.starts.keys())
		2:
			bg_index += 1
			if bg_index >= backgrounds.size():
				step = 10
				return false
			var bg: String = backgrounds[bg_index]
			autoload("Character").create(load("res://races/human.tres"), "T", bg, [], {}, {})
			O.pending = true
			change_scene_to_file(LEVEL)
			wait = 10
		3:
			var bg: String = backgrounds[bg_index]
			var start: Dictionary = O.starts[bg]
			var marker: Node3D = current_scene.get_node(start["marker"])
			ok(p.owner == current_scene, "%s: the new level's player" % bg)
			near(p.global_position.distance_to(marker.global_position), 0.0, 0.3, "%s: starts at %s" % [bg, start["marker"]])
			near(absf(angle_difference(p.rotation.y, marker.global_rotation.y)), 0.0, 0.01, "%s: facing the marker's way" % bg)
			var forward: Vector3 = -p.global_transform.basis.z
			var to_target: Vector3 = (LOOKS_AT[bg] - p.global_position) * Vector3(1, 0, 1)
			between(forward.dot(to_target.normalized()), 0.95, 1.0, "%s: looking the right way" % bg)
			ok(not O.pending, "%s: the opening is used up" % bg)
			ok(O.card_visible(), "%s: intro card showing" % bg)
			var labels: Array = O._card.find_children("*", "Label", true, false)
			ok(labels.size() == 2 and labels[0].text == start["title"], "%s: card title" % bg, labels.map(func(l): return l.text))
			var GS = autoload("GameState")
			ok(GS.has_flag("wrong_things_started") and GS.has_flag("opening_" + bg), "%s: flags set" % bg)
			var Q = autoload("QuestLog")
			ok(Q.status("wrong_things")["state"] == "active", "%s: Wrong Things started" % bg)
			ok(Q.current_objective("wrong_things") == "Talk to Maren at the waystation.", "%s: first objective" % bg, Q.current_objective("wrong_things"))
			if ITEMS[bg] != "":
				ok(autoload("Inventory").count(ITEMS[bg]) == 1, "%s: has %s" % [bg, ITEMS[bg]])
			# Maren knows why you're here.
			var DM = autoload("DialogueManager")
			DM.start("res://dialogue/maren.json", "Maren")
			var texts: Array = DM._choices.map(func(c): return c["text"])
			ok(DM._choices.size() > 0 and DM._choices[0].get("requires_background", "") == bg, "%s: Maren's first choice is the background's" % bg, texts)
			DM.choose(0)
			DM.choose(0)
			ok(DM.line_label.text.begins_with("Small wrong things."), "%s: leads to the wrong things" % bg, DM.line_label.text)
			DM.end()
			ok(Q.current_objective("wrong_things").begins_with("Find the hollow wolf"), "%s: next objective" % bg, Q.current_objective("wrong_things"))
			step = 2
			return false
		10:
			# Skipping the card.
			var press := InputEventAction.new()
			press.action = "interact"
			press.pressed = true
			Input.parse_input_event(press)
		11:
			var release := InputEventAction.new()
			release.action = "interact"
			Input.parse_input_event(release)
			wait = 40
		12:
			ok(not O.card_visible(), "interact skips the card")
			O.show_card("Test", "A card.")
			paused = true
			wait = 2
		13:
			ok(not O.card_visible(), "pausing closes the card")
			paused = false
			O.show_card("Test", "A card.")
			autoload("DialogueManager").start("res://dialogue/maren.json", "Maren")
			wait = 2
		14:
			ok(not O.card_visible(), "a conversation closes the card")
			autoload("DialogueManager").end()
			# The marker positions are clear of walls and props: nobody starts stuck.
			for bg in backgrounds:
				var marker: Node3D = current_scene.get_node(O.starts[bg]["marker"])
				var space = p.get_world_3d().direct_space_state
				var query := PhysicsShapeQueryParameters3D.new()
				var shape := CapsuleShape3D.new()
				shape.radius = 0.4
				shape.height = 1.8
				query.shape = shape
				query.transform = Transform3D(Basis(), marker.global_position + Vector3(0, 1.0, 0))
				query.collision_mask = 1
				var hits: Array = space.intersect_shape(query).filter(func(h): return h["collider"].name != "Ground")
				ok(hits.is_empty(), "%s: start spot is clear" % bg, hits.map(func(h): return h["collider"].name))
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
