# The Glass Coast: Sarabh, the Scar, and the Under-Glass

The seventh region, built 2026-10-26. It follows A.'s card from the Rootwell: the founders'
confession wasn't burned, "Look under the glass." Calaneth reads that as the Glass Coast, in
Sundra.

The lore is in `docs/lore/WORLD.md` and `PEOPLES.md`:
- the Mage War's two colleges fought over the deepest of the twelve wells here and burned the
  desert to glass: the Scar;
- the Glass College (Sight) stands on its edge, built by the founders;
- Sundra's oases are ruled by the Oasis Thrones under a Sovereign of Wells, and water is
  metered.

It's a greybox. The names, people and quests here are *(suggested)*.

**Story pacing (the user's call):** the founders' confession is the truth scene, and it stays
late. The vault under the Scar is a **waypoint**: it ends in a sealed door, the Seal of the
Twelve, that opens only when all twelve wells "answer". A socket lights for each well you've
dealt with. A.'s card shows she couldn't open it either. Nothing opens it yet.

## Getting there

- **From Ilunhall:** take the **ship** at the west end of the quay (`ShipToGlass`). You land
  on Sarabh's mole.
- **Back:** the ship at the end of the mole (`ShipHome`).
- **Fast travel:** the Glass Coast is a region. You can arrive at the mole, Sarabh's oasis,
  the Glass College, the Mercy's camp, the Under-Glass ring and (once found) the vault.

## The place (`levels/glass_coast.tscn`)

Outdoors, with its own mood (`levels/moods/glass.tres`): hot gold light, a little haze, dust
in the air. North is −z.

| Part | What's there |
|---|---|
| **The mole** (south) | The ship to Ilunhall, the Mole Warden |
| **Sarabh** | Flat-roofed houses round **the oasis well**, palms. Nadira's stall, Amir's tally-booth (and his chest), Jamila's kiln, **the Cistern House** (Rafiq; an alcove bed for 10 gold), Samira's house, the Square Warden |
| **The Glass College** (north-east) | A spire of fused glass. Seer-Magister Ophira on its steps |
| **The Scar** (north) | A plain of fused glass. Glass shards, and three knuckles of **singing glass** |
| **The Mercy's camp** (west edge of the Scar) | Three tents and a fire: Sister Ammara |
| **The black ring** (middle of the Scar) | A ring of black glass round a stair, and **the ward** over it |

**The Under-Glass** (`levels/glass_vault.tscn`):
- A black-glass stair down into a long hall with glass pillars.
- **The Glass Sentinel** (`enemies/glass_sentinel.gd`): the Stone Guardian's fight, in glass.
  It wakes when you walk into the hall (a `boss_arena`).
- **The Seal of the Twelve** on the far wall: twelve sockets. Lit ones show which wells are
  done:

  | Socket | Lit when |
  |---|---|
  | 1 | the Vale's stones (`stones_quest_done`) |
  | 2 | the Weirstones freed (`weirstones_freed`) |
  | 3 | the Deep Ring reported (`deep_ring_reported`) |
  | 4 | Seam Nine decided (`seam_resolved`) |
  | 5 | the Rootwell decided (`well_resolved`) |
  | 6 | this one: the Sentinel down (`glass_sentinel_down`) |
  | 7–12 | dark: wells not in the game yet |

## People

| Who | Look | What |
|---|---|---|
| **Seer-Magister Ophira** | human scholar | The Glass College. Trains **Sight** to 70 (trainer `ophira`). One lead to the vault; gives you the ward-glass |
| **Sister Ammara** | human priest | The Mercy, waiting on the Scar for A. The other lead; the Mercy cut a way through the ward |
| **Collector Amir Tahan** | human official | The Sovereign's water-collector. Holds Samira's tally-stone |
| **Samira** | human commoner | Couldn't pay the water-due. Gives The Sovereign's Due |
| **Jamila the Glassblower** | orc worker | At her kiln. Gives Glass That Sings |
| **Nadira** | human merchant | By the oasis: merchant `nadira` (water, bread, potions, a sword, lockpicks, two Sight tomes) |
| **Rafiq of the Cistern House** | small-folk innkeeper | Sells the alcove (`cistern_bed`) |
| **The Square Warden**, **the Mole Warden** | guards | The Sovereign's law (CRIME.md) |

**Routines:** Samira, Nadira and Jamila keep a day, and gather by the oasis in the evening.

**New faction:** **the Oasis Thrones** (`oasis_thrones`), known once you meet Amir. It's also
the Glass Coast's faction for crime.

## Quests

| Quest | Giver | Steps | Endings |
|---|---|---|---|
| **Under the Glass** (main) | Opens on `well_reported` (the Rootwell reported to Calaneth) | Take ship; find out what's under the glass (Ophira, or Ammara); get past the ward; go down; get past the Sentinel; study the seal; tell Ophira or Ammara | See below |
| **The Sovereign's Due** | Samira | Get her tally-stone back from Amir, then bring it to her | Pay the 60-gold due (Oasis Thrones +5), lean on him (Intimidate 45; Oasis Thrones −5), or take it from his chest (Apprentice lock; theft). Samira pays 25 |
| **Glass That Sings** | Jamila | Work three singing shards free on the Scar. They only sing at night (`requires_night`) | Jamila pays 60 gold and two magicka potions |

### Under the Glass: the choices

**The ward.** Three ways past it:
- **Ophira's ward-glass:** look at the ward through it. The lens cracks doing it, so it's used
  up (`ward_lifted`).
- **The Mercy's cut:** if Ammara told you about it (`mercy_way`).
- **Sight 40:** See the old seam in the ward (`ward_seen`).

**The seal.** It can't be studied while the Sentinel stands. Then you find **A.'s card**
(`seal_card`, a book) in the door's seam: she's tried the door, it wants all twelve, and she
says to count the dark sockets. Reading the seal sets `seal_read`. The door doesn't open.

**Who you tell:**
- **Ophira, everything** (`glass_told`): 150 gold. The College will send its seers after the
  wells too.
- **Ophira, a lie** (Glamour 40, `glass_lied`): it's a dead end. 50 gold.
- **Ammara** (`glass_mercy`): two healing potions. The Mercy will go after the wells.

These are hooks for later; nothing reads them yet.

## Building and editing the level

- Run `godot --headless --path . -s levels/builders/build_glass_coast.gd` from `godot/`. It
  writes both scenes.
- The Ilunhall builder (`build_ilunhall.gd`) adds the ship west.
- The builder's helpers are local to it: `glass_mat()`, `flat_house()`, `palm()`, `shard()`.
- `stone_guardian.gd` gained `body_color`, so a hit's flash fades back to the right colour
  (the Sentinel is glass, not stone).

## Known limits

- **A greybox coast.** The houses are blocks, the College is a solid spire, and the sea is a
  flat plane.
- **The vault is one hall, one fight.**
- **The seal never opens.** Only six of the twelve wells exist, and sockets 7–12 are dark.
- **The sockets read "dealt with" loosely.** Socket 2 needs the Weirstones *freed*; other
  endings there leave it dark. The others light for any ending.
- **The reports to Ophira or Ammara change nothing yet.** The College and the Mercy going after
  the wells is a hook.
- **The navmesh logs one edge-merge warning** when the coast loads (Godot 4.3, overlapping
  boxes). Paths are fine: the test walks from the mole to every place that matters.

## Tests

`tests/test_glass_coast.gd` checks:
- the ship both ways;
- every person;
- the law;
- the fast-travel arrival points;
- **a way on foot from the mole** to the College steps, the Mercy's camp, the ward, the inn,
  the kiln, Amir's booth and the singing glass, plus a check that it can fail;
- the sockets (one lit beforehand, the Sentinel's lighting when it falls);
- all three quests, the merchant, the trainer and the bed.

It has three variants:

| Variant | Lead | Ward | Due | Told |
|---|---|---|---|---|
| `college` | Ophira | the ward-glass | paid | Ophira, everything |
| `mercy` | Ammara | the Mercy's cut | Intimidate | Ammara |
| `sight` | Ophira | Sight 40 | stolen from the chest | Ophira, a lie (Glamour 40) |
