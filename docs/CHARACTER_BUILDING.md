# Character building: the plan

From the character building questionnaire (answers kept verbatim in
`docs/design/character-building-answers-2026-10-25.txt`). What's decided, how big it is, and
the order it gets built in. Built pieces are documented in `docs/godot-starter/` as they land.

## Decided

- **Levels** stay as they are: every 5 skill-ups, +10 Health, Stamina or Magicka, 1 perk point
  and 1 attribute point. **No level cap**: skills cap at 100.
- **Skills rise** by use, from **trainers** (gold, a few levels per character level) and from
  **skill books** (+1 when read). Mastering a main skill takes **most of a playthrough**.
- **24 skills, 4 per attribute** (SKILLS.md has the table): the 10 there are, plus Sneak, Light
  and Heavy Armour, Speech, Lockpicking, Alchemy, Smithing, Survival, the four other schools
  (Binding, Runecraft, Sight, Drawing), and two of my additions to make it even: *Unarmed*
  (Strength) and *Command* (Presence: companions).
- **Binding** is the next school.
- **Attributes:** Strength sets carry weight (and heavy weapons are clumsy without it);
  Willpower shortens harmful effects; Presence sets prices and helps persuasion. Attributes
  never lock gear: anyone can use anything, just worse.
- **Carry weight** by Strength; over it, slow and no sprinting.
- **Trading** gets a proper buy and sell screen, prices by Presence and Speech.
- **Perk trees: at least 20 perks per skill.** Numbers early, new mechanics deeper in.
- **Active powers** are earned through play too: shrines, quests, the stones.
- **Respec** for a price at a shrine or a teacher.
- **Real classes** (details still open: below).
- **Fights get deeper** with weapon arts, spell combinations, sneak attacks, dual-wielding and
  spell-blades. **Hybrid builds are encouraged**: perks that reward mixing.

## How big this is

24 skills × 20+ perks is about **480 perks**. "New mechanics deeper in" means many of them need
their own code, not just a number; the perk screen needs a real tree view; and several of the
new skills are whole systems (stealth with enemy awareness, crafting screens, lockpicking).
So it's built in phases, and **each skill gets its full 20-perk tree when it's built** (the
ten that exist get theirs filled in along the way).

## Phases

1. **Foundations** (no open decisions)
   - ✅ Governing attributes; carry weight and over-encumbered; Willpower and harmful effects.
   - ✅ Heavy weapons clumsy below a Strength level.
   - The buy and sell screen, with prices by Presence.
   - Skill books and trainers.
   - Respec at a shrine.
   - The perk tree view, ready for 20+ perks a skill.
2. **New skills on the body:** Sneak (and sneak attacks), Light and Heavy Armour, Speech
   (persuasion checks and haggling), Unarmed.
3. **Magic:** Binding, then Runecraft, Sight and Drawing (each with its 20 perks).
4. **Making things:** Alchemy, Smithing, Lockpicking, Survival.
5. **Fighting deeper:** weapon arts, dual-wielding, spell-blades, spell combinations.
6. **Classes**, once they're defined.
7. **Earned powers:** shrines, quests and the stones.

## Still open: classes

Real classes need answers before they can be built:
- When do you pick one: at creation, next to your background, or later in the game?
- What does a class give: skill bonuses, faster XP in its skills, its own perks or passive, a
  class power, or limits on what you can learn?
- How many, and which (one per attribute, or named mixes like Spellsword and Ranger)?
- Can you change class (a respec covers it?), and how do classes sit with "hybrids
  encouraged"?
