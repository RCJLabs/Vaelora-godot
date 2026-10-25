# Magic

**Hold right-click** to cast the spell in your left hand. **Q** cycles the left hand
through Block → each known spell → Block, and clicking a spell in **Tab → Magic** readies it.
The ready spell and how to cast it sit above the Magicka bar ("Firebolt (charge, release)").
You can't cast mid-swing or while blocking, nor while a shield, two-handed weapon or bow
takes your left hand.

## How spells are cast (styles)

| Style | How | Examples |
|---|---|---|
| **Stream** | Hold. Drains Magicka every second you hold | Flames, Healing |
| **Bolt** | Hold to **charge**, release to throw a projectile | Firebolt |
| **Area** | Hold to charge, release: a **burst where you're aiming** (up to 15 m) that hits everything in its radius, full damage at the centre down to half at the edge | Frost Burst |
| **Ward** | Hold: a barrier that stops part of every hit **from the front** (75°), paying Magicka for what it stops (0.8 per point) | Healing Ward |
| **Self** | Hold to charge, release: a status effect on you | Mending, Stoneflesh, Candlelight |

Charged spells only go off **fully charged** (the crosshair grows and the hand glows brighter
as they charge). Release early and the spell fizzles, which costs nothing. You can't start a
charge you can't afford: the Magicka bar blinks.

### Dual-casting
With **no weapon in your right hand** (unequip it in Tab → Inventory), left-click casts the
ready spell too, from a second hand. **Hold both buttons** to dual-cast:
- **×2.2 power for ×2.6 Magicka**: streams hit harder, bolts are bigger and stronger, bursts
  are 30% wider, and a dual ward stops 84% instead of 60%.
- For charged spells, hold both once the charge is full, then release.
- Self spells don't dual-cast (`can_dual_cast` is off on them).

With a weapon in your right hand, left-click attacks as usual and you cast one-handed. Sword in
the right hand and Flames in the left is the classic spellsword.

## The spells

| Spell | School | Style | Cost | Effect | Where |
|---|---|---|---|---|---|
| Healing | Restoration | Stream | 10/s | Heals you 12/s | Everyone starts with it |
| Flames | Destruction | Stream | 14/s | 16 damage/s in a 6 m stream, leaves Burning | Elves and Scholars start with it; others touch the stone-circle crystal |
| Firebolt | Destruction | Bolt, 0.55 s | 24 | 22 damage + Burning on whatever it hits | Scholars start with it; the bandit camp chest |
| Frost Burst | Destruction | Area, 0.8 s | 38 | 18 damage in 3 m + **Chilled** (60% speed, slow Stamina, 4 s) | Tome on the Bandit Leader |
| Healing Ward | Restoration | Ward | 6/s + 0.8 per point stopped | Stops 60% of a hit from the front | Acolytes start with it; Maren sells the tome (60 gold) |
| Mending | Restoration | Self, 0.5 s | 30 | +5 Health/s for 10 s | Acolytes start with it; tome in the waystation cellar chest |
| Stoneflesh | Alteration | Self, 0.7 s | 45 | 20% less damage taken for 60 s | Maren sells the tome (60 gold) |
| Candlelight | Alteration | Self, 0.4 s | 15 | A light floats above you for 3 minutes | Scholars start with it; Maren sells the tome (25 gold) |
| Mirror Image | Glamour | Area, 0.7 s | 30 | A decoy of you where you aim (up to 20 m). Enemies within 18 m of it go for it instead, until 3 hits or 12 s | Zora ("What do you really do?") |
| Fear | Glamour | Area, 0.9 s | 40 | Enemies within 5 m of where you aim run from you for 8 s, then come back | Zora, after Mirror Image |
| Charm | Glamour | Area, 1.0 s | 45 | The enemy nearest where you aim (within 2 m) fights for you for 15 s; its packmates within 10 m turn on it. Hitting it yourself breaks the charm | Zora, after Fear |
| Frenzy | Glamour | Area, 0.9 s | 40 | The enemy nearest where you aim attacks whoever's nearest for 12 s, its own pack included (you, if nobody else is near); its packmates turn on it. Your hits don't break it | Zora's second lesson ("Teach me more of it.") |
| Invisibility | Glamour | Self, 0.8 s | 50 | For 20 s wolves and bandits lose you: they head home, or go for your companion. Attacking or casting ends it. Wisps see through it | Zora's second lesson |
| Pull | Tidecraft | Area, 0.7 s | 30 | The enemy nearest where you aim (up to 20 m, within 2 m of the aim) is dragged to 2.2 m in front of you, takes 6, and reels for 1.2 s | Aurel, 80 gold |
| Tide's Shove | Tidecraft | Area, 0.6 s | 32 | Everything within 7 m and 70° of where you face takes 10, is thrown about 8 m away, and reels for 1.5 s | Aurel, 100 gold |
| Gravity Well | Tidecraft | Area, 1.0 s | 55 | A well on the ground where you aim (up to 18 m) drags everything within 4 m to its middle and pins it (30% speed) for 6 s. No damage | Aurel, 160 gold, after his readings |
| Moon-Crush | Tidecraft | Area, 1.2 s | 60 | Where you aim (up to 18 m, on the ground), everything within 3 m takes 32 at the middle down to 16 at the edge and is knocked down for 2.5 s. Hits what's too heavy to move, too | Aurel, 220 gold, after Gravity Well |
| The Lifting Tide | Tidecraft (mastery) | Area, 1.6 s | 90 | Where you aim (up to 20 m), everything within 6 m that can be moved rises 3 m and hangs there helpless for 4 s, then falls and takes 18 from the landing | Aurel, 400 gold, after Moon-Crush, at Tidecraft 50 |

