extends "res://tests/test_base.gd"
# The moons rise and set (levels/wanderer_moon.gd): each is up 12 hours, rising
# in the east, highest in the south, setting in the west, rising later the fuller
# it is (full: up all night; dark: up only by day). Full Ilun on the first night
# rises at dusk, is high at midnight and low in the west by dawn; the waxing
# Wanderer is up in the evening and gone after midnight; on Lanternfast it's
# not in the night sky at all, but one light hangs in the north, keeping watch
# (only that night). The disc is drawn where the moon is. The night
# light comes from Ilun while it's up (never lower than 15 degrees) and is
# dimmer while it's down.
var f := 0
var step := 0
var wait := 0
var W
var ilun
var wanderer
var full_light := 0.0

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func elevation(d: Vector3) -> float:
	return rad_to_deg(asin(clampf(d.y, -1.0, 1.0)))

func light_dir() -> Vector3:
	return n("Sun").global_transform.basis.z   # towards the light

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	W = autoload("WorldClock")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			ilun = n("IlunMoon"); wanderer = n("WandererMoon")
			wait = 3
		1:
			# Full Ilun, the first night.
			W.day = 1; W.hour = 18.5
			var d: Vector3 = ilun.direction
			ok(d.y > 0.0 and elevation(d) < 15.0 and d.x > 0.9, "full Ilun rises in the east at dusk", d)
			W.day = 2; W.hour = 0.0
			d = ilun.direction
			ok(elevation(d) > 45.0 and d.z > 0.0, "high in the south at midnight", [elevation(d), d])
			W.hour = 5.5
			d = ilun.direction
			ok(d.y > 0.0 and elevation(d) < 20.0 and d.x < -0.8, "low in the west before dawn", d)
			W.hour = 9.0
			ok(not ilun.is_up(), "set by morning")
			# The Wanderer, waxing: up in the evening, gone after midnight.
			W.day = 2; W.hour = 20.0
			ok(wanderer.is_up() and wanderer.direction.x < 0.0, "the waxing Wanderer is up in the evening, westering", wanderer.direction)
			W.day = 3; W.hour = 3.0
			ok(not wanderer.is_up(), "and gone by 3:00")
			# Full, it's up at midnight.
			W.day = 4; W.hour = 0.0
			ok(wanderer.is_up() and wanderer.direction.z > 0.5, "the full Wanderer is up at midnight, in the south", wanderer.direction)
			# Lanternfast: dark, and not in the night sky.
			W.day = 7; W.hour = 20.5
			ok(not wanderer.is_up(), "on Lanternfast it's not in the night sky")
			wait = 6   # (physics frames can run before the next _process)
		2:
			ok(not wanderer._disc.visible, "so no disc")
			# But one light in the north: whoever is aboard, keeping watch.
			var cam: Camera3D = root.get_camera_3d()
			var to_light: Vector3 = (wanderer._watch.global_position - cam.global_position).normalized()
			ok(wanderer.watch_shown() and wanderer._watch.visible, "one light in the sky on Lanternfast")
			ok(to_light.z < -0.8 and to_light.y > 0.3, "in the north, a third of the way up", to_light)
			ok(ilun._watch == null, "only the Wanderer has one")
			# The disc is drawn where the moon is.
			W.day = 2; W.hour = 0.0
			wait = 6
		3:
			ok(not wanderer._watch.visible, "no watch light on an ordinary night")
			var cam: Camera3D = root.get_camera_3d()
			var drawn: Vector3 = (ilun._disc.global_position - cam.global_position).normalized()
			ok(ilun._disc.visible and rad_to_deg(drawn.angle_to(ilun.direction)) < 1.0, "the disc is where Ilun is", [drawn, ilun.direction])
			ok(rad_to_deg(light_dir().angle_to(ilun.direction)) < 2.0, "moonlight from Ilun, high up", light_dir())
			full_light = n("Sun").light_energy
			# Just risen: the light comes from Ilun's side, but no lower than 15 degrees.
			W.day = 1; W.hour = 18.1
			wait = 2
		4:
			var d: Vector3 = ilun.direction
			ok(elevation(d) < 15.0 and d.y > 0.0, "Ilun low on the horizon", elevation(d))
			between(elevation(light_dir()), 14.5, 15.5, "the light from 15 degrees")
			ok(Vector2(light_dir().x, light_dir().z).normalized().dot(Vector2(d.x, d.z).normalized()) > 0.99, "on Ilun's side")
			# Ilun down (a week on, dark): dimmer.
			W.day = 8; W.hour = 0.0
			wait = 2
		5:
			ok(not ilun.is_up(), "a week on, Ilun is down at midnight")
			ok(n("Sun").light_energy < full_light * 0.6, "and the night is darker", [n("Sun").light_energy, full_light])
			ok(n("Sun").sky_mode == DirectionalLight3D.SKY_MODE_LIGHT_ONLY, "still no disc for the night light")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
