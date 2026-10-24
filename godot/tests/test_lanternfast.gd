extends "res://tests/test_base.gd"
# Lanternfast (systems/lanternfast.gd, WorldClock's Wanderer): the green moon is
# dark every 7th day, and that night from 18:00 to 2:00 is Lanternfast. The
# lanterns come out at the waystation, Maren, Ostap and Zora say their piece,
# the wisps leave you be, it survives a save and load, and at 2:00 it's over.
var f := 0
var step := 0
var wait := 0
var p
var GS
var DM
var W

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func talk(file: String) -> String:
	if DM.is_active:
		DM.end()
	DM.start("res://dialogue/%s.json" % file, file)
	var line: String = DM.line_label.text
	DM.end()
	return line

func wisps() -> Array:
	return get_nodes_in_group("enemy").filter(func(e): return e.has_method("_graced"))

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	GS = autoload("GameState"); DM = autoload("DialogueManager"); W = autoload("WorldClock")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			wait = 5
		1:
			ok(W.day == 1 and not W.wanderer_dark() and W.days_until_dark() == 6, "day 1: the Wanderer is dark in 6 days", [W.day, W.days_until_dark()])
			ok(W.wanderer_text() == "The Wanderer is waxing. Lanternfast in 6 days.", "the sky, in words", W.wanderer_text())
			W.day = 4
			ok(W.wanderer_text().begins_with("The Wanderer is full."), "full on day 4", W.wanderer_text())
			W.day = 7; W.hour = 12.0
			ok(W.wanderer_dark() and not W.is_lanternfast(), "day 7 is dark, but the festival waits for evening")
			ok(W.wanderer_text() == "The Wanderer is dark. Lanternfast tonight.", "dark-day sky text", W.wanderer_text())
			ok(not n("Lanternfast").is_present(), "no lanterns by day")
			for flag in ["met_maren", "met_zora"]: GS.set_flag(flag)
			W.hour = 17.95
			W.advance(0.1)
			wait = 2
		2:
			ok(W.is_lanternfast() and GS.has_flag("lanternfast_now") and GS.has_flag("saw_lanternfast"), "18:00: Lanternfast")
			ok(n("Lanternfast").is_present() and n("Lanternfast").get_child_count() >= 8, "the lanterns are out")
			ok(talk("maren").contains("can't get in"), "Maren: so the lights can't get in", DM.line_label.text)
			ok(talk("zora").contains("finding"), "Zora: they're for finding")
			ok(talk("ostap").contains("see it from the road"), "Ostap would light one, but")
			ok(not talk("maren").contains("can't get in"), "each says it once")
			W.advance(3.0)   # 21:00: the wisps are out
			wait = 30
		3:
			var ws := wisps()
			ok(ws.size() > 0, "wisps at the circle", ws.size())
			ok(ws.all(func(w): return w._graced(p)), "and they leave you be tonight")
			ok(autoload("SaveSystem").save_game(), "save")
			wait = 2
		4:
			autoload("SaveSystem").load_game()
			wait = 40
		5:
			ok(GS.has_flag("lanternfast_now") and n("Lanternfast").is_present(), "still Lanternfast after loading")
			W.advance(W.hours_until(2.05))
			wait = 3
		6:
			ok(W.day == 8 and not W.is_lanternfast(), "2:00 on day 8: over", W.text())
			ok(not GS.has_flag("lanternfast_now") and GS.has_flag("saw_lanternfast"), "the flag goes; the memory stays")
			ok(not n("Lanternfast").is_present(), "the lanterns are put away")
			var ws := wisps()
			ok(ws.is_empty() or not ws.any(func(w): return w._graced(p)), "and the wisps are wisps again")
			ok(W.days_until_dark() == 6, "next one in 6 days", W.days_until_dark())
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
