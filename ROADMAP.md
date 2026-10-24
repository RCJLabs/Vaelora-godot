# Roadmap: a mini Elder Scrolls, built in public

**One-line pitch:** a first-person, free-form fantasy RPG where you build exactly who you
are (race, background, traits, skills) and a reactive world answers your choices. Optional
survival and hardcore modes make it as forgiving or as brutal as you want.

This file is the plan from here to a first public demo and beyond. `DESIGN.md` holds the
vision and locked decisions. This file holds **order, scope and cost**.

> **Time estimates are rough guesses**, based on 15–30 hours a week and AI-assisted coding.
> They're there to make the order and size of each phase concrete, not as deadlines. Expect
> each phase to run long; that's normal.

---

## Decisions (October 2026)

| Topic | Decision | Why it matters |
|---|---|---|
| Platform | **PC only** (Windows/Linux/Mac), mouse + keyboard, gamepad later | Keeps Forward+ (volumetric fog, realistic lighting). No mobile or web compromises |
| Look | **Near-realistic, obviously mystical** (Avowed / Skyrim) | Replaces "stylized but grounded" in older docs. Photo-scanned base + magical lighting/VFX |
| Camera | **First-person now**, third-person later | First-person needs no full-body player animation, the biggest art saving available |
| World | **Open regions + separate interiors** (Skyrim-style) | Towns, dungeons and buildings load behind doors. No seamless-world streaming tech needed |
| Combat | **Avowed-style action** | Light/heavy attacks, combos, block and parry, dodge, stagger, more spell variety. The most animation-hungry choice, so it's planned carefully (see Phase 1) |
| Survival / hardcore | **Optional, chosen per character** | Normal mode stays approachable. Both modes need balancing |
| Art sources | **Bought packs + free CC0 + AI-generated** | Licences tracked in `godot/CREDITS.md` from day one |
| First release | **Free demo on itch.io** | Real feedback, an audience, and a finish line that's reachable |
| Setting | **Your lore** | Lore bible to be written from your ideas (see "Open questions") |
| Races in the demo | **Human, Elf, Orc, deepened** | More races come after the demo |
| Priority order | **Character creation → story & factions → survival & danger → companions, pets, mounts** | Sets the phase order below |

---

## The honest cost of each feature

What makes a feature expensive here is **art and animation**, not code. Anything that's
mostly code and data can be built quickly (including remotely, in cloud sessions like the
ones that built the current systems). Anything that needs animated characters waits on
assets.

| Feature | Main cost | Remote-friendly? | Phase |
|---|---|---|---|
| Backgrounds, traits, attributes, more skills, perks | Code + data + balancing | ✅ | 1 |
| Unique race/background abilities | Code + VFX | ✅ mostly | 1 |
| Character appearance (faces, bodies, hair) | **Art: rigged, morphable models** | ❌ | 4+ |
| Avowed-style combat | Code + **first-person arm/weapon animation** | ⚠️ code yes, feel needs your hands | 1 |
| New enemy types | **Animated creature/humanoid models** | ⚠️ | 2 |
| Questlines, side quests, choices | **Writing** + data | ✅ | 2+ |
| Factions & reputation (more of them) | Data + writing | ✅ | 2+ |
| Survival needs (hunger, thirst, sleep, cold) | Code + UI | ✅ | 2–3 |
| Hardcore damage (limbs, bleeding, injuries) | Code + UI + balancing | ✅ | 3 |
| Weather, environmental hazards and events | Code + **VFX/sound** | ⚠️ | 3 |
| Dungeons, towns, cities | **Level design + lots of assets** | ❌ needs your editor time | 2+ |
| Companions | Code (AI, commands) + **animated NPCs** | ⚠️ | 4 |
| Pets | Code + **animated animals** | ⚠️ | 4 |
| Mounts | **Animated mount + mounted controls**, the hardest single feature | ❌ | 5 |
| Climbing / parkour | First-person mantle and vault: code + camera ✅. Full wall-climbing: hand animations ⚠️ | ⚠️ | 2 (mantle), 5 (climb) |
| Third-person camera | **Fully animated player model** | ❌ | 5 |

---

## Phase 0: Systems prototype ✅ done

