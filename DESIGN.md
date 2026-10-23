# High-Fantasy Sandbox RPG — Design Plan

**Status:** Systems prototype done; planning the first demo. **Order, scope and phases: see [ROADMAP.md](ROADMAP.md).**  
**Developer:** Solo (RCJLabs) using AI tools + basic coding  
**Target style:** Elder Scrolls-like free-form open-world high fantasy  
**Visual north star:** Near-realistic but obviously mystical (Avowed / Skyrim), updated October 2026

## 1. Vision

A free-form high-fantasy sandbox where the player can become almost anything. The world is wondrous and hopeful, filled with beauty, discovery, and ancient mystery, but it contains real danger. Exploration is rewarded with unique stories, environmental secrets, and meaningful loot. Classic guilds and political factions exist and can go to war; the player builds reputation with them. Story and world outcomes shift based on choices.

The project starts extremely small: one tightly scoped vertical slice / concept demo that proves look, feel, and core loop before any expansion.

## 2. Design Pillars

1. **Free-form adventurer** — Player can pursue many roles (warrior, mage, explorer, thief, faction member, etc.).
2. **Wondrous + dangerous** — Beautiful, hopeful world with genuine threat and consequence.
3. **Exploration first** — Unique stories, secrets, and loot are the primary rewards.
4. **Meaningful factions** — Classic guilds + political factions at war, tracked by reputation.
5. **Reactive sandbox** — Mostly freeform play; story and outcomes change with player choices.
6. **Start small, expand later** — Solo + AI constraints mean prove one strong vertical slice before growing.

## 3. Foundational Decisions (Locked for Now)

| # | Topic | Decision |
|---|-------|----------|
| 1 | Core player fantasy | Free-form adventurer who can be anything |
| 2 | Tone | Wondrous and hopeful with real danger |
| 3 | Scope | Start very small (mockups + demo concepts). Expand only after vertical slice works |
| 4 | Character creation | Fully custom within limits. Start with **3 races**: Human, Elf, and Orc. Strong mechanical and cultural differences. Room to add more later. See `docs/races.md`. |
| 5 | Combat | **Avowed-style first-person action** (updated October 2026; the earlier jumping-off point was simple real-time). Light/heavy attacks, combos, block/parry, dodge, stagger, varied spells, clear enemy telegraphs. |
| 6 | Narrative structure | Mostly sandbox. Story and outcomes change with choices |
| 7 | Progression | Hybrid: skills improve through use + discrete level-ups that grant traits/perks |
| 8 | Exploration rewards | Unique stories, loot, environmental secrets. Open world is fairly dangerous |
| 9 | Factions | Classic guilds + political factions that can be at war + reputation system |
| 10 | Visual style | Near-realistic, obviously mystical (Avowed / Skyrim): photo-scanned base materials + magical lighting and VFX. Updated October 2026 |
| 11 | Platform | PC only (Windows/Linux/Mac), Forward+ renderer. Mobile/web dropped |
| 12 | Camera | First-person now, third-person later |
| 13 | World structure | Open regions + separate interiors behind doors (Skyrim-style) |
| 14 | Survival & hardcore | Optional modes chosen per character |
| 15 | First release | Free demo on itch.io |
| 16 | Setting | The developer's own lore (lore bible to be written) |

## 4. Original Phase 1 Scope — Vertical Slice / Concept Demo

*Superseded by [ROADMAP.md](ROADMAP.md). Most of the systems below now exist as a prototype (see `docs/godot-starter/`); art, interiors and the real demo zone are Phase 2 in the roadmap.*

**Goal:** A small, playable (or at least fully visual + interactive) slice that demonstrates the look, atmosphere, and core fantasy.

