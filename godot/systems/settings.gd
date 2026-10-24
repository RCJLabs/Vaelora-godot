extends Node

# Player options, saved to user://settings.cfg (separate from save games, so
# they apply to every character). Autoloaded as "Settings". Changed from the
# pause menu (Esc > Settings) or the title screen.

signal changed

const PATH := "user://settings.cfg"

var mouse_sensitivity := 1.0   # multiplier: 1.0 = the player's default
var invert_y := false
var fov := 75.0
var master_volume := 1.0       # 0..1
var fullscreen := false
var vsync := true
var show_hints := true          # one-time tutorial tips (systems/hints.gd)
var graphics_quality := 2      # index into QUALITY: Low, Medium, High (the look as designed, plus 2x MSAA), Ultra
var render_scale := 1.0        # 3D resolution, 0.5..1; below 1 it's upscaled with AMD FSR 1
var show_fps := false
# Accessibility & comfort (Settings → Accessibility)
var toggle_sprint := false      # press once to run, instead of holding
var toggle_block := false       # press once to raise your guard, again to lower it
var camera_shake := 1.0         # 0..1: how much hits, swings and landings jolt the view
var ui_scale := 1.0             # menus, HUD and text; the 3D view isn't affected

const KEYS := ["mouse_sensitivity", "invert_y", "fov", "master_volume", "fullscreen", "vsync", "show_hints",
		"graphics_quality", "render_scale", "show_fps", "toggle_sprint", "toggle_block", "camera_shake", "ui_scale"]
const UI_SCALES := [1.0, 1.15, 1.3, 1.5]

## Graphics presets. Effects only ever get switched off relative to how a scene was
## built (a scene without volumetric fog doesn't gain it on Ultra); shadow_distance
## multiplies each sun's own shadow distance.
const QUALITY_NAMES := ["Low", "Medium", "High", "Ultra"]
const QUALITY := [
	{"ssao": false, "volumetric_fog": false, "glow": false, "shadow_atlas": 1024, "shadow_distance": 0.5,
		"soft_shadows": RenderingServer.SHADOW_QUALITY_HARD, "msaa": Viewport.MSAA_DISABLED, "fxaa": true,
		"ssao_quality": RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, "fog_volume": 48},
	{"ssao": true, "volumetric_fog": false, "glow": true, "shadow_atlas": 2048, "shadow_distance": 0.75,
		"soft_shadows": RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, "msaa": Viewport.MSAA_DISABLED, "fxaa": true,
		"ssao_quality": RenderingServer.ENV_SSAO_QUALITY_LOW, "fog_volume": 48},
	{"ssao": true, "volumetric_fog": true, "glow": true, "shadow_atlas": 4096, "shadow_distance": 1.0,
		"soft_shadows": RenderingServer.SHADOW_QUALITY_SOFT_LOW, "msaa": Viewport.MSAA_2X, "fxaa": false,
		"ssao_quality": RenderingServer.ENV_SSAO_QUALITY_MEDIUM, "fog_volume": 64},
	{"ssao": true, "volumetric_fog": true, "glow": true, "shadow_atlas": 8192, "shadow_distance": 1.5,
		"soft_shadows": RenderingServer.SHADOW_QUALITY_SOFT_HIGH, "msaa": Viewport.MSAA_4X, "fxaa": false,
		"ssao_quality": RenderingServer.ENV_SSAO_QUALITY_HIGH, "fog_volume": 96},
]
const GRAPHICS_KEYS := ["graphics_quality", "render_scale"]

var _fps_label: Label
var _fps_timer := 0.0


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		for key in KEYS:
			set(key, config.get_value("settings", key, get(key)))
	graphics_quality = clampi(graphics_quality, 0, QUALITY.size() - 1)
	_make_fps_counter()
	# Each new scene's environment and sun get the current preset.
	get_tree().node_added.connect(func(node: Node):
		if node is WorldEnvironment or node is DirectionalLight3D:
			_apply_graphics_to.call_deferred(node))   # deferred: after the scene's own _ready
	apply()
	apply_graphics()


