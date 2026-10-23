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

- No weight/encumbrance, no dropping items, no equipment slots (the sword is fixed).
- No buy menu: trading is dialogue-only for now.
- Saved with the game (save version 3; older saves load with an empty inventory).
