# The look (greybox, until there's art)

No art yet. Instead, the greybox is built so you can tell what you're looking at:
people are shaped by race and dressed by role, surfaces have texture, and the
ground goes on to the horizon.

## People: `systems/figure.gd`

`Figure.build(race, role, cloth, sitting)` puts a person together from simple meshes:
legs, body, arms, hands, a head with eyes and a nose, and hair.

**Race** sets the proportions and features:

| Race | Height | Build | Look |
|---|---|---|---|
| Human | 1.0 | 1.0 | brown hair |
| Elf | 1.06 | slim | pale skin, fair hair, pointed ears |
| Orc | 1.05 | broad | green skin, black hair, tusks |
| Small Folk | 0.68 | | big head, curls |
| Deepfolk | 0.8 | very broad | ruddy skin, red-brown hair and beard |
| Ashen | 1.04 | slim | ash-grey skin, bald, pale glowing eyes |
| Passenger | 1.12 | thin | pale skin, white hair, pale glowing eyes |

**Role** sets what they wear and carry:

| Role | Kit |
|---|---|
| guard | helmet, breastplate, spear |
| merchant | pack and bedroll |
| innkeeper | apron |
| worker | straw hat |
| hunter | hood, bow on the back |
| priest | robe, hood, stole |
| scholar | robe, cap, book |
| official | tall hat, collar |
| physician | robe, wide hat, beak mask |
| inquisitor | long coat, wide hat, lantern badge |
| mercy | robe, hood, white mask |
| child | smaller, with a bigger head |
| commoner | nothing extra |

**Cloth** is the colour of their clothes.

### Where figures are used

- **NPCs** (`interactables/npc.gd`). Set **Race** (a file name from `races/`, such as
  `small_folk`) and **Role** in the Inspector. In game, the plain capsule is swapped
  for a figure in the capsule's colour, unless **Cloth** is set. The collision capsule
  is shortened to fit shorter races, so the interact ray still finds them. Leave Race
  empty to keep the capsule.
  - In the editor you still see the capsule. The figure is built when the game runs.
  - In builders, the last argument of `npc()` sets the look, for example
    `"small_folk/merchant"`.
- **Companions** (`Companions.DEFS`: race, role, cloth). Brannoc is an elf hunter,
  Zora a human priest. When one is down, the figure lies on the ground.
- **The player's third-person body** (`player/player_view.gd`). It takes your race and
  is rebuilt if your race changes. Held weapons sit at that race's shoulder height.

### Enemies

Humanoid enemies (`enemies/bandit.gd`, and the cultist and inquisitor scripts that extend it)
are figures too. The look is set by three exports in the **Look** group:
- `look_race`
- `look_role`: `bandit` (hood, red face scarf, strap), `mercy` for cultists, `inquisitor`
- `look_cloth`

In game, the scene's placeholder body is replaced. The figure is built without arms, and
`Figure.arm()` hangs the arms on the scene's own shoulder pivots, so every attack, guard,
stagger and death pose still swings them, sword and all.

The clothes get a material of their own (`own_cloth`), so a hit flash tints only the enemy you
hit.

**Variety:** `look_vary` (on by default) picks race and clothes from the enemy's place in the
scene, so the same enemy looks the same every time. It uses separate hashes for race, colour and
shade, so the three choices don't move together.
- **Bandits:** mostly human, some orcs and elves, in leather, moss, grey wool or rust.
- **The Mercy:** humans, elves and Passengers, in the same robes.
- **Named enemies** turn it off and set their look. Inquisitor Hale does; so does Magister Vessa
  in the Undercroft, as a Lamp College scholar.

Wolves, wisps, the Stone Guardian and The First keep their own models. Wolves already had a head,
snout, ears, legs and tail. The Guardian and The First are meant to look like constructs.

### Who's who

These NPCs had their race set in the docs or dialogue:
- Teodor, Passenger (RIVERLANDS.md).
- Wenna, small folk (her dialogue).
- The Lanternfast crowd: Pim, a human child; Hettie, small folk; Orrin, a Passenger;
  Moss, Ashen (QUESTLINE.md).
- Ysolde, Ashen.

The rest were judgement calls; change them freely:
- Brannoc: elf.
- Ostap and Sergeant Dace: orcs.
- Jory: small folk.
- Hesk and Bram: Ashen.
- Everyone else: human.

## Surfaces: `levels/builders/builder_base.gd`

`mat(color, transparent, kind)` lays a noise texture from `levels/materials/` over the
colour, mapped world-space triplanar so it lines up across boxes of any size:

- **ground**: big soft patches. `box()` uses it for big flat slabs: grounds, roads,
  fields.
- **stone**: cracked, with a normal map. Used for anything `surface_stone`.
- **grain**: a fine grain for plaster, wood and cloth. This is the default.
- **plain**: no texture. Used for water.

`skirt(color)` lays ground out to the horizon (1.6 km square, no collision, below the
rivers), so the sky's dark underside no longer shows past a level's edge.

The Vale (`test_level.tscn`) is hand-made and keeps its own materials.

## Light: `levels/atmosphere.tres`, `levels/day_night.gd`

Ambient light is now a mix: 55% sky and 45% a fill colour. `DayNight` moves the fill
with the fog light: cool and dim at night, near-neutral by day. Shade used to be
strongly sky-blue.

## Moods: `levels/level_mood.gd`, `levels/moods/`

Each outdoor region has a mood: its weather and colour, laid over the day/night cycle. The clock
still runs; the mood only tints it and thickens it. `DayNight` applies it every time it sets the
hour. To change one, set it as the level's **DayNight > Mood**, or edit the `.tres` in the
inspector.

