class_name BugReport
extends RefCounted

# "Report a bug" (pause menu and title screen): gathers what a bug report needs
# (game and engine version, system, graphics settings, where the player is,
# the end of the log) into text the player can paste. BugReport.build()

## Where the "Open bug report page" button goes. Empty: the button is hidden and
## players only get the copied text. Set it to the issue tracker or a form once
## there is a public one (an open decision: the repository may stay private).
const REPORT_URL := ""
const LOG_LINES := 40


static func build() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var lines: Array[String] = []
	lines.append("Game: %s %s" % [ProjectSettings.get_setting("application/config/name"),
			ProjectSettings.get_setting("application/config/version", "?")])
	lines.append("Engine: Godot %s" % Engine.get_version_info()["string"])
	lines.append("System: %s %s, %s, %d threads" % [OS.get_name(), OS.get_version(), OS.get_processor_name(),
			OS.get_processor_count()])
	lines.append("GPU: %s (%s), API %s, renderer setting %s" % [RenderingServer.get_video_adapter_name(),
			RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_api_version(),
			ProjectSettings.get_setting("rendering/renderer/rendering_method", "?")])
	lines.append("Screen: %s, window %s" % [DisplayServer.screen_get_size(), DisplayServer.window_get_size()])
	lines.append("Graphics: %s, render scale %d%%, fullscreen %s, vsync %s, %d fps" % [
			Settings.QUALITY_NAMES[Settings.graphics_quality], roundi(Settings.render_scale * 100.0),
			Settings.fullscreen, Settings.vsync, Engine.get_frames_per_second()])
	var scene := tree.current_scene
	lines.append("Scene: %s" % (scene.scene_file_path if scene else "none"))
	var player := tree.get_first_node_in_group("player") as Node3D
	if player:
		var p := player.global_position
		lines.append("Player: (%.1f, %.1f, %.1f), level %d, %s %s, modes %s" % [p.x, p.y, p.z,
				Skills.character_level, GameState.race, Character.background, Character.modes])
		lines.append("Time: %s" % WorldClock.text())
	lines.append("")
	lines.append("What happened (please describe):")
	lines.append("")
	lines.append("")
	lines.append("--- last %d log lines ---" % LOG_LINES)
	lines.append(_log_tail())
	return "\n".join(lines)


## The end of this run's log file (Godot writes it to user://logs/godot.log).
static func _log_tail() -> String:
	var path: String = ProjectSettings.get_setting("debug/file_logging/log_path", "user://logs/godot.log")
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return "(no log file)"
	var log_lines := file.get_as_text().split("\n")
	return "\n".join(log_lines.slice(maxi(log_lines.size() - LOG_LINES, 0)))
