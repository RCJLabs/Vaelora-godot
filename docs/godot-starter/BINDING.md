# Binding

The sixth school, and the first of phase 3 (`docs/CHARACTER_BUILDING.md`). It's Willpower's.
It's built to the lore bible (`docs/lore/MAGIC.md`, "Binding"): *calling things and holding
them: summoning, binding, raising.* The code is `systems/binding.gd` (the autoload
`Binding`); `player_magic.gd` casts it like Glamour and Tidecraft.

## The spells

All four are area spells: charge, then release where you're aiming. Each tome is a Bell
College primer, sold by Maren for now (the Bell College is in the Iron Moors, a long way
off).

| Spell | What it does |
|---|---|
| **Call Wolf-Spirit** | A wolf-spirit, pale and glowing, fights for you for 60 s |
| **Bind** | The enemy nearest your aim is rooted for 6 s. It can still bite or swing at whoever's in reach |
| **Summon Guardian** | A stone echo of an old guardian: 160 Health, slow, hits for 16, for 45 s |
| **Raise the Dead** | The nearest dead wolf or bandit gets up and fights for you for 40 s, then lies back down where it was |

Binding levels make all of them last longer (+1% per level, like Glamour).

## How called things behave

- **They fight for you** using Glamour's charm: each goes for the nearest enemy Glamour works on
  (wolves and bandit-kind). They leave wisps, the stone guardian and The First alone.
- **Enemies fight back.** Targeting counts them like companions, so a wolf goes for whichever
  is nearer, you or your wolf-spirit.
- **With nothing to fight, they follow you.** Their "home" is at your heels; one that falls
  more than 6 m behind runs to catch up.
- **One at a time.** Calling another sends the oldest back (Twin Souls: two; Host of Echoes:
  three).
- **They're gone when their time is up, or a moment after they fall.** No body, so no pelt
  or purse to take. They aren't saved, and a raised corpse lies back down.
- **Your swings pass through them, and a stray arrow doesn't turn them.** Spell bursts can
  still hurt them.
- **🔒 The horror** (lore): what you call are echoes of Vael-creatures that remember their
  masters. At corruption Stained or worse, one in three now and then looks at you "a moment
  too long, as if it knows what you are." That's a notice only, so far.

## Perks (21)

| Branch | Perks (level) |
|---|---|
| Cost | Efficient Binding (20) → II (45): −20% each |
| Time | Lasting Bonds (25) → II (50) → III (75): called things and the raised last 50% longer each |
| Strength | Strong Echoes (30) → II (55) → III (80): +30% Health each · Fierce Echoes (40): they hit 30% harder |
| Numbers | **Twin Souls** (60): two at once → **Host of Echoes** (100): three · **Spirit Pack** (55): Call Wolf-Spirit calls two wolves (counting as one) |
| Holding | Firm Hold (20): Bind lasts 50% longer → **Binding Circle** (40): Bind holds everything within 3 m of its target |
| The dead | Grave Calling (35): the raised stay twice as long → Deathless (65): they rise with 50% more Health |
| Craft | Long Reach (25): +50% range → Called Swiftly (35): charge 30% faster → Oath of the Bell (85): a third cheaper again, and faster still |
| — | **Soul Tether** (45): when a called thing falls, a quarter of its Magicka comes back · Bell-Sworn (15): Binding +25% XP |

New modifier names: `summon_duration`, `summon_health`, `summon_damage`, `bind_duration`,
`raise_duration`, `raise_health`, and two that work for any school: `spell_range_<skill>`
and `charge_time_<skill>`.

## Not yet

- The wolf-spirit is a recoloured wolf, and the stone echo a bandit with grey cloth, bigger
  and slower. Both need their own models.
- No commands: you can't tell a called thing to wait or to attack a particular enemy.
- The Bell College's oath ("a summoned thing must be bound by oath") isn't a mechanic yet. A
  natural one: summons that turn on you at high corruption.
- Raise the Dead works on wolves and bandit-kind only. A raised cultist or inquisitor comes
  back as a plain bandit.
- No trainer. The tomes are all at Maren's; the higher two would be better found than bought.