| Region | Mood | Look |
|---|---|---|
| The Greywater Vale | `vale` | A touch cooler and crisper |
| Weirholt and the Riverlands | `riverlands` | Damp: green-grey mist, a little cloud |
| The Grieving Fields | `fields` | Overcast: grey sky, dim sun, soft shadows, washed-out colour, thick fog |
| Ilunhall | `capital` | Hazy gold: a warm sun and haze, more glow, and more fill light at night from the city |

A mood can set:
- **Sky:** a tint, and cloud cover (`overcast`, which also dims the sun and softens shadows).
- **Sun:** a tint and a brightness.
- **Fog:** a tint, its density, and how much it glows towards the sun.
- **Grade:** ambient light, saturation, contrast, brightness and glow.

Builders pass a mood to `common()`, as in `common("Ilunhall", true, "capital")`.

**Nights are brighter now.** The shade's fill colour never drops below a moonlit blue
(`NIGHT_FILL`), and the night's ambient light is 2.2, so you can see the ground on a phone. It's
still dark. Stealth goes by the clock, not by how bright it looks, so this changes nothing in
play.

**The light-stone** in Ilunhall's eaves lights the halls around it twice as strongly
(`light_mult`), so at night the halls glow gold.

## Ground cover: `props/ground_cover.gd`, `props/foliage.gdshader`

Grass tufts, flowers, reeds and stones scattered over a region's grass, so greybox fields aren't
bare.

| Region | Style | What grows |
|---|---|---|
| The Vale | `meadow` | Grass, white, yellow and violet flowers, stones |
| Weirholt | `riverbank` | Lush grass, reeds, flowers, stones |
| The Grieving Fields | `ashfield` | Sparse grey grass, more stones |
| Ilunhall | — | None: it's paved |

**Where it grows:**
- A `GroundCover` node scatters points over its `area`.
- Each point is kept only if a ray from above lands first on a body in the `ground_cover` group
  (the region's grass).
- So nothing grows on roads, paving, in rivers, under houses, or inside trees.
- It's the same scatter every time (`scatter_seed`).

**Drawing:**
- Everything is drawn as MultiMeshes in 20 m chunks. Each chunk is culled on its own and hidden
  beyond the preset's clutter range.
- The grass sways in the wind; the shader does it, so there's no CPU cost.
- Stones cast shadows. Grass doesn't.

**Graphics presets** (new keys `clutter` and `clutter_range`):

| Preset | Amount | Drawn out to |
|---|---|---|
| Low | none | — |
| Medium | half | 40 m |
| High | as designed | 55 m |
| Ultra | 1.6× | 85 m |

Changing the preset rebuilds the cover.

**Cost:** the scatter is built when the level loads, in the loading frame, so it isn't a hitch a
moment into play.
- Weirholt, the biggest: about 25,000 pieces, 150 ms on a desktop. Expect a few times that on a
  phone.
- Medium halves it.

Builders: `ground_cover(style, area)`, plus `.add_to_group("ground_cover", true)` on the grass.

## Trees and houses

**Pines** (`systems/tree_dresser.gd`, autoload `TreeDresser`):
- Any MeshInstance3D named `Canopy` or `Crown` whose mesh is a cone is swapped, as it enters the
  tree, for three stacked, faceted cones.
- The layers are darker at the bottom, and each tree is a slightly different green, picked from
  where it stands so it's the same every time.
- It works on the hand-made Vale and the generated regions alike. Collision is untouched.
- The Hollow Oak's canopy isn't a cone, so it keeps its own look.

**Houses** (builder `house()`): the block is still the collision. On top of it, each house gets:
- a gabled roof along its long side, with a ridge beam and wall gables under it;
- dark corner posts;
- a door, and two windows, on the wall facing the middle of the level, where the streets are;
- one window at the back;
- a stone chimney.

The windows (`props/light_stone.gd`, with new `surface` and `glow` colours) are dark glass by day
and glow warm at night. Weirholt, Greyfold and Ilunhall's harbour houses were rebuilt with it.
The Vale's waystation is hand-made and unchanged.

## Water and sky

**Water** (`levels/materials/water.gdshader`, builder `water_mat(flow)`):
- Two layers of ripples scroll with the flow.
- It's darker looking straight down, and lighter and glossy at a glance (a cheap fresnel), so it
  catches the sky.
- Weirholt's river flows south, Ilunhall's fjord drifts, and the culvert's runoff and the
  Undercroft's cistern sit still (or nearly).

**Clouds and stars** (`levels/sky_dome.gd`, `levels/sky_dome.gdshader`):
- They're drawn on a great dome that follows the camera. `DayNight` makes one for each outdoor
  level, so no scene needs editing.
- Clouds drift, lit by the sun's colour and dark at night.
- The stars come out after dusk and twinkle.
- Cloud cover comes from the mood (`LevelMood.clouds`): Vale 0.4, Riverlands 0.55, Fields 0.85,
  Ilunhall 0.3.
- They're not in the sky shader on purpose. A sky shader that animates recomputes the scene's
  ambient light every frame, which phones can't spare.

**The Vale** now has the ground skirt out to the horizon too, so there's no dark band past its
edge.

## Renderers (a caveat)

On Android the game runs on the **Mobile** renderer. The screenshots for this pass were
taken with it (Vulkan, through a software driver).

The Mobile renderer has no SSAO and no volumetric fog. `atmosphere.tres` has both
turned on, but you only get them on desktop (Forward+).

The **Compatibility** (OpenGL) renderer looks quite different: brighter and more washed
out. Don't judge the look from it.
