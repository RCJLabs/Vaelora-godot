extends "res://tests/test_base.gd"
# Ground cover (props/ground_cover.gd): grass, flowers, reeds and stones scattered
# over each region's grass, never on a road, the same every time, thinner on
# Medium and gone on Low. docs/godot-starter/LOOK.md, "Ground cover".
var f := 0
var step := 0
var wait := 0
var S
var first := {}

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/weirholt.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func total(counts: Dictionary) -> int:
	var t := 0
	for k in counts:
		t += counts[k]
	return t

func _process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	S = autoload("Settings")
	match step:
		0:
			S.graphics_quality = 2   # High
			wait = 10
		1:
			var cover = n("GroundCover")
			ok(cover != null and cover.style == "riverbank", "Weirholt has riverbank cover")
			first = cover.counts()
			ok(first.get("tuft", 0) > 5000 and first.get("reed", 0) > 0 and first.get("stone", 0) > 0, "grass, reeds and stones", first)
			# Nothing on the woods road (it sits on the grass, so the rays hit it first).
			var road: Node3D = n("Road")
			var on_road := 0
			for mmi in cover.get_children():
				for i in mmi.multimesh.instance_count:
					var at: Vector3 = mmi.multimesh.get_instance_transform(i).origin
					if absf(at.x - road.global_position.x) < 2.8 and absf(at.z - road.global_position.z) < 31.0:
						on_road += 1
			ok(on_road == 0, "nothing grows on the road", on_road)
			ok(cover.get_children().all(func(c): return c.visibility_range_end > 0.0), "each chunk is hidden past the clutter range")
			# The same every time; timing for the curious.
			var started := Time.get_ticks_msec()
			cover.build()
			print("ground cover build: %d ms for %d" % [Time.get_ticks_msec() - started, total(cover.counts())])
			ok(cover.counts() == first, "the same scatter every time")
			# Presets.
			S.set_option("graphics_quality", 1)   # Medium
			wait = 3
		2:
			var medium: int = total(n("GroundCover").counts())
			ok(medium > 0 and medium < total(first) * 0.7, "thinner on Medium", [medium, total(first)])
			S.set_option("graphics_quality", 0)   # Low
			wait = 3
		3:
			ok(n("GroundCover").get_child_count() == 0, "none on Low")
			S.set_option("graphics_quality", 2)
			wait = 3
		4:
			ok(n("GroundCover").counts() == first, "back on High, back as it was")
			change_scene_to_file("res://levels/ilunhall.tscn")
			wait = 20
		5:
			ok(n("GroundCover") == null, "no grass on Ilunhall's paving")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