### Included in Phase 1
- One small outdoor zone (e.g., a valley edge, forest clearing with a ruin, or coastal overlook).
- 1–2 interiors (ruined tower, small cave, or simple building).
- Visual representation of at least 1–2 of the 3 races (full character creation can come later).
- 2–4 points of interest with environmental storytelling and simple interactables.
- Basic movement and camera.
- Simple interaction system (examine, pick up, talk to one NPC or trigger).
- At least one simple encounter or threat that communicates danger (using the simple real-time combat approach).
- Stylized-but-grounded art style established via concept art and in-engine assets.
- Placeholder or basic progression feedback (even if just UI stubs).

### Explicitly out of scope for Phase 1
- Full open world
- All 3 races fully playable with deep mechanics
- Polished or complex combat system
- Multiple factions or large quest lines
- Full progression trees
- Multiplayer or networking
- Polished UI / menus beyond what is needed to demo the slice

## 5. Core Systems (High-Level)

### Character & Races
- Start with 3 races: **Human, Elf, and Orc** (details in `docs/races.md`).
- Visually, culturally, and mechanically distinct.
- Full customization within each race (appearance, background flavor).
- Race differences should be readable in both visuals and early gameplay.

### Progression
- Skills improve through use (classic Elder Scrolls style).
- Character level-ups grant selectable traits/perks.
- Hybrid approach keeps both organic growth and deliberate choices.

### Exploration & World
- Dense, hand-crafted points of interest even in a small zone.
- Environmental storytelling and secrets are primary rewards.
- Danger is present but the world remains wondrous.

### Factions & Reputation
- Classic guilds (examples: mages, fighters, thieves, etc.).
- Larger political factions that can conflict.
- Reputation tracked per group; affects dialogue, access, and outcomes.

### Narrative
- Sandbox framing with reactive elements.
- Choices and reputation influence available stories and endings within the slice and beyond.

### Combat (Locked Jumping-Off Point)
**Simple real-time**
- Free player movement in the world.
- Click / tap / button to attack.
- Large, forgiving hitboxes.
- Clear enemy telegraphs (wind-ups, visual cues) so the player can react.
- Animations and VFX kept simple or AI-generated and triggered on events.
- Goal for the prototype: make combat readable and functional, not flashy. Polish comes later.

## 6. Technical & Production Approach

- **Solo developer** using AI tools for concept art, texture references, writing assistance, code generation, and asset iteration.
- **Basic coding** — prefer engines or frameworks that allow rapid iteration (exact engine TBD; Godot is a strong candidate for solo work).
- **Art pipeline:** AI image generation for concepts and style references → stylized-but-grounded assets. Prioritize strong silhouettes, readable forms, atmospheric lighting, and painterly or grounded materials over hyper-realism.
- **Version control:** This repository. Keep design docs, concepts, and code together.
- **Iteration style:** Mockups and concept demos first. Only expand systems once the vertical slice feels good.

## 7. Suggested Initial Milestones

1. **Style & Race Concepts** — Done (Human, Elf, Orc + concept art direction).
2. **Demo Zone Layout** — Block out or concept the small outdoor + interior area.
3. **Vertical Slice Prototype** — Basic movement, camera, interaction, and one point of interest in-engine.
4. **First Encounter** — Add a simple threat using the simple real-time combat approach.
5. **Playable Demo** — Something that can be shown or played for a few minutes that captures the fantasy.

## 8. Open Questions / Next Decisions

- Specific size and theme of the first demo zone.
- Engine / framework choice (Godot recommended for solo).
- Working title for the project.
- Exact starting numbers for race stats and ability tuning.
- One simple enemy type for the first encounter.

## 9. Repo Structure (Suggested)

```
/
├── DESIGN.md          # This document
├── README.md          # Short project overview + how to run (when code exists)
├── docs/              # Additional design notes, lore, race sheets
├── concepts/          # Concept art and style references
├── src/               # Code (when prototyping begins)
└── assets/            # Final or in-engine assets
```

---

**Combat (updated October 2026):** Avowed-style first-person action. See ROADMAP.md Phase 1c.
