# High-Fantasy Sandbox RPG

Solo-developed Elder Scrolls-style free-form high fantasy sandbox.

- **Tone:** Wondrous and hopeful with real danger
- **Style:** Stylized but grounded
- **Approach:** Start extremely small with a vertical slice / concept demo, expand only after it works
- **Tools:** AI-assisted art and coding + basic programming

## Design Document

The full design plan, pillars, scope, and foundational decisions are in [DESIGN.md](DESIGN.md).

## Roadmap

[ROADMAP.md](ROADMAP.md): decisions, the cost of each feature, and phases up to a free itch.io demo and beyond.

## Current Status

Godot 4 project in [`godot/`](godot): a title screen, a character creator (race, background, traits, attributes, Survival and Hardcore modes) with active powers and perk trees, first-person controller with mantling and vaulting, a day/night cycle, survival needs with campfires and beds, Health/Stamina/Magicka, skills that improve with use and character levels, inventory/gold/loot, magic (8 spells in 3 schools: streams, bolts, bursts, wards and self spells, with dual-casting), save slots with a pause menu and settings (graphics presets, an FPS counter, key rebinding, a bug-report button), footsteps by surface and day/night ambience, E-to-interact, JSON dialogue, and Avowed-style melee (combos, charged heavy attacks, block, parry, dodge, stagger) with seven weapon types (sword, dagger, axe, mace, greatsword, shield, bow) against a pathfinding wolf pack that telegraphs its bites, a bandit camp whose bandits guard, parry and take turns, and wisps that haunt the stone circle at night, a greybox dungeon with traps, a lever puzzle and a stone guardian boss, three quests (one with three endings) tracked in a journal with a compass, quest markers and a map, and Riverwatch faction reputation. Guides: [setup & collision](docs/godot-starter/FIRST_PERSON_SETUP.md), [dialogue](docs/godot-starter/DIALOGUE.md), [races](docs/godot-starter/RACES.md), [stats, saving, title screen, settings & graphics](docs/godot-starter/STATS_AND_SAVING.md), [combat](docs/godot-starter/COMBAT.md), [skills](docs/godot-starter/SKILLS.md), [inventory](docs/godot-starter/INVENTORY.md), [magic](docs/godot-starter/MAGIC.md), [quests](docs/godot-starter/QUESTS.md), [factions](docs/godot-starter/FACTIONS.md), [art & assets](docs/godot-starter/ASSETS.md), [Terrain3D setup](docs/godot-starter/TERRAIN3D.md), [controls, climbing & hints](docs/godot-starter/CONTROLS.md), [day/night, survival & resting](docs/godot-starter/SURVIVAL.md), [status effects, attributes, equipment, interiors, footsteps & ambience](docs/godot-starter/FOUNDATIONS.md), [character creation, traits, powers & perks](docs/godot-starter/CHARACTER.md), [dungeons, traps & bosses](docs/godot-starter/DUNGEONS.md), [compass & map](docs/godot-starter/MAP.md), [tests, CI & builds](docs/godot-starter/TESTING.md). To try it: [the playtest checklist](docs/PLAYTEST.md). The world: [LORE.md](LORE.md) (draft).

## Repo

Private repository for design docs, concepts, and eventual prototype code.
