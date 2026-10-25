extends "res://tests/test_base.gd"
# The attribute effects that were "later" (systems/attributes.gd): Strength sets
# how much you can carry (120 at 10, +10 a point), and over it you're
# over-encumbered: half speed, no sprinting, until you put something down;
# Willpower makes harmful effects on you wear off sooner (not on enemies); and
# each skill's governing attribute speeds up its XP (+3% a point), shown in the
# skills list; and heavy weapons without the Strength for them hit softer and
# cost more stamina.
var f := 0
var step := 0
var wait := 0
var p
var A
var I
var S

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	A = autoload("Attributes"); I = autoload("Inventory"); S = autoload("Skills")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			A.values["strength"] = 10; A.values["willpower"] = 10
			A.changed.emit()
			wait = 3
		1:
			# Carry weight.
			near(A.carry_capacity(), 120.0, 0.01, "carry 120 at Strength 10")
			ok(not p.is_over_encumbered(), "not over-encumbered to start", I.total_weight())
			var greatsword: float = I.get_item("steel_greatsword").weight
			var many := int(ceil((A.carry_capacity() - I.total_weight()) / greatsword)) + 1
			I.add("steel_greatsword", many)
			wait = 2
		2:
			ok(I.total_weight() > A.carry_capacity(), "now carrying too much", [I.total_weight(), A.carry_capacity()])
			ok(p.is_over_encumbered() and p.effects.active.has("over_encumbered"), "over-encumbered (shown as an effect)")
			near(p.stats.modifier("move_speed"), 0.5, 0.01, "half speed")
			# Try to sprint: no.
			Input.action_press("move_forward"); Input.action_press("sprint")
			p.stats.stamina = p.stats.max_stamina
			set_meta("stamina", p.stats.stamina)
			wait = 30
		3:
			ok(p.stats.stamina >= get_meta("stamina") - 0.5, "can't sprint (no stamina spent)", [get_meta("stamina"), p.stats.stamina])
			Input.action_release("move_forward"); Input.action_release("sprint")
			# Stronger: more room.
			A.increase("strength", 3)
			near(A.carry_capacity(), 150.0, 0.01, "Strength 13: carry 150")
			# Put the greatswords down.
			I.remove("steel_greatsword", I.count("steel_greatsword"))
			wait = 2
		4:
			ok(not p.is_over_encumbered() and is_equal_approx(p.stats.modifier("move_speed"), 1.0), "put them down: back to normal")
			ok(p.hud != null and str(autoload("Attributes").ATTRIBUTES["strength"]["description"]).contains("carry weight"), "Strength says so")
			# Willpower.
			p.effects.apply("burning")
			var plain: float = p.effects.active["burning"]["time_left"]
			p.effects.remove("burning")
			A.values["willpower"] = 15
			p.effects.apply("burning")
			near(p.effects.active["burning"]["time_left"], plain * 0.8, 0.01, "Willpower 15: harmful effects 20% shorter")
			p.effects.remove("burning")
			p.effects.apply("blessing")
			var blessing = load("res://effects/blessing.tres")
			near(p.effects.active["blessing"]["time_left"], blessing.duration, 0.01, "helpful ones aren't")
			var wolf = n("GreyfangPack/Wolf1")
			wolf.effects.apply("burning")
			near(wolf.effects.active["burning"]["time_left"], plain, 0.01, "and enemies don't get your Willpower")
			A.values["willpower"] = 10
			# Governing attributes.
			ok(S.SKILLS["one_handed"]["attribute"] == "strength" and S.SKILLS["tidecraft"]["attribute"] == "willpower", "every skill has an attribute")
			ok(S.SKILLS.values().all(func(s): return A.ATTRIBUTES.has(s.get("attribute", ""))), "all ten")
			near(A.skill_xp_mult("strength"), 1.09, 0.001, "Strength 13: +9% One-Handed XP")
			var before: float = S.xp["one_handed"]
			S.add_xp("one_handed", 1.0)
			var gained: float = S.xp["one_handed"] - before
			before = S.xp["archery"]
			S.add_xp("archery", 1.0)
			var plain_gain: float = S.xp["archery"] - before
			near(gained / plain_gain, 1.09, 0.001, "One-Handed learns 9% faster than Archery (Agility 10)")
			# Heavy weapons.
			A.values["strength"] = 10
			near(A.strength_needed(18.0), 14.0, 0.01, "a greatsword wants Strength 14")
			ok(A.strength_needed(9.0) == 0.0, "a sword wants nothing")
			near(A.heavy_damage_mult(18.0), 0.84, 0.001, "4 short: -16% damage")
			near(A.heavy_stamina_mult(18.0), 1.24, 0.001, "and +24% stamina")
			I.add("steel_greatsword"); I.equip("steel_greatsword")
			var heavy_cost: float = p.combat._stamina_cost(p.combat.light_attacks[0])
			A.values["strength"] = 14
			near(p.combat._stamina_cost(p.combat.light_attacks[0]), heavy_cost / 1.24, 0.01, "at Strength 14 the swing costs what it should")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
