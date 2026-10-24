extends "res://tests/test_base.gd"
# The graphics benchmark: runs every preset in every scene, puts the player's
# settings back, writes the report and returns to the title screen.
var f := 0
var bench
var report := ""
var quality_before := -1

func _initialize() -> void:
	change_scene_to_file("res://ui/title_screen.tscn")

func _process(_d: float) -> bool:
	f += 1
	if f == 5:
		var settings = autoload("Settings")
		settings.graphics_quality = 1   # a non-default setting that must survive
		quality_before = settings.graphics_quality
		bench = load("res://systems/benchmark.gd").start(self, 0.3)
		bench.finished.connect(func(text): report = text)
	if f > 5 and report != "" and current_scene and current_scene.name == "TitleScreen":
		var settings = autoload("Settings")
		ok(bench.results.size() == 12, "4 presets x 3 scenes measured", bench.results.size())
		ok(bench.results.all(func(r): return r["avg_fps"] > 0.0 and r["low_fps"] > 0.0 and r["low_fps"] <= r["avg_fps"] + 0.01), "every result has an average and a 1% low", bench.results)
		var names := {}
		for r in bench.results: names[r["preset"] + "/" + r["segment"]] = true
		ok(names.size() == 12, "each preset/scene pair once")
		ok(settings.graphics_quality == quality_before, "the player's quality setting is back", settings.graphics_quality)
		ok(settings.show_hints, "tutorial hints are back on")
		ok(FileAccess.file_exists("user://benchmark.txt"), "report saved to user://benchmark.txt")
		ok(report.contains("Barrow arena") and report.contains("Ultra") and report.contains("1% low"), "report lists scenes, presets and lows")
		return done()
	if f > 20000:
		ok(false, "benchmark finished in time")
		return done()
	return false
