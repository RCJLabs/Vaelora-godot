class_name Benchmark
extends Node

# Graphics benchmark: flies a camera through three scenes at each quality preset
# and measures frame times, so the presets can be tuned from real numbers.
#   Title screen → Settings → Graphics → Run benchmark    (about 3 minutes)
#   or start the game with:   <game> -- --benchmark
# VSync is turned off while it runs (otherwise every result is the screen's refresh
# rate). Your own settings are put back afterwards, and the results are shown,
# copied to the clipboard and saved to user://benchmark.txt.

signal finished(report: String)

const SEGMENTS := [
	{"name": "Day, open level", "scene": "res://levels/test_level.tscn", "hour": 13.0,
		"center": Vector3(-6, 1.5, -12), "radius": 26.0, "height": 6.0},
	{"name": "Night, stone circle", "scene": "res://levels/test_level.tscn", "hour": 22.5,
		"center": Vector3(-11, 1.5, -9), "radius": 11.0, "height": 2.5},
	{"name": "Barrow arena", "scene": "res://levels/test_dungeon.tscn", "hour": -1.0,
		"center": Vector3(0, 1.8, -56), "radius": 7.5, "height": 3.0},
]
const WARMUP := 2.0   # seconds (and at least 30 frames) before measuring: loading, shader compiles

## Seconds measured per scene and preset (tests use less).
var seconds_per_segment := 8.0
var results := []      # [{"preset", "segment", "avg_fps", "low_fps", "worst_ms"}]

var _saved := {}
var _camera: Camera3D
var _overlay: Label
var _angle := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 110
	_overlay = Label.new()
	_overlay.position = Vector2(20, 60)
	_overlay.add_theme_font_size_override("font_size", 20)
	_overlay.add_theme_color_override("font_outline_color", Color.BLACK)
	_overlay.add_theme_constant_override("outline_size", 5)
	layer.add_child(_overlay)
	add_child(layer)
	_run()


func _run() -> void:
	_saved = {"quality": Settings.graphics_quality, "hints": Settings.show_hints, "max_fps": Engine.max_fps}
	Settings.show_hints = false
	Engine.max_fps = 0
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for preset in Settings.QUALITY.size():
		Settings.graphics_quality = preset   # not set_option: nothing is saved
		for segment in SEGMENTS:
			await _load(segment)
			Settings.apply_graphics()
			_overlay.text = "Benchmark: %s, %s" % [Settings.QUALITY_NAMES[preset], segment["name"]]
			results.append(await _measure(preset, segment))
	_finish()


func _load(segment: Dictionary) -> void:
	var tree := get_tree()
	if tree.current_scene == null or tree.current_scene.scene_file_path != segment["scene"]:
		tree.change_scene_to_file(segment["scene"])
		await tree.process_frame
		await tree.process_frame
	var level := tree.current_scene
	if segment["hour"] >= 0.0:
		WorldClock.hour = segment["hour"]
	var player := tree.get_first_node_in_group("player")
	if player:
		player.process_mode = Node.PROCESS_MODE_DISABLED   # no input, no damage
		player.hud.hide()
	_camera = Camera3D.new()
	level.add_child(_camera)
	_camera.make_current()
	_angle = 0.0
	_place_camera(segment)


func _place_camera(segment: Dictionary) -> void:
	var center: Vector3 = segment["center"]
	var radius: float = segment["radius"]
	_camera.global_position = center + Vector3(cos(_angle) * radius, segment["height"], sin(_angle) * radius)
	_camera.look_at(center)


