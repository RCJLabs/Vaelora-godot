# Skills & Levelling

Skyrim-style: **you get better at what you do.** Press **Tab** to see your skills (the game
pauses).

## Skills

| Skill | Improves by | Effect | Starts at |
|---|---|---|---|
| One-Handed | Sword hits that land (3 XP each) | +1% sword damage per level | 15 (Orc 25) |
| Athletics | Sprinting (1 XP per 5 m) | −0.5% sprint stamina cost per level (max −50%) | 15 (Elf 25) |
| Destruction | Spell damage dealt (1 XP per 5) | +1% Destruction spell damage per level | 15 (Elf 25) |
| Restoration | Health restored by spells (1 XP per 5) | +1% Restoration healing per level | 15 |

- XP to the next level is `5 + level × 0.5`: 12.5 XP at level 15, 55 XP at level 100.
- Humans gain all skill XP 15% faster (`skill_xp_mult` in `races/human.tres`).
- A top-left notice shows each increase: "One-Handed increased to 16".

## Character level

Every **5 skill increases** raise your character level. Each level gives a bonus to spend in
the Tab menu: **+10 max Health, Stamina or Magicka**. The new points arrive full. Unspent
bonuses wait until you choose.

## Adding a skill

1. Add an entry to `SKILLS` at the top of `systems/skills.gd`:
   `"sneak": {"name": "Sneak", "description": "..."},`
2. Call `Skills.add_xp("sneak", amount)` wherever the player does that thing.
3. Read `Skills.levels["sneak"]` wherever the skill should have an effect.
4. Optional: give a race a head start in its `.tres`: **Skill Bonuses** → `"sneak": 10`.

Old saves still load. New skills just start at their starting level.

## Saved

Skill levels and XP, character level, progress to the next level, unspent bonuses, and the
bonuses already spent. Save files from before skills existed (version 1) still load, with
fresh skills.
