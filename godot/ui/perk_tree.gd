class_name PerkTree
extends HBoxContainer

# The Perks tab of the Tab menu (ui/character_menu.gd adds it): every skill on
# the left with how many of its perks you have; on the right, the chosen skill's
# perks as a tree. Rows are the skill level a perk needs (lowest at the top), a
# line joins a perk to the one it requires, and the colour says where you stand:
# gold taken, bright ready to take, dim locked. Click a perk for its details and
# Take it there. Built to hold 20+ perks a skill (it scrolls).

const NODE_SIZE := Vector2(190, 46)
const GAP := Vector2(28, 34)
const TAKEN := Color(0.95, 0.78, 0.35)
const READY := Color(0.85, 0.92, 1.0)
const LOCKED := Color(0.45, 0.47, 0.52)

var skill_id := ""
var selected_perk := ""
var _skills: ItemList
var _skill_ids := []
var _canvas: _Canvas
var _scroll: ScrollContainer
var _points: Label
var _details: Label
var _take: Button
var _buttons := {}   # perk id -> its button on the canvas


## The drawing surface: lines between perks, under their buttons.
class _Canvas extends Control:
	var lines := []   # [from: Vector2, to: Vector2, color: Color]
	func _draw() -> void:
		for line in lines:
			draw_line(line[0], line[1], line[2], 3.0, true)


func _init() -> void:
	name = "Perks"
	add_theme_constant_override("separation", 14)
	_skills = ItemList.new()
	_skills.custom_minimum_size = Vector2(230, 0)
	_skills.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_skills.item_selected.connect(func(i): show_skill(_skill_ids[i]))
	add_child(_skills)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 8)
	add_child(right)
	_points = Label.new()
	_points.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	right.add_child(_points)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.custom_minimum_size.y = 260
	right.add_child(_scroll)
	_canvas = _Canvas.new()
	_scroll.add_child(_canvas)
	_details = Label.new()
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size.y = 48
	right.add_child(_details)
	_take = Button.new()
	_take.text = "Take perk"
	_take.pressed.connect(func(): take(selected_perk))
	right.add_child(_take)


## Fills the skill list and redraws the chosen skill (call when anything changes).
func refresh() -> void:
	_points.text = "%d perk point%s to spend" % [Character.perk_points, "" if Character.perk_points == 1 else "s"]
	var keep := skill_id
	_skills.clear()
	_skill_ids.clear()
	for id in Skills.SKILLS:
		var all := perks_of(id)
		var have := all.filter(func(p): return p in Character.perks).size()
		var can_take := all.filter(func(p): return Character.perk_blocker(p) == "").size()
		_skills.add_item("%s  %d/%d%s" % [Skills.SKILLS[id]["name"], have, all.size(), "  •" if can_take > 0 else ""])
		_skill_ids.append(id)
	if keep == "" or not keep in _skill_ids:
		keep = _skill_ids[0]
	_skills.select(_skill_ids.find(keep))
	show_skill(keep)


## The perks of one skill, lowest level first.
func perks_of(id: String) -> Array:
	var order: Array = Character.perk_list.keys()
	var ids := order.filter(func(p): return Character.perk_list[p]["skill"] == id)
	ids.sort_custom(func(a, b):
		var la := int(Character.perk_list[a]["level"])
		var lb := int(Character.perk_list[b]["level"])
		return la < lb or (la == lb and order.find(a) < order.find(b)))
	return ids


## Where each perk sits: {perk: Vector2i(column, row)}. Rows are the distinct levels
## needed. A perk goes straight under the one it requires when nothing sits between
## them; otherwise (and for a perk that requires nothing) it opens a new column, so
## a line never runs behind an unrelated perk.
func layout(id: String) -> Dictionary:
	var perks := perks_of(id)
	var levels := []
	for p in perks:
		var level := int(Character.perk_list[p]["level"])
		if not level in levels:
			levels.append(level)
	levels.sort()
	var spots := {}
	var used := {}   # Vector2i -> true
	var next_col := 0
	for p in perks:
		var row := levels.find(int(Character.perk_list[p]["level"]))
		var parent: String = Character.perk_list[p].get("requires", "")
		var col := next_col
		if spots.has(parent):
			var above: Vector2i = spots[parent]
			var clear := row > above.y   # same level as its parent: beside it, not on it
			for r in range(above.y + 1, row + 1):
				clear = clear and not used.has(Vector2i(above.x, r))
			if clear:
				col = above.x
		spots[p] = Vector2i(col, row)
		used[Vector2i(col, row)] = true
		next_col = maxi(next_col, col + 1)
	return spots


