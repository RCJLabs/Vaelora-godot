# Magic

**Hold right-click** to cast the spell in your left hand. **Q** switches between known
spells and **Block** (an empty left hand blocks; see COMBAT.md), and clicking a spell in
**Tab → Magic** readies it. You can't cast mid-swing or while blocking. The ready spell's name sits above the
Magicka bar, and the left-hand orb takes its colour.

| Spell | School / skill | Cost | Effect | How you get it |
|---|---|---|---|---|
| Healing | Restoration | 10 Magicka/s | Heals you 12/s | Everyone starts with it |
| Flames | Destruction | 14 Magicka/s | 16 damage/s to everything in a 6 m stream | Elves start with it; others learn it by touching the stone-circle crystal |

Spell power gets **+1% per skill level** above 15 (Elf Destruction starts at 25 = +10%).

- **Destruction XP:** 1 per 5 spell damage dealt.
- **Restoration XP:** 1 per 5 health actually restored. Healing at full health gives none.

**Magicka** refills 5/s, starting 1 s after you stop casting. Race maximums: Elf 130, Human
100, Orc 70. An Orc gets about 5 s of Flames.

A Flames stream kills a wolf (35 HP) in about 2 s, with no knockback, so they keep biting.
Sword plus Flames together works, because both hands are independent.

## Adding a spell (no code, if it fits an existing effect)

1. Duplicate `spells/flames.tres` (a damage stream) or `spells/healing.tres` (a self-heal).
2. Edit **Id**, **Display Name**, **Description**, **Skill** (`destruction` / `restoration`),
   **Magicka Per Second**, **Power Per Second**, **Range**, **Color**.
3. Add its path to `SPELL_FILES` in `systems/spellbook.gd`.
4. Give it out: in a race's **Starting Spells**, from code with `Spellbook.learn("id")`, or
   from an interactable like the crystal (`props/floating_crystal.gd`).

A new *kind* of effect (a projectile, a ward, a frost slow) needs a new entry in
`SpellData.Effect` and a branch in `_update_casting()` in `player_first_person.gd`.

## Known limits

- Flames go through walls (the stream only checks enemies).
- No spell tomes or spell shop yet. Learning happens via race or the crystal.
- No dual-casting or charged/projectile spells.
- Saved with the game: known spells and the ready spell (save version 4; older saves load
  with the race's starting spells).
