# Art Direction & Assets

**Platform:** PC (Windows and Linux), on Godot's **Forward+** renderer. The Android build is
for testing on a phone only: it runs, it looks flatter, and nothing is tuned for it.

**Target look:** Avowed / Skyrim. Grounded, close-to-real materials, with magic that is
obviously *not* real: glowing runes, cold light, drifting motes, haze.

The plan to get there on a solo budget:
1. **The mood comes from lighting, not assets:** bounce light, haze, volumetric fog,
   film-style tone mapping and a colour grade per region. Most of this is done (LOOK.md,
   "Lighting on PC").
2. **Real-looking base:** photo-scanned CC0 textures and models (Poly Haven, ambientCG).
3. **The mystical layer is built in-engine:** emissive materials, coloured lights, particles.
4. **One level of realism for everything.** Photo-scanned rocks next to block people look
   worse than either alone. Hold every asset to the same standard.

## How assets get into the game

**Most levels are generated.** Every region except the Vale's test level is written by a
builder script (`levels/builders/build_*.gd`). Anything you place by hand in a generated
`.tscn` is wiped the next time its builder runs. So:

- **Materials** go in through the builders' material helpers (`builder_base.gd`: `mat()`, and
  `box()` with a `surface_stone` / `surface_wood` tag). Swapping those helpers to real texture
  sets re-skins every region at once. *(Not done yet: this is the next asset step.)*
- **Models** (props, buildings, trees) go in as scenes the builders place, in place of the
  greybox boxes.
- **The Vale's test level** (`levels/test_level.tscn`) is hand-made. You can edit it in the
  editor directly.
- **Sounds** need no code: `systems/sfx.gd` plays `assets/sfx/<name>.wav` or `.ogg` by name.
  Drop a file with the same name over a placeholder (`footstep_stone_1`, `parry`,
  `wolf_growl`, `ambience_night`, and so on: 47 in all) and it's used.

## What's in the project now (no downloads)

| File | What |
|---|---|
| `levels/atmosphere.tres` | The shared outdoor environment: sky, ACES tone mapping, SSAO, glow, distance fog, volumetric fog, **SDFGI bounce light, SSIL**, colour grade. Every outdoor level uses it |
| `levels/day_night.gd`, `levels/moods/` | The sun, moon, sky and fog through the day, and each region's weather (LOOK.md) |
| `props/stone_circle.tscn` | 7 standing stones with glowing runes, altar, floating crystal (E to touch), drifting light motes |
| Noise materials | Godot-generated stone, wood and grass variation. **Placeholders** until real textures arrive |
| `assets/sfx/` | 47 synthesised placeholder sounds (`tools/make_placeholder_sfx.py`) |
| `assets/models`, `textures`, `hdri`, `audio` | Empty folders for downloads |
| `CREDITS.md` (in `godot/`) | License log. Fill it in as you download |

## Download list (in the order to do it)

**1. Sound** (biggest change for the least work):
- A fantasy sound pack: footsteps (stone, wood, grass), sword swings, hits, parries, a bow,
  spell casts, wolves, UI clicks.
- Ambience loops: day, night, cellar or cave, town, wind.
- The **Sonniss GDC Game Audio Bundle** is royalty-free and free every year: gigabytes of it.

