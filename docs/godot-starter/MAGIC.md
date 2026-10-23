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

**Spell tomes** are items. Use one from Tab → Inventory to learn its spell (the tome is
used up). Maren's tomes are under "Let's trade."

## Skills

Spell power gets **+1% per skill level** above 15, plus Intellect (+2% per point above 10).
- **Destruction XP:** 1 per 5 damage dealt (streams, bolts, bursts).
- **Restoration XP:** 1 per 5 health actually restored, and 1 per 4 damage a ward stops.
- **Alteration XP:** 1 per 6 Magicka spent on Alteration spells.

Alteration perks: **Efficient Alteration** (20, −25% cost), **Arcane Reserve** (25, +25 max
Magicka), **Focused Mind** (35, after Arcane Reserve: Magicka +25% faster). Restoration
gained **Ward Mastery** (30, after Recovery: wards stop 20% more and cost 10% less).

**Magicka** refills 5/s (more with Willpower), starting 1 s after you stop casting.

## Adding a spell (no code)

1. Duplicate the spell closest to what you want in `spells/` (each style has one).
2. Edit **Id**, **Display Name**, **Description**, **Style**, **Skill** (`destruction` /
   `restoration` / `alteration`), **Color**, and the numbers in its style's group
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
- Saved with the game: known spells and the ready spell (Block saves as no spell).
