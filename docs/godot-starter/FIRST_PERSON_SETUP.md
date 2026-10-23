# First-Person Controller: Fixing "Falls Through the Ground" + Known-Good Setup

Godot 4.x (tested headless on **4.3-stable**, Godot Physics).

There is a ready-to-open project in [`/godot`](../../godot). If you just want something that works:
**Project Manager → Import → pick `godot/project.godot` → Edit → F5.** You should land on a green
50×50 floor and be able to walk, sprint, jump and look around. Compare it with your own scene
to find what's different.

---

## 1. Diagnose the fall (5 minutes)

### Step 1 — Turn on collision debug view
1. In the editor top menu, click **Debug**.
2. Tick **Visible Collision Shapes**.
3. Press **F6** (runs the scene you are *currently editing*; F5 runs the *main* scene, which
   may be a different one — a common source of "I fixed it but nothing changed").

While the game runs, every collision shape is drawn as a cyan wireframe.

- **No cyan box under the floor** → the ground has no working collider (causes A–C below).
- **No cyan capsule around you** (look down / check the Remote tree) → the player has no
  working collider (cause D).
- **Both are visible and you still fall** → layers/masks (cause E), or your box is much
  smaller than the floor mesh (cause C).

### Step 2 — Check the Scene dock for yellow ⚠ triangles
Hover any ⚠ next to a node. The two that matter here:
- *"A shape must be provided for CollisionShape3D to function"* → cause A / D.
- *"CollisionShape3D only serves to provide a collision shape to a CollisionObject3D derived
  node"* → cause B.

### The causes that were tested (each one reproduces the fall)

| # | Cause | Fix |
|---|---|---|
| A | Ground's `CollisionShape3D` → **Shape** is `<empty>` | Inspector → Shape → **New BoxShape3D**, then click the BoxShape3D and set **Size** to match the mesh (e.g. 50, 1, 50) |
| B | `CollisionShape3D` is a child of the **MeshInstance3D**, not of the **StaticBody3D** | Drag it in the Scene dock so it sits directly under `Ground (StaticBody3D)` |
| C | BoxShape3D left at default size **1×1×1** while the mesh is 50×50 — you spawn off the tiny box and fall past its edge | Set BoxShape3D **Size** = BoxMesh **Size** |
| D | Player's `CollisionShape3D` has no shape, is **Disabled**, or isn't a direct child of the CharacterBody3D | Shape → **New CapsuleShape3D**; untick Disabled; drag it directly under Player |
| E | Player's **Collision → Mask** doesn't include the ground's **Collision → Layer** (e.g. mask empty, or ground moved to layer 3) | Ground: Layer **1**. Player: Mask has **1** ticked |

Things that were tested and did **not** cause falling in 4.3: scaling the ground StaticBody3D
(it works, though resizing the shape is cleaner), and spawning the player partly inside the
floor (it gets pushed up out of it).

Not tested, but worth ruling out if none of the above match: the "ground" root is a different
node type (e.g. `Node3D`, `Area3D` or `RigidBody3D` instead of `StaticBody3D`). Click the node
and read the type at the top of the Inspector.

The new `player_first_person.gd` prints an error for cause D and an empty mask on startup, and
if you fall below `y = -50` it teleports you back to spawn and prints a warning, so you can keep
debugging instead of restarting.

---

## 2. Known-good node hierarchy

### `player/player.tscn`
```
Player (CharacterBody3D)         script: player_first_person.gd
├── CollisionShape3D             shape: CapsuleShape3D
└── Head (Node3D)
    └── Camera3D
```

The Player's origin is at its **feet** (the capsule is lifted by half its height). This makes
"place the player on the ground" mean "set Y = 0", and makes the camera height obvious.

| Node | Inspector setting | Value |
|---|---|---|
| Player | Collision → Layer | **2** only (the "player" layer) |
| Player | Collision → Mask | **1** (world) |
| Player | Script | `res://player/player_first_person.gd` |
| CollisionShape3D | Shape | New **CapsuleShape3D**: Radius **0.4**, Height **1.8** |
| CollisionShape3D | Transform → Position | (0, **0.9**, 0) |
| Head | Transform → Position | (0, **1.6**, 0) |
| Camera3D | Current | **On** |
| Camera3D | FOV | 75 |

Why Layer 2 for the player: later, enemy/interaction raycasts can choose whether to hit the
player, and world props on layer 1 don't need to care. Layer 1 also works for now.