**2. Textures** (Poly Haven, ambientCG; both CC0). Take **2K** for big surfaces (ground,
walls, cliffs), **1K** for small props. 4K/8K files bloat the repo and won't show the
difference at play distance.
Download the Diffuse/Color, Normal **GL**, Roughness and AO maps. Godot uses the
**OpenGL (GL)** normal convention: if a site offers "DX" and "GL", take GL.
- [ ] Forest floor / grass with dirt (the Vale, the Riverlands)
- [ ] Dry ash ground (the Grieving Fields)
- [ ] Mossy rock and rough cliff stone (standing stones, walls, Karrowdeep)
- [ ] Cobbles or flagstones (Ilunhall, Weirholt's streets)
- [ ] Plaster or adobe (houses; the Glass Coast)
- [ ] Old wood planks, and tree bark
- [ ] Sand (the Glass Coast)

**3. Characters**, the hardest category for this look:
- **Free:** MakeHuman exports are CC0 and give realistic humans. Ears and proportions can be
  pushed towards elves and orcs in Blender. **Mixamo** rigs a humanoid and has hundreds of
  free animations (idle, walk, run, attacks, hits, deaths).
- **Paid:** realistic medieval character packs on **Fab** and ArtStation. Realistic orcs,
  Deepfolk and small-folk are rare.
- One rigged base with a shared set of animations can replace every block figure in the game
  (NPCs, bandits, guards), with the race and role looks layered on.

**4. Trees and foliage:** trees are the hardest thing to get free and realistic. Expect to buy
a pack, or use a tree generator. Take packs with LODs (lower-detail versions for distance).

**5. Modular kits:** a medieval town kit (walls, roofs, doors, stalls) and a dungeon or cave
kit, so the builders can place real pieces in place of boxes.

**6. Terrain:** Terrain3D for the wilds between towns (below).

**Skip HDRI skies for outdoor levels.** An HDRI is a photo of one moment's sky, and the game's
sky changes through the day (`day_night.gd` drives a procedural sky, clouds and stars). An HDRI
would freeze it. They're still useful for lighting a model-viewer or a fixed-time interior.

## Where to get them

| Source | What | License |
|---|---|---|
| **Poly Haven** (polyhaven.com) | Textures, scanned rocks and logs, HDRIs | CC0 |
| **ambientCG** (ambientcg.com) | Textures | CC0 |
| **MakeHuman** | Realistic base humans | CC0 exports |
| **Mixamo** | Rigging and animations | Free, Adobe's terms |
| **Sonniss GDC bundle** | Sound | Royalty-free |
| **Freesound** | Sound | Varies per file: CC0, CC-BY (credit needed), or NC (don't use) |
| **Fab** (Epic) | Everything; free assets every month | Read each one: some are licensed for Unreal only |
| **Humble Bundle** | Game-dev bundles (sound, Synty, kits), cheap | Per bundle |
| **ArtStation, itch.io** | Characters, kits, sound | Per item |

Quaternius, KayKit and Kenney (all CC0) are excellent but **stylized** (low-poly). They don't
fit this target. Use them only for placeholders, or if the look changes.

## Terrain3D

Installed in your local project. Setup steps for the test level are in
[TERRAIN3D.md](TERRAIN3D.md): your terrain goes in its own scene
(`levels/test_level_terrain.tscn`), and the test level loads it automatically.

The plan on PC: Terrain3D for the open wilds between settlements, and the builders keep
generating towns, dungeons and interiors. It's a native plugin, so the CI tests and every
export need it installed before a level depends on it.

## Using downloads in Godot

**Texture → material** (on the hand-made test level; generated levels go through the builders):
1. Copy the maps into `assets/textures/<name>/`.
2. Click `Ground/MeshInstance3D` → Inspector → Mesh → Material → **New StandardMaterial3D**
   (or edit the existing one).
3. **Albedo → Texture**: drag the *diffuse/color* map. **Normal Map**: tick Enabled, drag the
   *nor_gl* map. **Roughness → Texture**: drag the *rough* map. **Ambient Occlusion**: tick, drag *ao*.
4. **UV1 → Triplanar: On**, **World Triplanar: On**, **Scale** e.g. `0.25, 0.25, 0.25`.
   This tiles the texture across the ground with no UV work.

**Model with collision**:
1. Copy the `.gltf`/`.glb` and its textures into `assets/models/<name>/`.
2. Double-click it in FileSystem → **Advanced Import Settings** → click the mesh in the tree →
   tick **Physics** → Body Type **Static** → Shape Type: **Simple Convex** for rocks,
   **Trimesh** for big cliffs/buildings → **Reimport**.
3. Drag the file into the test level, or ask for it to be added to a builder. Turn on
   **Debug → Visible Collision Shapes** and walk into it to check.

**To have a Claude session wire something up:** commit the files (only the parts of a pack you
want) to a branch. A session can't browse stores, buy anything, listen to sound, or see files
that aren't in the repo.

Then add a row to `CREDITS.md` for each one.
