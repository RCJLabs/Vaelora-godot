# Ithmarren: the canopy city, and the Rootwell

The sixth region, built 2026-10-26. It follows Brother Keld's orders from Seam Nine: "Bring
what you have to the forest city by the next dark of the Wanderer. Ithmarren keeps its own
wells, and keeps them badly."

The city's lore is in `docs/lore/WORLD.md` and `PEOPLES.md`:
- the elves' city lives in the canopy of a forest of giant trees, with walkways,
  lantern-gardens and houses grown, not built;
- the Great Houses meet as the Moot of Houses, and lineage matters more than anything;
- the elves were "kindled" by the lights, live four hundred years, and are the people most
  prone to corruption;
- in public wisps are sacred; in private some houses run the essence trade.

It's a greybox. The names, people and quests here are *(suggested)*.

## Getting there

- **From Karrowdeep:** take the **Hollow Way** in the north-east corner of the Guild Gallery,
  through the mountain. You come out of the mountain's foot onto the forest floor, south of
  the city.
- **Back:** the Hollow Way in the mountain's foot.
- **Fast travel:** Ithmarren is a region. You can arrive at the forest road, the Gate Landing,
  the Lantern Gardens, the Veil College, the Moot Hall and the Root Door.

## The place (`levels/ithmarren.tscn`)

Outdoors, with its own mood (`levels/moods/canopy.tres`): green-gold light, pollen by day and
fireflies by night. The city is a set of decks on five giant trees, joined by railed walkways.
A long stair (the Bough Stair) climbs from the forest floor to the first deck.

| Part | Height | What's there |
|---|---|---|
| **The forest floor** | 0 | The Hollow Way, the road in, the Moot Tree's roots: **the Root Door**, the Root Warden, Rhosyn |
| **The Gate Landing** | 12 m | **The Hanging Lantern**: Maelis, a hammock for 10 gold. The Bough Warden |
| **The Lantern Gardens** | 12 m | Tamsin's stall, Fennick's beds and the **night-blooms**, garden lanterns |
| **The Veil Terrace** | 12 m | **The Veil College** (Glamour): Magister Sylvaine |
| **The Moot Hall** | 20 m | A ring of seats round **the Moot Tree**: Moot-Speaker Calaneth |
| **The Sennaveth Bough** | 20 m | **House Sennaveth**: Lady Ithariel, Steward Lirael, the house's coffer and letter-box |

**Rails:** every deck is railed, except where the walkways join it. A 12 m fall does about 60
damage and a 20 m fall about 110.

**The lanterns** in the Gardens, on the Gate Landing, the Veil Terrace and round the Moot are
light-stone (`props/light_stone.gd`). They glow brighter at night, and dim for good if the
well is unbound (`well_unbound`).

**The Rootwell** (`levels/ithmarren_rootwell.tscn`):
- A root-lined stair down into a hollow under the Moot Tree, held up by root pillars.
- In the middle is **the well**: a pool of light where hundreds of small lights turn slowly.
  It has root-cages round it and Lord Caerwyn's desk beside it, with A.'s card on it.
- The takers: two Mercy acolytes, two Sennaveth essence-takers, and **Lord Caerwyn
  Sennaveth**.

## People

| Who | Look | What |
|---|---|---|
| **Moot-Speaker Calaneth** | elf official | Speaks for the Moot. Gives the main quest's lead |
| **Lady Ithariel Sennaveth** | elf official (plum) | Keeps the Root Door's key, and her brother's secret |
| **Steward Lirael** | elf official | Guards Sennaveth's bough and its letter-box |
| **Magister Sylvaine** | elf scholar | The Veil College. Trains **Glamour** to 60 (trainer `sylvaine`). Gives A Lie Well Told |
| **Tamsin Leafwright** | elf merchant | The Lantern Gardens: merchant `tamsin` (potions, alchemy ingredients, arrows, a bow, two Glamour tomes) |
| **Maelis** | elf innkeeper | The Hanging Lantern. Sells the hammock (`lantern_bed`) |
| **Fennick** | small-folk gardener | Keeps the Gardens. Gives Night-Blooms |
| **Rhosyn** | elf commoner | Of a fallen House, essence-sick. Another lead to the well |
| **The Bough Warden**, **the Root Warden** | guards | The Houses' law (CRIME.md) |

**Routines:** Tamsin and Fennick keep a day, and gather in the Lantern Gardens in the evening.

**New faction:** **the Great Houses** (`great_houses`), known once you meet Calaneth. It's
also Ithmarren's faction for crime.

