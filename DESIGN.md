# High-Fantasy Sandbox RPG — Design Plan

**Status:** Early concept / vertical-slice planning  
**Developer:** Solo (RCJLabs) using AI tools + basic coding  
**Target style:** Elder Scrolls-like free-form open-world high fantasy  
**Visual north star:** Stylized but grounded

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
| 4 | Character creation | Fully custom within limits. Start with **3 races** that have strong mechanical and cultural differences. Room to add more later |
| 5 | Combat | Must stay feasible for solo + AI tools. Likely simpler than full real-time action (exact approach TBD) |
| 6 | Narrative structure | Mostly sandbox. Story and outcomes change with choices |
| 7 | Progression | Hybrid: skills improve through use + discrete level-ups that grant traits/perks |
| 8 | Exploration rewards | Unique stories, loot, environmental secrets. Open world is fairly dangerous |
| 9 | Factions | Classic guilds + political factions that can be at war + reputation system |
| 10 | Visual style | Stylized but grounded. Whatever is realistically achievable with AI tools |

## 4. Phase 1 Scope — Vertical Slice / Concept Demo

**Goal:** A small, playable (or at least fully visual + interactive) slice that demonstrates the look, atmosphere, and core fantasy.

### Included in Phase 1
- One small outdoor zone (e.g., a valley edge, forest clearing with a ruin, or coastal overlook).
- 1–2 interiors (ruined tower, small cave, or simple building).
- Visual representation of at least 1–2 of the 3 races (full character creation can come later).
- 2–4 points of interest with environmental storytelling and simple interactables.
- Basic movement and camera.
- Simple interaction system (examine, pick up, talk to one NPC or trigger).
- At least one simple encounter or threat that communicates danger.
- Stylized-but-grounded art style established via concept art and in-engine assets.
- Placeholder or basic progression feedback (even if just UI stubs).

### Explicitly out of scope for Phase 1
- Full open world
- All 3 races fully playable with deep mechanics
- Complete combat system
- Multiple factions or large quest lines
- Full progression trees
- Multiplayer or networking
- Polished UI / menus beyond what is needed to demo the slice

## 5. Core Systems (High-Level)

### Character & Races
- Start with 3 races that are visually, culturally, and mechanically distinct.
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

### Combat (TBD — Feasibility Constraint)
Possible directions to explore (pick one that is realistic with AI tools + basic coding):
- Simple real-time with large hitboxes and clear telegraphs.
- Action with pause or slow-motion targeting.
- Light hybrid or structured exchanges.
- Heavy reliance on AI-generated animations and VFX triggered simply.

## 6. Technical & Production Approach

- **Solo developer** using AI tools for concept art, texture references, writing assistance, code generation, and asset iteration.
- **Basic coding** — prefer engines or frameworks that allow rapid iteration (exact engine TBD; Godot, Unity, or similar are candidates).
- **Art pipeline:** AI image generation for concepts and style references → stylized-but-grounded assets. Prioritize strong silhouettes, readable forms, atmospheric lighting, and painterly or grounded materials over hyper-realism.
- **Version control:** This repository. Keep design docs, concepts, and code together.
- **Iteration style:** Mockups and concept demos first. Only expand systems once the vertical slice feels good.

## 7. Suggested Initial Milestones

1. **Style & Race Concepts** — Generate and lock visual direction + the 3 starting races (look, culture, one mechanical hook each).
2. **Demo Zone Layout** — Block out or concept the small outdoor + interior area.
3. **Vertical Slice Prototype** — Basic movement, camera, interaction, and one point of interest in-engine.
4. **First Encounter** — Add a simple threat or interactive moment that shows danger + wonder.
5. **Playable Demo** — Something that can be shown or played for a few minutes that captures the fantasy.

## 8. Open Questions / Next Decisions

- Exact names, cultures, and mechanical hooks for the 3 starting races.
- Specific size and theme of the first demo zone.
- Combat approach that is realistic with current tools.
- Engine / framework choice.
- Working title for the project.

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

**Next immediate action:** Define the 3 starting races and generate a small set of stylized-but-grounded concept images for the visual north star and demo zone.
