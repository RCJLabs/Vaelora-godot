extends CanvasLayer

# Tab menu: character level, skills, and level-up bonuses. Pauses the game.
# Autoloaded as "CharacterMenu" (process mode Always, so it runs while paused).

@onready var root_control: Control = $Root
@onready var level_label: Label = %LevelLabel
@onready var level_up_box: Control = %LevelUpBox
@onready var skill_list: GridContainer = %SkillList

const XP_BG := preload("res://ui/xp_bar_bg.tres")
const XP_FILL := preload("res://ui/xp_bar_fill.tres")

var is_open := false


func _ready() -> void:
	root_control.hide()
	%HealthButton.pressed.connect(Skills.spend_level_up.bind("health"))
	%StaminaButton.pressed.connect(Skills.spend_level_up.bind("stamina"))
	%MagickaButton.pressed.connect(Skills.spend_level_up.bind("magicka"))
	Skills.changed.connect(_refresh)


# _input (not _unhandled_input) so Tab works even when a button has focus.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("character_menu"):
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.is_dead or DialogueManager.is_active:
		return
	is_open = true
	player.hud.hide()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	root_control.show()


func close() -> void:
	is_open = false
	root_control.hide()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.hud.show()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _refresh() -> void:
	if not is_open:
		return
	level_label.text = "Level %d   -   %d / %d skill increases to the next level" % [
		Skills.character_level, Skills.skill_ups_toward_level, Skills.SKILL_UPS_PER_LEVEL]
	level_up_box.visible = Skills.unspent_level_ups > 0
	%LevelUpLabel.text = "Level up! Choose a bonus (%d left):" % Skills.unspent_level_ups

	for child in skill_list.get_children():
		skill_list.remove_child(child)
		child.queue_free()
	for id in Skills.SKILLS:
		var info: Dictionary = Skills.SKILLS[id]
		var name_label := Label.new()
		name_label.text = info["name"]
		name_label.custom_minimum_size.x = 160
		name_label.tooltip_text = info["description"]
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		var level := Label.new()
		level.text = str(Skills.levels[id])
		level.custom_minimum_size.x = 50
		var bar := ProgressBar.new()
		bar.max_value = Skills.xp_needed(id)
		bar.value = Skills.xp[id]
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", XP_BG)
		bar.add_theme_stylebox_override("fill", XP_FILL)
		bar.custom_minimum_size = Vector2(260, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var desc := Label.new()
		desc.text = info["description"]
		desc.modulate = Color(1, 1, 1, 0.6)
		for c in [name_label, level, bar, desc]:
			skill_list.add_child(c)
