extends "res://tests/test_base.gd"
# Graphics presets: title (shared atmosphere.tres) -> Low -> test level (DayNight duplicates
# the environment) -> back to High must restore the designed effects; FPS counter toggles.
# Bounce light: SDFGI from High up, SSIL on Ultra, never in a scene built without it.
# Every interior is built for the PC look: SSAO, volumetric fog, SDFGI and SSIL.
const INTERIORS := ["glass_vault", "grieving_deep_ring", "ilunhall_undercroft", "ithmarren_rootwell", "karrowdeep",
		"karrowdeep_seam", "weirholt_culvert", "test_dungeon", "waystation_cellar"]
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

## Checks the bounce light: SDFGI and SSIL.
func expect_gi(tag: String, sdfgi: bool, ssil: bool) -> void:
	var e = env()
	ok(e.sdfgi_enabled == sdfgi and e.ssil_enabled == ssil, "%s: sdfgi/ssil = %s/%s" % [tag, sdfgi, ssil], [e.sdfgi_enabled, e.ssil_enabled])

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
		12:
			expect("level Low", false, false, false, 40.0, Viewport.MSAA_DISABLED, 0.7)
			expect_gi("level Low", false, false)
		13:
			ST.set_option("graphics_quality", 2); ST.set_option("render_scale", 1.0)
			expect("level High", true, true, true, 80.0, Viewport.MSAA_2X, 1.0)
			expect_gi("level High", true, false)
		14:
			ST.set_option("graphics_quality", 3)
			expect("level Ultra", true, true, true, 120.0, Viewport.MSAA_4X, 1.0)
			expect_gi("level Ultra", true, true)
		15: ST.set_option("show_fps", true)
		30:
			ok(ST._fps_label.visible and ST._fps_label.text.contains(" fps"), "FPS counter shows", ST._fps_label.text)
			ST.set_option("show_fps", false)
			ok(not ST._fps_label.visible, "FPS counter hides")
			ST.set_option("graphics_quality", 2)
		31: change_scene_to_file("res://levels/waystation_cellar.tscn")
		37:
			expect("cellar High", true, true, true, -1.0, Viewport.MSAA_2X, 1.0)
			expect_gi("cellar High", true, false)
			ST.set_option("graphics_quality", 1)
			expect("cellar Medium", true, false, true, -1.0, Viewport.MSAA_DISABLED, 1.0)
			expect_gi("cellar Medium", false, false)
			# A scene built without bounce light doesn't gain it, even on Ultra.
			var bare := WorldEnvironment.new()
			bare.environment = Environment.new()
			current_scene.add_child(bare)
			ST.set_option("graphics_quality", 3)
		38:
			var bare: WorldEnvironment = current_scene.get_children().back()
			ok(not bare.environment.sdfgi_enabled and not bare.environment.ssil_enabled, "a scene built without it doesn't gain bounce light on Ultra")
			bare.queue_free()
			ST.set_option("graphics_quality", 2)
			for level in INTERIORS:
				var scene: Node = load("res://levels/%s.tscn" % level).instantiate()
				var e: Environment = scene.get_node("WorldEnvironment").environment
				# How it was built: the presets have already changed the loaded level's (the cellar's).
				var built: Dictionary = e.get_meta("designed", {"ssao": e.ssao_enabled, "volumetric_fog": e.volumetric_fog_enabled,
						"sdfgi": e.sdfgi_enabled, "ssil": e.ssil_enabled})
				ok(built["ssao"] and built["volumetric_fog"] and e.volumetric_fog_density > 0.0 and built["sdfgi"] and built["ssil"],
						"%s: built for the PC look (SSAO, air, bounce light)" % level, [built, e.volumetric_fog_density])
				scene.free()
			return done()
	return false
