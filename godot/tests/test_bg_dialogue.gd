extends "res://tests/test_base.gd"
# Background-specific dialogue: each background's extra lines with Maren and
# Brannoc, two of them followed through, and the trait/background conditions.
var f := 0
var lines := {}   # "background npc" -> choice texts

func _process(_d: float) -> bool:
	f += 1
	if f == 3:
		var C = autoload("Character"); var DM = autoload("DialogueManager")
		for bg in ["soldier", "hunter", "outlaw", "scholar", "merchant"]:
			C.create(load("res://races/human.tres"), "T", bg, ["charming"], {}, {})
			for npc in ["maren", "brannoc"]:
				DM.start("res://dialogue/%s.json" % npc, npc)
				lines["%s %s" % [bg, npc]] = DM.choices_box.get_children().map(func(b): return b.text)
				if bg == "soldier" and npc == "maren":
					DM.choose(DM._choices.size() - 2)
					ok(DM.line_label.text.begins_with("Trouble's all we see."), "soldier's levy line with Maren", DM.line_label.text)
				if bg == "outlaw" and npc == "brannoc":
					choose_starting(DM, "(Keep your hood low.)")
					ok(DM.line_label.text.begins_with("Hm. You've a face I've seen on a notice board"), "outlaw recognised by Brannoc", DM.line_label.text)
				DM.end()
		has("soldier maren", "I served in a levy.")
		has("hunter maren", "Those were Greyfang tracks")
		has("outlaw brannoc", "(Keep your hood low.)")
		has("scholar brannoc", "The stones are resonating.")
		for bg in ["outlaw", "scholar", "merchant"]:
			ok(lines["%s maren" % bg].size() == 2, "%s gets no extra line with Maren" % bg, lines["%s maren" % bg])
		for bg in ["soldier", "hunter", "merchant"]:
			ok(lines["%s brannoc" % bg].size() == 5, "%s gets no extra line with Brannoc" % bg, lines["%s brannoc" % bg])
		var conditions = load("res://systems/conditions.gd")
		ok(conditions.met({"requires_trait": "charming"}), "requires_trait met")
		ok(not conditions.met({"requires_trait": ["charming", "hardy"]}), "requires_trait list needs all of them")
		ok(conditions.met({"requires_background": ["soldier", "merchant"]}), "requires_background list needs any one")
		return done()
	return false

func has(key: String, start: String) -> void:
	ok(lines[key].any(func(t: String): return t.substr(3).begins_with(start)), "%s offers '%s'" % [key, start], lines[key])


func choose_starting(DM, start: String) -> void:
	var texts = DM.choices_box.get_children().map(func(b): return b.text)
	for i in texts.size():
		if texts[i].substr(3).begins_with(start):
			DM.choose(i)
			return
	ok(false, "choice '%s' offered" % start, texts)
