extends "res://tests/test_base.gd"
# Spell styles: charged Firebolt, fizzle, Frost Burst area, Healing Ward, self spells, dual-casting, tomes, Maren's shop.
var f := 0
var steps := []
var wait := 0
var p; var m; var c; var level; var I; var SB; var w; var w2
var h0 := 0.0; var h1 := 0.0; var m0 := 0.0

func add(k: int, cb: Callable) -> void: steps.append([k, cb])

func _initialize() -> void:
	level = load("res://levels/test_level.tscn").instantiate(); root.add_child(level); current_scene = level

func park() -> void:
	for i in [1, 2, 3]:
		var wolf = level.get_node("GreyfangPack/Wolf%d" % i); wolf.set_physics_process(false); wolf.global_position = Vector3(40 + i * 3, 0, 40)
		wolf.stats.max_health = 9999; wolf.stats.health = 9999; wolf.effects.clear()
	for b in level.get_node("BanditCamp").get_children(): b.set_physics_process(false)

func aim() -> void:
	p.global_position = Vector3(8, 0, -8); p.rotation.y = 0; p.head.rotation.x = deg_to_rad(-6)
	w.global_position = Vector3(8, 0, -18); w._knockback = Vector3.ZERO
	p.stats.magicka = p.stats.max_magicka

func readied(id: String) -> void:
	if not SB.knows(id): SB.learn(id)
	SB.select(id)

