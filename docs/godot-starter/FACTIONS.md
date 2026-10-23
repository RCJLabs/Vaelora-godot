# Factions & Reputation

**Tab → Factions** shows every faction you've come across: your rank, a bar from −100 to
+100, and a short description. Changes appear as top-left notices: "Riverwatch Garrison
reputation +12", and "…now sees you as Friendly" when your rank changes.

## Ranks

| Reputation | Rank |
|---|---|
| 50 and up | Champion |
| 25–49 | Honored |
| 10–24 | Friendly |
| 0–9 | Neutral |
| −1 to −24 | Distrusted |
| −25 and below | Hated |

**Humans gain 20% more** from every gain (not from losses). That's `reputation_gain_mult`
in `races/human.tres`, from "mild bonus to reputation gains" in `docs/races.md`.

## The Riverwatch Garrison

| You… | Reputation (Human) |
|---|---|
| Finish the Greyfang quest (Maren tells the garrison) | +10 (+12) |
| Give the rune shards to Riverwatch | +15 (+18) |
| Keep the rune shards for yourself (new third ending) | −15 |
| Return the shards to the stones | 0 (Brannoc covers for you) |

What it changes, all through Brannoc:
- **Friendly (10+):** he sells Minor Healing Potions, 30 gold each.
- **Honored (25+):** a one-time gift from the captain: 2 potions and 50 gold. This takes both
  Riverwatch-friendly choices: wolves *and* shards.
- **Distrusted or worse (after keeping the shards):** he won't talk business. "The garrison
  remembers."
- First meeting him after the wolf quest, he's heard of you ("The wolf-killer from the
  waystation!").

## In dialogue

```json
"add_reputation": { "riverwatch": 10 }                  // action (negative = lose)
"requires_reputation": { "riverwatch": 10 }             // condition: at least 10
"requires_reputation_below": { "riverwatch": 0 }        // condition: below 0
```

The conditions also work in quests (`quests/quests.json`), because both use
`systems/conditions.gd`. From code: `Reputation.add("riverwatch", 5)`,
`Reputation.value("riverwatch")`, `Reputation.rank("riverwatch")`.

## Adding a faction

Add it to `factions/factions.json`:

```json
"circle_keepers": {
	"name": "Keepers of the Circle",
	"description": "...",
	"known_when": { "requires_flag": "met_a_keeper" }
}
```

It appears in the Factions tab once `known_when` passes or your reputation with it isn't 0.
(`also_known_when` is a second, optional way to discover it.) Rank names are shared by all
factions, at the top of the same file.

## Saved

Reputation values are saved (save version 5; older saves start at 0). Unlike quests,
reputation can't be worked out from flags, because the same action could be repeatable.
