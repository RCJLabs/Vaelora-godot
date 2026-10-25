extends CanvasLayer

# Tab menu: Skills tab (levels, level-up bonuses), Inventory tab (items,
# gold, using potions), Magic tab (known spells), Quests tab (the journal,
# also opened directly with J), Factions tab (reputation), Map tab (also
# opened directly with M; ui/map_view.gd) and Perks tab (the perk trees;
# ui/perk_tree.gd). Pauses the game.
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
const MAP_TAB := 5
const PERKS_TAB := 6
var map_view: MapView
var perk_tree: PerkTree
var _quest_ids: Array = []   # quest id for each row of quest_list

var _item_ids: Array = []   # item id for each row of item_list

const XP_BG := preload("res://ui/xp_bar_bg.tres")
const XP_FILL := preload("res://ui/xp_bar_fill.tres")
const REP_FILL := preload("res://ui/rep_bar_fill.tres")

var is_open := false


func _ready() -> void:
	root_control.hide()
	map_view = MapView.new()
	tabs.add_child(map_view)
	perk_tree = PerkTree.new()
	tabs.add_child(perk_tree)
	%PerksButton.pressed.connect(func(): tabs.current_tab = PERKS_TAB; _focus_tab.call_deferred())
	%HealthButton.pressed.connect(Skills.spend_level_up.bind("health"))
	%StaminaButton.pressed.connect(Skills.spend_level_up.bind("stamina"))
	%MagickaButton.pressed.connect(Skills.spend_level_up.bind("magicka"))
	Skills.changed.connect(_refresh)
	Character.changed.connect(_refresh)
	Attributes.changed.connect(_refresh)
	Inventory.changed.connect(_refresh_inventory)
	item_list.item_selected.connect(func(_i): _show_selected_item())
	item_list.item_activated.connect(func(_i): _use_selected())   # Enter / gamepad A
	use_button.pressed.connect(_use_selected)
	Spellbook.changed.connect(_refresh_magic)
	spell_list.item_selected.connect(func(row): Spellbook.select(Spellbook.known[row]))
	quest_list.item_selected.connect(func(_row): _show_selected_quest())
	Reputation.changed.connect(_refresh_factions)


# _input (not _unhandled_input) so Tab works even when a button has focus.
func _input(event: InputEvent) -> void:
	if BookReader.is_open or AlchemyScreen.is_open or SmithingScreen.is_open or LockpickScreen.is_open:
		return   # the reader (or brewing) handles its own keys, over the menu or not
	if not is_open and (DialogueManager.is_active or PauseMenu.is_open or RestMenu.is_open):
		return   # leave the keys to the conversation / pause menu
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
	elif event.is_action_pressed("map"):
		if is_open and tabs.current_tab == MAP_TAB:
			close()
		else:
			if not is_open:
				open()
			tabs.current_tab = MAP_TAB
			_focus_tab.call_deferred()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif is_open and (event.is_action_pressed("power_race") or event.is_action_pressed("power_background")):
		# The power buttons (gamepad LB / RB, keyboard Z / X) switch tabs while it's open.
		var step := -1 if event.is_action_pressed("power_race") else 1
		tabs.current_tab = wrapi(tabs.current_tab + step, 0, tabs.get_tab_count())
		_focus_tab.call_deferred()
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
	_focus_tab.call_deferred()


