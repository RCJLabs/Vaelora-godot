# Smithing

Phase 4's second skill (`docs/CHARACTER_BUILDING.md`). It's Strength's. The lore bible has
forge-towns in the Iron Moors and Deepfolk master crafters, but no rules for smithing, so
this is my design. The rules are `systems/smithing.gd` (the autoload `Smithing`); the screen
is `ui/smithing_screen.gd` (`SmithingScreen`); the forge is `props/forge.gd`.

## Where

- **The forge** by Maren's (east of Aurel) opens the smithing screen. It also warms you, for
  Survival's cold.
- **A smith's hammer** (Maren, 25 gold) opens the screen anywhere, but only for improving, and
  only with the Field Smith perk.

The screen has three tabs: **Forge**, **Improve** and, with the perk, **Salvage**.

## Forging

Recipes make items that are already in the game; there are no new weapon models yet.

| Makes | Needs | Notes |
|---|---|---|
| Leather Strip ×3 | 1 Wolf Pelt | |
| Steel Ingot | 2 Iron Ingots | Steel Smithing |
| Hunting Dagger | 1 Iron Ingot, 1 Leather Strip | |
| Iron Sword, Iron Axe | 2 Iron Ingots, 1 Leather Strip | |
| Iron Mace | 3 Iron Ingots | |
| Steel Greatsword | 3 Steel Ingots, 2 Leather Strips | Steel Smithing |
| Hunting Bow | 2 Seasoned Wood, 1 Leather Strip | |
| Arrows ×12 | 1 Seasoned Wood, 1 Iron Ingot | Arrowsmith: ×24 |
| Wooden Shield | 2 Seasoned Wood, 1 Iron Ingot | |
| Iron Helmet / Gauntlets / Boots / Cuirass | 2 / 1+1 strip / 2+1 strip / 4+2 strips | |
| Leather Cap / Gloves / Boots / Cuirass | 1 pelt+1 strip / 1 pelt / 1 pelt+1 strip / 2 pelts+2 strips | |

Maren sells iron ingots (10), seasoned wood (6) and leather strips (6). Pelts come from wolves.
XP: 2 plus a tenth of what you made is worth.

## Improving

- **Quality:** Fine, Superior, Exquisite, Flawless, Epic, Legendary.
- **Cost:** each step uses one of what the item is made of (`ItemData.material`). Iron takes an
  iron ingot, steel a steel ingot, leather a leather strip, wood (bows, the shield) seasoned
  wood. Steel needs Steel Smithing.
- **Cap:** Fine at the start, then one step more every 25 levels (Superior at 25, Exquisite at
  50, Flawless at 75, Epic at 100). Master Smith I–III add a step each; Deep-Forged adds one
  for steel.
- **What a step does:** weapons +4% damage (bows and shield bashes too). Shields let 4% less
  through when blocking. Armour +4%, before Light/Heavy Armour's own bonus. A material perk
  doubles it; Weaponsmith or Armourer adds half again; Legendary Touch a quarter.
- **XP:** 3 plus a twentieth of the item's value.
- **The name shows it:** "Iron Sword (Fine)" in the inventory and the screen.

### Quality is per item, not per copy

The inventory counts items (`iron_sword: 2`), it doesn't track copies. So quality belongs to
the item id: improve one iron sword and every iron sword you carry is Fine. When the last copy
leaves your pack (sold, dropped, broken down), the quality is forgotten. That stops "improve,
sell, buy back". Real per-copy quality needs the inventory to hold instances, which is a
bigger change.

## Perks (21)

| Branch | Perks (level) |
|---|---|
| Materials | Ironwright (15) → **Steel Smithing** (30): forge and improve steel, ×2 for steel → **Deep-Forged** (65): steel one step higher · Leatherworker (15) · Bowyer (20) → Arrowsmith (25): twice the arrows |
| Mastery | Master Smith (25) → II (50) → III (75): a step higher each → **Legendary Touch** (90): every step +25% |
| Weapons | Weaponsmith (30): +50% → **Balanced Blades** (45): improved weapons cost 15% less Stamina · **Heavy Hand** (60): improved weapons stagger 25% more |
| Armour | Armourer (30): +50% → **Close-Fitted** (50): +5 armour per improved piece you wear |
| Thrift | Thrifty Smith (25): one less of the biggest material → Careful Hands (40): one in four improvements is free · **Salvage** (35): break things down for half their materials |
| — | **Field Smith** (50): improve anywhere with the hammer · **Masterwork** (55): what you forge comes out Fine · Forge-Sense (15): Smithing +25% XP |

## Not yet

- **Mining and smelting.** No ore in the world: ingots come from Maren.
- **New items.** Forging only makes what already exists. Steel armour, orcish and Deepfolk
  gear need models and stats.
- **Enchanting** isn't Smithing's: Runecraft's Enchant Weapon is a timed spell.
- **No smith NPC or trainer.** The forge stands alone for now.
- **Selling improved things** isn't worth more. Improving adds no sale value, so there's no
  money loop in it.
