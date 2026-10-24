extends CanvasLayer

# Esc menu: Resume / Save / Load / Settings / Quit to Title / Quit Game.
# Autoloaded as "PauseMenu" (process mode Always, so it works while paused).
# The title screen opens the Load and Settings pages directly with open_page().

const TITLE_SCENE := "res://ui/title_screen.tscn"

@onready var root_control: Control = $Root
@onready var title_label: Label = %Title
@onready var content: VBoxContainer = %Content

var is_open := false
var _page := ""
var _from_title := false     # opened from the title screen: no "main" page, no pausing
var _confirm_slot := ""      # slot waiting for a second click to overwrite/delete
var _capturing := {}         # Controls page: {"action", "gamepad", "button"} while waiting for a key


func _ready() -> void:
	root_control.hide()


# _input so Esc is seen before the game. Dialogue and the Tab menu handle
# their own Esc, so leave it to them while they're open.
func _input(event: InputEvent) -> void:
	if not _capturing.is_empty():
		_capture(event)
		return
	# "pause" is Esc / the gamepad's Menu button. In the menu, "ui_cancel"
	# (Esc / gamepad B) goes back too. B alone doesn't open it: in the game B dodges.
	var pause := event.is_action_pressed("pause")
	if not pause and not (is_open and event.is_action_pressed("ui_cancel")):
		return
	if DialogueManager.is_active or CharacterMenu.is_open or RestMenu.is_open:
		return
	if is_open:
		if _page in ["graphics", "controls"]:
			_show("settings")   # sub-pages of Settings go back one level
		elif _page == "main" or _from_title:
			close()
		else:
			_show("main")
	else:
		var player := get_tree().get_first_node_in_group("player")
		if player == null or player.is_dead:
			return
		open_page("main")
	get_viewport().set_input_as_handled()


func open_page(page: String) -> void:
	_from_title = get_tree().get_first_node_in_group("player") == null
	is_open = true
	if not _from_title:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	root_control.show()
	_show(page)


func close() -> void:
	is_open = false
	root_control.hide()
	if not _from_title:
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _show(page: String) -> void:
	_page = page
	_confirm_slot = ""
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	match page:
		"main": _build_main()
		"save": _build_save()
		"load": _build_load()
		"settings": _build_settings()
		"graphics": _build_graphics()
		"report": _build_report()
		"controls": _build_controls()
	_focus_first.call_deferred()


# So a gamepad (D-pad + A) can use the menu straight away.
func _focus_first() -> void:
	for control in content.find_children("*", "Control", true, false):
		if control.focus_mode == Control.FOCUS_ALL and control.is_visible_in_tree() and not control.is_queued_for_deletion():
			control.grab_focus()
			return


# --- pages ---------------------------------------------------------------------

func _build_main() -> void:
	title_label.text = "Paused"
	_button("Resume", close)
	_button("Save Game", _show.bind("save"))
	_button("Load Game", _show.bind("load"))
	_button("Settings", _show.bind("settings"))
	_button("Report a Bug", _show.bind("report"))
	_button("Quit to Title", _quit_to_title)
	_button("Quit Game", func(): get_tree().quit())


func _build_save() -> void:
	title_label.text = "Save Game"
	if SaveSystem.hardcore_saves_locked():
		var note := Label.new()
		note.text = "Hardcore: you can only save by resting at a bed or a campfire."
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(note)
		_back_button()
		return
	var metas := {}
	for save in SaveSystem.list_saves():
		metas[save["slot"]] = save["meta"]
	for slot in SaveSystem.MANUAL_SLOTS:
		var text := "%s  -  %s" % [SaveSystem.slot_title(slot),
				SaveSystem.describe(metas[slot]) if metas.has(slot) else "empty"]
		var button := _button(text, Callable())
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(_on_save_slot.bind(slot, metas.has(slot), button))
	_back_button()