**Spell tomes** are items. Use one from Tab → Inventory to learn its spell (the tome is
used up). Maren's tomes are under "Let's trade."

### Glamour (the fourth school)

Glamour changes what minds see. It rarely deals damage itself: your enemies do it to each
other. Four of its spells are **Area** spells whose `glamour` field (`decoy`, `fear`, `charm`,
`frenzy`) replaces the damage; Invisibility is a **Self** spell (the `invisible` effect).
For the Area ones, `duration` is how long it lasts, scaled by spell power (skill, Intellect,
perks, and ×2.2 dual-cast). `systems/glamour.gd` (autoload **Glamour**) does the work:

- **Who enemies go after.** Wolves and bandit-kind (bandits, cultists, the inquisitor, the
  Mercy) ask `Targeting.foe_for()`, which asks `Glamour.target_for()` first. With no decoys
  and nobody charmed or frenzied, that's the player straight away. Otherwise: a charmed enemy
  goes for the nearest other enemy that isn't charmed (within 16 m; none means it heads
  home); a frenzied one goes for the nearest other enemy of any kind, or you; packmates
  within 10 m of either turn on it; anyone else within 18 m of a decoy goes for the decoy.
- **Invisible**, you're not a target: enemies after you give up and head home (or go for
  your companion), and idle ones don't notice you. Pressing attack or cast ends it.
- **Your hits** (melee, arrows, bolts, streams, bursts) call `Glamour.struck()`, which
  breaks a charm. Companions' hits and enemies' don't.
- **Who it works on:** anything with a `frighten()` method (wolves, bandits), unless
  `glamour_proof` is true (the hollow wolf). Wisps, the stone guardian and The First aren't
  touched: the wisps are Vael and this was their magic first.
- **When a charm wears off**, the enemy is still in the fight, and now it's after you.
- Companions leave charmed enemies alone. Enemies choose between you and a companion
  after Glamour has had its say (`systems/targeting.gd`).

### Tidecraft (the fifth school)

