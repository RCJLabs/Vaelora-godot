extends "res://tests/test_base.gd"
# Sprinting until exhausted and recovering while Shift stays held; then Continue on the title screen loads the save.
var f := 0
var phase := "sprint"

func player(): return get_first_node_in_group("player")

func speed(p) -> float: return Vector2(p.velocity.x, p.velocity.z).length()

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	var level = load("res://levels/test_level.tscn").instantiate()
	root.add_child(level); current_scene = level
	level.get_node("Player").rotation.y = deg_to_rad(-90)   # face +X
	level.get_node("Player").position = Vector3(-55, 1, 20)  # 110 m runway

func _physics_process(_d: float) -> bool:
	f += 1
	var p = player()
	if phase == "sprint":
		match f:
			60: Input.action_press("move_forward"); Input.action_press("sprint")
			120:
				near(speed(p), 8.0, 0.1, "sprint speed")
				between(p.stats.stamina, 80.0, 95.0, "stamina after 1 s of sprinting")
			590:
				ok(p._exhausted, "exhausted after about 8.7 s")
				near(p.stats.stamina, 0.0, 1.0, "stamina empty")
				near(speed(p), 5.0, 0.1, "slowed to walking")
			700:
				ok(p._exhausted, "still exhausted 1.8 s later with Shift held")
				near(speed(p), 5.0, 0.1, "still walking speed")
				between(p.stats.stamina, 10.0, 30.0, "stamina recovering while exhausted")
				near(p.global_position.y, 0.0, 0.05, "on the ground")
			760:
				ok(not p._exhausted, "exhaustion over 2.8 s later")
				near(speed(p), 8.0, 0.1, "sprinting again with Shift still held")
			761:
				Input.action_release("move_forward"); Input.action_release("sprint")
				p.global_position = Vector3(7, 0, 3)
				autoload("SaveSystem").save_game()
				# go back to the title screen like a fresh launch
				change_scene_to_file("res://ui/title_screen.tscn")
				phase = "menu"; f = 0
	elif phase == "menu":
		if f == 5:
			var button = current_scene.get_node("%Buttons/ContinueButton")
			ok(button.visible, "title screen shows Continue")
			button.emit_signal("pressed")
		if f == 15:
			ok(current_scene.name == "TestLevel", "Continue loads the level", current_scene.name)
			ok(player() != null and player().global_position.distance_to(Vector3(7, 0, 3)) < 0.5, "at the saved position", player().global_position if player() else null)
			autoload("SaveSystem").delete_save()
			return done()
	return false