func _on_save_slot(slot: String, occupied: bool, button: Button) -> void:
	if occupied and _confirm_slot != slot:
		_confirm_slot = slot   # first click on a used slot asks for confirmation
		button.text = "%s  -  click again to overwrite" % SaveSystem.slot_title(slot)
		return
	get_tree().paused = false   # saving reads the live game
	SaveSystem.save_game(slot)
	get_tree().paused = true
	_show("save")


func _build_load() -> void:
	title_label.text = "Load Game"
	var saves := SaveSystem.list_saves()
	if saves.is_empty():
		var none := Label.new()
		none.text = "No saved games yet."
		content.add_child(none)
	for save in saves:
		var row := HBoxContainer.new()
		var load_button := Button.new()
		load_button.text = "%s  -  %s" % [SaveSystem.slot_title(save["slot"]), SaveSystem.describe(save["meta"])]
		load_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		load_button.pressed.connect(_on_load_slot.bind(save["slot"]))
		var delete_button := Button.new()
		delete_button.text = "Delete"
		delete_button.pressed.connect(_on_delete_slot.bind(save["slot"], delete_button))
		row.add_child(load_button)
		row.add_child(delete_button)
		content.add_child(row)
	_back_button()


func _on_load_slot(slot: String) -> void:
	is_open = false
	root_control.hide()
	SaveSystem.load_game(slot)   # unpauses and changes scene


func _on_delete_slot(slot: String, button: Button) -> void:
	if _confirm_slot != slot:
		_confirm_slot = slot
		button.text = "Sure?"
		return
	SaveSystem.delete_save(slot)
	_show("load")


func _build_settings() -> void:
	title_label.text = "Settings"
	_slider("Mouse sensitivity", "mouse_sensitivity", 0.2, 3.0, 0.05, "%.2fx")
	_checkbox("Invert mouse Y", "invert_y")
	_slider("Field of view", "fov", 60.0, 100.0, 1.0, "%d")
	_slider("Volume", "master_volume", 0.0, 1.0, 0.05, "%.0f%%", 100.0)
	_checkbox("Tutorial hints", "show_hints")
	_button("Graphics...", _show.bind("graphics"))
	_button("Controls...", _show.bind("controls"))
	_back_button()


func _build_graphics() -> void:
	title_label.text = "Graphics"
	_choice("Quality", "graphics_quality", Settings.QUALITY_NAMES)
	_slider("Render scale", "render_scale", 0.5, 1.0, 0.05, "%.0f%%", 100.0)
	_checkbox("Fullscreen", "fullscreen")
	_checkbox("VSync", "vsync")
	_checkbox("Show FPS", "show_fps")
	var note := Label.new()
	note.text = "Low and Medium turn off volumetric fog; Low also turns off ambient occlusion and glow. Below 100% render scale, the picture is upscaled with FSR."
	note.modulate = Color(1, 1, 1, 0.65)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 560
	content.add_child(note)
	if _from_title:   # it changes scenes, so never in the middle of a game
		_button("Run benchmark (about 3 minutes)", func():
			close()
			Benchmark.start(get_tree()))
	_button("Back", _show.bind("settings"))


func _build_report() -> void:
	title_label.text = "Report a Bug"
	var report := BugReport.build()
	DisplayServer.clipboard_set(report)
	var note := Label.new()
	note.text = "The details below are copied to the clipboard. Paste them into your report and add what happened and what you expected."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 560
	content.add_child(note)
	var text := TextEdit.new()
	text.text = report
	text.editable = false
	text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text.focus_mode = Control.FOCUS_CLICK   # the gamepad lands on the buttons, not in the text
	text.custom_minimum_size = Vector2(620, 300)
	text.add_theme_font_size_override("font_size", 13)
	content.add_child(text)
	if BugReport.REPORT_URL != "":
		_button("Open bug report page", func(): OS.shell_open(BugReport.REPORT_URL))
	_button("Copy again", func(): DisplayServer.clipboard_set(report))
	_back_button()


