# Godot Engine Plan: Elder Scrolls-style Fantasy Sandbox RPG

**Project codename:** *Aetherbound* (placeholder)  
**Developer:** Solo (beginner-friendly)  
**Engine:** Godot 4.x (GDScript)  
**Target:** ~~Browser + desktop first, mobile later~~ **PC only** (decided October 2026, see ROADMAP.md)  
**Art direction:** ~~Stylized but grounded~~ **Near-realistic, obviously mystical** (see ROADMAP.md)

> This was the original plan from before the 3D prototype. The current plan is [ROADMAP.md](../ROADMAP.md).

## 1. Why Godot for This Game

- Free, open-source, no revenue cut.
- Excellent for both 2D and 3D; you can start in 2D (or hybrid) and move to 3D later without rewriting everything.
- GDScript is Python-like and very beginner-friendly.
- Scene/node system maps perfectly to “zones + objects + NPCs + systems”.
- Built-in UI, animation, physics, navigation, and export to Windows/Linux/macOS/Web.
- Active community and tons of free tutorials specifically for RPGs.

You already saw that pure browser canvas prototypes hit limits quickly. Godot removes those limits while still letting you iterate fast.

## 2. Design Pillars (from our earlier decisions)

| Pillar | How it appears in the game |
|--------|----------------------------|
| Free-form adventurer | No forced class. Skills improve with use + player-chosen traits on level-up. |
| 3 starting races | Human, Elf, Orc — distinct starting stats, abilities, and dialogue/faction reactions. |
| Sandbox + reactive story | Open exploration of zones. Quests and faction reputation change based on choices. |
| Hybrid progression | Use-based skill growth (like Elder Scrolls) + milestone level-ups that grant traits. |
| Factions & reputation | Classic guilds + political factions at war. Reputation unlocks quests, vendors, hostility. |
| Tone | Wondrous and hopeful with real danger. Environmental secrets and unique loot. |
| Visuals | Stylized but grounded. Start with strong 2D layered sprites or low-poly 3D. |

## 3. Recommended Scope for a Solo Beginner

**Do not** try to build a full open world on day one.

**Vertical slice goal (first major milestone):**
- 1 starting zone (ruined forest / ancient ruins — the area we already prototyped).
- Player movement + interaction + basic inventory.
- 1–2 NPCs with dialogue.
- Simple quest + faction reputation change.
- 3 race options at character creation.
- A few interactive objects with depth sorting (pillars, arch, etc.).

Once that feels good, expand outward.

## 4. Tech Stack

- **Godot 4.3+** (latest stable)
- **GDScript** (primary)
- **Rendering:**
  - Option A (recommended start): 2D with Y-sorting and layered sprites (exactly what the canvas prototype was trying to do, but properly).
  - Option B (later): 3D with low-poly stylized models + simple lighting.
- **Art sources:** AI-generated + cleaned sprites (the process we already started), free assets from OpenGameArt / itch.io, or purchased packs.
- **Version control:** Git + GitHub from day one.

## 5. High-Level Architecture

```
Main.tscn
├── World (Node2D or Node3D)
│   ├── Zones (each zone is its own scene)
│   │   ├── Ground / Environment
│   │   ├── Interactables (Area2D or Area3D + script)
│   │   ├── NPCs
│   │   └── Enemies
│   └── Player
├── UI (CanvasLayer)
│   ├── HUD
│   ├── Dialogue
│   ├── Inventory
│   ├── Character Sheet
│   └── Journal / Quests
└── Autoloads (singletons)
    ├── GameState
    ├── PlayerData
    ├── FactionManager
    ├── QuestManager
    └── AudioManager
```

Key systems as Autoloads so any scene can access them cleanly.

## 6. Core Systems (Build Order)

### Phase 0 – Setup (1–2 days)
- Create new Godot 4 project.
- Folder structure (see section 9).
- Player scene with basic movement (WASD + touch/gamepad later).
- Simple camera that follows the player.

