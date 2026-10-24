extends Node

# The first scene of a new game, which depends on the background. Autoloaded as
# "Openings".
#
# The character creator sets `pending`; the player, when it spawns in the first
# level, calls play(). That moves the player to the background's start marker
# (a Marker3D in the level), gives its items, starts the main quest and shows a
# short intro card. The starts are written in res://quests/openings.json:
#   "soldier": {"marker": "StartSoldier", "title": "Soldier", "text": "...",
#               "items": {"posting_orders": 1}}
# Loading a save never plays one, and a level run on its own (F6) has no
# background, so it doesn't either.

const FILE := "res://quests/openings.json"
## Seconds the card stays up before fading (any of interact / jump / Enter skips it).
const CARD_SECONDS := 9.0
## The story flag that starts main quest 1, "Wrong Things".
const MAIN_QUEST_FLAG := "wrong_things_started"

var starts: Dictionary = {}
var pending := false

var _card: CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # so _process can see the game pause
	var data = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if data is Dictionary:
		starts = data
	else:
		push_error("Openings: %s is missing or not valid JSON." % FILE)


## Called by the player when it spawns. Does nothing unless a new game just began.
func play(player: Node3D) -> void:
	if not pending:
		return
	pending = false
	var start: Dictionary = starts.get(Character.background, {})
	if start.is_empty():
		return
	player.arrive_at_marker(start["marker"])
	for id in start.get("items", {}):
		Inventory.add(id, int(start["items"][id]))
	GameState.set_flag("opening_" + Character.background)
	GameState.set_flag(MAIN_QUEST_FLAG)
	show_card(start["title"], start["text"])


## A dark band across the middle of the screen with a title and a few lines.
## It doesn't pause the game or take the mouse: you can start moving straight away.
func show_card(title: String, text: String, seconds: float = CARD_SECONDS) -> void:
	if _card:
		_card.queue_free()
	Sfx.play("story_card")
	_card = CanvasLayer.new()
	_card.layer = 20
	_card.name = "OpeningCard"
	var band := ColorRect.new()
	band.color = Color(0, 0, 0, 0.72)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.set_anchors_preset(Control.PRESET_HCENTER_WIDE)
	band.offset_top = -120.0
	band.offset_bottom = 120.0
	_card.add_child(band)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 80.0
	box.offset_right = -80.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(box)
	for line in [[title, 34, Color(1, 0.85, 0.5)], [text, 20, Color(0.92, 0.9, 0.85)]]:
		var label := Label.new()
		label.text = line[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", line[1])
		label.add_theme_color_override("font_color", line[2])
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 4)
		box.add_child(label)
	add_child(_card)
	band.modulate.a = 0.0
	var tween := band.create_tween()
	tween.tween_property(band, "modulate:a", 1.0, 0.6)
	tween.tween_interval(seconds)
	tween.tween_property(band, "modulate:a", 0.0, 1.5)
	tween.tween_callback(hide_card)


func hide_card() -> void:
	if _card:
		_card.queue_free()
		_card = null


func card_visible() -> bool:
	return _card != null


# The card gets out of the way of menus and conversations instead of sitting over them.
func _process(_delta: float) -> void:
	if _card and (get_tree().paused or DialogueManager.is_active):
		hide_card()


func _input(event: InputEvent) -> void:
	if _card and (event.is_action_pressed("interact") or event.is_action_pressed("jump") \
			or event.is_action_pressed("ui_accept")):
		var band: Control = _card.get_child(0)
		var tween := band.create_tween()
		tween.tween_property(band, "modulate:a", 0.0, 0.3)
		tween.tween_callback(hide_card)
