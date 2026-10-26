extends "res://tests/test_base.gd"
# The menus fit a narrow screen: every page of the Tab menu, the pause menu's
# pages, character creation, and the other screens (trade, training, rest, class,
# alchemy, smithing, lockpicking, books), on a 1024 x 880 window (a tablet's shape, like the one
# the skills page was cut off on). Nothing visible may stick out past either side
# (a long line that won't wrap pushes a whole menu off the screen).
const SIZE := Vector2i(1024, 880)
## Autoload, open() arguments ("@player": the player), what it is.
const SCREENS := [
	["TradeScreen", ["maren"], "trade screen"],
	["TrainingScreen", ["brannoc"], "training screen"],
	["RestMenu", ["@player", true], "rest menu"],
	["ClassScreen", [], "class screen"],
	["AlchemyScreen", [], "alchemy screen"],
	["SmithingScreen", [true], "smithing screen"],
	["LockpickScreen", [2], "lockpicking screen"],
	["BookReader", ["book_hallam"], "book reader"],
]
var f := 0
var step := 0
var wait := 0
var page := 0
var CM

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

## Visible controls under `node` that stick out past the window's left or right edge
## (inside a clipping parent doesn't count: the parent hides the overflow).
func overflowing(node: Node) -> Array:
	var out := []
	var width := float(get_root().size.x)
	for c in node.find_children("*", "Control", true, false):
		if not c.is_visible_in_tree() or c.size.x <= 0.0 or _clipped(c):
			continue
		var r: Rect2 = c.get_global_rect()
		if r.position.x < -1.0 or r.end.x > width + 1.0:
			out.append("%s (%d..%d)" % [c.name, int(r.position.x), int(r.end.x)])
	return out

func _clipped(c: Control) -> bool:
	var p := c.get_parent()
	while p is Control:
		if p.clip_contents or p is ScrollContainer:
			var pr: Rect2 = p.get_global_rect()
			if pr.position.x >= -1.0 and pr.end.x <= float(get_root().size.x) + 1.0:
				return true
		p = p.get_parent()
	return false

func _process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	CM = autoload("CharacterMenu")
	match step:
		0:
			get_root().size = SIZE
			wait = 5
		1:
			ok(get_root().size == SIZE, "a %dx%d window" % [SIZE.x, SIZE.y], get_root().size)
			CM.open()
			page = 0
			wait = 3
		2:
			CM.tabs.current_tab = page
			wait = 4
		3:
			var name: String = CM.tabs.get_tab_title(page)
			var bad := overflowing(CM.get_node("Root"))
			ok(bad.is_empty(), "the %s page fits" % name, bad.slice(0, 5))
			page += 1
			if page < CM.tabs.get_tab_count():
				step = 2
				return false
			CM.close()
			page = 0
			wait = 2
		4:
			var screen = SCREENS[page]
			var args: Array = screen[1].map(func(a): return get_first_node_in_group("player") if a is String and a == "@player" else a)
			autoload(screen[0]).callv("open", args)
			wait = 4
		5:
			var screen = SCREENS[page]
			var node = autoload(screen[0])
			ok(node.is_open, "the %s opens" % screen[2])
			var bad := overflowing(node)
			ok(bad.is_empty(), "the %s fits" % screen[2], bad.slice(0, 5))
			node.close()
			page += 1
			if page < SCREENS.size():
				step = 4
				return false
			page = 0
			wait = 2
		6:
			var pages := ["main", "settings", "graphics", "controls", "accessibility"]
			autoload("PauseMenu").open_page(pages[page])
			wait = 4
		7:
			var pages := ["main", "settings", "graphics", "controls", "accessibility"]
			var bad := overflowing(autoload("PauseMenu"))
			ok(bad.is_empty(), "the pause menu's %s page fits" % pages[page], bad.slice(0, 5))
			autoload("PauseMenu").close()
			page += 1
			if page < pages.size():
				step = 6
				return false
			change_scene_to_file("res://ui/character_creation.tscn")
			wait = 10
		8:
			var bad := overflowing(current_scene)
			ok(bad.is_empty(), "character creation fits", bad.slice(0, 5))
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
