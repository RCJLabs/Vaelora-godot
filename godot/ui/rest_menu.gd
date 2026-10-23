extends CanvasLayer

# The menu a bed or campfire opens: cook raw meat (campfires), rest or sleep
# for a while. Autoloaded as "RestMenu".
#   RestMenu.open(source, is_fire)
#
# Resting passes time (WorldClock), restores Health, Stamina and Magicka,
# clears timed harmful effects (bleeding, poison...), lowers Fatigue in Survival
# mode, gives Well Rested after 6+ hours, and autosaves. That autosave is the
# only way Hardcore characters can save. You can't rest while enemies are
# hunting you.

const WELL_RESTED_HOURS := 6.0
const ENEMY_RADIUS := 30.0

var is_open := false
var _is_fire := false
var _panel: PanelContainer
var _title: Label
var _info: Label
var _buttons: VBoxContainer
var _fade: ColorRect


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_fade)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(420, 0)
	_panel.visible = false
	root.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	box.add_child(_title)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	box.add_child(_info)
	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	box.add_child(_buttons)


func _input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


## Opens the menu for a bed (is_fire false) or campfire (true).
func open(_source: Node, is_fire: bool) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.is_dead or is_open:
		return
	if enemies_nearby(player.global_position):
		player.show_message("You can't rest with enemies nearby.")
		return
	_is_fire = is_fire
	is_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.hud.hide()
	_build()
	_panel.visible = true
	_panel.reset_size()
	_panel.position = (get_viewport().get_visible_rect().size - _panel.size) / 2.0


func close() -> void:
	is_open = false
	_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.hud.show()


## Is anything hunting the player (a wolf or bandit chasing, fighting...) close by?
func enemies_nearby(position: Vector3) -> bool:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var calm: bool = enemy.state in [enemy.State.IDLE, enemy.State.DEAD, enemy.State.RETURN]
		if not calm and enemy.global_position.distance_to(position) < ENEMY_RADIUS:
			return true
	return false


func _build() -> void:
	for child in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
	_title.text = "Campfire" if _is_fire else "Bed"
	var lines := [WorldClock.text()]
	if Survival.active():
		lines.append(Survival.text())
	if SaveSystem.hardcore_saves_locked():
		lines.append("Resting saves your game (the only way to save in Hardcore).")
	else:
		lines.append("Resting saves your game (Autosave slot).")
	_info.text = "\n".join(lines)
	var raw := Inventory.count("raw_wolf_meat")
	if _is_fire and raw > 0:
		_button("Cook raw wolf meat (%d)" % raw, _cook)
	_button("Rest 1 hour", _rest.bind(1.0))
	_button("Rest 4 hours", _rest.bind(4.0))
	_button("Sleep 8 hours", _rest.bind(8.0))
	var until_dawn := WorldClock.hours_until(6.0)
	if until_dawn > 1.0 and until_dawn < 16.0:
		_button("Sleep until dawn (%d h)" % roundi(until_dawn), _rest.bind(until_dawn))
	_button("Leave", close)
	_focus_first.call_deferred()


# For the gamepad. Deferred, so it finds the buttons as they are by then.
func _focus_first() -> void:
	for button in _buttons.get_children():
		if button.is_inside_tree() and not button.is_queued_for_deletion():
			button.grab_focus()
			return


func _button(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 40)
	button.pressed.connect(action)
	_buttons.add_child(button)


func _cook() -> void:
	var raw := Inventory.count("raw_wolf_meat")
	Inventory.remove("raw_wolf_meat", raw)
	Inventory.add("cooked_wolf_meat", raw)
	Sfx.play("spell_impact", -12.0)
	_build()


func _rest(hours: float) -> void:
	_panel.visible = false
	var tween := create_tween()
	tween.tween_property(_fade, "color:a", 1.0, 0.4)
	tween.tween_callback(_pass_time.bind(hours))
	tween.tween_interval(0.3)
	tween.tween_property(_fade, "color:a", 0.0, 0.6)
	tween.tween_callback(close)


func _pass_time(hours: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	WorldClock.advance(hours)
	Survival.tick(hours, true)
	var effects: StatusEffects = player.effects
	for id in effects.active.keys():
		var data: StatusEffectData = effects.active[id]["data"]
		if data.is_harmful and data.duration > 0.0:
			effects.remove(id)
	player.stats.refill()
	if hours >= WELL_RESTED_HOURS:
		effects.apply("well_rested")
	get_tree().paused = false   # saving reads the live game
	SaveSystem.save_game(SaveSystem.AUTOSAVE, true)
	get_tree().paused = true
	player.hud.notify("You rested %s. %s" % ["%d hours" % roundi(hours) if roundi(hours) != 1 else "an hour", WorldClock.text()])
