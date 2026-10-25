extends "res://tests/test_base.gd"
# Tidecraft (systems/tidecraft.gd): the tide (WorldClock.tide()) is high when
# Ilun is full or the Wanderer is dark and low in between, and Tidecraft spells
# are x0.6 to x1.4 by it; Pull, cast for real, drags a wolf to just in front of
# you and it reels; Tide's Shove hurls what's in front of you away and leaves
# what's behind; a Gravity Well drags wolves to its middle and pins them, then
# closes; the stone guardian can't be moved; Moon-Crush hits what's in its
# radius (hardest at the middle) and knocks it down; the HUD shows the tide; and
# Magister Aurel sells the tomes (Gravity Well only after his readings,
# Moon-Crush only after the well).
var f := 0
var step := 0
var wait := 0
var p
var W
var M
var DM
var w1
var w2
var base := Vector3.ZERO
var low_day := 1
var power_high := 0.0

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func park(wolf, at: Vector3) -> void:
	wolf.global_position = at
	wolf.home = at
	wolf.velocity = Vector3.ZERO

func stand(at: Vector3, yaw_deg: float, pitch_deg: float) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	p.rotation.y = deg_to_rad(yaw_deg)
	p.get_node("Head").rotation.x = deg_to_rad(pitch_deg)

func flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func cast(id: String) -> void:
	M.spell = autoload("Spellbook").get_spell(id)
	M._release()

func pick(start: String) -> bool:
	var t: Array = DM._choices.map(func(c): return c["text"])
	for i in t.size():
		if t[i].begins_with(start):
			DM.choose(i)
			return true
	ok(false, "choice '%s' offered" % start, t)
	return false

