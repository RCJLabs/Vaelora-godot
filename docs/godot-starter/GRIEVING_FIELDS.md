# The Grieving Fields: Greyfold and the Deep Ring

The third region (option 3 of "do 2-4 one at a time", 2026-10-26), following V.'s letter from
the Weirstones: "Move the harvest to the Fields: the Grieving Fields site runs deeper." Greybox,
like Weirholt. Names and people are *(suggested)*; the region itself is in the lore
(`docs/lore/WORLD.md`: the old battlefields of the Ashen Rising, where the Ashen live).

## Getting there

- From Weirholt: the **south road**, past the south gate and Ama's farm, to the map's south
  edge. You arrive at the top of the Fields' road.
- Back: the north road at the Fields' north edge. Both regions are in fast travel.

## The place

| Place | What's there |
|---|---|
| **Greyfold** | An Ashen village: six low grey houses around the Listening Stone, a well |
| The laying grounds | Stone biers open to the sky, where the Ashen lay out their dead "so the lights can see us" |
| The old battlefield | Broken spears in the grass; three toppled cairns of the Rising |
| Corin's hut | West of the village |
| Marta's wagon | A Hearthlands peddler by the road (merchant) |
| The sinkhole | North-east: the way down to **the Deep Ring** (`grieving_deep_ring.tscn`), one of the twelve sites, where the Mercy have moved the harvest |

People: **Listener Ysolde** (trains **Sight** to 50; an Ashen player is "kin", an elf gets a cold
welcome), **Old Hesk** the cairn-keeper, **Corin Dray** the wisp-finder, **Marta Coil**
(merchant `marta`), **Bram** the shepherd. A new faction, **the Ashen of the Fields**
(`ashen_fields`), known once you meet Ysolde.

## Quests

| Quest | Giver | How it goes | Endings |
|---|---|---|---|
| **The Deep Ring** (main) | Listener Ysolde | Find the sinkhole, go down, defeat three Mercy acolytes and the **Harvest-Warden**, then the engine: dozens of caged wisps wired to a seam-stone core | Smash it and free them; tell Ysolde (120 gold, Ashen +20). V.'s note sends the Mercy to **Ilunhall**: the Empress's light-stone is residue, and they mean to feed it |
| **The Wisp-Finder** | Corin Dray | He sells wisps' whereabouts to people in masks | Talk him round (Persuade 35), pay him 100 gold to stop, or tell Ysolde (he's sent away) |
| **Cairns of the Rising** | Old Hesk | Restack three toppled cairns, west, east and south, in any order | Hesk gives you his brother's sword (Ashen +10) |

All three are tagged `"region": "grieving_fields"`.

## Building

`levels/builders/build_grieving_fields.gd` builds both scenes:

```
godot --headless --path godot -s levels/builders/build_grieving_fields.gd
```

The builders now share `levels/builders/builder_base.gd` (boxes, houses, people, doors, markers,
trees, enemies, the common level nodes); Weirholt's builder was split onto it unchanged.

## Known limits

- Greybox, and nobody moves.
- Wisps aren't placed on the laying grounds yet (the Ashen side of them is only in dialogue).
- Ilunhall, where the main thread now points, isn't built.
- `tests/test_grieving_fields.gd` plays an Ashen character through the road both ways, the
  people, the merchant and trainer, fast-travel arrival points, and every quest, with all three
  endings of The Wisp-Finder.