func choices() -> Array: return autoload("DialogueManager").choices_box.get_children().map(func(b): return b.text)

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 3:
		p = level.get_node("Player"); m = p.magic; c = p.combat; I = autoload("Inventory"); SB = autoload("Spellbook")
		park(); w = level.get_node("GreyfangPack/Wolf1"); w2 = level.get_node("GreyfangPack/Wolf2")
		p.stats.max_magicka = 400; p.stats.magicka = 400
		# Firebolt: charge, release
		add(2, func(): aim(); readied("firebolt"); h0 = w.stats.health; m0 = p.stats.magicka; Input.action_press("cast"))
		add(20, func():
			ok(m.State.keys()[m.state] == "CHARGE", "firebolt charging")
			between(m.charge, 0.4, 0.85, "charge after 20 frames")
			near(m0 - p.stats.magicka, 0.0, 0.01, "no magicka spent while charging")
			ok(p.hud.spell_label.text.begins_with("Firebolt (charge, release)"), "HUD cast hint", p.hud.spell_label.text))
		add(20, func(): near(m.charge, 1.0, 0.01, "fully charged"); Input.action_release("cast"))
		add(30, func():
			near(h0 - w.stats.health, 22.7, 1.5, "firebolt damage at 10 m")
			ok(w.effects.has("burning"), "firebolt sets the wolf burning")
			near(m0 - p.stats.magicka, 24.0, 1.0, "firebolt magicka cost"))
		# early release fizzles for free
		add(5, func(): m0 = p.stats.magicka; Input.action_press("cast"))
		add(10, func(): Input.action_release("cast"))
		add(10, func(): near(m0 - p.stats.magicka, 0.0, 0.5, "early release fizzles for free"))
		# Frost Burst on two wolves
		add(5, func():
			aim(); readied("frost_burst"); w2.global_position = Vector3(9.5, 0, -18.5); h0 = w.stats.health; h1 = w2.stats.health; m0 = p.stats.magicka
			Input.action_press("cast"))
		add(55, func(): Input.action_release("cast"))
		add(10, func():
			near(h0 - w.stats.health, 20.0, 1.5, "frost burst damage at the centre")
			near(h1 - w2.stats.health, 11.8, 1.5, "frost burst damage falls off to the side")
			ok(w.effects.has("chilled") and w2.effects.has("chilled"), "both wolves chilled")
			near(w.stats.modifier("move_speed"), 0.6, 0.01, "chilled slows to x0.6")
			near(m0 - p.stats.magicka, 38.0, 1.0, "frost burst magicka cost"))
		# Healing Ward
		add(5, func(): w2.global_position = Vector3(50, 0, 60); readied("healing_ward"); Input.action_press("cast"))
		add(20, func():
			var h = p.stats.health; m0 = p.stats.magicka
			ok(p.receive_attack(10.0, w, 5.0) == "blocked", "ward blocks a frontal attack")
			near(h - p.stats.health, 3.17, 0.4, "ward lets a little through")
			near(m0 - p.stats.magicka, 4.8, 0.6, "ward absorbs with magicka"))
		add(5, func(): Input.action_release("cast"))
		# self spells
		for sid in ["mending", "stoneflesh", "candlelight"]:
			add(10, func(): readied(sid); Input.action_press("cast"))
			add(55, func(): Input.action_release("cast"))
		add(10, func():
			for sid in ["mending", "stoneflesh", "candlelight"]:
				ok(p.effects.has(sid), "self spell %s active" % sid)
			near(p.stats.modifier("damage_taken"), 0.8, 0.01, "stoneflesh: damage taken x0.8")
			ok(m._candle.visible, "candlelight lit"))
		# dual-cast firebolt with empty hands
		add(10, func():
			I.unequip("main_hand"); aim(); readied("firebolt"); h0 = w.stats.health; m0 = p.stats.magicka
			ok(m.right_hand_free(), "unarmed: right hand free")
			ok(p.hud.spell_label.text.contains("both hands to dual-cast"), "HUD offers dual-casting", p.hud.spell_label.text)
			Input.action_press("cast"); Input.action_press("attack"); p.combat.attack_pressed())
		add(45, func():
			near(m.charge, 1.0, 0.01, "dual charge full")
			ok(m.dual and c.State.keys()[c.state] == "READY", "dual-casting, no melee swing")
			Input.action_release("cast"); Input.action_release("attack"); c.attack_released())
		add(30, func():
			near(h0 - w.stats.health, 49.1, 3.0, "dual firebolt damage (x2.2)")
			near(m0 - p.stats.magicka, 62.0, 2.0, "dual firebolt cost (x2.6)"))
		# dual stream
		add(5, func(): readied("flames"); m0 = p.stats.magicka; Input.action_press("cast"); Input.action_press("attack"))
		add(60, func():
			near(m0 - p.stats.magicka, 36.4, 1.5, "dual flames magicka for 1 s (14 x 2.6)")
			Input.action_release("cast"); Input.action_release("attack"))
		# tome
		add(10, func():
			SB.known.erase("frost_burst"); I.add("tome_frost_burst")
			var used = I.use("tome_frost_burst")
			ok(used and SB.knows("frost_burst") and I.count("tome_frost_burst") == 0, "reading a tome teaches the spell and uses it up")
			I.add("tome_frost_burst")
			ok(not I.use("tome_frost_burst"), "a tome for a known spell isn't used"))
		# shield blocks casting
		add(5, func():
			I.add("iron_sword"); I.equip("iron_sword"); I.add("wooden_shield"); I.equip("wooden_shield"); readied("healing"); Input.action_press("cast"))
		add(10, func():
			ok(not p.is_casting and c.is_blocking(), "shield: right-click blocks instead of casting")
			Input.action_release("cast"))
		# Maren's shop
		add(5, func():
			var GS = autoload("GameState"); GS.set_flag("met_maren"); I.add_gold(200)
			var dm = autoload("DialogueManager"); dm.start("res://dialogue/maren.json", "Maren")
			var labels = choices()
			var trade = labels.filter(func(t): return t.contains("trade"))
			if not ok(trade.size() == 1, "Maren offers to trade", labels):
				dm.end(); return
			dm.choose(labels.find(trade[0])))
		add(5, func():
			var ts = autoload("TradeScreen")
			ok(ts.is_open and ts.merchant == "maren", "it opens the trading screen")
			var stock: Dictionary = autoload("Trade").stock("maren")
			ok(stock.has("tome_stoneflesh") and stock.has("arrow") and stock.has("hunting_bow"), "she sells food, arrows, the bow and tomes", stock.keys())
			var g = I.gold
			var price: int = autoload("Trade").buy_price("tome_stoneflesh")
			ok(ts.buy("tome_stoneflesh"), "buy the Stoneflesh tome")
			ok(g - I.gold == price and I.count("tome_stoneflesh") == 1, "for its price", [g - I.gold, price])
			ok(not autoload("Trade").stock("maren").has("tome_stoneflesh"), "the bought tome leaves the shop")
			ts.close())
		add(5, func(): done(); quit())
	if steps.is_empty() or f < 3: return false
	wait += 1
	if wait >= steps[0][0]:
		wait = 0
		steps.pop_front()[1].call()
	return false
