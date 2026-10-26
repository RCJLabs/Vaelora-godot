class_name MapView
extends Control

# The Map tab of the Tab menu (M opens it directly): a top-down picture of the
# current level taken when the map opens, with the places you've discovered, your
# quests' next targets (gold) and you (the arrow, pointing where you face).
# The level needs a LevelMap node saying which area to show; otherwise the tab
# says there's no map.
#
# Zoom with a pinch, the mouse wheel, the + / - buttons or the gamepad triggers;
# drag (finger or mouse) or the right stick to move around; "Me" centres on you.
# The level is drawn once, when the map opens, at RENDER_SIZE; zooming and moving
# only crop that picture (an AtlasTexture region), so dragging costs nothing.

const QUEST_COLOR := Compass.QUEST_COLOR
const PLACE_COLOR := Color(1.0, 0.97, 0.88)
const MIN_ZOOM := 1.0
const MAX_ZOOM := 4.0
const ZOOM_STEP := 1.5     # a button press, a wheel notch or a trigger pull
const RENDER_SIZE := 2048
const STICK_PAN := 600.0   # pixels a second, the right stick held over

## How far in: 1 shows the whole level, MAX_ZOOM a quarter of it across.
var zoom := MIN_ZOOM
## The world point (x, z) the map is centred on.
var center := Vector2.ZERO

var _viewport: SubViewport
var _camera: Camera3D
var _picture: TextureRect
var _atlas: AtlasTexture
var _overlay: Control
var _empty_label: Label
var _title: Label
var _buttons: HBoxContainer
var _level_map: LevelMap
var _touches := {}         # finger index -> position, for pinching
var _pinch_from := 0.0     # finger gap when the pinch started
var _pinch_zoom := 1.0     # zoom when the pinch started
var _dragging := false


func _ready() -> void:
	name = "Map"
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL   # so the tab gets focus and the gamepad can zoom
	clip_contents = true
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(RENDER_SIZE, RENDER_SIZE)
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
	_atlas = AtlasTexture.new()
	_atlas.atlas = _viewport.get_texture()
	_atlas.region = Rect2(0, 0, RENDER_SIZE, RENDER_SIZE)
	_picture = TextureRect.new()
	_picture.texture = _atlas
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_SCALE
	_picture.modulate = Color(1.0, 0.95, 0.85)   # a little warm, like paper
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE   # drags and pinches are the map's
	add_child(_picture)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.draw.connect(_draw_overlay)
	add_child(_overlay)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 18)
	_title.position = Vector2(8, 4)
	add_child(_title)
	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 8)
	for b in [["+", "Zoom in", func(): set_zoom(zoom * ZOOM_STEP)],
			["-", "Zoom out", func(): set_zoom(zoom / ZOOM_STEP)],
			["Me", "Centre on you", centre_on_player]]:
		var button := Button.new()
		button.name = "Zoom" + {"+": "In", "-": "Out", "Me": "Me"}[b[0]]
		button.text = b[0]
		button.tooltip_text = b[1]
		button.custom_minimum_size = Vector2(56, 56)   # a fingertip
		button.focus_mode = Control.FOCUS_NONE         # the gamepad keeps the map itself
		button.add_theme_font_size_override("font_size", 24)
		button.pressed.connect(b[2])
		_buttons.add_child(button)
	add_child(_buttons)
	_empty_label = Label.new()
	_empty_label.text = "There's no map of this place."
	_empty_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(_empty_label)
	resized.connect(_layout)
	visibility_changed.connect(func(): if is_visible_in_tree(): refresh())


## Takes a new picture and redraws the markers (called when the tab opens). Zoomed
## in, it opens centred on you.
func refresh() -> void:
	_level_map = get_tree().get_first_node_in_group("level_map") as LevelMap
	_empty_label.visible = _level_map == null
	_picture.visible = _level_map != null
	_buttons.visible = _level_map != null
	_title.text = _level_map.map_name if _level_map else ""
	if _level_map == null:
		_overlay.queue_redraw()
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player:
		_viewport.world_3d = player.get_world_3d()
	var full := full_area()
	_camera.size = full.size.x
	_camera.position = Vector3(full.get_center().x, _level_map.camera_height, full.get_center().y)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	if zoom > MIN_ZOOM and player:
		center = Vector2(player.global_position.x, player.global_position.z)
	else:
		center = full.get_center()
	_apply_view()
	_layout()


