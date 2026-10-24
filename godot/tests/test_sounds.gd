extends "res://tests/test_base.gd"
# Every sound a script asks for has a file. Sfx skips missing files silently (so code
# can name sounds before they exist), which also hides a typo or a forgotten file:
# this reads every script for Sfx.play / play_at / play_any / loop("name") and
# checks the name resolves (play_any("name", 3): name_1 to name_3). Names built at
# runtime ("footstep_" + surface) are skipped: test_footsteps covers those.

func _physics_process(_d: float) -> bool:
	var sfx := autoload("Sfx")
	var call := RegEx.create_from_string('Sfx\\.(play|play_at|play_any|loop)\\("([a-z0-9_]+)"\\s*(?:\\)|,\\s*(\\d+)?)')
	var names := {}
	for path in scripts("res://"):
		for m in call.search_all(FileAccess.get_file_as_string(path)):
			var sound := m.get_string(2)
			if m.get_string(1) == "play_any":
				var takes := int(m.get_string(3)) if m.get_string(3) != "" else 1
				for i in range(1, takes + 1):
					names["%s_%d" % [sound, i]] = path
			else:
				names[sound] = path
	ok(names.size() > 30, "found the sound calls", names.size())
	for story_sound in ["wisp_drain", "wisp_freed", "wisp_taken", "shrine_chime", "corruption_rise",
			"first_leak", "ritual_drone", "story_card", "wolf_yelp"]:
		ok(names.has(story_sound), "%s is played somewhere" % story_sound)
	var missing := []
	for sound in names:
		if sfx._stream(sound) == null:
			missing.append("%s (%s)" % [sound, names[sound]])
	ok(missing.is_empty(), "every sound a script plays has a file", missing)
	return done()

func scripts(folder: String) -> Array:
	var found := []
	var dir := DirAccess.open(folder)
	for sub in dir.get_directories():
		if sub not in ["tests", "addons", ".godot"]:
			found += scripts(folder.path_join(sub))
	for file in dir.get_files():
		if file.ends_with(".gd"):
			found.append(folder.path_join(file))
	return found