The pull of the two moons (docs/lore/MAGIC.md). Its five spells are **Area** spells whose
`tide` field (`pull`, `shove`, `well`, `crush`, `lift`) says what they do;
`systems/tidecraft.gd` (autoload **Tidecraft**) moves enemies by calling their `shove()` each
physics frame, which sets their knockback. Moon-Crush moves nothing: it hits and knocks down.
The Lifting Tide calls `lift(height, seconds)`: the enemy holds itself up instead of falling
(wisps hover at that height) and reels; when it lets go, Tidecraft hurts it on landing (once
it's on the floor, or 1.2 s after).

- **By the moons.** `WorldClock.tide()` (0 to 1) is the stronger of Ilun's fullness and the
  Wanderer's darkness. Tidecraft power is ×0.6 at the lowest tide and ×1.4 at the highest
  (`tide_mult()`), on top of skill, Intellect, perks and dual-casting. It scales damage, how
  far Tide's Shove throws and how long a well lasts. It doesn't care whether it's day.
  - It repeats every 14 days. At night: high (0.8+) on days 1 to 3, 6 to 7 and 13 to 14;
    low (under 0.45) on days 9 to 11, when Ilun is dark and the Wanderer full; middling
    otherwise. With two moons to lean on, it's high more often than low.
  - The ready spell's line above the Magicka bar says the tide ("Pull (charge, release,
    tide high)"), and so does the rest menu once you know a Tidecraft spell.
- **Who it moves:** anything with `shove()`: wolves, bandit-kind and wisps. The stone
  guardian and The First are too heavy, but Moon-Crush still hits them.
- **Who teaches it:** Magister Aurel, of the Collegium's Tide College, at the waystation
  ("The Tide College. Do you teach?").

### Binding (the sixth school)

Calling things and holding them: four spells, all sold by Maren as Bell College primers. The
full write-up is BINDING.md.

| Spell | Charge | Magicka | What it does | Tome |
|---|---|---|---|---|
| Call Wolf-Spirit | 1.0 s | 55 | A pale wolf-spirit where you aim (up to 15 m) fights for you for 60 s | 80 gold |
| Bind | 0.6 s | 30 | The enemy nearest where you aim (up to 20 m) is rooted for 6 s | 70 gold |
| Summon Guardian | 1.6 s | 90 | A stone echo of an old guardian (160 Health, slow, hits 16) fights for you for 45 s | 160 gold |
| Raise the Dead | 1.2 s | 70 | The nearest dead wolf or bandit where you aim gets up and fights for you for 40 s, then lies back down | 130 gold |

### Runecraft (the seventh school)

Rune-traps, wards and an enchanted blade: five spells, all sold by Maren as Seal College
primers. The full write-up is RUNECRAFT.md. Fire, Frost and Binding Runes wait on the ground
for an enemy to step close; Ward-Circle cuts the blows you take while you stand in it;
Enchant Weapon adds 8 to every blow for a minute.

### Sight (the eighth school)

The duellist-seer: Weak Point and Ill Fortune on an enemy, Foresight, True Sight (enemies
marked through walls) and the mastery, Moment of Clarity. All five are sold by Maren as Glass
College primers. The full write-up is SIGHT.md.

### Drawing (the ninth school, forbidden)

Taking life and power from living things: Draw (a beam that heals you), Siphon Magic (Magicka),
Hollowing Touch and the Great Drawing. It's the only school that corrupts you (0.05 per point
taken), and it grows stronger as you're corrupted (+15% a tier). Nobody sells it. You learn
it from Halina when you're Stained, from a book in the Barrow, or on its own at Hollowing. The
full write-up is DRAWING.md.

## Skills

