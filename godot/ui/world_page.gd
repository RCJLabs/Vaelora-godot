class_name WorldPage
extends ScrollContainer

# Tab → World: every place you've discovered, region by region, with a Travel
# button (systems/fast_travel.gd), and where you're wanted (systems/crime.gd).
# Built in code by CharacterMenu.

const GOLD := Color(0.95, 0.8, 0.45)
const GREY := Color(0.6, 0.6, 0.65)
const RED := Color(0.95, 0.45, 0.4)

var _box: VBoxContainer


func _init() -> void:
	name = "World"
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 8)
	add_child(_box)


func refresh() -> void:
	for child in _box.get_children():
		_box.remove_child(child)
		child.queue_free()
	var wanted: Array = Crime.bounty.keys().filter(func(r): return Crime.bounty_in(r) > 0)
	if not wanted.is_empty():
		_label("Wanted", 22, RED)
		for r in wanted:
			_label("%s: %d gold. A guard there will stop you; pay, or serve it in the cells." % [Crime.region_name(r).capitalize(), Crime.bounty_in(r)], 16, Color.WHITE)
	var reason := FastTravel.why_not()
	_label("Fast travel" + ("  -  " + reason if reason != "" else ""), 22, GOLD)
	_label(WorldClock.text() + ". Travelling takes time: the clock, hunger and thirst go on.", 15, GREY)
	var here: String = get_tree().current_scene.scene_file_path if get_tree().current_scene else ""
	for region in FastTravel.REGIONS:
		var places: Array = FastTravel.places_in(region["scene"]).filter(FastTravel.is_discovered)
		_label(region["name"] + ("  (you are here)" if region["scene"] == here else ""), 19, Color.WHITE)
		if places.is_empty():
			_label("Nowhere found here yet.", 15, GREY)
		for place in places:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 12)
			_box.add_child(row)
			var button := Button.new()
			button.custom_minimum_size = Vector2(110, 34)
			button.text = "Travel"
			button.disabled = reason != ""
			button.set_meta("place", place["id"])
			button.pressed.connect(_travel.bind(place))
			row.add_child(button)
			var hours: float = FastTravel.hours_to(place)
			_label("%s  -  about %s" % [place["name"], _hours_text(hours)], 16, Color.WHITE, row)


func _travel(place: Dictionary) -> void:
	CharacterMenu.close()
	FastTravel.go(place)


func _hours_text(hours: float) -> String:
	if hours < 1.0:
		return "%d minutes" % roundi(hours * 60.0)
	return "%d hour%s" % [roundi(hours), "" if roundi(hours) == 1 else "s"]


func _label(text: String, size: int, color: Color, parent: Node = null) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	(parent if parent else _box).add_child(label)
	return label
