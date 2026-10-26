# Karrowdeep: the city in the mountain, and Seam Nine

The fifth region, built 2026-10-26. It follows the lead from Ilunhall's Undercroft: the
conduit was cut from Karrowdeep seam-stone, and Vessa's ledger (if you turned her) says "The
Deep Guilds have a seam under the lowest gallery that sings. A. wants it before the Guilds dig
it out."

The city's lore is in `docs/lore/WORLD.md` and `PEOPLES.md`:
- the Deepfolk's city fills a hollow mountain, its halls terraced round a central chasm and lit
  by veins of rune-ore;
- markets stand on bridges over the dark;
- the guilds' law is carved into the walls;
- below the lowest gallery the mines go down further than anyone admits, and the **blind
  choir** sings.

It's a greybox. The names, people and quests here are *(suggested)*.

## Getting there

- **From Ilunhall:** take the **Deep Road** at the east end of the quay. You arrive in the
  Gate Hall.
- **Back:** the Deep Road in the Gate Hall's south wall.
- **Fast travel:** Karrowdeep is a region, so it's in fast travel too, from the Gate Hall,
  the Market Bridge, the Table, both Colleges and the Lamp and Pick.

## The place (`levels/karrowdeep.tscn`)

All of it is inside the mountain: a 25 m ceiling, no sky, and no day/night. The rune-ore's
cold blue light comes from the walls; braziers light the places people live.

| Part | Height | What's there |
|---|---|---|
| **The Gate Hall** (south) | 0 | The Deep Road, the Warden of the Bridge, Assayer Pell's bench and scales, Delvings (homes) |
| **The Market Bridge** | 0 | Stalls on a bridge over the chasm; Grima Coldiron's. "No guild owns the bridge." The chasm's floor is 40 m down |
| **The West Ledge** | 0 | **The Anvil College** (stone-shapers; Master Bek at his bench) |
| **The East Ledge** | 0 | **The Seal College** (rune-cutters; Magister Orsa on its step), Delvings |
| **The Guild Gallery** (north) | 0 | **The Table of Guildmasters** (Guildmaster Hrodna), **the Law Wall**, the Gallery Warden |
| **The Lowest Gallery** (south-west) | −8 m, down the Cut Stair | **The Lamp and Pick** (Torvald; a bed for 10 gold), Ebba Lowlamp, and **the Seal Door** to Seam Nine |

**Seam Nine** (`levels/karrowdeep_seam.tscn`):
- A drift down from the Seal Door into a worked cavern held up by old guild props.
- In the far wall, **the seam**: rune-ore that is really light held in stone, singing one long
  chord. The Mercy's cages and harvest-frame stand at the seam's face.
- Three Mercy miners and **Brother Keld**, their foreman, with his orders on his table.
- **The Deep**: a roped-off shaft. Listen, and you hear the blind choir.

## People

| Who | Look | What |
|---|---|---|
| **Guildmaster Hrodna** | deepfolk official | Keeps the Table this year. Holds the seal-key to Seam Nine |
| **Magister Orsa Deepcut** | deepfolk scholar | The Seal College. Trains **Runecraft** to 60 (trainer `orsa`). Gives The Anvil and the Seal |
| **Master Bek** | deepfolk worker | The Anvil College. Has the Seal College's rune-slate |
| **Grima Coldiron** | deepfolk merchant | The Market Bridge: merchant `grima` (ingots, tools, two rune tomes) |
| **Torvald of the Lamp** | deepfolk innkeeper | The Lamp and Pick. Sells the bed (`lamp_bed`) |
| **Ebba Lowlamp** | deepfolk worker | A hewer. Hears carts and singing past the Seal Door. Gives The Short Weight |
| **Assayer Pell** | small-folk official | Weighs the hewers' ore, light |
| **The Warden of the Bridge**, **the Gallery Warden** | guards | The Table's law (CRIME.md) |

**Routines:** Grima, Ebba and Bek keep a day; they gather at the Lamp and Pick in the evening
and go home at night (ROUTINES.md). So the market is shut at night, and Bek's bench is
unwatched.

