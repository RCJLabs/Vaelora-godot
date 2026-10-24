class_name MapView
extends Control

# The Map tab of the Tab menu (M opens it directly): a top-down picture of the
# current level taken when the map opens, with the places you've discovered, your
# quests' next targets (gold) and you (the arrow, pointing where you face).
# The level needs a LevelMap node saying which area to show; otherwise the tab
# says there's no map. Mouse wheel / gamepad triggers zoom; it re-centres on you.

const QUEST_COLOR := Compass.QUEST_COLOR
const PLACE_COLOR := Color(1.0, 0.97, 0.88)
const ZOOMS := [1.0, 1.6, 2.5]

var _viewport: SubViewport
var _camera: Camera3D
var _picture: TextureRect
var _overlay: Control
var _empty_label: Label
var _title: Label
var _level_map: LevelMap
var _zoom := 0


func _ready() -> void:
	name = "Map"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL   # so the tab gets focus and the gamepad can zoom
	clip_contents = true
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1024, 1024)
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.own_world_3d = false
	add_child(_viewport)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.rotation_degrees = Vector3(-90, 0, 0)   # straight down, north (-Z) at the top
	_camera.near = 0.05
	_camera.far = 400.0
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.12, 0.11, 0.1)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.9, 0.88, 0.82)
	environment.ambient_light_energy = 1.0   # readable at night and underground
	_camera.environment = environment
	_viewport.add_child(_camera)
	_picture = TextureRect.new()
	_picture.texture = _viewport.get_texture()
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.modulate = Color(1.0, 0.95, 0.85)   # a little warm, like paper
	add_child(_picture)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	_title.position = Vector2(8, 4)
	add_child(_title)
	_empty_label = Label.new()
	_empty_label.text = "There's no map of this place."
	_empty_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(_empty_label)
	resized.connect(_layout)
	visibility_changed.connect(func(): if is_visible_in_tree(): refresh())


## Takes a new picture and redraws the markers (called when the tab opens).
func refresh() -> void:
	_level_map = get_tree().get_first_node_in_group("level_map") as LevelMap
	_empty_label.visible = _level_map == null
	_picture.visible = _level_map != null
	_title.text = _level_map.map_name if _level_map else ""
	if _level_map == null:
		_overlay.queue_redraw()
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		_viewport.world_3d = player.get_world_3d()
	var area := shown_area()
	_camera.size = maxf(area.size.x, area.size.y)
	_camera.position = Vector3(area.get_center().x, _level_map.camera_height, area.get_center().y)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_layout()


## The world rectangle (x, z) the map shows: the level's area, or a square around the
## player when zoomed in.
func shown_area() -> Rect2:
	var full: Rect2 = _level_map.area
	var side: float = maxf(full.size.x, full.size.y) / ZOOMS[_zoom]
	var center := full.get_center()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if _zoom > 0 and player:
		center = Vector2(player.global_position.x, player.global_position.z)
	return Rect2(center - Vector2(side, side) / 2.0, Vector2(side, side))


func _layout() -> void:
	var side := minf(size.x, size.y)
	_picture.size = Vector2(side, side)
	_picture.position = (size - _picture.size) / 2.0
	_overlay.position = _picture.position
	_overlay.size = _picture.size
	_overlay.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var zoom_in: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP) \
			or event.is_action_pressed("attack")
	var zoom_out: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN) \
			or event.is_action_pressed("cast")
	if zoom_in or zoom_out:
		_zoom = clampi(_zoom + (1 if zoom_in else -1), 0, ZOOMS.size() - 1)
		refresh()
		accept_event()


## Map position (in the picture) of a world position.
func to_map(world: Vector3) -> Vector2:
	var area := shown_area()
	return Vector2((world.x - area.position.x) / area.size.x, (world.z - area.position.y) / area.size.y) * _overlay.size


func _draw_overlay() -> void:
	if _level_map == null:
		return
	var font := get_theme_default_font()
	var bounds := Rect2(Vector2.ZERO, _overlay.size)
	for place in Waypoints.locations(get_tree()):
		if not place.is_discovered():
			continue
		var at := to_map(place.global_position)
		if not bounds.has_point(at):
			continue
		Compass.draw_place_icon(_overlay, at, place.kind, PLACE_COLOR, 7.0)
		_overlay.draw_string_outline(font, at + Vector2(10, 5), place.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.8))
		_overlay.draw_string(font, at + Vector2(10, 5), place.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, PLACE_COLOR)
	for target in Waypoints.quest_targets(get_tree()):
		var at := to_map(target["position"]).clamp(Vector2(8, 8), _overlay.size - Vector2(8, 8))
		_overlay.draw_colored_polygon(PackedVector2Array([at + Vector2(-7, -14), at + Vector2(7, -14), at]), QUEST_COLOR)
		_overlay.draw_circle(at, 3.0, QUEST_COLOR)
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		var at := to_map(player.global_position)
		var facing := deg_to_rad(Waypoints.heading(player.camera if player.get("camera") else player))
		var arrow := PackedVector2Array([Vector2(0, -11), Vector2(7, 8), Vector2(0, 4), Vector2(-7, 8)])
		for i in arrow.size():
			arrow[i] = at + arrow[i].rotated(facing)
		_overlay.draw_colored_polygon(arrow, Color(0.95, 0.25, 0.2))
		_overlay.draw_polyline(arrow + PackedVector2Array([arrow[0]]), Color(0, 0, 0, 0.8), 1.5)
