extends Node3D

# The title screen: the stone circle at dusk with the camera slowly circling it,
# and the main menu. The first scene the game opens (Project Settings > Run >
# Main Scene); "Quit to Title" comes back here.
# GAME_TITLE is the game's name, Vaelora (LORE.md). The project's own name in Project
# Settings stays as it is for now: changing it moves the folder saves are kept in.

const GAME_TITLE := "Vaelora"
const SUBTITLE := "a prototype"
const NEW_GAME_SCENE := "res://ui/character_creation.tscn"
## How fast the camera circles (radians per second), how far out and how high.
const ORBIT_SPEED := 0.05
const ORBIT_RADIUS := 15.0
const ORBIT_HEIGHT := 3.2

@onready var camera: Camera3D = $Camera3D
@onready var title_label: Label = %TitleLabel
@onready var buttons: VBoxContainer = %Buttons
@onready var version_label: Label = %VersionLabel

var _angle := 0.6


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	title_label.text = GAME_TITLE
	%SubtitleLabel.text = SUBTITLE
	version_label.text = "v%s" % ProjectSettings.get_setting("application/config/version", "0")
	if SaveSystem.has_save():
		_button("Continue", func(): SaveSystem.load_game())   # the most recent save
	_button("New Game", func(): get_tree().change_scene_to_file(NEW_GAME_SCENE))
	if SaveSystem.has_save():
		_button("Load Game", PauseMenu.open_page.bind("load"))
	_button("Settings", PauseMenu.open_page.bind("settings"))
	_button("Report a Bug", PauseMenu.open_page.bind("report"))
	_button("Quit", func(): get_tree().quit())
	buttons.get_child(0).grab_focus.call_deferred()   # gamepad: A starts straight away
	_place_camera()
	# `<game> -- --benchmark` runs the graphics benchmark straight away (once).
	if "--benchmark" in OS.get_cmdline_user_args() and not get_tree().root.has_node("Benchmark") \
			and not get_tree().has_meta("benchmark_ran"):
		get_tree().set_meta("benchmark_ran", true)
		Benchmark.start.call_deferred(get_tree())


func _process(delta: float) -> void:
	_angle += ORBIT_SPEED * delta
	_place_camera()
	# Back from a submenu (load, settings): give the buttons focus again.
	if not PauseMenu.is_open and get_viewport().gui_get_focus_owner() == null:
		buttons.get_child(0).grab_focus()


func _place_camera() -> void:
	camera.position = Vector3(cos(_angle) * ORBIT_RADIUS, ORBIT_HEIGHT, sin(_angle) * ORBIT_RADIUS)
	camera.look_at(Vector3(0, 1.6, 0))


func _button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.name = text.replace(" ", "") + "Button"   # "ContinueButton"…
	button.text = text
	button.custom_minimum_size = Vector2(280, 52)
	button.add_theme_font_size_override("font_size", 22)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(action)
	buttons.add_child(button)
