# Godot 4 3D Skyrim-style Starter Plan

**Direction change:** Moving from 2D layered sprites to a **3D first-person / third-person** Skyrim-style exploration RPG.

**Engine:** Godot 4.x (GDScript)  
**First goal:** A playable character that can walk around a simple 3D environment with mouse look (first person) or orbit camera (third person).

## Recommended starting camera
Start with **first person**. It is simpler and closer to classic Elder Scrolls exploration. You can add third-person later with a SpringArm3D.

## Immediate setup steps in Godot

1. Create a new Godot 4 project (Forward+ renderer).
2. In Project Settings → Input Map, add these actions if they don’t exist:
   - `move_forward` (W)
   - `move_back` (S)
   - `move_left` (A)
   - `move_right` (D)
   - `jump` (Space)
   - `sprint` (Shift) — optional for later
3. Create a new 3D scene as the main scene.
4. Add a StaticBody3D + MeshInstance3D (BoxMesh or PlaneMesh) as the ground. Scale it large (e.g. 50x50).
5. Add a DirectionalLight3D and a WorldEnvironment (optional, for better lighting).
6. Create a Player scene (CharacterBody3D) and instance it in the main scene.

## Player scene structure (First Person)

```
Player (CharacterBody3D)
├── CollisionShape3D (CapsuleShape3D, height ~1.8, radius ~0.4)
├── Head (Node3D)          ← rotate this on X for looking up/down
│   └── Camera3D           ← set Current = true
└── MeshInstance3D (optional placeholder capsule or imported model)
```

## Player scene structure (Third Person – later)

```
Player (CharacterBody3D)
├── CollisionShape3D
├── MeshInstance3D (or imported character)
└── SpringArm3D
    └── Camera3D
```

## Starter scripts

See the accompanying files:
- `player_first_person.gd` — ready-to-use first-person controller
- `player_third_person.gd` — basic third-person with camera-relative movement

Attach the script to the CharacterBody3D root.

## Next systems after movement works

1. Interaction raycast (E to examine / talk)
2. Simple dialogue UI
3. Character creation (race selection)
4. Basic inventory
5. Faction reputation dictionary
6. One small outdoor zone with a few props

## Art direction note

For a Skyrim-like feel on a solo budget:
- Start with Godot’s built-in primitives + simple materials.
- Import free low-poly or stylized models from Sketchfab / OpenGameArt / itch.io.
- Later: AI-generated textures or purchased asset packs.
- Keep the scope to one starting outdoor area first.

## Learning resources (highly recommended)

- Official Godot “Your first 3D game” tutorial
- Search “Godot 4 CharacterBody3D first person” or “third person SpringArm3D”
- GDQuest and HeartBeast YouTube channels for 3D RPG systems

Once the character can walk around a simple 3D scene, we can add interaction, dialogue, and the race/skill systems from the original design.
