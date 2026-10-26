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
- **Real classes** (below).
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
   - ✅ The buy and sell screen, with prices by Presence.
   - ✅ Skill books and trainers.
   - ✅ Respec (Aurel's rite, 150 gold; the shrine's interaction is part of the Silent Shrine
     quest, so the teacher came first).
   - ✅ The perk tree view (Tab → Perks), ready for 20+ perks a skill.
2. **New skills on the body:**
   - ✅ Sneak, with sneak attacks, noise and a 22-perk tree (`docs/godot-starter/SNEAK.md`).
   - ✅ Light and Heavy Armour, 21 perks each, with perks that work only in armour or a full set
     (`docs/godot-starter/ARMOUR.md`).
   - ✅ Speech: persuade, intimidate and bribe checks in dialogue, haggling, and 22 perks
     (`docs/godot-starter/SPEECH.md`).
   - ✅ Unarmed: fists train their own skill, 21 perks that work bare-handed
     (`docs/godot-starter/UNARMED.md`).
3. **Magic:**
   - ✅ Binding: four spells and 21 perks, built to the lore bible's school
     (`docs/godot-starter/BINDING.md`).
   - ✅ Runecraft: rune-traps, a ward-circle, Enchant Weapon and 21 perks
     (`docs/godot-starter/RUNECRAFT.md`).
   - ✅ Sight: marks, curses, Foresight, True Sight, Moment of Clarity and 21 perks
     (`docs/godot-starter/SIGHT.md`).
   - ✅ Drawing: the forbidden school, four spells, 21 perks, learned from Halina, the Barrow
     or Hollowing itself (`docs/godot-starter/DRAWING.md`).
4. **Making things:**
   - ✅ Alchemy: nine effects, nine ingredients, 27 potions, a brewing screen, venom
     coats and 21 perks (`docs/godot-starter/ALCHEMY.md`).
   - ✅ Smithing: a forge, 18 recipes for the game's weapons and armour, six qualities of
     improvement and 21 perks (`docs/godot-starter/SMITHING.md`).
   - ✅ Lockpicking: a pin-setting minigame, locked containers in three places, lockpicks
     and 21 perks (`docs/godot-starter/LOCKPICKING.md`).
   - ✅ Survival: cooking meals with buffs, forage plants that regrow, making camp from
     firewood, slower needs in Survival mode, and 21 perks (`docs/godot-starter/SURVIVAL.md`).
   - ✅ Command (an addition, Presence): companions stronger by level, the Command key to point
     out a target, and 21 perks (`docs/godot-starter/COMPANIONS.md`).
   - ✅ The martial trees: One-Handed, Two-Handed, Block, Archery and Athletics to 21 perks
     each (`docs/godot-starter/COMBAT.md`, "Martial perk trees").
   - ✅ The magic trees: Ruin, Shaping, Mending, Glamour and Tidecraft to 21 perks each
     (`docs/godot-starter/MAGIC.md`, "Perk trees"). Every one of the 24 skills now has 21+.
5. **Fighting deeper:**
   - ✅ Weapon arts: one for each weapon (and the shield, and fists), learned at 25
     (`docs/godot-starter/COMBAT.md`, "Weapon arts").
   - ✅ Spell combinations: Shatter, Undertow, Riptide (`docs/godot-starter/MAGIC.md`).
   - ✅ Dual-wielding: a one-handed weapon in the left hand, twin strikes, three One-Handed
     perks (`docs/godot-starter/COMBAT.md`, "Dual-wielding").
   - ✅ Spell-blades: a charged spell into the blade in the other hand, four perks
     (`docs/godot-starter/COMBAT.md`, "Spell-blades").
6. ✅ **Classes**: chosen at creation, +20% XP in five skills, a class power on R, changed after
   Aurel's rite (`docs/godot-starter/CLASSES.md`).
7. ✅ **Earned powers:** eight, from quests and the stones, one held at a time on T and exchanged
   in Tab → Powers (`docs/godot-starter/POWERS.md`). Sideways to the starting powers, not above.

## Classes (decided, after the questionnaire)

- **Chosen at creation**, a third choice next to race and background.
- **A class gives faster XP in its skills** (+20%, my number) **and a class power** only it has.
  It never stops you learning anything else (hybrids stay encouraged).
- **About 9 to 12 named mixes**, hybrids included.
- **You can change class** with the paid respec.
- Built after phase 2, since most classes lean on skills that don't exist yet (the creation
  step itself can come earlier).

### The classes *(approved 2026-10-25; Spellsword's power changed, below)*

Five skills each, drawn from the 24 so every skill belongs to at least one class.

| Class | Skills | Class power |
|---|---|---|
| Warrior | One-Handed, Two-Handed, Block, Heavy Armour, Smithing | War Cry: nearby enemies reel |
| Ranger | Archery, Sneak, Light Armour, Survival, Athletics | Hunter's Mark: one target takes more from everything |
| Thief | Sneak, Lockpicking, Light Armour, Speech, One-Handed | Vanish: unseen for a few seconds |
| Mage | Ruin, Shaping, Mending, Runecraft, Alchemy | Arcane Surge: spells cost nothing for a few seconds |
| Spellsword | One-Handed, Ruin, Shaping, Block, Light Armour | Quickened Blade: your ready spell into your blade at once, free (was "Charged Blade", which spell-blades now give everyone) |
| Nightblade | Sneak, One-Handed, Glamour, Drawing, Light Armour | Shadow Feast: a sneak attack drains life |
| Tide-Warden | Tidecraft, Two-Handed, Heavy Armour, Mending, Sight | Moon's Favour: the tide is high for a minute |
| Battlemage | Ruin, Heavy Armour, Two-Handed, Binding, Athletics | Storm Mantle: harm around you as you fight |
| Binder | Binding, Command, Runecraft, Sight, Glamour | Call the Host: two bound creatures at once |
| Wayfarer | Unarmed, Athletics, Survival, Mending, Sight | Second Breath: Health and Stamina back |
| Herald | Speech, Command, Glamour, Archery, Light Armour | Rally: you and your companions fight harder |
| Hedge Witch | Drawing, Alchemy, Binding, Glamour, Mending | Old Bargain: trade Health for Magicka |

Together they cover all 24 skills.