# Gives the first usable control in the open tab focus, so the D-pad works.
func _focus_tab() -> void:
	var page := tabs.get_current_tab_control()
	if page == null:
		return
	if page.focus_mode == Control.FOCUS_ALL:   # the map page itself takes focus (zoom)
		page.grab_focus()
		return
	for control in page.find_children("*", "Control", true, false):
		if control.focus_mode == Control.FOCUS_ALL and control.is_visible_in_tree():
			control.grab_focus()
			return


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
	%IdentityLabel.text = _identity_text() + "\n" + WorldClock.text() + ("     " + Survival.text() if Survival.active() else "")
	var attribute_row: HBoxContainer = %AttributeRow
	for child in attribute_row.get_children():
		attribute_row.remove_child(child)
		child.queue_free()
	if Character.attribute_points > 0:
		var points := Label.new()
		points.text = "%d point%s:" % [Character.attribute_points, "" if Character.attribute_points == 1 else "s"]
		points.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
		attribute_row.add_child(points)
	for id in Attributes.ATTRIBUTES:
		var info: Dictionary = Attributes.ATTRIBUTES[id]
		var label := Label.new()
		label.text = "%s  %d" % [info["name"], Attributes.value(id)]
		label.tooltip_text = info["description"]
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.add_theme_font_size_override("font_size", 18)
		attribute_row.add_child(label)
		if Character.attribute_points > 0:
			var plus := Button.new()
			plus.text = "+"
			plus.tooltip_text = "Spend a point on %s" % info["name"]
			plus.pressed.connect(Character.spend_attribute_point.bind(id))
			attribute_row.add_child(plus)
	level_up_box.visible = Skills.unspent_level_ups > 0
	%LevelUpLabel.text = "Level up! Choose a bonus (%d left):" % Skills.unspent_level_ups

	for child in skill_list.get_children():
		skill_list.remove_child(child)
		child.queue_free()
	for id in Skills.SKILLS:
		var info: Dictionary = Skills.SKILLS[id]
		var name_label := Label.new()
		var governs: String = info.get("attribute", "")
		name_label.text = info["name"] + ("  (%s)" % Attributes.ATTRIBUTES[governs]["short"] if governs != "" else "")
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
	_refresh_perks()


func _identity_text() -> String:
	var race := GameState.race
	var bg: String = Character.backgrounds.get(Character.background, {}).get("name", "")
	var text := "%s  -  %s%s" % [Character.player_name, race, (" " + bg) if bg != "" else ""]
	if not Character.traits.is_empty():
		text += "  -  " + ", ".join(Character.traits.map(func(t): return Character.trait_list[t]["name"]))
	var modes := []
	if Character.modes["survival"]: modes.append("Survival")
	if Character.modes["hardcore"]: modes.append("Hardcore")
	if not modes.is_empty():
		text += "  -  " + " + ".join(modes)
	return text


func _refresh_perks() -> void:
	%PerksButton.text = "Perks  -  %d point%s to spend  >" % [Character.perk_points, "" if Character.perk_points == 1 else "s"]
	perk_tree.refresh()


func _refresh_inventory() -> void:
	if not is_open:
		return
	var selected_id: String = _selected_id()
	%GoldLabel.text = "Gold: %d      Armor: %d      Carrying: %.0f / %.0f" % [Inventory.gold, Inventory.armor_total(), Inventory.total_weight(), Attributes.carry_capacity()]
	item_list.clear()
	_item_ids = Inventory.items.keys()
	_item_ids.sort()
	for id in _item_ids:
		var count: int = Inventory.items[id]
		var item := Inventory.get_item(id)
		var shown := Smithing.display_name(id)   # "Iron Sword (Fine)"
		var text := shown if count == 1 else "%s  (%d)" % [shown, count]
		if Inventory.is_equipped(id):
			text += "   (equipped)"
		item_list.add_item(text)
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
	%ItemName.text = Smithing.display_name(id) if item else ""
	%ItemDescription.text = item.description if item else ""
	var details := ""
	if item:
		if item.type == ItemData.Type.WEAPON:
			var damage := item.damage * Smithing.damage_mult(item)
			details = "Damage %d%s   -   %.2f s per swing   -   Reach %.1f m   -   %d stamina per swing\n" % [
				roundi(damage), "" if is_equal_approx(damage, item.damage) else " (base %d)" % item.damage,
				item.attack_cooldown, item.reach, item.stamina_cost]
		elif item.type == ItemData.Type.ARMOR:
			var kind := Armor.kind_of(item)
			details = "Armor %d%s   -   %s%s\n" % [roundi(Armor.piece_armor(item)), "" if is_equal_approx(Armor.piece_armor(item), item.armor) else " (base %d)" % item.armor,
					("%s, " % ("Light" if kind == "light" else "Heavy")) if kind != "" else "", item.slot_name().capitalize()]
		details += "Value: %d gold   -   Weight: %.1f" % [item.value, item.weight]
		if Attributes.strength_needed(item.weight) > 0.0 and item.type == ItemData.Type.WEAPON:
			details += "\nHeavy: wants Strength %d%s" % [ceili(Attributes.strength_needed(item.weight)),
					"" if Attributes.strength_short(item.weight) == 0.0 else " (you're short: less damage, more stamina)"]
	%ItemValue.text = details
	use_button.visible = item != null and (item.type == ItemData.Type.CONSUMABLE or item.is_equipment() or item.is_readable())
	if item and item.is_equipment():
		use_button.text = "Unequip" if Inventory.is_equipped(id) else "Equip"
	elif item and item.is_readable():
		use_button.text = "Read"
	elif item and item.tool == "alchemy":
		use_button.text = "Brew"
	elif item and item.tool == "smithing":
		use_button.text = "Improve"
	elif item and item.potion_effect == "poison":
		use_button.text = "Coat blade"
	else:
		use_button.text = "Drink"


