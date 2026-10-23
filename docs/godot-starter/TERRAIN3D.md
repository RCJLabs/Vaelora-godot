# Terrain3D in the Test Level

These steps put a sculpted, textured Terrain3D landscape under the existing level, with
collision and wolf pathfinding working. They're written against **Terrain3D 1.0.x** (the
Asset Library version) and its documentation.

> **How the code was verified:** the cloud session that builds this project can't download
> Terrain3D, so the level code was tested with a stand-in object that provides the same
> function Terrain3D does (`generate_nav_mesh_source_geometry`). The editor clicks below
> come from Terrain3D's own docs and haven't been clicked through by that session. If a
> button name doesn't match your version, tell me what you see.

## How it fits together

- **Your terrain lives in its own scene:** `levels/test_level_terrain.tscn`. Updates to
  `test_level.tscn` can never overwrite your sculpting.
- **`TerrainSlot`** (a node in the test level) loads that scene automatically if the file
  exists. When the game runs, it removes the old green box ground so the two don't overlap.
  In the editor it shows the terrain too, but leaves the box ground alone.
- **Collision:** Terrain3D's collision defaults to **layer 1 / mask 1**, which is our "world"
  layer, so the player, wolves, interaction ray and sword all work on it unchanged. The
  default **Dynamic** collision exists within **64 m of the camera**. The wolf den is about
  30 m away, so that's enough here.
- **Navigation:** `NavigationRegion3D` bakes when the level loads, and now includes the
  terrain's **painted navigable areas**, the same way Terrain3D's own baker does.

## Where things are (keep this area flat)

Everything in the level sits at height **0**. New Terrain3D regions are also flat at 0, so
the safest plan is to **sculpt around this area, not under it**:

| What | Position (x, z) |
|---|---|
| Spawn | 0, 0 |
| Maren, sign, stone block | 2, -4 / -2, -4 / 4, -6 |
| Wall + door | x -3.6..3.6, z -10 |
| Brannoc | -6, -3 |
| Stone circle (radius ~5) and rune shards (~8 m around it) | -11, -9 |
| Wolf den (they wander ~4 m) | 8, -30 |
| Bandit camp (tents, fire, chest; the bandits fight within ~28 m) | -34, -34 |
| Waystation campfire / climbing fence / boulder | 6.5, 2.5 / 12, -12 / -16, 3 |

Roughly **x −40 to 20, z −40 to 10** is the "village" (the bandit camp is the south-west corner). Keep it flat, or gently rolling and
then nudge props up or down to sit on the ground.

## Step 1: Create the terrain scene

1. **Scene → New Scene.** Under "Create Root Node" click **Other Node**, search
   `Terrain3D`, **Create**.
2. **Ctrl+S** and save it as exactly `res://levels/test_level_terrain.tscn`. The name
   matters: that's what `TerrainSlot` looks for.
3. With the Terrain3D node selected, find **Data Directory** in the Inspector, click the
   folder icon, create a new folder `levels/terrain_data`, and select it. **Ctrl+S** again.
   (Terrain3D stores the heightmap and painting there, not in the .tscn.)

## Step 2: Add regions (where the terrain exists)

Regions are 256 × 256 m squares on a grid, with one corner at the world origin. Our level
spreads into negative x and z, so it needs **four** of them.

1. Select the Terrain3D node. Its toolbar appears on the left of the 3D view.
2. Pick the **Region** tool (the first one, a square with a cross), or press **E**.
3. Press **1** to show the region grid.
4. Click once in each of the four squares that meet at the origin: one in front, behind,
   left and right of the centre.

There's **no collision outside regions** (the "WorldNoise" background is only visual). If
you walk off a region, you fall and get put back at spawn.

## Step 3: Textures

If you installed Terrain3D's **demo** folder, you already have CC0 ambientCG textures that
match the grounded art style: `demo/assets/textures/ground037_*` (grass/dirt) and
`rock023_*` (cliff rock).

1. Open Terrain3D's **asset dock** (bottom panel or right sidebar, labelled with Textures /
   Meshes buttons).
2. Drag `ground037_alb_ht.png` onto the **Add Texture** icon. Then click the pencil on its
   thumbnail (or right-click it), and in the Inspector set **Normal Texture** to
   `ground037_nrm_rgh.png`.
