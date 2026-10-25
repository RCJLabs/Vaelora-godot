extends "res://tests/test_base.gd"
# Speech (systems/speech.gd): dialogue checks show what they take and what you
# have, with no dice. Persuade = Speech + 2 per Presence point above 10;
# intimidate uses Strength; perks add. A failed check goes to its fail node and
# isn't offered again; passing teaches Speech once. Bribes cost less with
# Speech. Haggling: prices by Speech and perks, within floors. The content: a
# regular's discount from Maren, the inquisitor talked out of the notebook, and
# talked down, scared off or paid off when he'd draw; walking away from him
# (Esc) is a fight. Trainers, companions and Fat Purses perks.
var f := 0
var step := 0
var wait := 0
var p
var S
var C
var I
var A
var T
var GS
var DM
var SP

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func labels() -> Array:
	return DM._choices.map(func(c): return SP.label(c.get("check", {})) + c["text"] if c.has("check") else c["text"])

func pick(start: String) -> bool:
	var t := labels()
	for i in t.size():
		if t[i].begins_with(start) or DM._choices[i]["text"].begins_with(start):
			DM.choose(i)
			return true
	ok(false, "choice '%s' offered" % start, t)
	return false

func _process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	S = autoload("Skills"); C = autoload("Character"); I = autoload("Inventory"); A = autoload("Attributes")
	T = autoload("Trade"); GS = autoload("GameState"); DM = autoload("DialogueManager"); SP = autoload("Speech")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			wait = 5
		1:
			ok(S.SKILLS["speech"]["attribute"] == "presence" and S.levels["speech"] == 15, "a Speech skill (Presence), from 15")
			A.values["presence"] = 10; A.values["strength"] = 10
			ok(SP.score("persuade") == 15 and SP.score("intimidate") == 15, "scores: Speech 15, attributes at 10")
			A.values["presence"] = 14
			ok(SP.score("persuade") == 23 and SP.score("intimidate") == 15, "Presence 14: persuade 23; intimidate goes by Strength", [SP.score("persuade"), SP.score("intimidate")])
			ok(SP.label({"kind": "persuade", "difficulty": 30}) == "[Persuade 30 · you 23] ", "the choice shows it", SP.label({"kind": "persuade", "difficulty": 30}))
			# Maren: fail first.
			GS.set_flag("met_maren")
			DM.start("res://dialogue/maren.json", "Maren")
			ok(labels().has("[Persuade 30 · you 23] Any chance of a better price for a regular?"), "Maren: a persuade check", labels())
			var xp: float = S.xp["speech"]
			pick("Any chance of a better price")
			ok(DM.line_label.text.contains("Prices are prices") and GS.has_flag("speech_failed_maren_discount"), "23 < 30: she says no", DM.line_label.text)
			ok(S.xp["speech"] == xp, "a failed check teaches nothing (without Learn From It)")
			DM.end()
			DM.start("res://dialogue/maren.json", "Maren")
			ok(not DM._choices.any(func(c): return c.has("check")), "and it isn't offered again")
			DM.end()
			# Pass.
			GS.clear_flag("speech_failed_maren_discount")
			S.levels["speech"] = 40
			var plain: float = T.buy_mult("maren")
			DM.start("res://dialogue/maren.json", "Maren")
			pick("Any chance of a better price")
			ok(GS.has_flag("maren_discount") and DM.line_label.text.contains("A tenth off"), "48 >= 30: a regular's discount", DM.line_label.text)
			ok(S.xp["speech"] + S.levels["speech"] * 1000 > xp + 40 * 1000, "passing teaches Speech")
			near(T.buy_mult("maren"), plain * 0.9, 0.001, "Maren takes a tenth off")
			near(T.buy_mult(""), plain, 0.001, "(only Maren)")
			DM.end()
			# Haggling by Speech.
			A.values["presence"] = 10
			S.levels["speech"] = 65
			near(T.buy_mult(), 1.25 - 0.15, 0.001, "Speech 65: buy at x1.10")
			near(T.sell_mult(), 0.45 + 0.10, 0.001, "and sell at x0.55")
			for i in range(1, 6): C.perks.append("haggling_%d" % i)
			near(T.buy_mult(), 1.10 * pow(0.95, 5), 0.001, "Haggling V: x0.95 five times")
			near(T.sell_mult(), 0.55 * pow(1.05, 5), 0.001, "selling x1.05 five times")
			A.values["presence"] = 20
			S.levels["speech"] = 100
			near(T.buy_mult(), 0.85, 0.001, "buying bottoms out at x0.85")
			near(T.sell_mult(), 0.8, 0.001, "selling tops out at x0.8, under buying")
			C.perks.clear()
			A.values["presence"] = 10
			S.levels["speech"] = 15
			S.xp["speech"] = 0.0
			var trade_xp: float = S.xp["speech"]
			I.add_gold(100)
			ok(T.buy("maren", "bread") and S.xp["speech"] > trade_xp, "trading teaches Speech")
			# Bribes.
			S.levels["speech"] = 15
			ok(SP.bribe_cost(150) == 150, "a 150 bribe at Speech 15", SP.bribe_cost(150))
			S.levels["speech"] = 65
			ok(SP.bribe_cost(150) == 120, "Speech 65: 120", SP.bribe_cost(150))
			C.perks.append("bribery")
			ok(SP.bribe_cost(150) == 90, "Bribery: 90", SP.bribe_cost(150))
			C.perks.clear()
			# The notebook, talked out of the inquisitor.
			S.levels["speech"] = 40
			S.xp["speech"] = 0.0
			A.values["presence"] = 14
			GS.set_flag("met_inquisitor"); GS.set_flag("zora_notebook_started")
			DM.start("res://dialogue/inquisitor.json", "Inquisitor")
			pick("You carry a hedge-witch's notebook.")
			ok(labels().has("[Persuade 45 · you 48] Ilse's dead. Her words can't hurt anyone, and they might help the living."), "the notebook: persuade 45", labels())
			pick("Ilse's dead.")
			ok(I.count("book_ilse_notebook") == 1 and GS.has_flag("zora_notebook_persuaded"), "he gives it up for nothing")
			DM.end()
			# He'd draw on a Stained player: pay him off.
			autoload("Corruption").value = 55.0
			I.add_gold(500)
			var gold: int = I.gold
			DM.start("res://dialogue/inquisitor.json", "Inquisitor")
			ok(DM.line_label.text.contains("The Order is merciful") and not GS.has_flag("inquisitor_hostile"), "Stained: he'd draw, but you can still talk", DM.line_label.text)
			var t := labels()
			ok(t.any(func(x): return x.begins_with("[Persuade 60 · you 48] I'm fighting it.")) and t.any(func(x): return x.begins_with("[Intimidate 55 · you")) and t.any(func(x): return x.begins_with("[Bribe 135 gold]")) and t.has("(Fight.)"), "persuade, intimidate, bribe or fight", t)
			pick("[Bribe")
			ok(I.gold == gold - 135 and GS.has_flag("inquisitor_spared") and not GS.has_flag("inquisitor_hostile"), "paid: he steps aside", [gold - I.gold, DM.line_label.text])
			DM.end()
			DM.start("res://dialogue/inquisitor.json", "Inquisitor")
			ok(DM.line_label.text.contains("Still fighting it?"), "and lets you pass after", DM.line_label.text)
			DM.end()
			# Perks elsewhere.
			var lesson: int = autoload("Training").cost("one_handed")
			C.perks.append("training_discount")
			ok(autoload("Training").cost("one_handed") == roundi(lesson * 0.8), "Good Student: lessons 20% cheaper")
			C.perks.append("trusted")
			var before: int = autoload("Companions").approval.get("brannoc", 0)
			autoload("Companions").add_approval("brannoc", 4)
			ok(autoload("Companions").approval["brannoc"] == before + 5, "Trusted: approval 4 -> 5", autoload("Companions").approval["brannoc"] - before)
			var persuade: int = SP.score("persuade"); var intimidate: int = SP.score("intimidate")
			C.perks.append("persuasive"); C.perks.append("golden_voice")
			ok(SP.score("persuade") == persuade + 20 and SP.score("intimidate") == intimidate + 10, "check bonuses: +10 persuade, +10 all")
			C.perks.clear()
			var perks: Array = C.perk_list.keys().filter(func(k): return C.perk_list[k]["skill"] == "speech")
			ok(perks.size() >= 20, "20+ Speech perks", perks.size())
			# Walking away from him (Esc) is a fight.
			GS.clear_flag("inquisitor_spared")
			DM.start("res://dialogue/inquisitor.json", "Inquisitor")
			var esc := InputEventAction.new(); esc.action = "ui_cancel"; esc.pressed = true
			DM._unhandled_input(esc)
			ok(not DM.is_active and GS.has_flag("inquisitor_hostile"), "Esc out of it: he draws")
			autoload("Corruption").value = 0.0
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
