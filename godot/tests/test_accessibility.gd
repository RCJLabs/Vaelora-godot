extends "res://tests/test_base.gd"
# Accessibility options: toggle sprint, toggle block, camera shake strength,
# interface size, and the settings page.
var f := 0
var step := 0
var wait := 0
var p
var S

func _initialize() -> void:
	var level = load("res://levels/test_level.tscn").instantiate()
	root.add_child(level); current_scene = level
	level.get_node("Player").position = Vector3(-40, 0.1, 20)
	level.get_node("Player").rotation.y = deg_to_rad(-90)   # face +X: open ground

func speed() -> float:
	return Vector2(p.velocity.x, p.velocity.z).length()

func _physics_process(_d: float) -> bool:
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = current_scene.get_node("Player"); S = autoload("Settings")
	match step:
		0: wait = 30
		1:
			# Hold to sprint (default): letting go walks.
			Input.action_press("move_forward"); Input.action_press("sprint"); wait = 40
		2:
			near(speed(), p.sprint_speed, 0.2, "holding Shift sprints")
			Input.action_release("sprint"); wait = 30
		3:
			near(speed(), p.walk_speed, 0.2, "letting go of Shift walks (hold mode)")
			S.set_option("toggle_sprint", true)
			Input.action_press("sprint"); wait = 1
		4:
			Input.action_release("sprint"); wait = 40
		5:
			near(speed(), p.sprint_speed, 0.2, "toggle mode: one tap keeps sprinting")
			Input.action_press("sprint"); wait = 1
		6:
			Input.action_release("sprint"); wait = 30
		7:
			near(speed(), p.walk_speed, 0.2, "a second tap walks again")
			Input.action_press("sprint"); wait = 1
		8:
			Input.action_release("sprint"); wait = 30
		9:
			near(speed(), p.sprint_speed, 0.2, "sprinting (toggled) again")
			Input.action_release("move_forward"); wait = 30
		10:
			Input.action_press("move_forward"); wait = 40
		11:
			near(speed(), p.walk_speed, 0.2, "stopping ends a toggled sprint")
			Input.action_release("move_forward")
			S.set_option("toggle_sprint", false)
			# Toggle block.
			autoload("Spellbook").ready_block()
			S.set_option("toggle_block", true)
			Input.action_press("cast"); wait = 1
		12:
			Input.action_release("cast"); wait = 10
		13:
			ok(p.combat.is_blocking(), "toggle block: a tap raises the guard and it stays up")
			Input.action_press("cast"); wait = 1
		14:
			Input.action_release("cast"); wait = 10
		15:
			ok(not p.combat.is_blocking(), "a second tap lowers it")
			S.set_option("toggle_block", false)
			Input.action_press("cast"); wait = 10
		16:
			ok(p.combat.is_blocking(), "hold mode: blocking while held")
			Input.action_release("cast"); wait = 10
		17:
			ok(not p.combat.is_blocking(), "hold mode: letting go lowers it")
			# Camera shake.
			S.set_option("camera_shake", 0.0)
			p._camera_kick = Vector3.ZERO
			p.camera_kick(Vector3(-4, 0, 3))
			ok(p._camera_kick.length() < 0.001, "camera shake 0%: hits don't jolt the view", p._camera_kick)
			S.set_option("camera_shake", 0.5)
			p.camera_kick(Vector3(-4, 0, 0))
			near(p._camera_kick.x, -2.0, 0.01, "camera shake 50%: half the jolt")
			S.set_option("camera_shake", 1.0)
			# Interface size.
			S.set_option("ui_scale", 1.3)
			near(root.content_scale_factor, 1.3, 0.001, "interface size 130% scales the UI")
			var config := ConfigFile.new()
			config.load(S.PATH)
			ok(is_equal_approx(config.get_value("settings", "ui_scale", 0.0), 1.3) and config.get_value("settings", "toggle_block", null) == false, "options are saved")
			S.set_option("ui_scale", 1.0)
			near(root.content_scale_factor, 1.0, 0.001, "and back to 100%")
			autoload("PauseMenu").open_page("accessibility")
			wait = 3
		18:
			var PM = autoload("PauseMenu")
			ok(PM.title_label.text == "Accessibility", "Settings → Accessibility page opens")
			var boxes = PM.content.find_children("*", "CheckBox", true, false)
			ok(boxes.size() == 2, "two toggles on the page", boxes.size())
			PM.close()
			return done()
	step += 1
	return false
