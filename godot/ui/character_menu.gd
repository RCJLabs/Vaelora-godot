extends CanvasLayer

# Tab menu: Skills tab (levels, level-up bonuses), Inventory tab (items,
# gold, using potions), Magic tab (known spells), Quests tab (the journal,
# also opened directly with J) and Factions tab (reputation). Pauses the game.
# Autoloaded as "CharacterMenu" (process mode Always, so it runs while paused).

@onready var root_control: Control = $Root
@onready var level_label: Label = %LevelLabel
@onready var level_up_box: Control = %LevelUpBox
@onready var skill_list: GridContainer = %SkillList
@onready var item_list: ItemList = %ItemList
@onready var use_button: Button = %UseButton
@onready var spell_list: ItemList = %SpellList
@onready var quest_list: ItemList = %QuestList
@onready var tabs: TabContainer = %Tabs

const QUESTS_TAB := 3
var _quest_ids: Array = []   # quest id for each row of quest_list

var _item_ids: Array = []   # item id for each row of item_list

const XP_BG := preload("res://ui/xp_bar_bg.tres")
const XP_FILL := preload("res://ui/xp_bar_fill.tres")
const REP_FILL := preload("res://ui/rep_bar_fill.tres")

var is_open := false


func _ready() -> void:
	root_control.hide()
	%HealthButton.pressed.connect(Skills.spend_level_up.bind("health"))
	%StaminaButton.pressed.connect(Skills.spend_level_up.bind("stamina"))
	%MagickaButton.pressed.connect(Skills.spend_level_up.bind("magicka"))
	Skills.changed.connect(_refresh)
	Inventory.changed.connect(_refresh_inventory)
	item_list.item_selected.connect(func(_i): _show_selected_item())
	use_button.pressed.connect(_use_selected)
	Spellbook.changed.connect(_refresh_magic)
	spell_list.item_selected.connect(func(row): Spellbook.select(Spellbook.known[row]))
	quest_list.item_selected.connect(func(_row): _show_selected_quest())
	Reputation.changed.connect(_refresh_factions)


# _input (not _unhandled_input) so Tab works even when a button has focus.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("character_menu"):
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal"):
		if is_open and tabs.current_tab == QUESTS_TAB:
			close()
		else:
			if not is_open:
				open()
			tabs.current_tab = QUESTS_TAB
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
	_refresh_inventory()
	_refresh_magic()
	_refresh_quests()
	_refresh_factions()
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
	var attribute_row: HBoxContainer = %AttributeRow
	for child in attribute_row.get_children():
		attribute_row.remove_child(child)
		child.queue_free()
	for id in Attributes.ATTRIBUTES:
		var info: Dictionary = Attributes.ATTRIBUTES[id]
		var label := Label.new()
		label.text = "%s  %d" % [info["name"], Attributes.value(id)]
		label.tooltip_text = info["description"]
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.add_theme_font_size_override("font_size", 18)
		attribute_row.add_child(label)
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


func _refresh_inventory() -> void:
	if not is_open:
		return
	var selected_id: String = _selected_id()
	%GoldLabel.text = "Gold: %d" % Inventory.gold
	item_list.clear()
	_item_ids = Inventory.items.keys()
	_item_ids.sort()
	for id in _item_ids:
		var count: int = Inventory.items[id]
		var item := Inventory.get_item(id)
		item_list.add_item(item.display_name if count == 1 else "%s  (%d)" % [item.display_name, count])
	if _item_ids.is_empty():
		item_list.add_item("(empty)", null, false)
	else:   # keep the same item selected after using one, if any are left
		item_list.select(maxi(_item_ids.find(selected_id), 0))
	_show_selected_item()


func _selected_id() -> String:
	var rows := item_list.get_selected_items()
	if rows.is_empty() or rows[0] >= _item_ids.size():
		return ""
	return _item_ids[rows[0]]