func _measure(preset: int, segment: Dictionary) -> Dictionary:
	var frame_ms := []
	var warm := 0.0          # warm-up time so far; loading hitches belong here
	var warm_frames := 0
	var measured := 0.0
	var last := Time.get_ticks_usec()
	while measured < seconds_per_segment:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		last = now
		_angle += ms / 1000.0 * TAU / 16.0   # a full circle every 16 s
		if is_instance_valid(_camera):
			_place_camera(segment)
		if warm < WARMUP or warm_frames < 30:
			warm += ms / 1000.0
			warm_frames += 1
			continue
		frame_ms.append(ms)
		measured += ms / 1000.0
	_camera.queue_free()
	frame_ms.sort()
	var total := 0.0
	for ms in frame_ms:
		total += ms
	var count := maxi(frame_ms.size(), 1)
	var p99: float = frame_ms[mini(int(frame_ms.size() * 0.99), frame_ms.size() - 1)] if frame_ms.size() > 0 else 0.0
	return {"preset": Settings.QUALITY_NAMES[preset], "segment": segment["name"],
		"avg_fps": 1000.0 / maxf(total / count, 0.001),
		"low_fps": 1000.0 / maxf(p99, 0.001),   # "1% low": the slowest 1% of frames
		"worst_ms": frame_ms[-1] if frame_ms.size() > 0 else 0.0}


func _finish() -> void:
	Settings.graphics_quality = _saved["quality"]
	Settings.show_hints = _saved["hints"]
	Engine.max_fps = _saved["max_fps"]
	Settings.apply()   # VSync and the rest back as they were
	Settings.apply_graphics()
	var report := report_text()
	var file := FileAccess.open("user://benchmark.txt", FileAccess.WRITE)
	if file:
		file.store_string(report)
	DisplayServer.clipboard_set(report)
	_overlay.text = ""
	finished.emit(report)
	get_tree().change_scene_to_file("res://ui/title_screen.tscn")
	await get_tree().process_frame
	await get_tree().process_frame
	_show_report(report)


func report_text() -> String:
	var lines: Array[String] = []
	lines.append("Benchmark — %s %s" % [ProjectSettings.get_setting("application/config/name"),
			ProjectSettings.get_setting("application/config/version", "?")])
	lines.append("GPU: %s (%s), API %s" % [RenderingServer.get_video_adapter_name(),
			RenderingServer.get_video_adapter_vendor(), RenderingServer.get_video_adapter_api_version()])
	lines.append("CPU: %s, %d threads   OS: %s %s" % [OS.get_processor_name(), OS.get_processor_count(), OS.get_name(), OS.get_version()])
	lines.append("Window: %s, render scale %d%%, %.1f s per scene" % [DisplayServer.window_get_size(),
			roundi(Settings.render_scale * 100.0), seconds_per_segment])
	lines.append("")
	lines.append("%-8s %-22s %8s %8s %9s" % ["Preset", "Scene", "avg fps", "1% low", "worst ms"])
	for r in results:
		lines.append("%-8s %-22s %8.0f %8.0f %9.1f" % [r["preset"], r["segment"], r["avg_fps"], r["low_fps"], r["worst_ms"]])
	return "\n".join(lines)


func _show_report(report: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 115
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(dim)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.1, 0.97)
	style.border_color = Color(0.95, 0.8, 0.45, 0.6)
	style.set_border_width_all(1)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	var title := Label.new()
	title.text = "Benchmark results (copied to the clipboard; also in user://benchmark.txt)"
	box.add_child(title)
	var text := Label.new()
	text.text = report
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Menlo", "monospace"])
	text.add_theme_font_override("font", mono)
	text.add_theme_font_size_override("font_size", 14)
	box.add_child(text)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(queue_free)
	box.add_child(close)
	panel.add_child(box)
	layer.add_child(panel)
	add_child(layer)
	panel.position = (get_viewport().get_visible_rect().size - panel.get_combined_minimum_size()) / 2.0
	close.grab_focus.call_deferred()


## Starts a benchmark (from the title screen). Returns the running node.
static func start(tree: SceneTree, seconds: float = 8.0) -> Benchmark:
	var bench := Benchmark.new()
	bench.seconds_per_segment = seconds
	bench.name = "Benchmark"
	tree.root.add_child(bench)
	return bench