**New faction:** **the Deep Guilds** (`deep_guilds`), known once you meet Hrodna. It's also
Karrowdeep's faction for crime (`Crime.FACTIONS`).

## Quests

| Quest | Giver | Steps | Endings |
|---|---|---|---|
| **The Seam That Whispers** (main) | Opens on `light_reported`, whatever you did with Vessa | Take the Deep Road; find whose seam it is (Hrodna, or Ebba); get past the Seal Door; go down; defeat the Mercy and Brother Keld; decide the seam; tell Hrodna | See below |
| **The Anvil and the Seal** | Magister Orsa | Get the rune-slate from Master Bek, then bring it to Orsa | Talk him round (Persuade 40), buy it (a 120-gold bribe, less with Speech), or take it off his bench (theft: it's his). Orsa pays 100 gold, Deep Guilds +5 |
| **The Short Weight** | Ebba Lowlamp | Look at the assay scales (the counterweight's hollow) | Tell Hrodna (Pell's fined, Deep Guilds +10, Ebba pays you 40), or take Pell's 80 gold (Ebba knows) |

### The Seam That Whispers: the choices

**The Seal Door.** Four ways past it:
- **Ebba's word:** talk to Ebba first, and tell Hrodna her own hewers hear the carts. She gives you the seal-key (`seal_key_given`).
- **Persuade Hrodna** (Persuade 50). Same key.
- **Steal the key** from Hrodna's strongbox behind the Table (Expert lock). It's theft (CRIME.md).
- **Unpick the seals** with Runecraft 40 (`seal_unpicked`).

Opening it with the key leaves the key in the door.

**The seam:**
- **Bring the face down** (`seam_collapsed`): the lights go free, singing, up through the rock. Hrodna pays 50 for the Mercy, and the Deep Guilds −10 for the richest seam under the mountain.
- **Shut the harvest-frame** (`seam_sealed`): the seam stays, and it's the Table's again. Hrodna pays 200, and the Deep Guilds +15.

**Brother Keld's orders** (`keld_orders`, a book) are on his table. They're from A.:
- every cart of seam-stone is a cage of lights (Weirholt's mill has one, and Ilunhall's conduit);
- don't go down to the Choir, "not yet";
- bring the harvest to Ithmarren by the next dark of the Wanderer.

Show them to Hrodna (`keld_shown`). The quest's journal remembers them. **Ithmarren is the
next lead**: see ITHMARREN.md. The Hollow Way runs out of the Guild Gallery's north-east corner.

**The blind choir.** Listening at the Deep sets `heard_blind_choir`. It's a thread for later.
Nothing else uses it yet.

## Building and editing the level

- Run `godot --headless --path . -s levels/builders/build_karrowdeep.gd` from `godot/`. It
  writes both scenes.
- The Ilunhall builder (`build_ilunhall.gd`) adds the Deep Road east.

## Known limits

- **A greybox city.** The Colleges, Delvings and the Table are solid blocks or open halls;
  there are no interiors.
- **Seam Nine is small:** one drift and one cavern, one fight.
- **The seam looks the same after you collapse it.** The rubble isn't modelled; only the
  journal and Hrodna know.
- **The blind choir is a hook only.**
- **The Seal Door's key is in two places:** Hrodna's neck and her strongbox. Either opens
  it once.
- **Underground means no clock you can see.** Routines still keep time.

## Tests

`tests/test_karrowdeep.gd` checks:
- the Deep Road both ways;
- every person;
- the law;
- the fast-travel arrival points;
- all three quests, the merchant, the trainer and the bed.

It has three variants:

| Variant | Seal Door | Seam | Slate | Pell |
|---|---|---|---|---|
| `key` | Ebba's word, Hrodna's key | collapsed | talked round | reported |
| `steal` | the key from her strongbox | sealed | taken off the bench | took his money |
| `rune` | Runecraft 40 | collapsed | bought | reported |
