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

const KEYS := ["mouse_sensitivity", "invert_y", "fov", "master_volume", "fullscreen", "vsync"]


func _ready() -> void:
	var config := ConfigFile.new()
	if config.load(PATH) == OK:
		for key in KEYS:
			set(key, config.get_value("settings", key, get(key)))
	apply()


## Change one option: applies it, saves the file and tells listeners (e.g. the camera).
func set_option(key: String, value) -> void:
	set(key, value)
	apply()
	var config := ConfigFile.new()
	for k in KEYS:
		config.set_value("settings", k, get(k))
	config.save(PATH)
	changed.emit()


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	if DisplayServer.get_name() == "headless":
		return   # no window to change (automated tests)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)
