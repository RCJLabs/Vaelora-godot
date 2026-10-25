extends "res://tests/test_base.gd"
# Skill books and trainers (systems/training.gd, ui/training_screen.gd): a skill
# book raises its skill by one the first time it's read, never again (and not
# for a book read before it taught anything); Maren sells two; a trainer's
# lesson costs 10 + 3 per level, raises the skill and counts toward your level;
# five lessons per character level, then not until the next; each trainer
# teaches only so far; and the lessons taken are saved.
var f := 0
var step := 0
var wait := 0
var p
var S
var I
var TR
var TS

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func _process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	S = autoload("Skills"); I = autoload("Inventory"); TR = autoload("Training"); TS = autoload("TrainingScreen")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			wait = 5
		1:
			# Skill books.
			var one: int = S.levels["one_handed"]
			I.add("book_swordsmans_rest")
			I.use("book_swordsmans_rest")
			ok(S.levels["one_handed"] == one + 1, "reading The Swordsman's Rest: One-Handed +1", [one, S.levels["one_handed"]])
			autoload("BookReader").close()
			I.use("book_swordsmans_rest")
			ok(S.levels["one_handed"] == one + 1, "a second reading teaches nothing more")
			autoload("BookReader").close()
			var archery: int = S.levels["archery"]
			I.add("book_hallam"); I.use("book_hallam"); autoload("BookReader").close()
			ok(S.levels["archery"] == archery + 1, "the Hallam book is an Archery book now")
			autoload("GameState").set_flag("read_book_lullaby")   # read in an older version
			var glamour: int = S.levels["glamour"]
			I.add("book_lullaby"); I.use("book_lullaby"); autoload("BookReader").close()
			ok(S.levels["glamour"] == glamour, "a book already read doesn't teach after the fact")
			var stock: Dictionary = autoload("Trade").stock("maren")
			ok(stock.has("book_swordsmans_rest") and stock.has("book_tide_table"), "Maren sells two skill books")
			# Trainers.
			var brannoc: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dialogue/brannoc.json"))
			ok(brannoc["nodes"]["greet_again"]["choices"].any(func(c): return c.get("open_training", "") == "brannoc"), "Brannoc offers lessons")
			S.levels["one_handed"] = 20
			S.trained_this_level = 0
			I.add_gold(1000)
			TS.open("brannoc")
			wait = 2
		2:
			ok(TS.is_open and paused, "the lesson screen opens, and pauses")
			ok(TR.cost("one_handed") == 70, "a lesson at 20 costs 70", TR.cost("one_handed"))
			var gold: int = I.gold
			var level_ups: int = S.skill_ups_toward_level + S.character_level * S.SKILL_UPS_PER_LEVEL
			ok(TS.train(), "train once")
			ok(S.levels["one_handed"] == 21 and I.gold == gold - 70, "One-Handed 21, 70 gold", [S.levels["one_handed"], gold - I.gold])
			ok(S.skill_ups_toward_level + S.character_level * S.SKILL_UPS_PER_LEVEL == level_ups + 1, "it counts toward your level")
			ok(TR.lessons_left() == 4, "4 lessons left this level", TR.lessons_left())
			# Use them up (stay in the same character level for the check).
			S.skill_ups_toward_level = 0
			for i in 4:
				S.skill_ups_toward_level = 0
				TS.train()
			ok(TR.lessons_left() == 0 and not TS.train(), "five a level, no more", TR.lessons_left())
			ok(TR.why_not("brannoc").contains("next level"), "and it says why")
			# A new level: lessons again.
			S.skill_ups_toward_level = S.SKILL_UPS_PER_LEVEL - 1
			S.raise("athletics")
			ok(TR.lessons_left() == 5, "a new character level: five more")
			# Brannoc only goes so far.
			S.levels["one_handed"] = 40
			ok(not TS.train() and TR.why_not("brannoc").contains("nothing left"), "Brannoc teaches up to 40")
			# Can't afford.
			S.levels["one_handed"] = 30
			I.add_gold(-I.gold)
			ok(not TS.train() and TR.why_not("brannoc").contains("afford"), "no gold, no lesson")
			# Saved.
			S.trained_this_level = 3
			var data: Dictionary = S.to_dict()
			S.trained_this_level = 0
			S.from_dict(data)
			ok(S.trained_this_level == 3, "lessons taken this level are saved")
			ok(TR.TRAINERS.has("ostap") and TR.TRAINERS.has("zora") and TR.TRAINERS.has("aurel"), "Ostap, Zora and Aurel teach too")
			TS.close()
			wait = 2
		3:
			ok(not TS.is_open and not paused, "closed")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
