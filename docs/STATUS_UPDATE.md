# Project Status Update — Godot 3D Skyrim-style Prototype

**Date:** 2026-10-23  
**Repo:** RCJLabs/high-fantasy-sandbox-rpg  
**Current focus:** Getting a basic first-person 3D character controller working in Godot 4 so we can build toward a Skyrim-like exploration RPG.

## What We Are Building

A solo-developed, Elder Scrolls / Skyrim-style fantasy sandbox RPG in **Godot 4** (GDScript).

**Core vision (from earlier design):**
- Free-form adventurer (no forced class)
- 3 starting races: Human, Elf, Orc (unique traits)
- Hybrid progression (skills improve with use + level-up traits)
- Factions / guilds with a reputation system
- Open exploration with choice-driven story
- Stylized but grounded visuals
- Start small with a vertical slice, then expand

**Current technical direction:**
- 3D first-person (third-person later)
- CharacterBody3D player controller
- Simple outdoor starting zone
- Later: interaction, dialogue, inventory, quests, factions

## What We Have Done

- Created design docs and a Godot plan in the repo (`docs/`)
- Generated starter first-person and third-person GDScript controllers
- User set up a Godot 4 project and created a basic 3D scene with ground + player
- Added a minimal gravity + `move_and_slide()` script so the game loads

## Current Issue (Blocking)

**Player falls through the ground.**

### Symptoms
- With the full first-person script or a minimal gravity script, the character falls through the floor.
- Game loads when a script is attached.
- Collision setup appears present but is not registering.

### Troubleshooting already attempted
- Confirmed Ground should be StaticBody3D + CollisionShape3D (BoxShape3D)
- Confirmed Player should be CharacterBody3D + CollisionShape3D (CapsuleShape3D)
- Raised player starting Y position
- Checked collision layers/masks (set to 1)
- Detached script temporarily (game failed to run without a script)
- Re-attached minimal script (loads but still falls through)

### Likely causes still to check
1. CollisionShape3D on Ground has no Shape assigned (empty).
2. CollisionShape3D on Player has no Shape assigned.
3. Ground root is not actually a StaticBody3D.
4. Collision layers/masks still mismatched.
5. Player starts intersecting the ground collider.
6. Scale on the ground or collision shape is zero or extremely small.

## Recommended Next Steps (for whoever continues)

1. Create a brand-new minimal test scene:
   - StaticBody3D + MeshInstance3D (BoxMesh 20x1x20) + CollisionShape3D (BoxShape3D 20x1x20)
   - CharacterBody3D + CollisionShape3D (CapsuleShape3D)
   - Minimal script that only applies gravity and calls `move_and_slide()`
   - Place player at Y = 5
2. If the player stands on the box in the test scene, the problem is in the original ground setup.
3. Once collision works, re-attach the full first-person controller (`player_first_person.gd` in `docs/godot-starter/`).
4. Add mouse look, WASD movement, and jump.
5. Then move on to interaction raycast, dialogue, and race selection.

## Files Already in the Repo

- `docs/Godot_Engine_Plan.md` — original 2D-focused plan
- `docs/Godot_3D_Skyrim_Starter.md` — 3D setup notes
- `docs/godot-starter/player_first_person.gd` — full first-person controller
- `docs/godot-starter/player_third_person.gd` — basic third-person controller
- `DESIGN.md` — high-level design notes

## Continuation Prompt (copy-paste this to another AI / service)

```
I am building a Skyrim-style 3D fantasy sandbox RPG in Godot 4 (GDScript) as a solo beginner developer.

Current goal: Get a working first-person CharacterBody3D controller that does not fall through the ground.

Project context:
- Repo: https://github.com/RCJLabs/high-fantasy-sandbox-rpg
- Design: free-form adventurer, 3 races (Human/Elf/Orc), hybrid skill progression, factions with reputation, open exploration.
- We already have starter scripts in docs/godot-starter/ (player_first_person.gd and player_third_person.gd).

Problem:
The player falls through the ground. A minimal script with gravity + move_and_slide() loads the game but the character still falls. Collision shapes appear to be set up (StaticBody3D ground with BoxShape3D, CharacterBody3D player with CapsuleShape3D) but collisions are not registering.

Please help me:
1. Diagnose and fix the "falling through the ground" issue with clear, click-by-click Godot 4 steps.
2. Once collision works, set up a proper first-person controller (mouse look + WASD + jump) using or improving the existing player_first_person.gd.
3. Give me the exact node hierarchy and Inspector settings that are known to work.
4. After movement works, outline the next 2–3 systems to add (interaction raycast, simple dialogue, race selection).

Keep instructions beginner-friendly and specific to Godot 4.
```

---

**Status:** Blocked on basic 3D collision. Once the player stands on the ground, we can resume building the exploration prototype.