func _use_selected() -> void:
	var id := _selected_id()
	if id == "":
		return
	var item := Inventory.get_item(id)
	if item.is_equipment():
		if Inventory.is_equipped(id):
			Inventory.unequip(item.slot_name())
		else:
			Inventory.equip(id)
	else:
		Inventory.use(id)


func _refresh_magic() -> void:
	if not is_open:
		return
	spell_list.clear()
	for id in Spellbook.known:
		var spell := Spellbook.get_spell(id)
		spell_list.add_item(spell.display_name)
	var current := Spellbook.current()
	if current == null:
		spell_list.deselect_all()
		%SpellName.text = "Left hand: Block"
		%SpellDescription.text = "Hold right-click to block. Block just before a hit lands to parry it. Pick a spell here, or press Q, to ready it instead."
		%SpellStats.text = "Blocks %d%% of a hit with what you're holding" % roundi(Skills.block_share(_block_reduction()) * 100.0)
	else:
		spell_list.select(Spellbook.current_index)
		%SpellName.text = current.display_name
		%SpellDescription.text = current.description
		%SpellStats.text = _spell_stats(current)


func _spell_stats(spell: SpellData) -> String:
	var skill_name: String = Skills.SKILLS[spell.skill]["name"]
	var power := Skills.spell_power_mult(spell.skill)
	var dual := "   -   dual-cast with both hands" if spell.can_dual_cast else ""
	match spell.style:
		SpellData.Style.STREAM:
			var verb := "damage" if spell.effect == SpellData.Effect.DAMAGE_STREAM else "healing"
			return "Hold: %d Magicka per second   -   %d %s per second   -   %s%s" % [
				spell.magicka_per_second, spell.power_per_second * power, verb, skill_name, dual]
		SpellData.Style.WARD:
			return "Hold: %d Magicka per second, more per blow stopped   -   stops %d%% from the front   -   %s%s" % [
				spell.magicka_per_second, roundi(spell.ward_strength * 100.0), skill_name, dual]
		SpellData.Style.SELF:
			return "Charge %.1f s, release: %d Magicka   -   %s" % [spell.charge_time, spell.magicka_cost, skill_name]
	var what := "bolt" if spell.style == SpellData.Style.BOLT else "%.0f m burst" % spell.radius
	return "Charge %.1f s, release: %d Magicka   -   %d damage %s   -   %s%s" % [
		spell.charge_time, spell.magicka_cost, spell.damage * power, what, skill_name, dual]


func _block_reduction() -> float:
	var item := Inventory.equipped_item("main_hand")
	return item.block_reduction if item else 0.3


func _refresh_quests() -> void:
	if not is_open:
		return
	quest_list.clear()
	_quest_ids = []
	# active quests first, then completed ones; main quests ("main": true) first in each
	var ids: Array = QuestLog.quests.keys().filter(func(id): return QuestLog.quests[id].get("main", false))
	ids += QuestLog.quests.keys().filter(func(id): return not QuestLog.quests[id].get("main", false))
	for wanted in ["active", "completed"]:
		for id in ids:
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
	%QuestGiver.text = ("Main quest. From " if quest.get("main", false) else "From ") + quest.get("giver", "")
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
