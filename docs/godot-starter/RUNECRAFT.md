# Runecraft

The seventh school, phase 3's second (`docs/CHARACTER_BUILDING.md`). It's Intellect's. It's
built to the lore bible (`docs/lore/MAGIC.md`, "Runecraft"): *the trapper and artificer.
Set rune-traps, fight from behind rune-wards, wield weapons you enchanted yourself. You plan
the battlefield before the fight starts.* The code is `systems/runecraft.gd` (the autoload
`Runecraft`).

## The spells

The tomes are Seal College primers, sold by Maren for now.

| Spell | Charge | Magicka | What it does | Tome |
|---|---|---|---|---|
| **Fire Rune** | 0.9 s | 40 | A rune on the ground where you aim (up to 15 m). When an enemy comes within 1.6 m it goes off: everything within 2.5 m takes 30 and burns | 90 gold |
| **Frost Rune** | 0.9 s | 40 | The same in frost: 24 damage, and chilled (60% speed) | 90 gold |
| **Binding Rune** | 0.9 s | 35 | Holds instead of hurting: anything within 2.5 m is rooted for 6 s | 100 gold |
| **Ward-Circle** | 1.2 s | 50 | A circle 3 m across where you stand, for 20 s. Inside it, blows do 40% less | 120 gold |
| **Enchant Weapon** | 1.0 s | 45 | A burning rune on your weapon (or fists) for 60 s: +8 a blow, and 3 in 10 set them alight | 110 gold |

- **Runes** lie for 2 minutes. You keep three at once, and a new one replaces the oldest.
- **Rune damage** scales with Runecraft and Intellect, like any spell. A rune that goes off
  trains Runecraft (2 XP + damage dealt ÷ 5), on top of the usual 1 per 5 Magicka cast.
- **What they hit:** runes go off for enemies only, never for you or your called things.

## Perks (21)

| Branch | Perks (level) |
|---|---|
| Damage | Potent Runes (15) → II (35) → III (60): +25% each → **Chain Runes** (70): a rune going off sets off any other within 4 m |
| The field | Runic Field (30): five runes → II (55): seven → **Living Runes** (100): a rune that's gone off draws itself again once, after 3 s |
| Reach | Wide Runes (40): trigger and blast 50% wider · Lasting Runes (25): twice as long on the ground · Rune Thrower (30): +50% range · Quick Scribe (25): charge 30% faster |
| Wards | **Steady Ward** (30): 60% less inside → **Ward of Renewal** (55): Health three times as fast inside |
| The blade | Keen Edge (20): the weapon rune +50% → **Searing Edge** (45): always sets them alight · Lasting Edge (35): twice as long |
| Tricks | **Ambusher's Runes** (50): double damage to anything that hadn't noticed you (a Sneak hybrid) · **Runic Snare** (45): fire and frost runes also hold for a second |
| Cost | Efficient Runecraft (20) → II (45): −20% each · Runesmith (15): Runecraft +25% XP |

New modifiers:

- `rune_damage`, `rune_radius`, `rune_lifetime`, `enchant_damage`;
- `duration_<effect id>`, which lengthens one of your own effects (Lasting Edge is
  `duration_rune_blade`), for any effect, harmful or not.

## Not yet

- The lore's **alarm rune** (it tells you when something passes) isn't in. It wants Sneak's
  enemy awareness, which now exists; it'd be a good small addition.
- **Enchanting is a spell, not an item.** Enchanted weapons and armour you keep (the
  artificer half of the lore) need Smithing (phase 4) to make sense.
- Runes are glowing discs. They need real rune art.
- One trainer: **Magister Orsa Deepcut** of the Seal College in Karrowdeep (to 60). The tomes are at
  Maren's; Grima Coldiron on Karrowdeep's Market Bridge sells two of them too.
