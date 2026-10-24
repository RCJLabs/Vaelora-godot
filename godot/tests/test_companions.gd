extends "res://tests/test_base.gd"
# Companions (systems/companions.gd, companions/companion.gd): Brannoc, once he'd
# travel with you, joins from any of his hub conversations; the man at his post
# goes and a companion appears behind you. He follows, fights a wolf that's after
# you, waits when told, catches up when left far behind, comes back after F9, and
# goes home when dismissed. Zora can't be asked while he's with you, or once
# you've sold her out to the Order.
var f := 0
var step := 0
var wait := 0
var p
var GS
var DM
var CO
var wolf
var held := Vector3.ZERO

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func texts() -> Array:
	return DM._choices.map(func(c): return c["text"])

func pick(start: String) -> bool:
	var t := texts()
	for i in t.size():
		if t[i].begins_with(start):
			DM.choose(i)
			return true
	ok(false, "choice '%s' offered" % start, t)
	return false

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func order(start: String) -> void:
	var c = CO.body()
	c.interact(p)
	pick(start)
	DM.end()

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	GS = autoload("GameState"); DM = autoload("DialogueManager"); CO = autoload("Companions")
	match step:
		0:
			for i in [1, 2, 3]:
				var w = n("GreyfangPack/Wolf%d" % i)
				w.set_physics_process(false)
				w.global_position += Vector3(80, 0, 0)
			wait = 5
		1:
			ok(CO.active() == "" and CO.body() == null, "nobody with you at the start")
			# Mid-story: the stones quest is under way, so he opens with "progress", not greet_again.
			for flag in ["met_brannoc", "wrong_things_done", "stones_quest_started"]: GS.set_flag(flag)
			DM.start("res://dialogue/brannoc.json", "Brannoc")
			ok(not texts().has("Come with me. Now, not later."), "not before he's said he'd travel", texts())
			pick("What will you do, after all this?")
			ok(GS.has_flag("brannoc_would_travel"), "his travel line isn't stuck behind greet_again")
			DM.end()
			DM.start("res://dialogue/brannoc.json", "Brannoc")
			pick("Come with me.")
			ok(GS.has_flag("companion_brannoc") and CO.active() == "brannoc", "Brannoc joins")
			DM.end()
			wait = 5
		2:
			ok(not n("BrannocAtPost").is_present(), "the man at his post is gone")
			var c = CO.body()
			ok(c != null and c.display_name == "Brannoc", "and he's behind you")
			if c:
				ok(flat(c.global_position, p.global_position) < 4.0, "close behind", flat(c.global_position, p.global_position))
				ok(c.prompt == "Talk to Brannoc", "prompt", c.prompt)
			# Walk off (well, appear) 10 m away: he follows.
			p.global_position += Vector3(10, 0, 0)
			wait = 150
		3:
			var c = CO.body()
			ok(flat(c.global_position, p.global_position) < 5.0, "he followed", [c.global_position, p.global_position])
			# A wolf comes for you: he fights it.
			wolf = n("GreyfangPack/Wolf1")
			n("GreyfangPack").can_break = false
			wolf.global_position = p.global_position + Vector3(0, 0.2, -6)
			wolf.set_physics_process(true)
			wolf.join_hunt()
			wait = 150
		4:
			var c = CO.body()
			ok(wolf.stats.health < wolf.stats.max_health, "he hits the wolf", [wolf.stats.health, c.State.keys()[c.state], flat(c.global_position, wolf.global_position)])
			wolf.stats.take_damage(1000.0, true)
			p.stats.health = p.stats.max_health
			wait = 10
		5:
			var c = CO.body()
			ok(c.state == c.State.FOLLOW, "back to following once it's dead", c.State.keys()[c.state])
			order("Wait here.")
			ok(c.state == c.State.WAIT and not GS.has_flag("companion_cmd_wait"), "told to wait (the order isn't kept as a flag)")
			held = c.global_position
			p.global_position += Vector3(-12, 0, 0)
			wait = 120
		6:
			var c = CO.body()
			ok(flat(c.global_position, held) < 0.5, "he waits", flat(c.global_position, held))
			order("Follow me.")
			ok(c.state == c.State.FOLLOW, "follows again")
			p.global_position += Vector3(0, 0, 60)   # further than he'd walk: he catches up
			wait = 10
		7:
			var c = CO.body()
			ok(flat(c.global_position, p.global_position) < 4.0, "and catches up from far away", flat(c.global_position, p.global_position))
			ok(autoload("SaveSystem").save_game(), "save")
			wait = 5
		8:
			autoload("SaveSystem").load_game()
			wait = 40
		9:
			ok(CO.active() == "brannoc" and CO.body() != null, "still with you after loading")
			ok(not n("BrannocAtPost").is_present(), "and not at his post")
			# Zora can't be asked while he's with you.
			for flag in ["met_zora", "zora_would_travel"]: GS.set_flag(flag)
			DM.start("res://dialogue/zora.json", "Zora")
			ok(not texts().has("Come with me."), "one companion at a time", texts())
			DM.end()
			order("Go home.")
			wait = 5
		10:
			ok(CO.active() == "" and not GS.has_flag("companion_brannoc"), "dismissed")
			ok(CO.body() == null and current_scene.get_node_or_null("Companion_brannoc") == null, "he's gone from beside you")
			ok(n("BrannocAtPost").is_present(), "and back at his post")
			DM.start("res://dialogue/zora.json", "Zora")
			ok(texts().has("Come with me."), "now Zora can be asked", texts())
			DM.end()
			GS.set_flag("inquisitor_told_zora")
			GS.set_flag("zora_knows_betrayed")
			DM.start("res://dialogue/zora.json", "Zora")
			ok(not texts().has("Come with me."), "but not after you sold her out", texts())
			DM.end()
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
