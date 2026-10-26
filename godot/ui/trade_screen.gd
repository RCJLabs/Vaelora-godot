extends CanvasLayer

# The buy and sell screen. Autoloaded as "TradeScreen".
#   TradeScreen.open("maren")    (a dialogue choice does it with "open_trade")
#
# Their goods on the left, yours on the right, each with its price. Click (or
# A / Enter on) a row to buy or sell one; the buttons under each list do the
# same for the selected row. Esc closes. Pauses the game while it's open.
# Prices, stock and purses are systems/trade.gd.

var is_open := false
var merchant := ""
var _panel: PanelContainer
var _title: Label
var _purses: Label
var _theirs: ItemList
var _yours: ItemList
var _buy: Button
var _sell: Button
var _note: Label
var _their_ids := []
var _your_ids := []


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(820, 480)
	_panel.visible = false
	var backing := StyleBoxFlat.new()   # solid: two lists over the busy world are hard to read
	backing.bg_color = Color(0.07, 0.075, 0.09, 0.96)
	backing.set_corner_radius_all(6)
	_panel.add_theme_stylebox_override("panel", backing)
	root.add_child(_panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	_panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", Color(0.95, 0.8, 0.45))
	box.add_child(_title)
	_purses = Label.new()
	_purses.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	box.add_child(_purses)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 16)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(columns)
	_theirs = _column(columns, "For sale")
	_yours = _column(columns, "Yours")
	_theirs.item_activated.connect(func(_i): _do_buy())
	_yours.item_activated.connect(func(_i): _do_sell())
	_theirs.item_selected.connect(func(_i): _refresh_buttons())
	_yours.item_selected.connect(func(_i): _refresh_buttons())
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	box.add_child(buttons)
	_buy = Button.new()
	_buy.pressed.connect(_do_buy)
	_buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_buy)
	_sell = Button.new()
	_sell.pressed.connect(_do_sell)
	_sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_sell)
	_note = Label.new()
	_note.add_theme_color_override("font_color", Color(0.95, 0.65, 0.5))
	box.add_child(_note)
	var close_button := Button.new()
	close_button.text = "Done (Esc)"
	close_button.pressed.connect(close)
	box.add_child(close_button)
	for button in [_buy, _sell, close_button]:
		_style(button)


# Buttons that stand out on the dark panel.
func _style(button: Button) -> void:
	for state in [["normal", 0.2], ["hover", 0.28], ["pressed", 0.34], ["focus", 0.24], ["disabled", 0.12]]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(state[1], state[1] + 0.01, state[1] + 0.04)
		box.set_corner_radius_all(4)
		box.content_margin_top = 6
		box.content_margin_bottom = 6
		button.add_theme_stylebox_override(state[0], box)


func _column(parent: Control, heading: String) -> ItemList:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(column)
	var label := Label.new()
	label.text = heading
	column.add_child(label)
	var list := ItemList.new()
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size.y = 280
	column.add_child(list)
	return list


func _input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		close()
		get_viewport().set_input_as_handled()


func open(merchant_id: String) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.is_dead or is_open or not Trade.MERCHANTS.has(merchant_id):
		return
	merchant = merchant_id
	is_open = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.hud.hide()
	_note.text = ""
	_refresh()
	_panel.visible = true
	_panel.reset_size()
	_panel.position = (get_viewport().get_visible_rect().size - _panel.size) / 2.0
	_theirs.grab_focus()
	if _theirs.item_count > 0:
		_theirs.select(0)
		_refresh_buttons()


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


## Buys the row selected on their side (tests call it with an item id).
func buy(id: String) -> bool:
	var reason := Trade.why_not_buy(merchant, id)
	if reason != "":
		_note.text = reason
		return false
	var price := Trade.buy_price(id, merchant)
	Trade.buy(merchant, id)
	_note.text = "Bought %s for %d." % [Inventory.get_item(id).display_name, price]
	_refresh()
	return true


func sell(id: String) -> bool:
	var reason := Trade.why_not_sell(merchant, id)
	if reason != "":
		_note.text = reason
		return false
	var price := Trade.sell_price(id)
	Trade.sell(merchant, id)
	_note.text = "Sold %s for %d." % [Inventory.get_item(id).display_name, price]
	_refresh()
	return true


func _do_buy() -> void:
	var picked := _theirs.get_selected_items()
	if not picked.is_empty():
		buy(_their_ids[picked[0]])


func _do_sell() -> void:
	var picked := _yours.get_selected_items()
	if not picked.is_empty():
		sell(_your_ids[picked[0]])


func _refresh() -> void:
	var who: String = Trade.MERCHANTS[merchant]["name"]
	_title.text = "Trading with %s" % who
	_purses.text = "Your gold: %d      %s's gold: %d      (Presence %d, Speech %d: buying at x%.2f, selling at x%.2f)" % [
			Inventory.gold, who, Trade.gold(merchant), Attributes.value("presence"), Skills.levels["speech"], Trade.buy_mult(merchant), Trade.sell_mult()]
	var keep_theirs := _selected_id(_theirs, _their_ids)
	var keep_yours := _selected_id(_yours, _your_ids)
	_theirs.clear(); _their_ids.clear()
	var stock: Dictionary = Trade.stock(merchant)
	for id in stock:
		var item := Inventory.get_item(id)
		_theirs.add_item("%s  x%d      %d gold" % [item.display_name, stock[id], Trade.buy_price(id, merchant)])
		_their_ids.append(id)
	_yours.clear(); _your_ids.clear()
	for id in Inventory.items:
		var item := Inventory.get_item(id)
		var price := Trade.sell_price(id)
		var label := "%s  x%d      %s" % [item.display_name, Inventory.items[id],
				"keep" if item.quest_item else ("%d gold" % price if price > 0 else "worthless")]
		var hot: int = Crime.stolen_count(id, Trade.MERCHANTS[merchant].get("region", ""))
		if hot > 0:
			label += "   (%d stolen here)" % hot   # they won't buy those (systems/crime.gd)
		_yours.add_item(label)
		_your_ids.append(id)
		if Inventory.is_equipped(id):
			_yours.set_item_custom_fg_color(_yours.item_count - 1, Color(0.7, 0.85, 1.0))
	_reselect(_theirs, _their_ids, keep_theirs)
	_reselect(_yours, _your_ids, keep_yours)
	_refresh_buttons()


func _refresh_buttons() -> void:
	var their_pick := _selected_id(_theirs, _their_ids)
	var your_pick := _selected_id(_yours, _your_ids)
	_buy.text = "Buy %s (%d gold)" % [Inventory.get_item(their_pick).display_name, Trade.buy_price(their_pick, merchant)] if their_pick != "" else "Buy"
	_buy.disabled = their_pick == "" or Trade.why_not_buy(merchant, their_pick) != ""
	_sell.text = "Sell %s (%d gold)" % [Inventory.get_item(your_pick).display_name, Trade.sell_price(your_pick)] if your_pick != "" else "Sell"
	_sell.disabled = your_pick == "" or Trade.why_not_sell(merchant, your_pick) != ""


func _selected_id(list: ItemList, ids: Array) -> String:
	var picked := list.get_selected_items()
	return ids[picked[0]] if not picked.is_empty() and picked[0] < ids.size() else ""


func _reselect(list: ItemList, ids: Array, id: String) -> void:
	var at := ids.find(id)
	if at >= 0:
		list.select(at)
