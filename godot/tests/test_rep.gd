extends "res://tests/test_base.gd"
# Riverwatch reputation through the Waking Stones quest: Maren's reward, Brannoc's
# two endings (argument human_give or keep), the shop discount/refusal that follows,
# the journal outcome, the factions tab, and save/load.
var f := 0
var started := false
var path := "human_give"
var DM; var I; var GS; var R; var QL
var seen := []
func player(): return get_first_node_in_group("player")
func key(k: Key) -> void:
	var e := InputEventKey.new(); e.keycode = k; e.physical_keycode = k; e.pressed = true
	Input.parse_input_event(e)
	var r := InputEventKey.new(); r.keycode = k; r.physical_keycode = k; r.pressed = false
	Input.parse_input_event(r)
func face(target: Vector3) -> void:
	var p = player(); p.global_position = Vector3(target.x, 0, target.z + 2.0); p.velocity = Vector3.ZERO
	p.rotation.y = 0; p.get_node("Head").rotation.x = atan2(target.y - 1.6, 2.0)
func choices() -> Array: return DM.choices_box.get_children().map(func(b): return b.text)
func pick(start: String) -> void:
	var c = choices()
	for i in c.size():
		if c[i].substr(3).begins_with(start):
			DM.choose(i); return
	ok(false, "choice '%s' offered" % start, c)
func rep() -> String: return "rep=%d (%s)" % [R.value("riverwatch"), R.rank("riverwatch")]
func flush() -> Array:
	var out := seen
	seen = []
	return out
var steps := []
var wait := 0
func talking() -> bool: return DM.is_active
func idle() -> bool: return not DM.is_active
func always() -> bool: return true
func add(name: String, guard: Callable, action: Callable) -> void: steps.append([guard, action, name])
func talk_to(pos: Vector3) -> void:
	add("face", idle, func(): face(pos))
	add("press E", always, func(): key(KEY_E))
