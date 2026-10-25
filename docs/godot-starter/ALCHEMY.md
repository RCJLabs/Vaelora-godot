# Alchemy

The first of phase 4, making things (`docs/CHARACTER_BUILDING.md`). It's Intellect's. The
lore bible says nothing about alchemy, so this is my design: Skyrim's shared-effect rule,
simplified to nine effects you can see. The rules are `systems/alchemy.gd` (the autoload
`Alchemy`); the screen is `ui/alchemy_screen.gd` (`AlchemyScreen`).

## How it works

- **Brewing:** use a **mortar and pestle** from your pack (Maren sells one for about 30 gold),
  wherever you are. Pick two or three ingredients. Every effect at least two of them share
  becomes a potion, and you use up one of each.
- **Strength:** weak below Alchemy 40, standard from 40, strong from 75 (Purity: a step
  stronger). Each strength is its own item (`potion_<effect>_<0-2>`): ×1, ×1.6 and ×2.4.
- **XP:** 6 per potion, times its strength (1 to 3).
- **Effects are shown.** Choosing an ingredient lists its effects (tooltip and preview), and
  the screen says what the mix will make before you brew. Nothing to discover by trial yet.

| Effect | Potion | Weak (×1) |
|---|---|---|
| restore_health | Healing | +40 Health |
| restore_stamina | Vigour | +40 Stamina |
| restore_magicka | Clarity | +40 Magicka |
| regeneration | Regeneration | Health comes back 3× as fast, 45 s |
| swiftness | Swiftness | Move 20% faster, 45 s |
| might | Might | Blows do 20% more, 45 s |
| resist | Resistance | Blows do 20% less to you, 45 s |
| cure | Cure | Ends every harmful effect on you |
| poison | Poison | Coats your weapon: 3 hits, each puts 1 dose of **venom** in what it strikes |

**Venom** (`effects/venom.tres`) does 3 a second for 10 s per dose and slows a little. Doses
stack to 5. A standard poison is 5 hits of 2 doses; a strong one is 7 hits of 3. It's melee
only: arrows and spells aren't coated.

## Ingredients

| Ingredient | Effects | Where |
|---|---|---|
| Mountain Flower | Healing, Swiftness, Resistance | Maren |
| Red Cap | Healing, Poison, Might | Maren |
| Blue Moss | Clarity, Regeneration, Cure | Maren |
| River Reed | Vigour, Swiftness, Cure | Maren |
| Lantern Moth Wing | Clarity, Cure, Swiftness | Maren (two) |
| Nightshade | Poison, Clarity, Might | The Barrow, on the floor by the cult's worktable |
| Grave Dust | Regeneration, Poison, Resistance | The Barrow, the other side of the worktable |
| Wolf Fang | Might, Resistance, Vigour | Skinning a wolf |
| Apple | Healing, Vigour, Regeneration | Already in the game |

Some pairs to start with:

- Mountain Flower + Red Cap: Healing.
- River Reed + Lantern Moth Wing: Swiftness and Cure.
- Red Cap + Nightshade + Wolf Fang: Might and Poison.

## Perks (21)

| Branch | Perks (level) |
|---|---|
| Potency | Alchemist (15) → II (30) → III (45) → IV (60) → V (80): +15% each · **Purity** (70, after III): brew a step stronger → **Master Brewer** (90): two of each |
| Healing | Physician (25): restoring +25% → Benefactor (35): timed potions +50% longer · **Field Medic** (50): Healing also cures → **Hardened Stomach** (60): below a quarter Health, potions +50% |
| Poison | Poisoner (30): +2 hits → **Potent Poisons** (50): +1 dose a hit → **Concentrated Poison** (65): poisoned hits also bring bad luck (+20% damage, 10 s) · Snakeblood (40): poison on you lasts half as long |
| Gathering | **Green Thumb** (20): two of every ingredient you pick up or skin → Herb-Wise (20): ingredients 25% cheaper |
| Brewing | **Experimenter** (55): three ingredients give one more potion → **Efficient Brewer** (45): one in four ingredients isn't used up |
| — | Steady Hand (25): any potion also gives 10 Stamina · Herbalist (15): Alchemy +25% XP |

New modifiers: `potion_potency`, `restore_potency`, `potion_duration` and `ingredient_price`.
Snakeblood uses the generic `duration_poisoned`. It works against dart traps and raw meat;
nothing poisons you with venom yet.

## Not yet

- **Gathering in the world** came with the Survival skill: forage plants grow mountain
  flowers, red caps, blue moss, river reeds and apples around the test level (SURVIVAL.md).
  Green Thumb doubles those too. Nightshade and grave dust are still only in the Barrow.
- **Unknown effects.** Skyrim hides an ingredient's effects until you taste it or brew with it.
  Here they're all shown. Hiding them would make Alchemy more about discovery.
- **No alchemist trainer or skill book.**
- **Old potions:** the Minor Healing Potion you start with is a plain consumable, not part of
  this system.
- **Venom on the player:** no enemy uses venom yet, so Snakeblood only covers `poisoned`.
- **Money:** at base prices a weak potion sells for less than its ingredients cost; strong
  potions (75+), Master Brewer and Experimenter make brewing for sale profitable. Like Skyrim,
  on purpose for now; a merchant cap on potions bought would rein it in.
