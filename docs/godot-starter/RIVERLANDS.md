# The Riverlands: Weirholt

The first region beyond the Greywater Vale (chosen 2026-10-26: the Riverlands, one town and
three quests). Everything here is **greybox**: boxes for buildings, capsules for people.
Names and people are *(suggested)*; rename freely.

## Getting there

- From the Vale: walk south from the waystation to the **south road** at the map's south edge
  (a signpost, then "Take the south road to Weirholt"). You arrive at the top of the **woods
  road**, about 60 m of forest north of Weirholt's gate.
- Back: the **north road**, at the far (north) end of the woods road.
- Travel uses `SaveSystem.travel` like the cellar and the barrow, so health, items and effects
  come with you and each place remembers its state (WorldState).

## The town

Weirholt is the first walled town on the Greywater south of the Vale. The River Compact owns the
weir, the Empire owns the walls, and the river owns everyone.

| Place | What's there |
|---|---|
| North and south gates | Walls on three sides; the river is the east side |
| Market square | Wenna Pike's stall (merchant), the notice board |
| The Lantern Weir | The inn: Hedda Marrow; a bed at the back once you've paid her 5 gold |
| Compact counting house | Factor Tarle |
| The mill and the weir | A waterwheel and the Compact's new seam-stone millstone |
| The docks | Jory Vell, the barge *Heron* and its sealed crates, the culvert grate |
| The Lanes | The Passengers' quarter: Teodor, the Lanes' well |
| Surgery | Physician Fenn |
| Barracks, toll-fort | Captain Varga (trains **Block** to 50), Sergeant Dace, the toll strongbox |
| Outside the south gate | Goodwife Ama; a ford across the river |
| **The culvert** (`weirholt_culvert.tscn`) | Under the docks: three smugglers, cages, the ledger chest |

New: a **River Compact** faction (known once you meet Tarle or Jory), merchant `wenna` in
`systems/trade.gd`, trainer `varga` in `systems/training.gd`, and two quest items (Harvest
Ledger, Toll Ledger). Dialogue can now check `"requires_night": true` / `"requires_day": true`.

## The country around it

The level is 200 × 200 m around the town (`_build_wilds()` in the builder):

| Place | What's there |
|---|---|
| The woods road | 70 trees either side of the road north of the town; an overturned cart |
| A clearing west of the road | The toll-road gang: two highwaymen and their leader, tents, a fire, a chest |
| The ford | The easy way across the river, south-east of the town |
| **The Weirstones** | On the east bank: a ring of eight standing stones, one of the **twelve sites**. Empty by day apart from a humming bundle; at night the Mercy's acolytes feed it, and wisps come out |
| Ama's farm | West of the town: a farmhouse and fields |

## Quests

| Quest | Giver | How it goes | Endings |
|---|---|---|---|
| **Down the Greywater** (main) | Jory Vell, on the docks | Ask Factor Tarle what the barges carry at the dark of the Wanderer (he lies; Persuade 40 gets a little more); look at the *Heron*'s crates **after dark** (by day there are too many eyes); go down the culvert, deal with the smugglers, take the **Harvest Ledger** | Give it to Captain Varga (Tarle arrested, +75 gold, Compact −15), sell it back to Tarle (200 gold, Compact +15, the barges keep sailing), or refuse him (he flees downriver) |
| **The Toll of the Weir** | Goodwife Ama, south gate | Sergeant Dace charges four coppers when the board says two | Intimidate him (35), bribe him (60 gold), or take the **Toll Ledger** from the toll-fort strongbox (a lock) to Varga; then tell Ama |
| **Fever in the Lanes** | Teodor, in the Lanes | Look into the well (a sheen, a pipe to the mill), find the Compact's seam-stone millstone | Convince Physician Fenn (Persuade 30, or Alchemy 25) and he says it in the square, or wedge the pipe shut yourself (the fever eases, Fenn still blames the Passengers) |

Their entries in `quests.json` carry `"region": "riverlands"` (the Vale's start-to-finish playthrough test checks only the Vale's).

| **The Toll-Road Gang** | Captain Varga (a 100-gold bounty), or the overturned cart | Clear the gang's camp in the woods | Collect from Varga |
| **The Weirstones** (main) | Opens when Down the Greywater ends (Varga or Jory point you across the ford) | At the stones **after dark** the rite is under way: three Mercy acolytes; then look at what they were feeding | Break the rune-iron cage and give the light back to the stones. Their letter (signed V.) moves the harvest to the **Grieving Fields**; tell Varga for 50 gold |

Down the Greywater is the thread out of the demo's cliffhanger: the harvest goes upriver by
barge, and the ledger's last page carries the circle split by three lines.

## Building and editing the level

`levels/builders/build_weirholt.gd` builds both scenes:

```
godot --headless --path godot -s levels/builders/build_weirholt.gd
```

Change the layout there and re-run rather than hand-editing the `.tscn` files (they're
regenerated whole). The NPCs' words are in `dialogue/*.json` (`hedda`, `tarle`, `wenna`,
`varga`, `dace`, `ama`, `teodor`, `fenn`, `jory_weirholt`, and `weirholt_*` for the things you
examine).

## Known limits

- Greybox only. No interiors except the inn's open front; the other buildings are solid.
- Nobody walks around: NPCs stand where they're placed, day and night.
- The river is a shallow channel you can wade; the ford is the easy way across.
- Jory is here whatever happened to him in the Vale (he greets you if you rescued him).
- The Weirstones reuse the Vale's ritual-site script (`props/ritual_site.gd`, now with a
  per-site "seen by day" flag) and its hooded cultists.
- `tests/test_weirholt_wilds.gd` covers the woods, the gang and the bounty, and the Weirstones
  by day and by night.
- `tests/test_weirholt.gd` covers the road both ways, the people, the inn, the merchant, the
  trainer and every quest step, with all three endings of Down the Greywater.
