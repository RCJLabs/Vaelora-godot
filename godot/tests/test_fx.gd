extends "res://tests/test_base.gd"
# Effects (props/fx.gd): chimney smoke (systems/dresser.gd), campfire embers, motes
# in the air by mood and hour (levels/sky_dome.gd), hit bursts; and none of the
# ambient ones on Low. docs/godot-starter/LOOK.md, "Effects".
var f := 0
var step := 0
var wait := 0
var S

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/weirholt.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

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
			wait = 10
		1:
			var smoke = n("CountingHouseDressing/Smoke")
			ok(smoke is CPUParticles3D and smoke.emitting, "chimneys smoke")
			var dn = n("DayNight")
			dn.apply(12.0)
			ok(n("SkyDome/MotesDay") != null and n("SkyDome/MotesDay").emitting and not n("SkyDome/MotesNight").emitting, "pollen by day")
			dn.apply(23.0)
			ok(n("SkyDome/MotesNight").emitting and not n("SkyDome/MotesDay").emitting, "fireflies by night")
			# A hit: a burst, gone when it's done.
			var before: int = current_scene.get_children().filter(func(c): return c is CPUParticles3D).size()
			Fx.burst(self, Vector3(0, 1, 0), true)
			var bursts: Array = current_scene.get_children().filter(func(c): return c is CPUParticles3D)
			ok(bursts.size() == before + 1 and bursts.back().one_shot and bursts.back().emitting, "a hit throws a one-off burst")
			wait = 60
		2:
			ok(current_scene.get_children().filter(func(c): return c is CPUParticles3D).is_empty(), "and cleans itself up")
			change_scene_to_file("res://levels/test_level.tscn")
			wait = 20
		3:
			var fires: Array = get_nodes_in_group("heat_source").filter(func(h): return h.get_node_or_null("Embers") != null)
			ok(not fires.is_empty(), "campfires throw embers (and smoke)", fires.size())
			change_scene_to_file("res://levels/grieving_fields.tscn")
			wait = 20
		4:
			var day: CPUParticles3D = n("SkyDome/MotesDay")
			ok(day != null and day.mesh.size.x > 0.08, "ash on the Grieving Fields")
			# Low: no ambient effects.
			S.set_option("graphics_quality", 0)
			change_scene_to_file("res://levels/weirholt.tscn")
			wait = 20
		5:
			ok(n("CountingHouseDressing/Smoke") == null, "no chimney smoke on Low")
			ok(n("SkyDome/MotesDay") == null, "and no motes")
			S.set_option("graphics_quality", 2)
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
