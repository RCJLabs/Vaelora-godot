extends "res://tests/test_base.gd"
# The buy and sell screen (systems/trade.gd, ui/trade_screen.gd): Maren's "Let's
# trade." opens it and pauses the game; prices come from value and Presence
# (buying never cheaper than value, selling never dearer than buying); buying
# and selling move gold both ways and she can't pay more than her purse; quest
# items can't be sold; the bow and tomes don't come back, the rest restocks
# every 3 days; something bought before this screen existed (a flag) stays sold;
# and it all saves.
var f := 0
var step := 0
var wait := 0
var p
var T
var TS
var I
var A
var DM

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func _process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	T = autoload("Trade"); TS = autoload("TradeScreen"); I = autoload("Inventory"); A = autoload("Attributes"); DM = autoload("DialogueManager")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			wait = 5
		1:
			# Through Maren.
			autoload("GameState").set_flag("met_maren")
			DM.start("res://dialogue/maren.json", "Maren")
			var labels: Array = DM._choices.map(func(c): return c["text"])
			var i := labels.find("Let's trade.")
			ok(i >= 0, "Maren: Let's trade.", labels)
			DM.choose(i)
			wait = 3
		2:
			ok(TS.is_open and TS.merchant == "maren" and paused, "the trading screen opens, and the game pauses")
			ok(not DM.is_active, "the conversation closed")
			# Prices.
			A.values["presence"] = 12
			near(T.buy_mult(), 1.20, 0.001, "Presence 12: buy at x1.20")
			near(T.sell_mult(), 0.49, 0.001, "and sell at x0.49")
			ok(T.buy_price("bread") == 4 and T.sell_price("wolf_pelt") == 7, "bread 4, a pelt fetches 7", [T.buy_price("bread"), T.sell_price("wolf_pelt")])
			A.values["presence"] = 20
			ok(is_equal_approx(T.buy_mult(), 1.0) and is_equal_approx(T.sell_mult(), 0.65), "Presence 20: at value, and x0.65")
			A.values["presence"] = 2
			ok(T.buy_mult() <= 1.6 and T.sell_mult() >= 0.25 and T.sell_mult() < T.buy_mult(), "never worse than x1.6 / x0.25")
			A.values["presence"] = 12
			# Buying.
			I.add_gold(500)
			var gold: int = I.gold
			var purse: int = T.gold("maren")
			var bread: int = T.stock("maren")["bread"]
			ok(TS.buy("bread"), "buy bread")
			ok(I.gold == gold - 4 and I.count("bread") >= 1 and T.stock("maren")["bread"] == bread - 1 and T.gold("maren") == purse + 4, "gold to her, bread to you")
			ok(TS.buy("hunting_bow") and I.count("hunting_bow") == 1, "buy the bow")
			ok(not T.stock("maren").has("hunting_bow") and autoload("GameState").has_flag("bought_maren_bow"), "it's gone (and the old flag is set)")
			# Selling.
			I.add("iron_sword")
			gold = I.gold
			ok(TS.sell("iron_sword") and I.gold == gold + T.sell_price("iron_sword"), "sell a sword")
			I.add("rune_glass")
			ok(not TS.sell("rune_glass") and I.count("rune_glass") == 1, "a quest item can't be sold")
			ok(T.why_not_sell("maren", "rune_glass").contains("keep"), "and it says why")
			# Her purse.
			T._gold["maren"] = 3
			I.add("iron_axe")
			ok(not TS.sell("iron_axe") and T.why_not_sell("maren", "iron_axe").contains("can't afford"), "she can't pay more than she has")
			# You can't either.
			I.add_gold(-I.gold)
			ok(not TS.buy("bread") and T.why_not_buy("maren", "bread").contains("afford"), "nor can you")
			I.add_gold(100)
			# Three days on: restocked, but not the bow.
			autoload("WorldClock").day += 3
			ok(T.gold("maren") == 250 and T.stock("maren")["bread"] >= 8, "restocked after 3 days")
			ok(not T.stock("maren").has("hunting_bow"), "the bow doesn't come back")
			# Saved.
			var data: Dictionary = T.to_dict()
			T.reset()
			T.from_dict(data)
			ok(not T.stock("maren").has("hunting_bow") and T.gold("maren") == 250, "saved and loaded")
			# Bought before this screen existed.
			T.reset()
			autoload("GameState").set_flag("bought_tome_candlelight")
			ok(not T.stock("maren").has("tome_candlelight") and T.stock("maren").has("tome_stoneflesh"), "an old save's bought tome stays sold")
			TS.close()
			wait = 2
		3:
			ok(not TS.is_open and not paused, "closed: the game goes on")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