### `levels/test_level.tscn`
```
TestLevel (Node3D)
├── WorldEnvironment             Environment → Background: Sky, ProceduralSkyMaterial
├── Sun (DirectionalLight3D)     rotated to point down at an angle, Shadow: On
├── Ground (StaticBody3D)        Position (0, -0.5, 0)  → top surface at y = 0
│   ├── MeshInstance3D           Mesh: BoxMesh, Size (50, 1, 50)
│   └── CollisionShape3D         Shape: BoxShape3D, Size (50, 1, 50)
├── StoneBlock (StaticBody3D)    Position (4, 0.5, -6) — something to jump onto
│   ├── MeshInstance3D           BoxMesh (2, 1, 2)
│   └── CollisionShape3D         BoxShape3D (2, 1, 2)
└── Player (instance of player.tscn)   Position (0, 2, 0)
```
Ground: Collision → Layer **1**, Mask **1** (defaults).

Click-by-click for the ground, from an empty 3D scene:
1. Scene dock → **+** → search `StaticBody3D` → Create. Rename to `Ground`.
2. Select Ground → **+** → `MeshInstance3D`. Inspector → Mesh → **New BoxMesh** → click it →
   Size `50, 1, 50`.
3. Select **Ground** again (important — not the mesh) → **+** → `CollisionShape3D`.
   Inspector → Shape → **New BoxShape3D** → click it → Size `50, 1, 50`.
4. Select Ground → Inspector → Transform → Position `0, -0.5, 0`.

Shortcut for complex meshes later: select a MeshInstance3D → top toolbar **Mesh** →
**Create Trimesh Static Body**. It builds the StaticBody3D + CollisionShape3D for you.

### Input Map
Already in `godot/project.godot`. In your own project: **Project → Project Settings → Input
Map**, add `move_forward` W, `move_back` S, `move_left` A, `move_right` D, `jump` Space,
`sprint` Shift, `interact` E. (The script also adds these at runtime if they're missing.)

---

## 3. Controller behaviour (`godot/player/player_first_person.gd`)

`godot/` is the up-to-date version. `docs/godot-starter/player_first_person.gd` is the
movement-only script from step 2, kept for copying into other projects (it has no HUD or
interaction code).


- Mouse look: body yaws, `Head` pitches, clamped to ±85°.
- **Esc** frees the mouse; **left-click** recaptures it.
- WASD with acceleration (`ground_accel`), weaker steering in the air (`air_accel`).
- Shift sprint, Space jump (only when `is_on_floor()`).
- Startup self-check for missing/disabled player collision shape or empty mask.
- Fall-safety: below `kill_y` you respawn at your start position with a warning.

All tuning values are `@export`, so you can change them in the Inspector on the Player node.

---

## 4. Next systems, in order

### 4.1 Interaction raycast (E to use/talk) — done
Built in `godot/`. Look at something within 2.5 m: a `[E] ...` prompt appears under the
crosshair, and pressing E uses it.

- `Player/Head/Camera3D/InteractRay` (RayCast3D): Target Position `(0, 0, -2.5)`, Mask **1**.
  The player is on layer 2, so the ray never hits the player's own capsule. Walls are on
  layer 1, so you can't use things through a wall.
- `Player/HUD` (`ui/hud.tscn`): crosshair, prompt label, and a message label that fades after a
  few seconds (`player.show_message(text)`).
- **The contract:** any physics body with an `interact(player)` method is usable. An optional
  `prompt` property sets the on-screen text. No base class or group is required.
- Examples in the test level:
  - `interactables/sign.gd` (StaticBody3D): set **Text** in the Inspector.
  - `interactables/door.gd` (AnimatableBody3D): swings 100° on E.

Making a new interactable: add a StaticBody3D with a MeshInstance3D and CollisionShape3D (both
**direct children**, the same cause B rule), attach a script with `var prompt := "..."` and
`func interact(player): ...`.

**Door gotcha (tested in 4.3):** rotate the **AnimatableBody3D itself**, with the mesh/shape
offset inside it so the body's origin is the hinge. If you rotate a parent Node3D instead,
the door *looks* open but its collision stays where it was.

### 4.2 Simple dialogue — done
See [DIALOGUE.md](DIALOGUE.md). The `GameState` autoload it added (`race`, `flags`) is what
race selection builds on.

### 4.3 Race selection — done
See [RACES.md](RACES.md).

Inventory, skill-use XP and faction reputation all hang off that same `GameState` autoload,
so building 4.3 early pays off.
