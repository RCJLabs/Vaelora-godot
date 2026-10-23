extends "res://tests/test_base.gd"
# Collision set-up mistakes (FIRST_PERSON_SETUP.md troubleshooting): each variant
# breaks the test level's floor or the player's shape in one way, and the test checks
# whether the player still stands or falls through. Argument: a variant name;
# anything else (e.g. "human") is the unbroken baseline, which must stand.
const EXPECT_FALL := ["empty_ground_shape", "shape_under_mesh", "default_box_size_offcenter",
		"player_mask_zero", "player_shape_empty"]
const EXPECT_STAND := ["ground_layer_not_in_mask", "ground_scaled_body", "centered_capsule_at_y0",
		"centered_capsule_at_y_minus_0_3"]
var frames := 0
var player: CharacterBody3D
var variant: String

func _initialize() -> void:
	variant = arg("baseline")
	var level: Node = load("res://levels/test_level.tscn").instantiate()
	player = level.get_node("Player")
	var ground: StaticBody3D = level.get_node("Ground")
	var gshape: CollisionShape3D = ground.get_node("CollisionShape3D")
	var gmesh: MeshInstance3D = ground.get_node("MeshInstance3D")
	match variant:
		"empty_ground_shape": gshape.shape = null
		"shape_under_mesh":
			ground.remove_child(gshape); gmesh.add_child(gshape)
		"default_box_size_offcenter":
			gshape.shape = BoxShape3D.new(); player.position = Vector3(5, 2, 5)
		"player_mask_zero": player.collision_mask = 0
		"ground_layer_not_in_mask": ground.collision_layer = 4
		"ground_scaled_body":
			gshape.shape = BoxShape3D.new(); gmesh.mesh = BoxMesh.new(); ground.scale = Vector3(50, 1, 50); player.position = Vector3(5, 2, 5)
		"centered_capsule_at_y0":
			var ps: CollisionShape3D = player.get_node("CollisionShape3D"); ps.position = Vector3.ZERO; player.position = Vector3(0, 0, 0)
		"centered_capsule_at_y_minus_0_3":
			var ps2: CollisionShape3D = player.get_node("CollisionShape3D"); ps2.position = Vector3.ZERO; player.position = Vector3(0, -0.3, 0)
		"player_shape_empty":
			player.get_node("CollisionShape3D").shape = null
	root.add_child(level)

func _physics_process(_d: float) -> bool:
	frames += 1
	if frames == 180:
		var stands := player.is_on_floor() and player.global_position.y > -0.5
		if variant in EXPECT_FALL:
			ok(not stands, "%s: player falls through" % variant, player.global_position)
		else:
			ok(stands, "%s: player stands on the floor" % variant, player.global_position)
		return done()
	return false
