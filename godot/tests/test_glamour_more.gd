extends "res://tests/test_base.gd"
# The rest of Glamour: Zora's second lesson (Frenzy, Invisibility); Frenzy sets a
# wolf on its packmate and the pack on it, falls back on you when nobody else is
# near, and your hits don't break it; your Flames on a charmed wolf break the
# charm; Invisibility, cast for real, makes a hunting wolf give up and head home
# and an idle one not notice you, sends it to your companion if you have one, and
# ends when you attack.
var f := 0
var step := 0
var wait := 0
var p
var GS
var DM
var G
var T
var SB
var w1
var w2
var w3
var base := Vector3.ZERO

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func pick(start: String) -> bool:
	var t: Array = DM._choices.map(func(c): return c["text"])
	for i in t.size():
		if t[i].begins_with(start):
			DM.choose(i)
			return true
	ok(false, "choice '%s' offered" % start, t)
	return false

func park(wolf, at: Vector3, on: bool) -> void:
	wolf.global_position = at
	wolf.home = at
	wolf.velocity = Vector3.ZERO
	wolf.set_physics_process(on)

func stand(at: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.rotation.y = deg_to_rad(yaw_deg)
	p.get_node("Head").rotation.x = deg_to_rad(pitch_deg)

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	GS = autoload("GameState"); DM = autoload("DialogueManager"); G = autoload("Glamour"); T = autoload("Targeting"); SB = autoload("Spellbook")
	match step:
		0:
			n("GreyfangPack").can_break = false
			w1 = n("GreyfangPack/Wolf1"); w2 = n("GreyfangPack/Wolf2"); w3 = n("GreyfangPack/Wolf3")
			base = w1.global_position
			park(w1, base, false)
			park(w2, base + Vector3(3, 0, 0), false)
			park(w3, base + Vector3(80, 0, 0), false)
			stand(base + Vector3(0, 0.05, 12), 0, 0)
			wait = 5
		1:
			# Zora's second lesson.
			for flag in ["met_zora", "zora_taught_glamour"]: GS.set_flag(flag)
			DM.start("res://dialogue/zora.json", "Zora")
			pick("Teach me more of it.")
			pick("And the last?")
			DM.end()
			var I = autoload("Inventory")
			for id in ["frenzy", "invisibility"]:
				ok(I.count("tome_" + id) == 1, "Zora gives the %s tome" % id)
				I.use("tome_" + id)
				ok(SB.knows(id), "and it teaches " + id)
			# Frenzy on Wolf2, both hunting you.
			for w in [w1, w2]:
				w.set_physics_process(true)
				w.join_hunt()
			wait = 2
		2:
			G.cast(SB.get_spell("frenzy"), w2.global_position, 1.0, p)
			ok(G.kind_of(w2) == "frenzy" and w2.get_node_or_null("FrenzyMark") != null, "Frenzy takes the one you aimed at, marked red")
			ok(not G.is_charmed(w2), "frenzied isn't charmed")
			ok(T.foe_for(w2, p) == w1, "it goes for its packmate")
			ok(T.foe_for(w1, p) == w2, "and its packmate turns on it")
			G.struck(w2, p)
			ok(G.kind_of(w2) == "frenzy", "your hits don't break a frenzy")
			w1.set_meta("h", w1.stats.health)
			wait = 180
		3:
			ok(w1.stats.health < w1.get_meta("h"), "the frenzied wolf bites its packmate", [w1.get_meta("h"), w1.stats.health])
			w1.stats.take_damage(1000.0, true)
			wait = 2
		4:
			ok(T.foe_for(w2, p) == p, "with nobody else near, a frenzied wolf comes for you")
			# Charm it instead, then hit it with Flames yourself: the charm breaks.
			G.charm(w2, 30.0)
			ok(G.is_charmed(w2) and G.kind_of(w2) == "charm", "charm replaces the frenzy")
			w2.set_physics_process(false)
			SB.learn("flames"); SB.select("flames")
			var to: Vector3 = w2.global_position
			stand(to + Vector3(0, 0.05, 3), 0, -12)
			p.stats.magicka = p.stats.max_magicka
			Input.action_press("cast")
			wait = 20
		5:
			Input.action_release("cast")
			ok(not G.is_charmed(w2), "your Flames break the charm")
			ok(w2.get_node_or_null("CharmMark") == null, "and its light goes out")
			G.reset()
			# Invisibility, cast for real, with Wolf3 hunting you.
			w2.stats.take_damage(1000.0, true)
			park(w3, base + Vector3(-6, 0, 20), true)
			stand(base + Vector3(-6, 0.05, 28), 0, 0)
			w3.join_hunt()
			wait = 30
		6:
			ok(T.foe_for(w3, p) == p, "Wolf3 is after you")
			w3.home = base + Vector3(-6, 0, 10)   # home is 18 m back
			SB.select("invisibility")
			p.stats.magicka = p.stats.max_magicka
			Input.action_press("cast")
			wait = 60
		7:
			Input.action_release("cast")
			wait = 3
		8:
			ok(p.effects.has("invisible"), "Invisibility, cast")
			ok(T.foe_for(w3, p) == null, "the wolf loses you")
			w3.set_meta("d", flat(w3.global_position, w3.home))
			wait = 90
		9:
			ok(w3.state == w3.State.RETURN or w3.state == w3.State.IDLE, "and gives up", w3.State.keys()[w3.state])
			ok(flat(w3.global_position, w3.home) < w3.get_meta("d") - 3.0, "heading home", [w3.get_meta("d"), flat(w3.global_position, w3.home)])
			ok(p.stats.health == p.stats.max_health, "untouched")
			# Home and idle, it doesn't notice you right beside it.
			park(w3, w3.home, true)
			w3.state = w3.State.IDLE
			stand(w3.home + Vector3(0, 0.05, 3), 0, 0)
			wait = 30
		10:
			ok(w3.state == w3.State.IDLE, "an idle wolf doesn't notice you", w3.State.keys()[w3.state])
			# With a companion, it goes for them instead.
			GS.set_flag("companion_brannoc")
			wait = 20
		11:
			var c = autoload("Companions").body()
			ok(c != null and T.foe_for(w3, p) == c, "with a companion, it goes for them instead")
			GS.clear_flag("companion_brannoc")
			wait = 5
		12:
			Input.action_press("attack")
			wait = 1
		13:
			Input.action_release("attack")
			ok(not p.effects.has("invisible"), "attacking ends it")
			ok(T.foe_for(w3, p) == p, "and the wolf sees you again")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