func _build_steps() -> void:
	add("wolf flags", always, func():
		for fl in ["met_maren", "heard_about_wolves", "wolf_quest_accepted", "wolves_cleared"]: GS.set_flag(fl))
	talk_to(Vector3(2, 1.2, -4))
	add("report wolves", talking, func(): pick("The Greyfang pack is dead"))
	add("after reward", talking, func():
		ok(R.value("riverwatch") == (13 if path == "human_give" else 11), "rep after Maren's reward", rep())
		ok(R.rank("riverwatch") == "Friendly", "rank Friendly", rep())
		ok(I.gold == 50, "gold after Maren's reward", I.gold)
		ok(R.known("riverwatch"), "Riverwatch now known")
		var n = flush()
		ok(n.size() == 2 and n[1] == "Riverwatch Garrison now sees you as Friendly", "reputation notices", n)
		DM.choose(0))
	talk_to(Vector3(-6, 1.2, -3))
	add("first meeting", talking, func(): ok(choices()[0].ends_with("Maren says she told Riverwatch about the wolves."), "Brannoc mentions Maren's report", choices()); pick("Maren says"))
	add("heard", talking, func(): ok(DM.line_label.text.begins_with("The wolf-killer from the waystation!"), "Brannoc has heard of you", DM.line_label.text); pick("Ask me what"))
	add("accept", talking, func(): pick("I'll look into it"))
	add("bye", talking, func(): DM.choose(0))
	add("get shards", idle, func(): GS.set_flag("touched_crystal"); I.add("rune_shard", 3))
	talk_to(Vector3(-6, 1.2, -3))
	add("progress", talking, func(): ok(choices()[0].ends_with("I found three rune shards."), "shards choice offered", choices()); pick("I found three"))
	add("decide", talking, func(): ok(choices().size() == 4, "three endings + think about it", choices()); pick("Take them" if path == "human_give" else "I think I'll keep"))
	add("ending", talking, func():
		if path == "human_give":
			ok(DM.line_label.text.begins_with("Sixty gold from the garrison purse"), "give ending line", DM.line_label.text)
			ok(R.value("riverwatch") == 32 and R.rank("riverwatch") == "Honored", "rep after giving the shards", rep())
			ok(I.gold == 110, "paid 60 gold", I.gold)
		else:
			ok(DM.line_label.text.begins_with("...Keep them, then."), "keep ending line", DM.line_label.text)
			ok(R.value("riverwatch") == -4 and R.rank("riverwatch") == "Distrusted", "rep after keeping the shards", rep())
			ok(I.gold == 50, "no payment", I.gold)
		var n = flush()
		ok(n.size() == 2, "rep change + rank notices", n)
		DM.choose(0))
	talk_to(Vector3(-6, 1.2, -3))
	add("next talk", talking, func():
		if path == "human_give":
			ok(DM.line_label.text.begins_with("The captain sent word"), "captain's reward line", DM.line_label.text)
		else:
			ok(DM.line_label.text.begins_with("You. I've nothing to say to you"), "Brannoc is cold", DM.line_label.text)
		ok(choices().size() == 1, "one choice", choices())
		DM.choose(0))
	add("after next", idle, func():
		ok(I.gold == (160 if path == "human_give" else 50), "gold after the next talk", I.gold)
		ok(I.count("minor_healing_potion") == (3 if path == "human_give" else 1), "potions after the next talk", I.count("minor_healing_potion")))
	talk_to(Vector3(-6, 1.2, -3))
	add("third talk", talking, func():
		if path == "human_give":
			ok(DM.line_label.text.begins_with("The scholars are beside themselves."), "scholars line", DM.line_label.text)
			ok(choices().size() == 3, "potion / news / goodbye", choices())
			pick("Can the garrison")
		else:
			ok(DM.line_label.text.begins_with("You. I've nothing to say"), "still cold", DM.line_label.text)
			DM.choose(0))
	if path == "human_give":
		add("bought", talking, func():
			ok(DM.line_label.text.begins_with("For a friend of Riverwatch?"), "friendly shop line", DM.line_label.text)
			ok(I.gold == 130 and I.count("minor_healing_potion") == 4, "bought a potion for 30", [I.gold, I.count("minor_healing_potion")])
			pick("That's all"))
	add("journal", idle, func():
		var outcome: String = QL.status("waking_stones")["outcome"]
		ok(outcome.begins_with("I gave the shards to Brannoc" if path == "human_give" else "I kept the shards for myself."), "journal outcome", outcome)
		key(KEY_TAB))
	add("factions tab", always, func():
		var m = root.get_node("CharacterMenu"); m.tabs.current_tab = 4
		var rows = m.get_node("%FactionList").get_children().map(func(b): return b.get_child(0).text if b.get_child_count() > 0 else b.text)
		ok(rows == ["Riverwatch Garrison  -  %s (%d)" % [R.rank("riverwatch"), R.value("riverwatch")]], "factions tab row", rows)
		key(KEY_TAB))
	add("save", always, func(): key(KEY_F5))
	add("load", always, func(): R.reset(); key(KEY_F9))
	add("wait", always, func(): pass)
	add("wait", always, func(): pass)
	add("after load", always, func():
		ok(R.value("riverwatch") == (32 if path == "human_give" else -4), "rep restored by load", rep())
		ok(seen.is_empty(), "loading raises no notices", seen)
		root.get_node("SaveSystem").delete_save())
func _physics_process(_d: float) -> bool:
	if not started:
		started = true
		DM = root.get_node("DialogueManager"); I = root.get_node("Inventory"); GS = root.get_node("GameState"); R = root.get_node("Reputation"); QL = root.get_node("QuestLog")
		path = arg("human_give")
		var race = load("res://races/%s.tres" % ("human" if path.begins_with("human") else "orc"))
		GS.set_race(race); root.get_node("Skills").reset(race); root.get_node("Spellbook").reset(race); GS.flags = {}; I.reset(); R.reset(); QL.reset_baseline()
		root.get_node("SaveSystem").delete_save()
		R.notice.connect(func(t): seen.append(t))
		var level = load("res://levels/test_level.tscn").instantiate()
		root.add_child(level); current_scene = level
		ok(not R.known("riverwatch"), "Riverwatch unknown at the start")
		return false
	f += 1
	if steps.is_empty() and f == 1:
		_build_steps()
	if wait > 0:
		wait -= 1
		return false
	if steps.is_empty():
		return done()
	var step = steps[0]
	if step[0].call():
		steps.pop_front()
		step[1].call()
		wait = 3
	elif f > 2000:
		ok(false, "stuck waiting at step " + step[2]); return done()
	return false
