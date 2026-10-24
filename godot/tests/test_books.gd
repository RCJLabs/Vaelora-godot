extends "res://tests/test_base.gd"
# Books (ItemData.book_text, ui/book_reader.gd): taking one from the world opens
# it, pauses the game and sets read_<id>; E or Esc closes it; it stays in the pack
# and Read in the inventory opens it again, over the Tab menu, which stays paused
# and open underneath. Tab and the pause menu leave an open book alone. The five
# books placed in the demo exist and say what they should.
const BOOKS := {
	"BookHallam": ["book_hallam", "You should have stayed in the sky"],
	"BookCharter": ["book_charter", "This rule takes no commentary"],
	"BookDimming": ["book_dimming", "the residue is a well, not a spring"],
	"BookLantern": ["book_lantern", "We will make it quick"],
	"BookLullaby": ["book_lullaby", "The lanterns are for finding"],
}
var f := 0
var step := 0
var wait := 0
var p
var R
var I
var GS

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func key(k: Key) -> void:
	var e := InputEventKey.new(); e.keycode = k; e.physical_keycode = k; e.pressed = true
	Input.parse_input_event(e)
	var r := InputEventKey.new(); r.keycode = k; r.physical_keycode = k; r.pressed = false
	Input.parse_input_event(r)

func _process(_d: float) -> bool:   # runs while the game is paused, unlike _physics_process
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	R = autoload("BookReader"); I = autoload("Inventory"); GS = autoload("GameState")
	match step:
		0:
			wait = 5
		1:
			for node_name in BOOKS:
				var node = current_scene.get_node_or_null(node_name)
				var item = I.get_item(BOOKS[node_name][0])
				ok(node != null and item != null and item.is_readable(), "%s is in the world, and readable" % node_name)
				ok(item.book_text.contains(BOOKS[node_name][1]), "%s says \"%s\"" % [item.display_name, BOOKS[node_name][1]])
			var book = current_scene.get_node("BookHallam")
			ok(book.prompt == "Take and read Hallam and the Hundred Lights", "prompt", book.prompt)
			book.interact(p)
			ok(R.is_open and paused, "taking it opens it, and pauses the game")
			ok(R._title.text == "Hallam and the Hundred Lights" and R._text.text.begins_with("Inside the cover"), "title and text shown")
			ok(GS.has_flag("read_book_hallam"), "read_book_hallam")
			ok(I.count("book_hallam") == 1, "it's in the pack")
			key(KEY_TAB)   # the Tab menu leaves an open book alone
			wait = 2
		2:
			ok(not autoload("CharacterMenu").is_open and R.is_open, "Tab doesn't open the menu over a book")
			key(KEY_E)
			wait = 2
		3:
			ok(not R.is_open and not paused, "E closes it, and the game goes on")
			# Read it again, from the inventory, over the Tab menu.
			autoload("CharacterMenu").open()
			ok(paused, "the Tab menu pauses")
			ok(I.use("book_hallam") and R.is_open, "Read from the inventory")
			ok(I.count("book_hallam") == 1, "reading doesn't use it up")
			key(KEY_ESCAPE)
			wait = 2
		4:
			ok(not R.is_open, "Esc closes the book")
			ok(autoload("CharacterMenu").is_open and paused, "the Tab menu is still open, still paused")
			ok(not autoload("PauseMenu").is_open, "and Esc didn't open the pause menu")
			autoload("CharacterMenu").close()
			ok(not paused, "closing the menu unpauses")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
