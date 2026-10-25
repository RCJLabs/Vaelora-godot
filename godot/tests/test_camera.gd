extends "res://tests/test_base.gd"
# First and third person (player/player_view.gd): V switches; each camera draws
# only its own things (first-person hands and weapons, or the body); in third
# person the eye turns to what's under the crosshair, so you can take a potion
# you're pointing at; a wall behind you pulls the camera in (and hides the body
# when it's that close); what you hold is on the body, posed like the first-person
# model and rebuilt when you change weapons; the choice survives a level load
# (Settings); V again goes back; and V does nothing mid-conversation.
var f := 0
var step := 0
var wait := 0
var p
var V
var wall: StaticBody3D

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func key(k: Key) -> void:
	var e := InputEventKey.new(); e.keycode = k; e.physical_keycode = k; e.pressed = true
	Input.parse_input_event(e)
	var r := InputEventKey.new(); r.keycode = k; r.physical_keycode = k; r.pressed = false
	Input.parse_input_event(r)

func stand(at: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.rotation.y = deg_to_rad(yaw_deg)
	p.get_node("Head").rotation.x = deg_to_rad(pitch_deg)

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	V = p.get_node("View") if p else null
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			wait = 5
		1:
			ok(V != null and not V.third_person, "first person to start")
			ok(p.camera.current and not V.camera.current, "the eye camera is the one drawing")
			ok(not V.body.visible, "no body in first person")
			var models: Array = p.camera.find_children("*", "GeometryInstance3D", true, false)
			ok(models.size() > 0 and models.all(func(m): return m.layers == V.VIEWMODEL_LAYER), "first-person models are on their own layer", models.filter(func(m): return m.layers != V.VIEWMODEL_LAYER).map(func(m): return [m.get_path(), m.layers]))
			ok(p.camera.cull_mask & V.BODY_LAYER == 0 and p.camera.cull_mask & V.VIEWMODEL_LAYER != 0, "the eye sees hands, not the body")
			ok(V.camera.cull_mask & V.VIEWMODEL_LAYER == 0 and V.camera.cull_mask & V.BODY_LAYER != 0, "the third-person camera sees the body, not floating hands")
			stand(Vector3(0, 0.05, 6), 0, 0)
			key(KEY_V)
			wait = 3
		2:
			ok(V.third_person and V.camera.current and not p.camera.current, "V: third person")
			ok(autoload("Settings").third_person, "remembered in Settings")
			ok(V.body.visible, "and there you are")
			# What you hold, on the body.
			var sword: Node3D = V.held_copy("Weapon")
			var parts: Array = sword.find_children("*", "GeometryInstance3D", true, false) if sword else []
			ok(parts.size() > 0 and parts.all(func(m): return m.layers == V.BODY_LAYER), "your sword is on the body (body layer)", parts.size())
			var hand: Node3D = V.held_copy("SpellHand")
			ok(hand != null and hand.find_children("*", "Light3D", true, false).is_empty(), "the spell hand too, without a second light")
			var local: Vector3 = p.get_node("Head").global_transform.affine_inverse() * V.camera.global_position
			ok(local.z > 2.0 and local.x > 0.3, "the camera is behind your right shoulder", local)
			# Aim: the eye looks where the crosshair points.
			var aim: Vector3 = V.crosshair_point() - p.camera.global_position
			var eye_forward: Vector3 = -p.camera.global_transform.basis.z
			ok(rad_to_deg(eye_forward.angle_to(aim)) < 1.5, "the eye aims at what's under the crosshair", rad_to_deg(eye_forward.angle_to(aim)))
			# Put the potion under the crosshair, 2 m past your head: you can take it.
			var cam: Camera3D = V.camera
			var reach: float = cam.global_position.distance_to(p.get_node("Head").global_position) + 2.0
			n("Potion").global_position = cam.global_position - cam.global_transform.basis.z * reach
			wait = 3
		3:
			ok(p.hud.prompt_label.text == "[E] Take Minor Healing Potion", "take what the crosshair is on, in third person", p.hud.prompt_label.text)
			# The copy takes the first-person model's pose (here, raised overhead).
			p.weapon.go("overhead", 0.01)
			var I = autoload("Inventory")
			I.add("iron_mace")
			I.equip("iron_mace")
			wait = 3
			step += 1
			return false
		4:
			var held: Node3D = V.held_copy("Weapon")
			ok(held.transform.origin.is_equal_approx(p.weapon.transform.origin * V.REACH_SCALE) and held.transform.basis.is_equal_approx(p.weapon.transform.basis), "the body's weapon follows the first-person pose", [held.transform.origin, p.weapon.transform.origin])
			ok(held.get_child_count() == p.weapon.get_child_count() and held.get_child(0).name == p.weapon.get_child(0).name, "and changes with your weapon", [held.get_child(0).name, p.weapon.get_child(0).name])
			# A wall right behind you pulls the camera in.
			n("Potion").global_position = Vector3(100, -50, 100)
			wall = StaticBody3D.new()
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(6, 6, 0.5)
			shape.shape = box
			wall.add_child(shape)
			current_scene.add_child(wall)
			wall.global_position = p.get_node("Head").global_position + Vector3(0, 0, 1.2)
			wait = 3
		5:
			var dist: float = V.camera.global_position.distance_to(p.get_node("Head").global_position)
			ok(dist < 1.3, "a wall behind you pulls the camera in", dist)
			ok(not V.body.visible, "and the body hides that close", V.arm.get_hit_length())
			wall.queue_free()
			# Still third person after loading another level (and back).
			change_scene_to_file("res://levels/waystation_cellar.tscn")
			wait = 30
		6:
			ok(V != null and V.third_person and V.camera.current, "still third person in the next level")
			key(KEY_V)
			wait = 3
		7:
			ok(not V.third_person and p.camera.current, "V again: first person")
			ok(V.aim_rotation == Vector3.ZERO and not V.body.visible, "the eye looks straight ahead again, and no body")
			ok(not autoload("Settings").third_person, "remembered")
			# A weapon equipped now is a first-person model too.
			var I = autoload("Inventory")
			I.add("iron_axe")
			I.equip("iron_axe")
			wait = 3
			step += 1
			return false
		8:
			var axe: Array = p.camera.get_node("Weapon").find_children("*", "GeometryInstance3D", true, false)
			ok(axe.size() > 0 and axe.all(func(m): return m.layers == V.VIEWMODEL_LAYER), "a weapon equipped later goes on the first-person layer too", axe.size())
			autoload("DialogueManager").start("res://dialogue/maren.json", "Maren")
			key(KEY_V)
			wait = 3
		9:
			ok(not V.third_person, "V does nothing mid-conversation")
			autoload("DialogueManager").end()
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