Built and tested (see PR #1 and `docs/godot-starter/`):
- **The basics:** first-person controller, collision, interaction.
- **Character:** 3 races, stats with Health/Stamina/Magicka bars, skills that improve with use plus character levels.
- **Items and magic:** inventory, gold, loot, trading through dialogue; two spells (Healing, Flames) with Destruction and Restoration.
- **Combat and AI:** sword combat, a wolf pack that hunts together, pathfinding.
- **Story:** JSON dialogue with conditions and actions; a quest journal with two quests (one with three endings); Riverwatch faction reputation.
- **Saving and menus:** save slots, pause menu, settings.
- **World:** atmosphere, a mystical stone circle, Terrain3D-ready level.

This is a **systems sandbox**, not yet a game slice: placeholder art, one test level.

---

## Phase 1: "Who you are": character & combat foundation

**Goal:** the character you build plays **noticeably differently**, and combat feels good.
**Rough size:** 250–400 hours (≈ 3–5 months).

### 1a. Foundations other features depend on (do first) ✅ done, see `docs/godot-starter/FOUNDATIONS.md`
- [x] **Status effects:** one system for buffs and debuffs (poisoned, burning, bleeding,
      blessed, exhausted…), with duration, stacking and HUD icons. Abilities, survival,
      hardcore and potions all use it.
- [x] **Equipment:** slots (main hand, off hand, head, body, hands, feet, rings, amulet),
      weapon and armour data (damage, speed, reach, weight, armour rating), equip from the
      inventory.
- [x] **Attributes:** a small set of core attributes that drive derived stats. Built with
      the draft list (Strength, Endurance, Agility, Intellect, Willpower, Presence). Still
      open to change.
- [x] **World state per location:** remember dead enemies, opened containers, taken items
      and doors per region/interior. Needed before there's more than one scene.
- [x] **Region/interior transitions:** doors that load interiors and return you to where you
      left, keeping saves and quests consistent.

### 1b. Character creation depth (mechanics now, visuals later) (mostly done with draft content, see `docs/godot-starter/CHARACTER.md`)
- [x] **Backgrounds** (draft: Soldier, Scholar, Outlaw, Hunter, Acolyte, Merchant): starting
      gear, skill bonuses, starting reputation, unique dialogue options.
- [x] **Traits:** pick 2 positive, and optionally take a negative one for a third positive
      (Fallout-style). Mechanical, and visible in dialogue. (The `requires_trait` condition
      exists, but no trait-specific lines are written yet.)
- [x] **Unique abilities:** race signatures become real active powers with cooldowns
      (Adaptable, Innate Focus, Battle Fury); one per background.
- [x] **Perks on level-up:** small perk trees per skill (Skyrim-style), chosen in the Tab menu.
- [ ] **More skills**, each added with its feature: Two-Handed, Archery, Block, Light/Heavy
      Armour, Sneak, Speech, Alchemy, Survival, Acrobatics.
- [x] **Character creator flow:** name → race → background → traits → attributes → summary,
      plus a **Survival** and **Hardcore** toggle. (Built as race → background → traits →
      attributes → name & mode. Survival is saved but does nothing until survival needs exist.)

### 1c. Avowed-style combat (first-person) (core done, see `docs/godot-starter/COMBAT.md`)
- [x] Light attacks with **combos**, charged **heavy** attacks, **block**, timed **parry**,
      **dodge** with i-frames (moments of invulnerability), **stagger/poise**.
- [x] **Weapon types:** sword, axe, mace, dagger, two-hander, shield, bow. Each has its own
      feel and its own skill. (Axe bleeds, mace staggers, greatsword cleaves, shield blocks
      85% and bashes, bow draws and drops. Skills: One-Handed, Two-Handed, Block, Archery.)
- [x] **A humanoid enemy that fights back:** bandits telegraph, guard (heavies break it),
      parry (the leader), and take turns attacking. Bandit camp + bounty quest.
- [x] **Spells:** cast styles (stream, bolt, area, ward), dual-casting, 6–8 spells across 3 schools.
      (Stream, bolt, area, ward and self; dual-cast with an empty right hand; 8 spells across
      Destruction, Restoration and Alteration; spell tomes. See MAGIC.md.)
- [x] **First-person animation pipeline:** bought first-person arm/weapon animation packs, or
      procedural animation as a placeholder. Decide early; it shapes everything above.
      (Decided: procedural placeholder now, behind an interface a bought pack can replace;
      timing lives in AttackData. Trying a real pack needs the PC.)
- [x] **Enemy telegraphs and hit reactions**, readable at a glance. (Wolves: crouch, eye
      flare and growl before a bite; flinch, stagger. Placeholder synthesised sounds.)
- [x] **Gamepad support.** (Every action, stick look, menus and dialogue, prompts that follow
      the device. Tested with simulated input only; see CONTROLS.md.)

**Done when:** a Human soldier and an Elf scholar feel like different games for 20 minutes.

---

## Phase 2: "The demo region" → itch.io demo v0.1

**Goal:** a polished 1–2 hour slice of *your* world that a stranger can enjoy.
**Rough size:** 400–700 hours (≈ 5–8 months). **Demo target: about 9–14 months from now.**

- [x] **Lore bible v1** from your ideas: the region, its history, factions, the demo's story.
      (LORE.md, approved 24 October 2026. Its eight questions are still open, none blocking.)
- [ ] **Asset pass:** buy or download a consistent environment set (rocks, trees, buildings)
      plus humanoid NPC models and animations. Terrain3D landscape for the region.
- [ ] **One outdoor region** (~1 km²), with a small town or village, a road, wilderness,
      landmarks and secrets.
      (Groundwork done: compass with quest markers, discoverable places and a top-down map.
      See MAP.md.)
- [~] **One or two dungeons** (interiors): traps, a puzzle, a boss. (Toolkit done with a
      greybox test dungeon: pressure plates, darts, swinging blades, levers and gates, and a
      two-phase Stone Guardian boss. See DUNGEONS.md. The real dungeons wait on the region
      and the lore.)
- [x] **A short main questline** (3–5 quests) with a real choice that changes the ending,
      plus **5–8 side quests** and **2–3 factions** that react to you. Built in greybox
      (docs/QUESTLINE.md; every quest and flag is charted in docs/QUEST_FLOW.md): the six
      background openings, the five main quests (Wrong Things, The Waking Stones, Ask the
      Forest, The Barrow, What They Made) with The First as the final boss and an ending, all
      six side quests, the outlaws as a second faction, corruption (docs/CORRUPTION.md, which
      changes the ending), and a Greyfang pack you can drive off instead of kill. What's left
      is outside this item: the real region, models, and a playtest.
- [x] **3–5 enemy types:** wolves, bandits (human, uses the combat system), night-time
      wisps (magical), cultists, and two bosses: the Stone Guardian and The First.
- [x] **Survival v1 (optional mode):** hunger, thirst, sleep, cold, with food, camping and
      inns. (Plus a world clock with day and night. Beds and campfires rest and autosave;
      inns and paid beds come with a town. See SURVIVAL.md.)
- [x] **First-person mantle and vault:** climb onto ledges, which opens up exploration.
      (Ledges up to 2.1 m, ledge grabs mid-jump, vaulting fences. See CONTROLS.md.)
- [~] **Sound and music:** footsteps, combat, ambience, a few tracks (CC0 plus bought).
      (Placeholder synthesised sounds for combat, footsteps by surface, day/night and cellar
      ambience, campfire crackle. No music. All to be replaced with real recordings.)
- [~] **Hardcore v1 (optional mode):** higher damage both ways, slower healing, no fast
      travel, limited saves. (Damage and healing done; saving only by resting done; there's
      no fast travel to forbid yet. Permadeath is still an open question.)
- [~] **Polish:** tutorial prompts, a title screen, key rebinding, performance on mid-range
      PCs, a bug-report link. (Tutorial hints done, with a setting to turn them off; key
      rebinding done: Settings → Controls; title screen done, with a placeholder name;
      Low–Ultra graphics presets, render scale and an FPS counter done, but not yet profiled
      on real hardware; Report a Bug copies diagnostics, with no public link to send them to yet.)
- [ ] **itch.io page:** screenshots, a trailer, a feedback form. (CI now exports Windows and
      Linux builds; see TESTING.md. Uploading to itch.io isn't automated yet.)

**Done when:** five people who aren't you finish the demo and say what they'd want next.

---

## Phase 3: "The world bites back": survival & danger depth

**Rough size:** 300–500 hours.
- [ ] **Hardcore v2:** injuries per body part (limp, shaky aim, broken arm), bleeding,
      infection, armour coverage, realistic healing times.
- [ ] **Weather:** rain, snow, fog, storms. These affect visibility, temperature, stealth and
      fire magic.
- [ ] **Temperature and clothing:** warmth values, wetness, fires and shelter.
- [ ] **Environmental hazards:** cold water, rockfalls, poisonous swamps, magical storms
      near ley lines, unstable ruins.
- [ ] **World events:** caravans attacked, faction patrols clashing, wandering creatures,
      eclipses that strengthen magic.
- [ ] **Crafting:** cooking, alchemy, basic smithing and repair. This feeds both survival and the
      economy.

## Phase 4: "Never alone": companions & pets

**Rough size:** 300–500 hours.
- [ ] **Companion framework:** follow, wait, attack, carry items, use doors, stay out of
      traps, approval/loyalty, opinions on your choices.
- [ ] **2–3 written companions** with personal quests (one from each major faction).
- [ ] **Pets:** a dog or wolf companion (tame a Greyfang pup?), with commands, a carry
      bag, and finding items.
- [ ] **Character appearance v1:** bought morphable human/elf/orc heads and bodies, visible
      on NPCs and in a mirror or portrait.

## Phase 5: "Further and faster": mounts, climbing, third-person

**Rough size:** 400–700 hours, the most animation-heavy phase.
- [ ] **Animated player body**, then a **third-person camera** option.
- [ ] **Mounts:** a horse (bought rigged and animated), mount and dismount, saddlebags,
      mounted combat later.
- [ ] **Climbing:** wall climbing with stamina, climbing gear, an Acrobatics/Climbing skill.

## Phase 6 onward: "The wider world"

Pick and order these after the demo, based on feedback:
- **The first city** (Riverwatch?), with guilds (fighters, mages, thieves), guild questlines,
  housing.
- **More regions,** each with a distinct biome, culture and dungeon set.
- **More races** (each needs lore, models, voice and dialogue reactions), and a full character
  creator with sliders.
- **Faction wars:** territory control and choices that shift who rules where.
- **Economy and trading menus,** bounties and a crime system, prisons.
- **Early Access** on Steam once there's a few hours of polished content and a clear plan.

---

## Things that run through every phase

- **Playtest every month,** even if it's just you with fresh eyes, plus a friend.
- **Save compatibility:** keep loading older saves (the save system already versions them).
- **Performance budget:** test on a mid-range PC from Phase 2 on.
- **Keep docs current:** every system gets a page in `docs/godot-starter/`.
- **Licences:** every asset goes into `CREDITS.md` on the day it's added.

## Risks (and what we do about them)

| Risk | Mitigation |
|---|---|
| Scope creep: the list grows faster than the game | Each phase has a "done when" line. New ideas go into Phase 6, not the current phase |
| Art bottleneck: systems outrun visuals | Asset pass in Phase 2; buy consistent packs rather than mixing styles; placeholders are fine until then |
| Avowed-style combat needs a lot of animation | Decide the first-person animation source in Phase 1 and prototype with it before building 7 weapon types |
| Burnout | A playable milestone every few months; ship the demo even if it's small |
| Mixed art styles from many sources | Pick one main pack family per category; atmosphere/lighting ties them together |
| Lore never gets written | Lore bible v1 is a Phase 2 task with the demo's quests depending on it |

---

## Open questions (to settle as we go)

Answered in the lore questionnaire (24 October 2026); see `LORE.md`:
1. **Your lore:** drafted as `LORE.md` v1 (world: Vaelora). The *(suggested)* parts and its
   "Questions for you" are still open.
2. **Attributes:** decide after the playtest.
3. **Backgrounds and traits:** decide after the playtest.
4. **Death:** neither permadeath nor reload. You wake up wounded, sometimes captured by
   enemies, sometimes found by allies. Built for Hardcore (SURVIVAL.md); Normal still reloads.
5. **Title:** **Vaelora** (also the world's name).
6. **Budget:** free assets for now; spend what's needed later.
