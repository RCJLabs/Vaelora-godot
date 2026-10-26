extends "res://tests/test_base.gd"
# Companion depth (systems/companions.gd, companions/<id>.json): approval, the
# remarks story flags draw while they follow you, banter now and then, their
# quests ("Her Teacher's Notebook" for Zora, bought back from Inquisitor Hale;
# "What Riverwatch Was Founded On" for Brannoc, read in the old barrow and told
# true), approval and what's been said surviving a save, and walking out at low
# approval (and not coming back).
var f := 0
var step := 0
var wait := 0
var p
var GS
var DM
var CO
var Q
var I
var said := []

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

func talk(file: String) -> void:
	if DM.is_active:
		DM.end()
	DM.start("res://dialogue/%s.json" % file, file)

func offered(start: String) -> bool:
	return texts().any(func(t): return t.begins_with(start))

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	GS = autoload("GameState"); DM = autoload("DialogueManager"); CO = autoload("Companions"); Q = autoload("QuestLog"); I = autoload("Inventory")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			CO.said.connect(func(id, line): said.append([id, line]))
			for flag in ["met_zora", "zora_would_travel", "companion_zora"]: GS.set_flag(flag)
			wait = 20
		1:
			ok(CO.approval["zora"] == 0 and CO.approval["brannoc"] == 0, "everyone starts at 0")
			# A remark, and approval, when something she cares about happens.
			GS.set_flag("took_wisp_essence")
			ok(CO.approval["zora"] == -10, "Zora minds you taking a wisp's light", CO.approval["zora"])
			ok(said.size() == 1 and said[0][0] == "zora" and said[0][1].begins_with("I felt that"), "and says so", said)
			ok(p.hud.message_label.text.begins_with("Zora: \"I felt that"), "on screen", p.hud.message_label.text)
			GS.set_flag("released_wisp")
			ok(CO.approval["zora"] == 0, "and likes you letting one go", CO.approval["zora"])
			# Her quest needs her to like you a little.
			talk("companion_zora")
			ok(not offered("You said the Order burned your teacher."), "not at 0")
			CO.add_approval("zora", 10)
			talk("companion_zora")
			pick("You said the Order burned your teacher.")
			ok(GS.has_flag("zora_notebook_started") and Q.status("zora_notebook")["state"] == "active", "Her Teacher's Notebook starts")
			DM.end()
			ok(n("InquisitorDrawn/InquisitorFoe").loot.has("book_ilse_notebook"), "Hale carries it (if it comes to a fight)")
			# Buy it back.
			talk("inquisitor")
			pick("You carry a hedge-witch's notebook.")
			ok(not offered("(Donate 100 gold.)"), "no donation without the gold")
			DM.end()
			I.add_gold(150)
			talk("inquisitor")
			pick("You carry a hedge-witch's notebook.")
			pick("(Donate 100 gold.)")
			ok(I.count("book_ilse_notebook") == 1 and I.gold == 50, "bought for 100", [I.count("book_ilse_notebook"), I.gold])
			DM.end()
			talk("companion_zora")
			pick("I have Ilse's notebook.")
			DM.end()
			ok(I.count("book_ilse_notebook") == 0 and CO.approval["zora"] == 25, "she takes it, and likes you better", CO.approval["zora"])
			var q: Dictionary = Q.status("zora_notebook")
			ok(q["state"] == "completed" and q["outcome"].contains("bought"), "Her Teacher's Notebook done: bought", q)
			# Banter, now and then: the first line she hasn't said whose conditions pass.
			said.clear()
			CO._banter_left = 0.01
			wait = 10   # it ticks in _process: under load several physics frames can pass first
		2:
			ok(said.size() == 1 and said[0][1].begins_with("You'd think after thirty years"), "banter", said)
			CO._banter_left = 0.01
			wait = 10
		3:
			ok(said.size() == 2 and said[1][1].begins_with("The Lantern Order burned my teacher"), "and the next line, not the same one", said)
			# Brannoc instead.
			GS.set_flag("companion_cmd_dismiss")
			GS.set_flag("companion_brannoc")
			wait = 20
		4:
			ok(CO.active() == "brannoc" and CO.body() != null, "Brannoc with you now")
			# His usual conversation, while the man at his post is away with you.
			talk("companion_brannoc")
			pick("About something else.")
			wait = 2
			step += 1
			return false
		5:
			ok(DM.is_active and DM.line_label.text.begins_with("Easy - you're no bandit."), "\"About something else\" opens his usual conversation", DM.line_label.text)
			DM.end()
			CO.add_approval("brannoc", 10)
			talk("companion_brannoc")
			pick("Your father's story")
			ok(Q.status("brannoc_founded")["state"] == "active", "What Riverwatch Was Founded On starts")
			DM.end()
			change_scene_to_file("res://levels/test_dungeon.tscn")
			wait = 40
		6:
			ok(CO.body() != null, "he comes into the barrow with you")
			var roll = n("RiverwatchRoll")
			ok(roll != null, "the roll is in the barrow's first hall")
			roll.interact(p)
			autoload("BookReader").close()
			ok(GS.has_flag("read_book_riverwatch_roll"), "read it")
			talk("companion_brannoc")
			pick("I read the roll in the barrow.")
			pick("The truth")
			DM.end()
			ok(GS.has_flag("brannoc_knows_hunt") and CO.approval["brannoc"] == 20, "told the truth: he knows, and trusts you more", CO.approval["brannoc"])
			var q: Dictionary = Q.status("brannoc_founded")
			ok(q["state"] == "completed" and q["outcome"].contains("I told him the truth"), "quest done: the truth", q)
			ok(autoload("SaveSystem").save_game(), "save")
			wait = 2
		7:
			CO.reset()
			autoload("SaveSystem").load_game()
			wait = 40
		8:
			ok(CO.approval["brannoc"] == 20 and CO.approval["zora"] == 25, "approval survives a load", CO.approval)
			ok(CO._said["zora"].size() == 2, "and what's been said", CO._said)
			# Walking out.
			said.clear()
			CO.add_approval("brannoc", -70)
			ok(GS.has_flag("left_you_brannoc") and CO.active() == "", "at -40 or below, he leaves")
			ok(said.size() == 1 and said[0][1].begins_with("I've seen enough"), "with a parting line", said)
			wait = 3
		9:
			ok(CO.body() == null, "and he's gone")
			GS.set_flag("met_brannoc")
			GS.set_flag("brannoc_would_travel")
			talk("brannoc")
			ok(not offered("Come with me."), "and won't come back", texts())
			DM.end()
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
