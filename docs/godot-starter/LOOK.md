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

## Renderers (a caveat)

On Android the game runs on the **Mobile** renderer. The screenshots for this pass were
taken with it (Vulkan, through a software driver).

The Mobile renderer has no SSAO and no volumetric fog. `atmosphere.tres` has both
turned on, but you only get them on desktop (Forward+).

The **Compatibility** (OpenGL) renderer looks quite different: brighter and more washed
out. Don't judge the look from it.
