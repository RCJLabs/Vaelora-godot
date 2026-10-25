extends "res://tests/test_base.gd"
# Glamour (systems/glamour.gd, glamour/decoy.gd): Zora teaches it (three tomes);
# Mirror Image, cast for real, puts a decoy on the ground where you aim, and a
# hunting wolf goes for it instead of you until three bites break it; Fear sends
# a wolf and a bandit running and then they come back; Charm turns a wolf on its
# packmate and its packmate on it, until it wears off. The hollow wolf and wisps
# can't be glamoured.
var f := 0
var step := 0
var wait := 0
var p
var GS
var DM
var G
var w1
var w2
var base := Vector3.ZERO
var decoy
var decoy_hits := []
var watch := 0

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

func heal() -> void:
	p.stats.health = p.stats.max_health

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	GS = autoload("GameState"); DM = autoload("DialogueManager"); G = autoload("Glamour")
	match step:
		0:
			n("GreyfangPack").can_break = false
			w1 = n("GreyfangPack/Wolf1"); w2 = n("GreyfangPack/Wolf2")
			base = w1.global_position
			park(w1, base, false)
			park(w2, base + Vector3(60, 0, 0), false)
			park(n("GreyfangPack/Wolf3"), base + Vector3(80, 0, 0), false)
			wait = 5
		1:
			var S = autoload("Skills")
			ok(S.SKILLS.has("glamour") and S.SKILLS["glamour"]["name"] == "Glamour", "Glamour is a skill")
			# Zora teaches it.
			GS.set_flag("met_zora")
			DM.start("res://dialogue/zora.json", "Zora")
			pick("What do you really do?")
			pick("And?")
			pick("I won't.")
			DM.end()
			var I = autoload("Inventory")
			for id in ["mirror_image", "fear", "charm"]:
				ok(I.count("tome_" + id) == 1, "Zora gives the %s tome" % id)
				I.use("tome_" + id)
				ok(autoload("Spellbook").knows(id), "and it teaches " + id)
			DM.start("res://dialogue/zora.json", "Zora")
			ok(not DM._choices.any(func(c): return c["text"].begins_with("What do you really do?")), "only once")
			DM.end()
			# Mirror Image, cast for real: aim at the ground 6 m ahead (towards the wolf).
			autoload("Spellbook").select("mirror_image")
			p.global_position = base + Vector3(0, 0.05, 12)
			p.velocity = Vector3.ZERO
			p.rotation.y = 0.0
			p.get_node("Head").rotation.x = deg_to_rad(-15)
			p.stats.magicka = p.stats.max_magicka
			Input.action_press("cast")
			wait = 60
		2:
			Input.action_release("cast")
			wait = 5
		3:
			var decoys := get_nodes_in_group("decoy")
			ok(decoys.size() == 1, "Mirror Image makes a decoy", decoys.size())
			ok(p.stats.magicka < p.stats.max_magicka - 20.0, "for Magicka", p.stats.magicka)
			ok(autoload("Skills").xp["glamour"] > 0.0, "and Glamour XP")
			decoy = decoys[0] if decoys.size() > 0 else null
			if decoy:
				var ahead: Vector3 = decoy.global_position - p.global_position
				between(-ahead.z, 3.0, 9.0, "where you aimed, ahead of you")
				between(decoy.global_position.y, base.y - 1.0, base.y + 1.0, "on the ground")
			# The wolf, hunting: it goes for the decoy.
			heal()
			w1.set_physics_process(true)
			w1.join_hunt()
			ok(G.target_for(w1, p) == decoy, "a hunting wolf goes for the decoy")
			watch = 0
			step += 1
			return false
		4:
			# Until the decoy breaks (three bites) or 9 s pass.
			watch += 1
			if is_instance_valid(decoy) and decoy.is_in_group("decoy") and watch < 540:
				if not decoy.hits_left in decoy_hits: decoy_hits.append(decoy.hits_left)
				return false
			ok(not is_instance_valid(decoy) or not decoy.is_in_group("decoy"), "the decoy breaks", watch)
			ok(decoy_hits.has(1) and watch < 540, "after three bites, before its time is up", [decoy_hits, watch])
			ok(p.stats.health == p.stats.max_health, "and the wolf never touched you", p.stats.health)
			ok(G.target_for(w1, p) == p, "then it comes for you")
		5:
			# Fear: runs, then comes back (2 s, not gone for good like a broken pack).
			heal()
			G.cast(autoload("Spellbook").get_spell("fear"), w1.global_position, 0.25, p)
			ok(w1.state == w1.State.FLEE, "Fear sends the wolf running")
			w1.set_meta("d0", w1.global_position.distance_to(p.global_position))
			wait = 60
		6:
			ok(w1.global_position.distance_to(p.global_position) > w1.get_meta("d0"), "away from you")
			wait = 90
		7:
			ok(is_instance_valid(w1) and w1.state != w1.State.FLEE and w1.state != w1.State.DEAD, "and comes back when it wears off", w1.State.keys()[w1.state])
			# Charm: Wolf2 beside Wolf1, both hunting you.
			park(w2, w1.global_position + Vector3(3, 0, 0), true)
			w2.home = base
			w2.join_hunt()
			wait = 2   # so the physics server knows where it is now
		8:
			heal()
			G.cast(autoload("Spellbook").get_spell("charm"), w2.global_position, 1.0, p)
			ok(G.is_charmed(w2) and not G.is_charmed(w1), "Charm takes the one you aimed at")
			ok(w2.get_node_or_null("CharmMark") != null, "marked with a light")
			ok(G.target_for(w2, p) == w1, "the charmed wolf goes for its packmate")
			ok(G.target_for(w1, p) == w2, "and its packmate turns on it")
			w1.set_meta("h", w1.stats.health)
			wait = 240
		9:
			ok(w1.stats.health < w1.get_meta("h"), "the charmed wolf bites its packmate", [w1.get_meta("h"), w1.stats.health])
			ok(p.stats.health == p.stats.max_health, "and nobody bites you", p.stats.health)
			G._spells[w2]["left"] = 0.01   # skip to the end of the charm
			wait = 3
		10:
			ok(not G.is_charmed(w2) and w2.get_node_or_null("CharmMark") == null, "the charm wears off")
			ok(G.target_for(w2, p) == p, "and it remembers whose side it's on")
			# A bandit can be frightened too.
			var bandit = n("BanditCamp/Bandit1")
			ok(G.susceptible(bandit), "bandits can be glamoured")
			bandit.frighten(1.0)
			ok(bandit.state == bandit.State.FLEE, "Fear: the bandit runs")
			# Some things can't be fooled.
			ok(not G.susceptible(n("HollowWolf")), "not the hollow wolf")
			var others: Array = get_nodes_in_group("enemy").filter(func(e): return e.has_method("absorb") or e.get_script().resource_path.ends_with("wisp.gd"))
			ok(others.is_empty() or not G.susceptible(others[0]), "nor wisps")
			for w in [w1, w2]: w.set_physics_process(false)
			wait = 90
		11:
			var bandit = n("BanditCamp/Bandit1")
			ok(bandit.state != bandit.State.FLEE, "and comes back", bandit.State.keys()[bandit.state])
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
