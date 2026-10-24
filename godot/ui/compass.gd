class_name Compass
extends Control

# The compass strip at the top of the screen: which way you're facing (N, NE, E...),
# your quests' next targets (gold), and places you know (pale icons; places you
# haven't found yet show dim when you're near them). Hover the middle of the strip
# over a quest marker to see how far it is. Added by the HUD.

const WIDTH := 560.0
const HEIGHT := 30.0
## How many degrees the strip spans, left edge to right edge.
const SPAN := 180.0
const KNOWN_RANGE := 300.0      # known places further than this aren't shown
const UNKNOWN_RANGE := 60.0     # undiscovered places show (dim) within this
const QUEST_COLOR := Color(1.0, 0.8, 0.3)
const PLACE_COLOR := Color(0.85, 0.9, 1.0, 0.9)
const UNKNOWN_COLOR := Color(0.6, 0.6, 0.65, 0.45)
const LETTERS := {0: "N", 45: "NE", 90: "E", 135: "SE", 180: "S", 225: "SW", 270: "W", 315: "NW"}

var _targets: Array = []        # cached quest targets (refreshed twice a second)
var _refresh_left := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -WIDTH / 2.0
	offset_right = WIDTH / 2.0
	offset_top = 6.0
	offset_bottom = 6.0 + HEIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.5
		_targets = Waypoints.quest_targets(get_tree())
	queue_redraw()


func _player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


## Where a bearing lands on the strip (x), or NAN if it's off the strip.
func x_for(bearing: float, heading: float) -> float:
	var relative := wrapf(bearing - heading, -180.0, 180.0)
	if absf(relative) > SPAN / 2.0:
		return NAN
	return WIDTH / 2.0 + relative / (SPAN / 2.0) * (WIDTH / 2.0)


func _draw() -> void:
	var player := _player()
	if player == null:
		return
	var heading := Waypoints.heading(player.camera if player.get("camera") else player)
	var font := get_theme_default_font()
	# Background: dark in the middle, fading out at the ends.
	for i in 24:
		var t := float(i) / 24.0
		var alpha := 0.45 * sin(PI * (t + 0.5 / 24.0))
		draw_rect(Rect2(t * WIDTH, 0, WIDTH / 24.0 + 1.0, HEIGHT), Color(0.05, 0.05, 0.07, alpha))
	# Ticks every 15 degrees, letters every 45.
	for degrees in range(0, 360, 15):
		var x := x_for(degrees, heading)
		if is_nan(x):
			continue
		var fade := 1.0 - absf(x - WIDTH / 2.0) / (WIDTH / 2.0) * 0.7
		if LETTERS.has(degrees):
			var text: String = LETTERS[degrees]
			var size := 18 if text.length() == 1 else 13
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			draw_string(font, Vector2(x - w / 2.0, 21), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, fade))
		else:
			draw_line(Vector2(x, 12), Vector2(x, 20), Color(1, 1, 1, 0.45 * fade), 1.0)
	# Places.
	for place in Waypoints.locations(get_tree()):
		var distance: float = player.global_position.distance_to(place.global_position)
		var known: bool = place.is_discovered()
		if (known and distance > KNOWN_RANGE) or (not known and distance > UNKNOWN_RANGE) or distance < 2.0:
			continue
		var x := x_for(Waypoints.bearing(player.global_position, place.global_position), heading)
		if not is_nan(x):
			draw_place_icon(self, Vector2(x, HEIGHT - 6), place.kind, PLACE_COLOR if known else UNKNOWN_COLOR, 5.0)
	# Quest targets (on top), with the distance to the one nearest the middle.
	var nearest_x := INF
	var nearest_text := ""
	for target in _targets:
		var where: Vector3 = target["position"]
		var x := x_for(Waypoints.bearing(player.global_position, where), heading)
		if is_nan(x):
			continue
		draw_colored_polygon(PackedVector2Array([Vector2(x - 6, 2), Vector2(x + 6, 2), Vector2(x, 12)]), QUEST_COLOR)
		if absf(x - WIDTH / 2.0) < 18.0 and absf(x - WIDTH / 2.0) < absf(nearest_x - WIDTH / 2.0):
			nearest_x = x
			nearest_text = "%d m" % roundi(player.global_position.distance_to(where))
	if nearest_text != "":
		var w := font.get_string_size(nearest_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, Vector2(nearest_x - w / 2.0, HEIGHT + 14), nearest_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, QUEST_COLOR)
	# Centre mark.
	draw_line(Vector2(WIDTH / 2.0, 0), Vector2(WIDTH / 2.0, 5), Color(1, 1, 1, 0.8), 2.0)


## A small icon per kind of place (shared with the map).
static func draw_place_icon(canvas: CanvasItem, at: Vector2, kind: int, color: Color, r: float) -> void:
	match kind:
		MapMarker.Kind.SETTLEMENT:   # a house
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-r, 0), at + Vector2(0, -r * 1.3),
					at + Vector2(r, 0), at + Vector2(r, r), at + Vector2(-r, r)]), color)
		MapMarker.Kind.CAMP:         # a tent
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-r, r), at + Vector2(0, -r), at + Vector2(r, r)]), color)
		MapMarker.Kind.DUNGEON:      # a doorway
			canvas.draw_rect(Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), color)
			canvas.draw_rect(Rect2(at - Vector2(r * 0.4, 0), Vector2(r * 0.8, r)), Color(0, 0, 0, color.a))
		_:                           # a standing stone / landmark
			canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0),
					at + Vector2(0, r), at + Vector2(-r, 0)]), color)
