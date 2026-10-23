extends "res://tests/test_base.gd"
# Graphics presets: title (shared atmosphere.tres) -> Low -> test level (DayNight duplicates
# the environment) -> back to High must restore the designed effects; FPS counter toggles.
var f := 0
var ST

func env(): return current_scene.find_children("*", "WorldEnvironment", true, false)[0].environment
func sun(): var s = current_scene.find_children("*", "DirectionalLight3D", true, false); return s[0] if s.size() > 0 else null

## Checks fog / SSAO / glow, the sun's shadow distance (-1: no sun), MSAA and render scale.
func expect(tag: String, ssao: bool, fog: bool, glow: bool, sun_distance: float, msaa: int, scale: float) -> void:
	var e = env()
	ok(e.ssao_enabled == ssao and e.volumetric_fog_enabled == fog and e.glow_enabled == glow,
			"%s: ssao/fog/glow = %s/%s/%s" % [tag, ssao, fog, glow], [e.ssao_enabled, e.volumetric_fog_enabled, e.glow_enabled])
	if sun_distance >= 0.0:
		near(sun().directional_shadow_max_distance, sun_distance, 0.5, "%s: sun shadow distance" % tag)
	ok(root.msaa_3d == msaa, "%s: msaa" % tag, root.msaa_3d)
	near(root.scaling_3d_scale, scale, 0.001, "%s: render scale" % tag)

func _initialize() -> void:
	ST = autoload("Settings")
	change_scene_to_file("res://ui/title_screen.tscn")

func _process(_d: float) -> bool:
	f += 1
	match f:
		5:
			expect("title High", true, true, true, 100.0, Viewport.MSAA_2X, 1.0)
			ST.set_option("graphics_quality", 0); ST.set_option("render_scale", 0.7)
			expect("title Low", false, false, false, 50.0, Viewport.MSAA_DISABLED, 0.7)
		6: change_scene_to_file("res://levels/test_level.tscn")
		12: expect("level Low", false, false, false, 40.0, Viewport.MSAA_DISABLED, 0.7)
		13:
			ST.set_option("graphics_quality", 2); ST.set_option("render_scale", 1.0)
			expect("level High", true, true, true, 80.0, Viewport.MSAA_2X, 1.0)
		14:
			ST.set_option("graphics_quality", 3)
			expect("level Ultra", true, true, true, 120.0, Viewport.MSAA_4X, 1.0)
		15: ST.set_option("show_fps", true)
		30:
			ok(ST._fps_label.visible and ST._fps_label.text.contains(" fps"), "FPS counter shows", ST._fps_label.text)
			ST.set_option("show_fps", false)
			ok(not ST._fps_label.visible, "FPS counter hides")
			ST.set_option("graphics_quality", 2)
		31: change_scene_to_file("res://levels/waystation_cellar.tscn")
		37:
			expect("cellar High", true, true, true, -1.0, Viewport.MSAA_2X, 1.0)
			ST.set_option("graphics_quality", 1)
			expect("cellar Medium", true, false, true, -1.0, Viewport.MSAA_DISABLED, 1.0)
			ST.set_option("graphics_quality", 2)
			return done()
	return false