func show_skill(id: String) -> void:
	skill_id = id
	if _skill_ids.has(id):
		_skills.select(_skill_ids.find(id))
	for child in _canvas.get_children():
		_canvas.remove_child(child)
		child.queue_free()
	_buttons.clear()
	var spots := layout(id)
	var extent := Vector2.ZERO
	for p in spots:
		var spot: Vector2i = spots[p]
		var pos := Vector2(spot.x * (NODE_SIZE.x + GAP.x), spot.y * (NODE_SIZE.y + GAP.y)) + GAP * 0.5
		var button := Button.new()
		button.position = pos
		button.size = NODE_SIZE
		button.clip_text = true
		var perk: Dictionary = Character.perk_list[p]
		var blocker := Character.perk_blocker(p)
		button.text = ("✓ " if blocker == "taken" else "") + "%s  (%d)" % [perk["name"], int(perk["level"])]
		var color := TAKEN if blocker == "taken" else (READY if blocker == "" or blocker == "no perk points" else LOCKED)
		button.add_theme_color_override("font_color", color)
		button.set_meta("color", color)
		for state in [["hover", 0.17, 0.8], ["pressed", 0.2, 1.0], ["focus", 0.15, 1.0]]:
			button.add_theme_stylebox_override(state[0], _box(color, state[1], state[2], 2))
		button.tooltip_text = perk["description"]
		button.pressed.connect(func(): select(p))
		_canvas.add_child(button)
		_buttons[p] = button
		extent = extent.max(pos + NODE_SIZE + GAP * 0.5)
	_canvas.custom_minimum_size = extent
	_canvas.lines.clear()
	for p in spots:
		var parent: String = Character.perk_list[p].get("requires", "")
		if parent == "" or not _buttons.has(parent):
			continue
		var from: Vector2 = _buttons[parent].position + Vector2(NODE_SIZE.x / 2.0, NODE_SIZE.y)
		var to: Vector2 = _buttons[p].position + Vector2(NODE_SIZE.x / 2.0, 0.0)
		_canvas.lines.append([from, to, TAKEN if parent in Character.perks else LOCKED])
	_canvas.queue_redraw()
	if not selected_perk in spots:
		selected_perk = spots.keys()[0] if not spots.is_empty() else ""
	select(selected_perk)


func select(perk_id: String) -> void:
	selected_perk = perk_id
	for p in _buttons:   # the selected perk: lighter, with a thick border
		var color: Color = _buttons[p].get_meta("color")
		_buttons[p].add_theme_stylebox_override("normal", _box(color, 0.2, 1.0, 4) if p == perk_id else _box(color, 0.11, 0.55, 2))
	if perk_id == "":
		_details.text = "No perks for this skill yet."
		_take.disabled = true
		return
	var perk: Dictionary = Character.perk_list[perk_id]
	var blocker := Character.perk_blocker(perk_id)
	var needs := "%s %d" % [Skills.SKILLS[perk["skill"]]["name"], int(perk["level"])]
	if perk.has("requires"):
		needs += ", and %s" % Character.perk_list[perk["requires"]]["name"]
	_details.text = "%s: %s\nNeeds %s.%s" % [perk["name"], perk["description"], needs,
			"  You have it." if blocker == "taken" else ("" if blocker == "" else "  (%s)" % blocker)]
	_take.disabled = blocker != ""
	_take.text = "Take %s" % perk["name"] if blocker == "" else "Take perk"


func _box(color: Color, shade: float, alpha: float, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(shade, shade + 0.01, shade + 0.03)
	style.border_color = Color(color, alpha)
	style.set_border_width_all(width)
	style.set_corner_radius_all(5)
	return style


## Takes a perk if it can be taken (tests call it too). Character.changed has the
## menu refresh this tab; the selection stays on the perk.
func take(perk_id: String) -> bool:
	return perk_id != "" and Character.take_perk(perk_id)