Spell power gets **+1% per skill level** above 15, plus Intellect (+2% per point above 10).
- **Destruction XP:** 1 per 5 damage dealt (streams, bolts, bursts).
- **Restoration XP:** 1 per 5 health actually restored, and 1 per 4 damage a ward stops.
- **Alteration XP:** 1 per 6 Magicka spent on Alteration spells.
- **Glamour XP:** 1 per 5 Magicka spent on Glamour spells. Glamour levels make them last longer.
- **Tidecraft XP:** 1 per 5 Magicka spent on Tidecraft spells.
- **Binding XP:** 1 per 5 Magicka spent on Binding spells. Binding levels make them last longer.
- **Runecraft XP:** 1 per 5 Magicka spent, plus 2 + damage ÷ 5 each time a rune goes off.
- **Sight XP:** 1 per 5 Magicka spent on aimed Sight spells, 1 per 6 on its self spells.
- **Drawing XP:** 1 per 5 damage the streams deal, plus 1 per 5 Magicka for the charged spells.

Alteration perks: **Efficient Alteration** (20, −25% cost), **Arcane Reserve** (25, +25 max
Magicka), **Focused Mind** (35, after Arcane Reserve: Magicka +25% faster). Restoration
gained **Ward Mastery** (30, after Recovery: wards stop 20% more and cost 10% less). Glamour:
**Efficient Glamour** (20, −25% cost) and **Long Shadows** (35, after it: +30% duration).
Tidecraft: **Efficient Tidecraft** (20, −25% cost) and **Spring Tide** (35, after it: +30%
power).

**Magicka** refills 5/s (more with Willpower), starting 1 s after you stop casting.

## Perk trees

Ruin, Shaping, Mending, Glamour and Tidecraft have 21 perks each. Numbers are perk modifiers,
including per spell (`spell_power_<spell id>`, `spell_cost_<spell id>`), per school
(`spell_power_`, `spell_cost_`, `charge_time_`, `spell_range_`, new `spell_radius_<school>`),
`dual_power`, and `duration_<effect>` for self-spells. The rest are fields
`systems/spellcraft.gd` (the autoload `Spellcraft`) reads: a school's perks count for that
school's spells.

| School | Perks (level) |
|---|---|
| Ruin | Augmented Flames → Searing I–II (+25% each) → **Archmage of Ruin** (90): half cost · Efficient Destruction I–II · Fire Mastery (30): Firebolt and Flames +30% · Frost Mastery (30) · Lingering Elements (40): burning and chill twice as long · Rapid Ruin (25) · Long Fire (35) · Wide Blast (40): bursts +30% wider · **Impact** (45): one hit in three staggers → **Arc** (65): half a hit arcs to the next enemy within 5 m · Arcane Precision I–II (35/60): crits → **Annihilate** (75): +50% under a quarter health · **Kindling** (50): 15 Magicka a kill → Desperate Power (70): +50% under a quarter Magicka · Twin Flames (45): dual-casting +25% · Pyromancer's Lore (15) |
| Shaping | Efficient Alteration I–II · Arcane Reserve I–III: +25 Magicka each · Focused Mind I–II → **Deep Reserves** (65): under half Magicka, +50% regen · Quick Shaping I–II · Lasting Light (20) → Lantern Mind (35): by Candlelight, Magicka +20% · Lasting Stone (25) → Living Stone (50): in Stoneflesh, Health twice as fast → Granite Skin (75) · **Stone Body** (60): in Stoneflesh, you can't be staggered · Stone Ward (45) · Attunement (30): all spells −5% → **Spellweaver** (80): −10% cost and charge → **Archmage** (95): +50 Magicka, all spells +10% · Shaper's Insight (15) |
| Mending | Potent Healing I–III · Efficient Restoration I–II · Recovery I–II · Ward Mastery I–II → **Ward Absorb** (45): a quarter of what a ward stops is Magicka · Patient Ward (35): the Healing Ward −25% · Lasting Mending (25) · **Respite** (30): half of healing as Stamina · Battle Medic (40): +25% with enemies near → Desperate Prayer (50): +50% under a quarter health → **Last Breath** (80): once every 10 minutes, under a tenth of your health, heal 50 · Lantern's Grace (35): +25% at night · **Cleansing Light** (45): healing ends poison, bleeding, burning, venom → **Shared Light** (60): it heals your companion too · Quick Mending (25) · Healer's Lore (15) |
| Glamour | Efficient Glamour I–II · Long Shadows I–II → **Master Illusionist** (80) · Spreading Spell (30): 40% wider · Quick Glamour (25) · Far Glamour (30) · Dreadful (35) → **Panic** (50): a fleeing enemy takes 25% more → Terror (75) · Beguiling (35) → Enthrall (75) · Blood Frenzy (35) · Many Faces (40) → Lasting Phantoms (70) · Lasting Veil (35) → Veil (60): Invisibility half cost · **Shade's Edge** (55): blows from Invisibility +50% · Honeyed Words (20): +10 to checks · Glamour Lore (15) |
| Tidecraft | Efficient Tidecraft I–II · Spring Tide I–II → **Master of Tides** (95) · Quick Tides (25) → Tide-Caller (70) · Far Tides (30) · Wide Tides (35) · Undertow (30): Pull · Breaker I–II: Shove · Deep Well (40) · Crushing Depths → Drowning Depths: Moon-Crush · Rising Tide (45) · **Moon-Touched** (35): the moons sway it twice as much, both ways → **Steady Tide** (45): they never weaken it → **Moonborn** (85): at a high tide, every spell +20% · Tidal Reserve (50): +30 Magicka · Tide Lore (15) |