func _show_selected_item() -> void:
	var id := _selected_id()
	var item := Inventory.get_item(id) if id != "" else null
	%ItemName.text = item.display_name if item else ""
	%ItemDescription.text = item.description if item else ""
	%ItemValue.text = ("Value: %d gold" % item.value) if item else ""
	use_button.visible = item != null and item.type == ItemData.Type.CONSUMABLE
	use_button.text = "Drink" if use_button.visible else "Use"


func _use_selected() -> void:
	var id := _selected_id()
	if id != "":
		Inventory.use(id)


func _refresh_magic() -> void:
	if not is_open:
		return
	spell_list.clear()
	for id in Spellbook.known:
		var spell := Spellbook.get_spell(id)
		spell_list.add_item(spell.display_name)
	var current := Spellbook.current()
	if current:
		spell_list.select(Spellbook.current_index)
		%SpellName.text = current.display_name
		%SpellDescription.text = current.description
		var verb := "damage" if current.effect == SpellData.Effect.DAMAGE_STREAM else "healing"
		%SpellStats.text = "%d Magicka per second   -   %d %s per second   -   %s skill" % [
			current.magicka_per_second,
			current.power_per_second * Skills.spell_power_mult(current.skill), verb,
			Skills.SKILLS[current.skill]["name"]]


func _refresh_quests() -> void:
	if not is_open:
		return
	quest_list.clear()
	_quest_ids = []
	# active quests first, then completed ones
	for wanted in ["active", "completed"]:
		for id in QuestLog.quests:
			if QuestLog.status(id)["state"] == wanted:
				_quest_ids.append(id)
				var title: String = QuestLog.quests[id]["title"]
				quest_list.add_item(title if wanted == "active" else "%s  (done)" % title)
	if _quest_ids.is_empty():
		quest_list.add_item("(no quests yet)", null, false)
	else:
		quest_list.select(0)
	_show_selected_quest()


func _show_selected_quest() -> void:
	var rows := quest_list.get_selected_items()
	var id: String = _quest_ids[rows[0]] if not rows.is_empty() and rows[0] < _quest_ids.size() else ""
	if id == "":
		for label in [%QuestTitle, %QuestGiver, %QuestDescription, %QuestObjectives, %QuestOutcome]:
			label.text = ""
		return
	var quest: Dictionary = QuestLog.quests[id]
	var status := QuestLog.status(id)
	%QuestTitle.text = quest["title"]
	%QuestGiver.text = "From " + quest.get("giver", "")
	%QuestDescription.text = quest.get("description", "")
	var lines := []
	for o in status["objectives"]:
		lines.append(("[x]  " if o["done"] else "[  ]  ") + o["text"])
	%QuestObjectives.text = "\n".join(lines)
	%QuestOutcome.text = status["outcome"]


func _refresh_factions() -> void:
	if not is_open:
		return
	var list: VBoxContainer = %FactionList
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	for id in Reputation.factions:
		if not Reputation.known(id):
			continue
		var faction: Dictionary = Reputation.factions[id]
		var box := VBoxContainer.new()
		var title := Label.new()
		title.text = "%s  -  %s (%d)" % [faction["name"], Reputation.rank(id), Reputation.value(id)]
		title.add_theme_font_size_override("font_size", 22)
		title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
		var bar := ProgressBar.new()   # -100 .. 100
		bar.min_value = -100
		bar.max_value = 100
		bar.value = Reputation.value(id)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(420, 14)
		bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		bar.add_theme_stylebox_override("background", XP_BG)
		bar.add_theme_stylebox_override("fill", REP_FILL)
		var desc := Label.new()
		desc.text = faction["description"]
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.modulate = Color(1, 1, 1, 0.75)
		for c in [title, bar, desc]:
			box.add_child(c)
		list.add_child(box)
	if list.get_child_count() == 0:
		var none := Label.new()
		none.text = "You haven't dealt with any factions yet."
		none.modulate = Color(1, 1, 1, 0.6)
		list.add_child(none)
