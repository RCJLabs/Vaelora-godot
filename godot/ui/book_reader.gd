extends CanvasLayer

# Shows a book's or note's text: an item with book_text (ItemData). Autoloaded as
# "BookReader".
#   BookReader.open("book_hallam")
#
# Opened by taking a book from the world (pickup.gd) or by Read in the inventory
# (Inventory.use). Pauses the game while it's open (or keeps it paused, over the
# Tab menu), and closes with E, Esc or the Close button. Reading sets the flag
# "read_<item id>", so quests and dialogue can tell what you've read.

var is_open := false
var _panel: PanelContainer
var _title: Label
var _text: Label
var _scroll: ScrollContainer
var _was_paused := false
var _mouse_before := Input.MOUSE_MODE_CAPTURED


func _ready() -> void:
	layer = 25   # above the Tab menu (CharacterMenu) and the HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(560, 0)
	_panel.visible = false
	add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 24)
	_title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_title)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, 360)
	box.add_child(_scroll)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.add_theme_color_override("font_color", Color(0.85, 0.83, 0.78))
	_scroll.add_child(_text)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(close)
	box.add_child(close_button)


func _input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause") or event.is_action_pressed("interact")):
		close()
		get_viewport().set_input_as_handled()


func open(item_id: String) -> void:
	var item: ItemData = Inventory.get_item(item_id)
	if item == null or not item.is_readable() or is_open:
		return
	is_open = true
	_was_paused = get_tree().paused
	_mouse_before = Input.mouse_mode
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_title.text = item.display_name
	_text.text = item.book_text
	_scroll.scroll_vertical = 0
	GameState.set_flag("read_" + item_id)
	_panel.visible = true
	_panel.reset_size()
	_panel.position = (get_viewport().get_visible_rect().size - _panel.size) / 2.0
	Hints.show_once("books", "Books and notes stay in your pack. Read them again from the inventory (%s)." % Hints.key("character_menu"))


func close() -> void:
	if not is_open:
		return
	is_open = false
	_panel.visible = false
	get_tree().paused = _was_paused   # still paused if the Tab menu is open underneath
	Input.mouse_mode = _mouse_before