Streams hit every frame, so they don't roll staggers, and Lingering Elements stretches an
effect once rather than every frame.

## Combinations

From the questionnaire ("frost then fire shatters, a well then a crush"). `systems/combos.gd`.

| Combination | How | What |
|---|---|---|
| **Shatter** | A spell that burns (Firebolt, Flames) on a chilled enemy (Frost Burst) | 30 more (by your Ruin), a stagger, and the chill is gone |
| **Undertow** | Moon-Crush on an enemy a Gravity Well is holding | Double |
| **Riptide** | Hit something within 1.5 s of pulling it (Pull) | Half as much again, from a blade, an arrow or a spell; once |

Each says its name and is 5 XP (Ruin for Shatter, Tidecraft for the others).

## Adding a spell (no code)

1. Duplicate the spell closest to what you want in `spells/` (each style has one).
2. Edit **Id**, **Display Name**, **Description**, **Style**, **Skill** (`destruction` /
   `restoration` / `alteration` / `glamour` / `tidecraft`), **Color**, and the numbers in its style's group
   (Stream and ward, or Charged).
3. Self spells give a status effect: make one in `effects/` and add it to `EFFECT_FILES` in
   `systems/effect_library.gd`.
4. Add the spell to `SPELL_FILES` in `systems/spellbook.gd`.
5. Give it out: a race's **Starting Spells**, a background's `spells` in
   `character/backgrounds.json`, or a tome (duplicate an `items/tome_*.tres`, set **Teaches
   Spell**, and add it to `ITEM_FILES` in `systems/inventory.gd`).

The casting code is in `player/player_magic.gd`; projectiles and bursts are
`combat/spell_bolt.*` and `combat/spell_burst.gd`.

## Known limits

- Flames go through walls (the stream only checks enemies); bursts and bolts don't.
- Spells can't hurt you or friendly NPCs (no friendly fire), and enemies don't cast yet.
- Candlelight is one light that follows you; it doesn't cast shadows.
- Glamour (greybox): the decoy is a translucent capsule; you look the same to yourself while
  invisible (only the effect in the HUD says so); the mastery spell (a whole camp charmed)
  isn't in; and people you can talk to can't be glamoured.
- Tidecraft (greybox): a well is a turning ring, nothing more; thrown enemies take no damage
  from hitting walls; lifted enemies rise straight up (no tumbling) and only the wolf's lift
  is covered by a test, though bandit-kind and wisps share the code.
- Saved with the game: known spells and the ready spell (Block saves as no spell).