## Quests

| Quest | Giver | Steps | Endings |
|---|---|---|---|
| **The Well Kept Badly** (main) | Opens on `seam_reported` (Seam Nine reported to the Table) | Take the Hollow Way; find where the harvest goes (Calaneth, or Rhosyn); get through the Root Door; go down; defeat the takers and Lord Caerwyn; decide the well; tell Calaneth | See below |
| **A Lie Well Told** | Magister Sylvaine | Get this week's Sennaveth letter, then bring it to Sylvaine | Fool Lirael (Glamour 30), talk him round (Persuade 45), or take it from the letter-box (theft). Sylvaine pays 120 gold, and you keep the letter |
| **Night-Blooms** | Fennick | Pick three moonpetals from his beds. They only open at night (`requires_night`) | Fennick pays 40 gold and two healing potions. **Moonpetal** is a new alchemy ingredient (Restore Magicka, Cure, Regeneration) |

### The Well Kept Badly: the choices

**The Root Door.** Four ways through:
- **Lady Ithariel's leave:** Persuade 55. She gives you the root-key (`ithariel_leave`).
- **Shame her** with her own letter to her brother (from A Lie Well Told). She gives you the
  key (`ithariel_shamed`), and the Great Houses think a little less of you (−5).
- **Steal the root-key** from House Sennaveth's coffer (Expert lock). It's theft.
- **Glamour 40:** wear a Sennaveth face, and the roots let family in (`root_glamoured`).

Opening it with the key leaves the key in the knot.

**The well:**
- **Unbind it** (`well_unbound`): the root-cages break, the lights go home, and every
  lantern in the Gardens dims. Calaneth pays 50, and the Great Houses −5 ("angry for fifty
  years, grateful for five hundred").
- **Give it to the Moot** (`well_given`): it stays bound, and it's no longer Sennaveth's.
  Calaneth pays 200, and the Great Houses +15.
- **Drink it** (`well_drunk`): **+30 corruption** (CORRUPTION.md). Calaneth sees what
  you've become, and the Great Houses −20. Rhosyn sees it too.

**A.'s card** (`rootwell_letter`, a book) is on Caerwyn's desk:
- the well under the Moot Tree is the sixth of the twelve;
- A. comes for the harvest on the dark of the Wanderer, then goes north;
- the founders' confession wasn't burned: "Look under the glass."

Show it to Calaneth (`card_shown`): she says that means the Glass Coast, in Sundra, where the
Glass College stands. **That's the next lead**: see GLASS_COAST.md. The ship sails from Ilunhall's quay.

**Engine change:** a new dialogue action, `"add_corruption": 30` (`ui/dialogue_manager.gd`).

## Building and editing the level

- Run `godot --headless --path . -s levels/builders/build_ithmarren.gd` from `godot/`. It
  writes both scenes.
- The Karrowdeep builder (`build_karrowdeep.gd`) adds the Hollow Way.
- The builder's helpers are local to it:
  - `trunk()`: a giant tree;
  - `platform()`: a railed deck, with gaps where walkways join;
  - `walkway()`: a railed bridge or stair between any two points;
  - `lanterns()`: a light-stone string.
- `builder_base.stores()` takes a `parent`, so the letter-box can sit under a presence node.

## Known limits

- **A greybox canopy.** The trees are cylinders with flat green crowns, and the houses are
  the usual blocks.
- **The Rootwell is one room, one fight.**
- A.'s visit "on the dark of the Wanderer" isn't
  scheduled.
- **The drunk ending:** the Gardens' lanterns keep their light (they fade by autumn), and only
  the Rootwell goes dark.
- **The coffer and the letter-box** stay on the bough after you've been given what was in
  them. The letter-box disappears once Lirael hands the letter over; the coffer doesn't.

## Tests

`tests/test_ithmarren.gd` checks:
- the Hollow Way both ways;
- every person;
- the law;
- the fast-travel arrival points;
- **a way on foot (the navmesh) from the forest floor to every deck and the Root Door**, plus
  a check that it can fail;
- all three quests, the merchant, the trainer and the bed.

It has three variants:

| Variant | Lead | Letter | Root Door | Well |
|---|---|---|---|---|
| `letter` | Calaneth | Lirael fooled (Glamour 30) | Ithariel shamed with the letter | unbound |
| `steal` | Rhosyn | from the letter-box | key from the coffer | given to the Moot |
| `glamour` | Calaneth | Lirael persuaded | Glamour 40 | drunk |