3. Do the same with `rock023_alb_ht.png` and `rock023_nrm_rgh.png`.
4. **Autoshader** (grass on flat ground, rock on slopes, automatically): select the
   Terrain3D node → **Material** → tick **Auto Shader**. It uses texture **0** as the base and
   **1** on slopes by default (`auto_base_texture` / `auto_overlay_texture` in the material's
   shader parameters), which is why the grass goes in first and the rock second. New regions
   are autoshaded by default.

Using your own textures later: Terrain3D packs albedo+height and normal+roughness into two
PNGs (**Terrain3D Tools → Pack Textures**), and all textures must share size and import
settings. See its "Texture Prep" page. Add each texture to `CREDITS.md`.

**Terrain turned white?** That's a texture size or format mismatch. See Terrain3D's
Troubleshooting page.

## Step 4: Sculpt

- **R**: **Raise** (Ctrl+click lowers). **Shift**+click smooths.
- **Ctrl + Height tool**: picks the height under the cursor and flattens to it. Use it to
  repair the village area back to 0 if you go too far.
- Hills, a ridge behind the wolf den, a valley toward "Riverwatch" (the north road): keep
  it subtle at first. Our wolves can't climb steeper than about 45° (the navigation mesh's
  slope limit).

## Step 5: Paint where wolves can walk (important)

By default **no terrain is walkable** for navigation. Pick Terrain3D's **Navigable** tool
and paint (dark magenta) over the village area and anywhere wolves should be able to chase
you. Ctrl+paint removes it. Paint only what's needed: the bake runs every time the level
loads, and big painted areas make loading slower.

Unpainted terrain isn't a disaster: wolves then fall back to running straight at you, like
before pathfinding existed.

**Ctrl+S** to save the terrain scene.

## Step 6: See it in the level and play

1. Open `levels/test_level.tscn`. Your terrain appears under the props. The old green box
   ground is still there in the editor (it's removed when the game runs), so the two may
   flicker where they overlap at height 0.
2. **F5** (or F6 on the test level). Walk around, talk to Maren, chase or flee the wolves.
3. Debug views (top menu **Debug**):
   - **Visible Navigation**: the walkable area as a coloured overlay. It should cover your
     painted area.
   - **Visible Collision Shapes**: to see Terrain3D's collision, first set the terrain's
     **Collision Mode** (Inspector, *Collision* section) to *Dynamic / Editor* in the terrain
     scene (the default *Dynamic / Game* has no visible shapes). Switch it back afterwards
     for performance.

**Don't use any "Bake NavMesh" button for the test level.** Terrain3D's editor baker only
sees terrains saved inside the scene you're editing, and ours is loaded by `TerrainSlot`,
so an editor bake would leave the terrain out. Then, because the mesh would no longer be
empty, the automatic bake would stop running. If you baked by accident: select
**NavigationRegion3D** in the test level → **Clear NavigationMesh** in the toolbar above
the 3D view → save.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Fall through the ground right away | Standing outside a region (step 2), or the terrain's **Collision Mode** is *Disabled*, or its **Collision Layer** was changed from 1 |
| No terrain in the test level | File not named exactly `levels/test_level_terrain.tscn`, or the Terrain3D plugin is disabled (Project Settings → Plugins) |
| Box ground still there while playing | Same as above: the terrain scene didn't load |
| Wolves run straight at you and get stuck on hills | No **Navigable** paint (step 5), or a NavigationMesh was baked in the editor (see above) |
| Props float or are buried | You sculpted under them. Flatten the area back to 0 (Ctrl + Height) or move the props |
| Wolves fall through terrain far away | They're beyond the 64 m collision radius. Raise **Collision Radius**, or use *Full / Game* mode for small maps |

## Version notes

- `project.godot` in this repo lists Terrain3D under **[editor_plugins]**, so copying an
  update over your project keeps it enabled. The addon (`addons/terrain_3d/`) and demo are
  not in the repo. If you start using git for this project, either commit `addons/` so the
  project opens anywhere, or note in the README that Terrain3D must be installed from the
  Asset Library.
- Terrain3D 1.0.1 targets **Godot 4.4+**. If Godot asks to convert the project when you open
  it after an update, that's because this repo's `project.godot` still says 4.3. Converting
  is fine.
