# Skills & Levelling

Skyrim-style: **you get better at what you do.** Press **Tab** to see your skills (the game
pauses).

## Skills

Fifteen so far, each rising by use from 15 (plus race bonuses) to 100. Each has a **governing
attribute**: +3% XP for that skill per point above 10 (`Attributes.skill_xp_mult()`).

| Skill | Attribute | Improves by | Effect |
|---|---|---|---|
| One-Handed | Strength | Hits with swords, axes, maces, daggers | +1% damage per level |
| Two-Handed | Strength | Greatsword hits | +1% damage per level |
| Unarmed | Strength | Punches that land | +1% fist damage per level (UNARMED.md) |
| Archery | Agility | Arrow hits | +1% bow damage per level |
| Sneak | Agility | Sneaking near unaware enemies, sneak attacks | Crouched, enemies notice you closer and slower (SNEAK.md) |
| Light Armour | Agility | Being hit in light armour | +1% armour from light pieces per level (ARMOUR.md) |
| Block | Endurance | Blocking and parrying | +0.5% of a hit blocked per level |
| Athletics | Endurance | Sprinting (1 XP per 5 m) | −0.5% sprint stamina cost per level |
| Heavy Armour | Endurance | Being hit in heavy armour | +1% armour from heavy pieces per level (ARMOUR.md) |
| Ruin (`destruction`) | Intellect | Spell damage dealt | +1% Ruin damage per level |
| Shaping (`alteration`) | Intellect | Casting Shaping spells | +1% to Shaping spells per level |
| Mending (`restoration`) | Willpower | Health restored | +1% healing per level |
| Speech | Presence | Checks passed, trading | +1 to persuade and intimidate checks per level, cheaper bribes, better prices (SPEECH.md) |
| Glamour | Presence | Casting Glamour spells | +1% duration per level |
| Tidecraft | Willpower | Casting Tidecraft spells | +1% power per level (and the moons) |

- XP to the next level is `5 + level × 0.5`: 12.5 XP at level 15, 55 XP at level 100.
- XP is multiplied by the race (Humans +15%), traits and powers (`skill_xp`), and the
  governing attribute.
- A top-left notice shows each increase: "One-Handed increased to 16".

### Skill books and trainers

Skills also rise two other ways (`Skills.raise(id)`: whole levels that count toward your
character level, with the XP towards the next level kept).

- **Skill books:** a book with **Teaches Skill** set gives +1 the first time you read it (the
  `read_<id>` flag BookReader already sets). Today: *The Swordsman's Rest* (One-Handed) and
  *A Tide Table, Annotated* (Tidecraft), both sold by Maren; and three of the lore books in the
  world: the Hallam book (Archery), the Dimming book (Shaping) and the Passenger lullaby
  (Glamour). A book read before it taught anything (an older save) doesn't teach afterwards.
- **Trainers** (`systems/training.gd`, the screen `ui/training_screen.gd`): a lesson raises the
  skill by one for **10 gold + 3 per level you're at**. **Five lessons per character level**,
  from anyone, then none until your next level. Each trainer teaches up to their own level:

  | Trainer | Skill | Up to | Ask |
  |---|---|---|---|
  | Brannoc | One-Handed | 40 | "Teach me to use a blade properly." |
  | Ostap | Archery | 40 | "Can you teach me to shoot?" |
  | Zora | Glamour | 50 | "Will you train me in Glamour? I'll pay." (after her first lesson) |
  | Magister Aurel | Tidecraft | 50 | "Teach me yourself, not from a book." |

  A dialogue choice with `"open_training": "<id>", "next": "end"` opens it. Lessons taken this
  level are saved.

### The planned skills (character building, round one)

Four skills to each attribute (your note: an even number per attribute). Bold ones exist;
*Unarmed* and *Command* are my additions to make it even.

| Attribute | Skills |
|---|---|
| Strength | **One-Handed**, **Two-Handed**, Smithing, ***Unarmed*** |
| Endurance | **Block**, **Heavy Armour**, **Athletics**, Survival |
| Agility | **Archery**, **Light Armour**, **Sneak**, Lockpicking |
| Intellect | **Ruin**, **Shaping**, Runecraft, Alchemy |
| Willpower | **Mending**, Binding, **Tidecraft**, Drawing |
| Presence | **Speech**, **Glamour**, Sight, *Command* (companions) |

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
