extends CanvasLayer

# Picking a lock. Autoloaded as "LockpickScreen". A locked container opens it
# (loot_container.gd). A marker sweeps along the lock; press Space, E, click or
# the confirm button when it's in the gold sweet spot to set a pin. Esc gives up.
# Pauses the world; the marker runs on real time. Rules: systems/lockpicking.gd.

const BAR_SIZE := Vector2(560, 34)

var is_open := false
var _target: Node = null
var _panel: PanelContainer
var _title: Label
var _bar: ColorRect
var _spot: ColorRect
var _marker: ColorRect
var _pins: Label
var _note: Label
var _spring: Button
var _close_timer := 0.0         # after it opens, a moment before the screen goes


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(600, 0)
	_panel.visible = false
	var backing := StyleBoxFlat.new()
	backing.bg_color = Color(0.07, 0.075, 0.09, 0.96)
	backing.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", backing)
	root.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	margin.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	box.add_child(_title)
	_bar = ColorRect.new()
	_bar.custom_minimum_size = BAR_SIZE
	_bar.color = Color(0.16, 0.16, 0.19)
	box.add_child(_bar)
	_spot = ColorRect.new()
	_spot.color = Color(0.85, 0.65, 0.25, 0.85)
	_bar.add_child(_spot)
	_marker = ColorRect.new()
	_marker.color = Color(0.92, 0.92, 0.95)
	_marker.size = Vector2(4, BAR_SIZE.y + 10)
	_bar.add_child(_marker)
	_pins = Label.new()
	_pins.add_theme_font_size_override("font_size", 22)
	box.add_child(_pins)
	_note = Label.new()
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(560, 0)
	_note.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	box.add_child(_note)
	_spring = Button.new()
	_spring.text = "Spring the Lock (once a day)"
	_spring.focus_mode = Control.FOCUS_NONE   # Space and Enter are for the pins
	_spring.pressed.connect(func(): if Lockpicking.spring(): _opened())
	box.add_child(_spring)
	var hint := Label.new()
	hint.text = "Space / E / click / (A): set a pin      Esc / (B): give up"
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	box.add_child(hint)


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()
	elif _close_timer <= 0.0 and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact")
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
				and not _spring.get_global_rect().has_point(event.position))):
		attempt()
		get_viewport().set_input_as_handled()


func open(level: int, target: Node = null) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.is_dead or is_open:
		return
	is_open = true
	_target = target
	_close_timer = 0.0
	Lockpicking.start(level, target)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.hud.hide()
	_title.text = "%s lock (Lockpicking %d)" % [Lockpicking.LEVEL_NAMES[level], Skills.levels.get("lockpicking", Skills.START_LEVEL)]
	_note.text = "Lockpicks: %d" % Inventory.count("lockpick")
	_panel.visible = true
	_refresh()
	_panel.reset_size()
	_panel.position = (get_viewport().get_visible_rect().size - _panel.size) / 2.0


func close() -> void:
	if not is_open:
		return
	is_open = false
	_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.hud.show()


func _process(delta: float) -> void:
	if not is_open:
		return
	if _close_timer > 0.0:
		_close_timer -= delta
		if _close_timer <= 0.0:
			close()
		return
	Lockpicking.tick(delta)
	_refresh()


## Tries to set a pin (tests call it too). Returns what Lockpicking.attempt said.
func attempt() -> String:
	var result := Lockpicking.attempt()
	match result:
		"set":
			_note.text = "Click. A pin sets."
			Sfx.play("lever", -10.0)
		"open":
			_opened()
		"miss":
			_note.text = "It slips." + ("" if "quick_hands" in Character.perks else " A pin drops back.")
		"broke":
			_note.text = "Snap! The pick breaks. Lockpicks left: %d" % Inventory.count("lockpick")
			if Inventory.count("lockpick") <= 0:
				_note.text += ". You're out."
				_close_timer = 1.2
		"no_picks":
			_note.text = "You're out of lockpicks."
			_close_timer = 0.8
	_refresh()
	return result


func _opened() -> void:
	_note.text = "The lock opens."
	Sfx.play("lever", -4.0)
	_close_timer = 0.6
	var player := get_tree().get_first_node_in_group("player")
	if _target and player and _target.has_method("interact"):
		_target.interact(player)   # take what's inside


func _refresh() -> void:
	var width := Lockpicking.spot_width()
	_spot.position = Vector2((Lockpicking.spot_center - width / 2.0) * BAR_SIZE.x, 0)
	_spot.size = Vector2(width * BAR_SIZE.x, BAR_SIZE.y)
	_marker.position = Vector2(Lockpicking.marker * BAR_SIZE.x - 2, -5)
	_pins.text = "Pins: " + "".join(range(Lockpicking.pins).map(func(i): return "● " if i < Lockpicking.set_pins else "○ "))
	_spring.visible = Lockpicking.can_spring()
