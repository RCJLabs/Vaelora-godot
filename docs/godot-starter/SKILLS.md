# Skills & Levelling

Skyrim-style: **you get better at what you do.** Press **Tab** to see your skills (the game
pauses).

## Skills

Ten so far, each rising by use from 15 (plus race bonuses) to 100. Each has a **governing
attribute**: +3% XP for that skill per point above 10 (`Attributes.skill_xp_mult()`).

| Skill | Attribute | Improves by | Effect |
|---|---|---|---|
| One-Handed | Strength | Hits with swords, axes, maces, daggers | +1% damage per level |
| Two-Handed | Strength | Greatsword hits | +1% damage per level |
| Archery | Agility | Arrow hits | +1% bow damage per level |
| Block | Endurance | Blocking and parrying | +0.5% of a hit blocked per level |
| Athletics | Endurance | Sprinting (1 XP per 5 m) | −0.5% sprint stamina cost per level |
| Ruin (`destruction`) | Intellect | Spell damage dealt | +1% Ruin damage per level |
| Shaping (`alteration`) | Intellect | Casting Shaping spells | +1% to Shaping spells per level |
| Mending (`restoration`) | Willpower | Health restored | +1% healing per level |
| Glamour | Presence | Casting Glamour spells | +1% duration per level |
| Tidecraft | Willpower | Casting Tidecraft spells | +1% power per level (and the moons) |

- XP to the next level is `5 + level × 0.5`: 12.5 XP at level 15, 55 XP at level 100.
- XP is multiplied by the race (Humans +15%), traits and powers (`skill_xp`), and the
  governing attribute.
- A top-left notice shows each increase: "One-Handed increased to 16".

### The planned skills (character building, round one)

Four skills to each attribute (your note: an even number per attribute). Bold ones exist;
*Unarmed* and *Command* are my additions to make it even.

| Attribute | Skills |
|---|---|
| Strength | **One-Handed**, **Two-Handed**, Smithing, *Unarmed* |
| Endurance | **Block**, Heavy Armour, **Athletics**, Survival |
| Agility | **Archery**, Light Armour, Sneak, Lockpicking |
| Intellect | **Ruin**, **Shaping**, Runecraft, Alchemy |
| Willpower | **Mending**, Binding, **Tidecraft**, Drawing |
| Presence | Speech, **Glamour**, Sight, *Command* (companions) |

See `docs/CHARACTER_BUILDING.md` for the order they'll be built in.

## Character level

Every **5 skill increases** raise your character level. Each level gives a bonus to spend in
the Tab menu: **+10 max Health, Stamina or Magicka**, plus **1 perk point** and **1 attribute
point** (CHARACTER.md). The new points arrive full. Unspent bonuses wait until you choose. No
level cap: skills cap at 100, and levels follow.

## Adding a skill

1. Add an entry to `SKILLS` at the top of `systems/skills.gd`:
   `"sneak": {"attribute": "agility", "name": "Sneak", "description": "..."},`
2. Call `Skills.add_xp("sneak", amount)` wherever the player does that thing.
3. Read `Skills.levels["sneak"]` wherever the skill should have an effect.
4. Optional: give a race a head start in its `.tres`: **Skill Bonuses** → `"sneak": 10`.

Old saves still load. New skills just start at their starting level.

## Saved

Skill levels and XP, character level, progress to the next level, unspent bonuses, and the
bonuses already spent. Save files from before skills existed (version 1) still load, with
fresh skills.