## Change one option: applies it, saves the file and tells listeners (e.g. the camera).
func set_option(key: String, value) -> void:
	set(key, value)
	apply()
	if key in GRAPHICS_KEYS:
		apply_graphics()
	var config := ConfigFile.new()
	for k in KEYS:
		config.set_value("settings", k, get(k))
	config.save(PATH)
	changed.emit()


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	if _fps_label:
		_fps_label.visible = show_fps
	get_tree().root.content_scale_factor = ui_scale
	if DisplayServer.get_name() == "headless":
		return   # no window to change (automated tests)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)


# --- graphics -----------------------------------------------------------------------

## Applies the quality preset and render scale to the renderer and every
## environment and sun currently in the game.
func apply_graphics() -> void:
	var preset: Dictionary = QUALITY[graphics_quality]
	var viewport := get_tree().root
	viewport.scaling_3d_scale = render_scale
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if render_scale < 0.99 else Viewport.SCALING_3D_MODE_BILINEAR
	viewport.msaa_3d = preset["msaa"]
	viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if preset["fxaa"] else Viewport.SCREEN_SPACE_AA_DISABLED
	viewport.positional_shadow_atlas_size = preset["shadow_atlas"]
	RenderingServer.directional_shadow_atlas_set_size(preset["shadow_atlas"], true)
	RenderingServer.directional_soft_shadow_filter_set_quality(preset["soft_shadows"])
	RenderingServer.positional_soft_shadow_filter_set_quality(preset["soft_shadows"])
	RenderingServer.environment_set_ssao_quality(preset["ssao_quality"], graphics_quality < 3, 0.5, 2, 50, 300)
	RenderingServer.environment_set_volumetric_fog_volume_size(preset["fog_volume"], preset["fog_volume"])
	for node in viewport.find_children("*", "WorldEnvironment", true, false):
		_apply_graphics_to(node)
	for node in viewport.find_children("*", "DirectionalLight3D", true, false):
		_apply_graphics_to(node)


func _apply_graphics_to(node: Node) -> void:
	if not is_instance_valid(node):
		return
	var preset: Dictionary = QUALITY[graphics_quality]
	if node is WorldEnvironment and node.environment:
		var env: Environment = node.environment
		# Remember what the scene was built with, the first time we see it.
		if not env.has_meta("designed"):
			env.set_meta("designed", {"ssao": env.ssao_enabled, "volumetric_fog": env.volumetric_fog_enabled,
					"glow": env.glow_enabled})
		var designed: Dictionary = env.get_meta("designed")
		env.ssao_enabled = designed["ssao"] and preset["ssao"]
		env.volumetric_fog_enabled = designed["volumetric_fog"] and preset["volumetric_fog"]
		env.glow_enabled = designed["glow"] and preset["glow"]
	elif node is DirectionalLight3D:
		if not node.has_meta("designed_shadow_distance"):
			node.set_meta("designed_shadow_distance", node.directional_shadow_max_distance)
		node.directional_shadow_max_distance = node.get_meta("designed_shadow_distance") * preset["shadow_distance"]


# --- FPS counter ------------------------------------------------------------------------

func _make_fps_counter() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 120   # above menus
	_fps_label = Label.new()
	_fps_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_fps_label.offset_left = -130
	_fps_label.offset_right = -12
	_fps_label.offset_top = 8
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.add_theme_font_size_override("font_size", 16)
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 4)
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fps_label)
	add_child(layer)
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps counting in menus


func _process(delta: float) -> void:
	if not _fps_label.visible:
		return
	_fps_timer -= delta
	if _fps_timer <= 0.0:
		_fps_timer = 0.25
		_fps_label.text = "%d fps  %.1f ms" % [Engine.get_frames_per_second(), 1000.0 / maxf(Engine.get_frames_per_second(), 1.0)]
