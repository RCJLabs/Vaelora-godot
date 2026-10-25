# Sight

The eighth school, phase 3's third (`docs/CHARACTER_BUILDING.md`). It's Presence's. It's
built to the lore bible (`docs/lore/MAGIC.md`, "Sight"): *the duellist-seer. See attacks a
moment before they come, mark weak points for huge hits, see through walls, and curse
enemies with bad luck.* The code is `systems/sight.gd` (the autoload `Sight`). The aimed
spells go through it; the self spells are plain status effects that combat reads.

## The spells

Each tome is a Glass College primer, sold by Maren for now.

| Spell | Kind | Magicka | What it does | Tome |
|---|---|---|---|---|
| **Weak Point** | aimed, 0.7 s | 30 | The enemy nearest your aim (up to 25 m) takes 50% more damage for 10 s | 80 gold |
| **Ill Fortune** | aimed, 0.8 s | 35 | The enemy nearest your aim is cursed for 15 s: a third of its blows at you go astray, and it stumbles (85% speed) | 90 gold |
| **Foresight** | self, 0.8 s | 40 | 8 s: the parry window is three times as long, and dodges stay untouchable twice as long | 100 gold |
| **True Sight** | self, 1.0 s | 35 | 30 s: every enemy within 40 m wears a gold ◆, seen through walls and hills | 90 gold |
| **Moment of Clarity** | self, 2.0 s | 120 | The mastery: 6 s in which nothing lands on you and your blows do double | 400 gold |

- **Foresight isn't slowed time.** The lore's "slowed time for perfect dodges and parries" would
  fight the game's hit-stop, which already uses `Engine.time_scale`. Foresight gives you the
  windows instead. Real slow time needs one owner of the time scale first.
- **"A blow goes astray"** means it misses: the attacker is told "dodged", so there's no damage
  and no bleed. It's checked before dodges, blocks and wards.
- **Durations:** Sight levels lengthen Weak Point and Ill Fortune (+1% per level, like any
  spell's power). The self spells last their set time unless a perk changes it.

## Perks (21)

| Branch | Perks (level) |
|---|---|
| Foresight | Long Foresight (25) → II (50): +50% each · **Counterseer** (40): during Foresight, every parry gives 20 Magicka → **Read the Fight** (55): during Foresight, your blows do 25% more |
| The mark | **Exposed** (30): a marked enemy takes double → **Marked for Death** (60): killing one while it's marked heals you 25 · Lasting Mark (25): twice as long |
| Bad luck | **Jinx** (40): half its blows go astray → **Spreading Misfortune** (65): curses everything within 4 m of the target · **Bad Omen** (45): cursed enemies take 20% more |
| True Sight | Wide Eyes (35): 70 m → **Hunter's Eye** (50): the ◆ shows each enemy's health · Long Sight (25): twice as long |
| Seeing ahead | **Prescience** (75): one blow in ten that would hit you goes astray, always on → Moment Extended (90): Moment of Clarity twice as long |
| Craft | Far Sight (20): +50% range → Quick Sight (25): charge 30% faster · Efficient Sight (20) → II (45): −20% each · Clear Mind (30): +20 max Magicka · Seer-Born (15): Sight +25% XP |

New modifiers: `mark_duration` and `true_sight_range`. The rest use the generic
`duration_<effect>`, `spell_range_<skill>` and `charge_time_<skill>`.

## Not yet

- Seeing **invisible** things: nothing in the game turns invisible yet but you.
- A real time-slow (see above).
- The ◆ is a text glyph, and True Sight doesn't put enemies on the compass. Both are easy to
  improve.
- No trainer: the tomes are at Maren's. The Glass College is on the Glass Coast, far off.
