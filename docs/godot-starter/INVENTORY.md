# Inventory, Gold & Loot

Press **Tab** → **Inventory** tab: your gold, your items, and a description of the selected
item. Potions get a **Drink** button. The game is paused while the menu is open, so you can
drink mid-fight like in Skyrim.

## Where items come from right now

| | How |
|---|---|
| Minor Healing Potion | On top of the stone block near spawn. Maren also gives one as a quest reward |
| 20 gold | Coin purse on the stone circle's altar |
| Wolf Pelt | Look at a dead wolf and press **E** ("Skin wolf") |
| 50 gold | Maren's reward for the Greyfang quest |
| 15 gold each | Sell pelts to Maren ("I have a wolf pelt to sell") |

Pickups stay gone once taken, even after loading, because each one sets a `taken:...` flag.

## Trading

Maren's **"Let's trade."** opens the buy and sell screen (`ui/trade_screen.gd`, autoload
**TradeScreen**; the rules are `systems/trade.gd`, autoload **Trade**). Her goods on the left,
yours on the right; click a row (or A / Enter) to buy or sell one, Esc to leave. The game
pauses while it's open.

- **Prices** come from an item's **Value** and your **Presence**: you buy at ×1.25 (2.5% less
  per point above 10, never under ×1.0) and sell at ×0.45 (2% more per point, never over ×0.7).
  The top line shows both. Speech will add to it once it exists.
- **Her purse:** Maren has 250 gold and can't pay more than she has.
- **Restocking:** every 3 days her stock and purse come back. The bow on her wall and the tomes
  are one of a kind: once bought, gone.
- **Can't sell:** quest items (**Quest Item** ticked in the item: the rune-glass, letters and
  notes, the Riverwatch Roll, wisp essences...) show "keep"; worthless things show "worthless".
- Her **pelt deal** ("I have a wolf pelt to sell", full value) and Aurel's Tidecraft lessons
  stay in dialogue.
- **Adding a merchant:** an entry in `MERCHANTS` in `systems/trade.gd` (name, gold, stock,
  unique items), and a dialogue choice with `"open_trade": "<id>", "next": "end"`.
- Saved with the game (the "trade" section); older saves start with full stock, except what
  was bought through the old dialogue shop (its flags are honoured).

## Adding a new item (no code)

1. In FileSystem, right-click `items/wolf_pelt.tres` → **Duplicate** → e.g. `iron_ore.tres`.
2. Double-click it. In the Inspector set **Id** (`iron_ore`, never change it later), **Display
   Name**, **Description**, **Value**. For a potion, set **Type** to Consumable and fill in the
   *Restore* numbers.
3. Add its path to `ITEM_FILES` at the top of `systems/inventory.gd`.

## Putting an item in the world

1. Duplicate the `Potion` node in `test_level.tscn` (Ctrl+D) and move it.
2. Inspector: **Item Id** = the item's id, **Item Count**, optionally **Gold** and **Label**.
3. Keep **Collision → Layer** on 4 "loot" only. The player walks through it, and the E ray
   still finds it.

## In dialogue

See DIALOGUE.md: `give_item`, `take_item`, `give_gold`, `take_gold`, and the conditions
`requires_item` and `requires_gold`. Maren's pelt trade is a working example.

## From code

```gdscript
Inventory.add("wolf_pelt")            # or add("wolf_pelt", 3)
Inventory.remove("wolf_pelt")         # false if you don't have enough
Inventory.count("wolf_pelt")
Inventory.add_gold(10)
Inventory.use("minor_healing_potion")
```

## Known limits

- No dropping items. Carry weight is in FOUNDATIONS.md.
- Only Maren trades so far; there's no haggling (Speech) yet.
- Saved with the game (save version 3; older saves load with an empty inventory).
