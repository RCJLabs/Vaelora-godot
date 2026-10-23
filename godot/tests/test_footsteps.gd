extends "res://tests/test_base.gd"
# Footsteps by surface and stride, landing thuds, and the ambience / campfire loops.
var f := 0
var steps := []          # [frame, sound name, volume_db]
var last_pos := {}

func player(): return get_first_node_in_group("player")

func _initialize() -> void:
	var level = load("res://levels/test_level.tscn").instantiate()
	root.add_child(level); current_scene = level
	level.get_node("Player").position = Vector3(-40, 0.1, 20)
	level.get_node("Player").rotation.y = deg_to_rad(-90)

# Records each new footstep sound started on one of Sfx's players.
func watch() -> void:
	for p in autoload("Sfx").get_children():
		if not (p is AudioStreamPlayer) or p.stream == null: continue
		var pos = p.get_playback_position()
		if p.playing and pos < last_pos.get(p, 99.0) and "footstep" in p.stream.resource_path:
			steps.append([f, p.stream.resource_path.get_file().get_basename(), p.volume_db])
		last_pos[p] = pos if p.playing else 99.0

func count(from: int, to: int, prefix: String) -> int:
	return steps.filter(func(s): return s[0] >= from and s[0] < to and s[1].begins_with(prefix)).size()

func _physics_process(_d: float) -> bool:
	f += 1
	watch()
	var p = player()
	match f:
		30: Input.action_press("move_forward")
		210:
			between(count(90, 210, "footstep_soft"), 5, 7, "soft steps in 2 s walking")
			ok(p.footsteps.surface() == "soft", "grass counts as soft", p.footsteps.surface())
			Input.action_press("sprint")
		390:
			between(count(270, 390, "footstep_soft"), 6, 8, "soft steps in 2 s sprinting")
			Input.action_release("sprint"); Input.action_release("move_forward")
		420: p.global_position = Vector3(4, 1.05, -6); p.velocity = Vector3.ZERO
		430: ok(p.footsteps.surface() == "stone", "the stone block counts as stone", p.footsteps.surface())
		440: Input.action_press("move_forward"); p.rotation.y = 0.0
		470:
			ok(count(440, 471, "footstep_stone") >= 1, "a stone step on the block")
			Input.action_release("move_forward")
		500: p.global_position = Vector3(-30, 4.0, 20); p.velocity = Vector3.ZERO
		560:
			var landing = steps.filter(func(s): return s[0] >= 500 and s[0] < 560)
			ok(landing.size() == 1, "one landing step after a 4 m fall", landing)
			if landing.size() > 0:
				ok(landing[0][2] > p.footsteps.VOLUME_DB + 3.0, "landing is louder than a step", landing[0][2])
			var amb = current_scene.get_node("Ambience")
			ok(amb.get_child_count() == 2 and amb.get_children().all(func(c): return c.playing), "day and night ambience loops play")
			ok(amb.get_children().any(func(c): return c.volume_db > -20.0) and amb.get_children().any(func(c): return c.volume_db < -40.0), "at 08:00 one loop is up and the other faded out", amb.get_children().map(func(c): return c.volume_db))
			var fire = current_scene.get_node("Campfire").get_children().filter(func(c): return c is AudioStreamPlayer3D)
			ok(fire.size() == 1 and fire[0].playing and fire[0].stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "campfire crackle loops")
			change_scene_to_file("res://levels/waystation_cellar.tscn")
		580: Input.action_press("move_forward")
		640:
			Input.action_release("move_forward")
			ok(player().footsteps.surface() == "stone", "the cellar floor counts as stone", player().footsteps.surface())
			ok(count(580, 641, "footstep_stone") >= 2, "stone steps in the cellar")
			ok(current_scene.get_node("Ambience").get_child_count() == 1, "the cellar plays one room-tone loop")
			return done()
	return false