### Phase 1 – Interaction & Depth (1 week)
- Y-sorting so the player correctly walks behind pillars/arches (Godot’s `y_sort_enabled` on a Node2D makes this trivial).
- Interaction system: when player is near an object, show “Examine” / “Talk” prompt and trigger on input.
- Basic dialogue UI (text box + choices).

### Phase 2 – Character & Progression (1–2 weeks)
- Character creation screen: choose Human / Elf / Orc.
- Race traits (example):
  - **Human:** +dialogue options, balanced stats.
  - **Elf:** faster movement / magic affinity, lower health.
  - **Orc:** higher strength / health, some factions start wary.
- Skill system: skills increase when used (e.g. “Athletics” from running/jumping, “Persuasion” from dialogue success).
- Level-up: every X total skill uses → player picks a trait.

### Phase 3 – Inventory, Quests, Factions (2 weeks)
- Simple inventory (grid or list).
- Quest log.
- Faction reputation (dictionary of faction → value). Reputation changes from dialogue choices, quests, and actions.
- One small quest that involves talking to an NPC, interacting with a ruin object, and changing reputation.

### Phase 4 – Content & Polish (ongoing)
- More zones, NPCs, enemies, loot.
- Save/load.
- Better art pass.
- Sound and music.

## 7. Art Pipeline (Realistic for Solo + AI)

1. Generate sprites/environments with AI (prompts that request solid background, then remove background cleanly).
2. Clean and export as transparent PNGs.
3. Import into Godot as Sprite2D or AnimatedSprite2D.
4. For environments: either tiled backgrounds, parallax layers, or a single large painted background + layered interactive sprites (the approach we tested).
5. Later: move key assets to 3D if desired (Godot’s 3D is very capable).

## 8. Difficulty for a Solo Beginner

**Honest assessment:**  
- Learning curve: moderate. Godot is one of the friendliest engines for solo beginners.
- Biggest challenges will be **systems design** (quests, dialogue, reputation) more than the engine itself.
- You can get a playable prototype of the ruins zone in 1–2 weeks if you focus.
- Recommended learning path:
  1. Official Godot “Your first 2D game” tutorial.
  2. HeartBeast or GDQuest 2D RPG tutorials.
  3. Build the vertical slice above before adding more features.

You do **not** need to know advanced programming. GDScript + Godot’s node system is approachable.

## 9. Suggested Project Structure (for the GitHub repo)

```
aetherbound/
├── assets/
│   ├── sprites/
│   ├── ui/
│   ├── audio/
│   └── fonts/
├── scenes/
│   ├── player/
│   ├── zones/
│   ├── npcs/
│   ├── ui/
│   └── main.tscn
├── scripts/
│   ├── autoload/
│   ├── player/
│   ├── systems/
│   └── interactables/
├── docs/
│   └── design_notes.md
├── .gitignore
└── README.md
```

## 10. Milestones

| Milestone | Goal | Rough Time (solo, part-time) |
|-----------|------|------------------------------|
| 0 | Project setup + player movement | 2–3 days |
| 1 | Ruins zone with depth sorting + interaction | 1 week |
| 2 | Character creation (3 races) + basic skills | 1–2 weeks |
| 3 | Dialogue + one quest + reputation | 1–2 weeks |
| 4 | Vertical slice (playable 10–15 min) | 4–6 weeks total |
| 5 | Expand content + polish | Ongoing |

## 11. Next Immediate Steps

1. Download Godot 4 (latest stable) from godotengine.org.
2. Create a new project and set up the folder structure above.
3. Make a simple player that moves and a couple of Sprite2D objects with Y-sorting enabled.
4. Import the cleaned pillar / arch / hero sprites we already generated and test depth sorting.
5. Add a basic interaction prompt.

Once that works, we can start adding the race selection and skill system.

---

**This plan is deliberately small at the start.**  
The goal is a fun, explorable vertical slice that proves the fantasy sandbox feeling, then expand. Godot makes that expansion much smoother than the pure browser prototypes. 

Ready to start building the first Godot scene whenever you are.