## The square the picture is drawn of: the level's area, squared up around its centre.
func full_area() -> Rect2:
	var area: Rect2 = _level_map.area
	var side := maxf(area.size.x, area.size.y)
	return Rect2(area.get_center() - Vector2(side, side) / 2.0, Vector2(side, side))


## The world rectangle (x, z) the map shows now: a square zoom times smaller than the
## level's, around `center`, kept inside the level.
func shown_area() -> Rect2:
	var full := full_area()
	var side := full.size.x / zoom
	var half := Vector2(side, side) / 2.0
	var c := center.clamp(full.position + half, full.end - half)
	return Rect2(c - half, Vector2(side, side))


## Zoom to `to` (clamped), keeping the world point under `focus` (a position in the
## picture; default its middle) where it is.
func set_zoom(to: float, focus := Vector2(-1, -1)) -> void:
	if _level_map == null:
		return
	if focus.x < 0.0:
		focus = _overlay.size / 2.0
	var before := to_world(focus)
	zoom = clampf(to, MIN_ZOOM, MAX_ZOOM)
	center = shown_area().get_center()
	var after := to_world(focus)
	center += before - after
	_apply_view()


## Move the map by a drag of `pixels` (the picture follows the finger).
func pan(pixels: Vector2) -> void:
	if _level_map == null or _overlay.size.x <= 0.0:
		return
	center = shown_area().get_center() - pixels / _overlay.size.x * shown_area().size.x
	_apply_view()


func centre_on_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and _level_map:
		center = Vector2(player.global_position.x, player.global_position.z)
		_apply_view()


## Crop the picture to shown_area() and redraw the markers.
func _apply_view() -> void:
	if _level_map == null:
		return
	var full := full_area()
	var shown := shown_area()
	center = shown.get_center()
	var px := RENDER_SIZE / full.size.x
	_atlas.region = Rect2((shown.position - full.position) * px, shown.size * px)
	_overlay.queue_redraw()


func _layout() -> void:
	var side := minf(size.x, size.y)
	_picture.size = Vector2(side, side)
	_picture.position = (size - _picture.size) / 2.0
	_overlay.position = _picture.position
	_overlay.size = _picture.size
	_buttons.position = Vector2(size.x - _buttons.get_combined_minimum_size().x - 8, 8)
	_overlay.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
		else:
			_touches.erase(event.index)
		if _touches.size() == 2:
			_pinch_from = _finger_gap()
			_pinch_zoom = zoom
		accept_event()
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() >= 2 and _pinch_from > 0.0:
			set_zoom(_pinch_zoom * _finger_gap() / _pinch_from, _finger_middle() - _overlay.position)
		accept_event()
	elif event is InputEventMagnifyGesture:   # trackpads, and pinches where the OS sends them
		set_zoom(zoom * event.factor, event.position - _overlay.position)
		accept_event()
	elif event is InputEventPanGesture:
		pan(-event.delta * 8.0)
		accept_event()
	elif event is InputEventMouseButton:
		# A finger counts as the mouse too (Godot emulates it): one finger drags.
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var step := ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / ZOOM_STEP
			set_zoom(zoom * step, event.position - _overlay.position)
		accept_event()
	elif event is InputEventMouseMotion:
		if _dragging and _touches.size() < 2:
			pan(event.relative)
			accept_event()
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		# Only the gamepad's triggers: "attack" is also the left mouse button, and a tap.
		if event.is_action_pressed("attack"):
			set_zoom(zoom * ZOOM_STEP)
			accept_event()
		elif event.is_action_pressed("cast"):
			set_zoom(zoom / ZOOM_STEP)
			accept_event()


func _process(delta: float) -> void:
	if not has_focus() or _level_map == null or not is_visible_in_tree():
		return
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick.length() > 0.2:
		pan(-stick * STICK_PAN * delta)


func _finger_gap() -> float:
	var at: Array = _touches.values()
	return (at[0] as Vector2).distance_to(at[1])


func _finger_middle() -> Vector2:
	var at: Array = _touches.values()
	return ((at[0] as Vector2) + (at[1] as Vector2)) / 2.0


## World position (x, z) under a point in the picture.
func to_world(at: Vector2) -> Vector2:
	var area := shown_area()
	var size_px := _overlay.size if _overlay.size.x > 0.0 else Vector2.ONE
	return area.position + at / size_px * area.size


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