func offered(start: String) -> bool:
	return DM._choices.any(func(c): return c["text"].begins_with(start))

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	W = autoload("WorldClock"); DM = autoload("DialogueManager")
	M = p.get_node("Magic") if p else null
	match step:
		0:
			n("GreyfangPack").can_break = false
			w1 = n("GreyfangPack/Wolf1")
			w2 = n("GreyfangPack/Wolf2")
			base = w1.global_position + Vector3(0, 0, 25)
			var w3 = n("GreyfangPack/Wolf3")
			w3.set_physics_process(false)
			park(w3, base + Vector3(80, 0, 0))
			park(w2, base + Vector3(60, 0, 0))
			for id in ["pull", "tides_shove", "gravity_well", "moon_crush"]:
				autoload("Spellbook").learn(id)
			wait = 5
		1:
			# The tide.
			ok(autoload("Skills").SKILLS.has("tidecraft"), "a Tidecraft skill")
			W.day = 1; W.hour = 22.0
			ok(W.tide() > 0.95 and W.tide_word() == "high", "day 1: Ilun full, high tide", W.tide())
			ok(W.tide_text() == "The tide is high: Ilun is full.", "and why", W.tide_text())
			near(W.tide_mult(), 1.4, 0.02, "x1.4 at the top")
			W.day = 7; W.hour = 19.0
			ok(W.tide_word() == "high" and W.tide_text().contains("the Wanderer is dark"), "Lanternfast: the Wanderer dark, high tide", W.tide_text())
			var lowest := 2.0
			for d in range(1, 15):
				W.day = d; W.hour = 22.0
				if W.tide() < lowest:
					lowest = W.tide(); low_day = d
			ok(lowest < 0.3, "some nights the tide is low", [low_day, lowest])
			W.day = low_day
			ok(W.tide_word() == "low" and W.tide_text().begins_with("The tide is low"), "and says so", W.tide_text())
			near(W.tide_mult(), lerpf(0.6, 1.4, lowest), 0.001, "weaker then")
			# The spells feel it; other schools don't.
			M.spell = autoload("Spellbook").get_spell("pull")
			var low: float = M._power_mult()
			M.spell = autoload("Spellbook").get_spell("firebolt")
			var fire_low: float = M._power_mult()
			W.day = 1
			M.spell = autoload("Spellbook").get_spell("pull")
			power_high = M._power_mult()
			near(power_high / low, 1.4 / lerpf(0.6, 1.4, lowest), 0.02, "Pull is stronger at high tide by the tide's ratio")
			M.spell = autoload("Spellbook").get_spell("firebolt")
			near(M._power_mult(), fire_low, 0.0001, "Firebolt doesn't care")
			# Pull, for real: a wolf 12 m in front of you.
			stand(base + Vector3(0, 0.05, 0), 0, -5)
			park(w1, base + Vector3(0, 0, -12))
			w1.set_physics_process(true)
			w1.set_meta("h", w1.stats.health)
			wait = 3
		2:
			var xp: float = autoload("Skills").xp["tidecraft"]
			var mp: float = p.stats.magicka
			cast("pull")
			ok(p.stats.magicka < mp, "it costs Magicka")
			ok(autoload("Skills").xp["tidecraft"] > xp, "Tidecraft XP")
			ok(w1.state == w1.State.STAGGER, "the wolf reels")
			ok(w1.stats.health < w1.get_meta("h"), "and is hurt a little", w1.stats.health)
			wait = 40
		3:
			var d := flat(w1.global_position, p.global_position)
			between(d, 1.6, 3.2, "dragged to just in front of you")
			# Tide's Shove: a wolf in front, one behind.
			p.stats.magicka = p.stats.max_magicka
			w1.stagger(0.1)
			park(w1, base + Vector3(0, 0, -3))
			park(w2, base + Vector3(0, 0, 3))
			w2.set_physics_process(true)
			wait = 2
		4:
			cast("tides_shove")
			ok(w1.state == w1.State.STAGGER, "the one in front reels")
			wait = 30
		5:
			ok(flat(w1.global_position, p.global_position) > 8.0, "and is hurled away", flat(w1.global_position, p.global_position))
			ok(flat(w2.global_position, base + Vector3(0, 0, 3)) < 2.0, "the one behind isn't", w2.global_position - base)
			# Gravity Well: two wolves 3 m either side of a point 10 m ahead.
			p.stats.magicka = p.stats.max_magicka
			var middle := base + Vector3(0, 0, -10)
			park(w1, middle + Vector3(3, 0, 0))
			park(w2, middle + Vector3(-3, 0, 0))
			w1.stagger(3.0); w2.stagger(3.0)   # so they don't come for you meanwhile
			set_meta("middle", middle)
			stand(base + Vector3(0, 0.05, 0), 0, -9)
			wait = 2
		6:
			cast("gravity_well")
			ok(not autoload("Tidecraft")._wells.is_empty(), "a well opens")
			var well: Dictionary = autoload("Tidecraft")._wells[0]
			ok(flat(well["center"], get_meta("middle")) < 1.5, "where you aimed, on the ground", well["center"] - get_meta("middle"))
			ok(is_instance_valid(well["mark"]), "you can see it")
			near(well["left"], 6.0 * power_high, 0.3, "6 s, by the tide")
			wait = 60
		7:
			var c: Vector3 = autoload("Tidecraft")._wells[0]["center"]
			ok(flat(w1.global_position, c) < 1.2 and flat(w2.global_position, c) < 1.2, "both dragged to the middle", [flat(w1.global_position, c), flat(w2.global_position, c)])
			ok(w1.effects.active.has("pinned") and autoload("Tidecraft").in_well(w1), "and pinned there")
			autoload("Tidecraft")._wells[0]["left"] = 0.05
			wait = 3
		8:
			ok(autoload("Tidecraft")._wells.is_empty(), "then it closes")
			# Too heavy: the stone guardian has no shove().
			var guardian = load("res://enemies/stone_guardian.gd").new()
			ok(not guardian.has_method("shove"), "stone guardians can't be moved")
			guardian.free()
			# Moon-Crush on the two wolves: one at the middle, one 2.5 m out.
			p.stats.magicka = p.stats.max_magicka
			var middle: Vector3 = get_meta("middle")
			park(w1, middle); park(w2, middle + Vector3(2.5, 0, 0))
			w1.stagger(0.05); w2.stagger(0.05)
			wait = 2
		9:
			for w in [w1, w2]:
				w.stats.health = w.stats.max_health   # fresh: earlier spells wore them down
				w.set_meta("h", w.stats.health)
			cast("moon_crush")
			var lost1: float = w1.get_meta("h") - w1.stats.health
			var lost2: float = w2.get_meta("h") - w2.stats.health
			ok(lost1 > 0.0 and lost2 > 0.0, "Moon-Crush hits both", [lost1, lost2])
			ok(lost1 > lost2, "harder at the middle", [lost1, lost2])
			ok(w1.state in [w1.State.STAGGER, w1.State.DEAD], "the one at the middle is down (at high tide, likely dead)", w1.State.keys()[w1.state])
			ok(w2.state == w2.State.STAGGER, "the one further out is knocked down", w2.State.keys()[w2.state])
			ok(lost2 <= 32.0 * power_high + 0.5 and lost2 >= 32.0 * power_high * 0.5 - 0.5, "between half and all of 32, by the tide", [lost2, 32.0 * power_high])
			# The HUD says which way the tide is.
			autoload("Spellbook").select("pull")
			wait = 3
		10:
			ok(p.hud.spell_label.text.contains("tide high"), "the HUD shows the tide", p.hud.spell_label.text)
			# Aurel sells the tomes.
			autoload("Inventory").add_gold(800)
			DM.start("res://dialogue/aurel.json", "Aurel")
			ok(DM.line_label.text.contains("Tide College"), "Aurel is of the Tide College")
			pick("The Tide College. Do you teach?")
			ok(not offered("Gravity Well. (160 gold)") and offered("Gravity Well?"), "the well waits for his readings")
			var I = autoload("Inventory")
			var gold: int = I.gold
			pick("Pull. (80 gold)")
			ok(I.count("tome_pull") == 1 and I.gold == gold - 80, "Pull for 80 gold", I.gold)
			pick("Something else.")
			ok(not offered("Pull."), "sold once")
			pick("Tide's Shove.")
			ok(I.count("tome_tides_shove") == 1, "Tide's Shove")
			DM.end()
			autoload("GameState").set_flag("readings_delivered")
			DM.start("res://dialogue/aurel.json", "Aurel")
			pick("The Tide College. Do you teach?")
			ok(not offered("Moon-Crush. (220 gold)") and offered("Moon-Crush?"), "Moon-Crush waits for the well")
			pick("Gravity Well. (160 gold)")
			ok(I.count("tome_gravity_well") == 1, "after the readings: Gravity Well")
			pick("Something else.")
			pick("Moon-Crush. (220 gold)")
			ok(I.count("tome_moon_crush") == 1, "then Moon-Crush")
			DM.end()
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