# --- Controls: rebinding -------------------------------------------------------

func _build_controls() -> void:
	title_label.text = "Controls"
	var note := Label.new()
	note.text = "Click a binding, then press the new key, mouse button or gamepad button. Esc cancels."
	note.modulate = Color(1, 1, 1, 0.7)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, 380)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true   # the D-pad scrolls the list
	content.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)
	for header in ["Action", "Keyboard & mouse", "Gamepad"]:
		var label := Label.new()
		label.text = header
		label.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
		grid.add_child(label)
	for pair in KeyBindings.ACTIONS:
		var name_label := Label.new()
		name_label.text = pair[1]
		name_label.custom_minimum_size.x = 250
		grid.add_child(name_label)
		for gamepad in [false, true]:
			var button := Button.new()
			button.text = KeyBindings.event_name(KeyBindings.binding(pair[0], gamepad))
			button.custom_minimum_size = Vector2(160, 34)
			button.pressed.connect(_start_capture.bind(pair[0], gamepad, button))
			grid.add_child(button)
	_button("Reset to defaults", func(): KeyBindings.reset(); _show("controls"))
	_button("Back", _show.bind("settings"))


func _start_capture(action: String, gamepad: bool, button: Button) -> void:
	button.text = "press a %s..." % ("button" if gamepad else "key")
	# Wait a frame, so the click / button press that started this isn't captured.
	await get_tree().process_frame
	_capturing = {"action": action, "gamepad": gamepad, "button": button}


func _capture(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		_capturing = {}
		_show("controls")   # cancelled
		return
	if not KeyBindings.is_bindable(event) or KeyBindings.is_gamepad(event) != _capturing["gamepad"]:
		return   # e.g. a key while waiting for a gamepad button: keep waiting
	var taken := KeyBindings.rebind(_capturing["action"], _capturing["gamepad"], event)
	_capturing = {}
	_show("controls")
	if taken != "":
		var warning := Label.new()
		warning.text = "%s was also used by \"%s\", which is now unbound there." % [KeyBindings.event_name(event), taken]
		warning.add_theme_color_override("font_color", Color(1, 0.6, 0.45))
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		content.add_child(warning)
		content.move_child(warning, 1)


# --- small UI helpers ------------------------------------------------------------

func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	if action.is_valid():
		button.pressed.connect(action)
	content.add_child(button)
	return button


func _back_button() -> void:
	_button("Back", close if _from_title else _show.bind("main"))


func _slider(label_text: String, key: String, low: float, high: float, step: float,
		format: String, display_scale: float = 1.0) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 220
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = Settings.get(key)
	slider.custom_minimum_size.x = 320
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value_label := Label.new()
	value_label.text = format % (slider.value * display_scale)
	slider.value_changed.connect(func(v):
		value_label.text = format % (v * display_scale)
		Settings.set_option(key, v))
	for c in [label, slider, value_label]:
		row.add_child(c)
	content.add_child(row)


## A slider over a list of named steps (gamepad: left/right).
func _choice(label_text: String, key: String, names: Array) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 220
	var slider := HSlider.new()
	slider.max_value = names.size() - 1
	slider.step = 1
	slider.tick_count = names.size()
	slider.ticks_on_borders = true
	slider.value = Settings.get(key)
	slider.custom_minimum_size.x = 320
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var value_label := Label.new()
	value_label.text = names[int(slider.value)]
	slider.value_changed.connect(func(v):
		value_label.text = names[int(v)]
		Settings.set_option(key, int(v)))
	for c in [label, slider, value_label]:
		row.add_child(c)
	content.add_child(row)


func _checkbox(label_text: String, key: String) -> void:
	var box := CheckBox.new()
	box.text = label_text
	box.button_pressed = Settings.get(key)
	box.toggled.connect(func(on): Settings.set_option(key, on))
	content.add_child(box)


func _quit_to_title() -> void:
	close()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(TITLE_SCENE)
