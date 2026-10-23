# Quests & the Journal

Press **J** (or **Tab → Quests**) for the journal. It lists active quests first, then
completed ones. For the selected quest it shows who gave it, the description, objectives
(`[x]` done, `[  ]` to do), and, once finished, how it ended.

Top-left notices announce progress: **Quest started**, **Objective complete** (with the
next objective), **Quest completed**.

## The quests

| Quest | Giver | Steps | Endings |
|---|---|---|---|
| The Greyfang Pack | Maren (waystation) | Kill the wolves NE of spawn → return to Maren | 50 gold + healing potion |
| The Waking Stones | Brannoc (Riverwatch scout, between spawn and the stone circle) | Touch the crystal → find 3 rune shards (glowing, scattered around the circle) → bring them to Brannoc → **choose** | **Riverwatch:** 60 gold, Brannoc is grateful. **The stones:** return the shards to the crystal yourself: +10 max Magicka, the crystal burns brighter |

Brannoc has extra lines for Elves, and both quests remember what you did. Kill the wolves
*before* Maren asks and you can still report it. Touch the crystal before meeting Brannoc
and that objective is already ticked when he gives you the quest.

## How quests work (no quest save data)

A quest doesn't store a state of its own. Everything is **worked out from story flags and
your inventory** each time, using the same conditions as dialogue. Because flags and items
are already saved, quests are saved too, for free.

Quests live in `quests/quests.json`:

```json
"waking_stones": {
	"title": "The Waking Stones",
	"giver": "Brannoc, a scout of the Riverwatch garrison",
	"description": "...",
	"started_when":   { "requires_flag": "stones_quest_started" },
	"completed_when": { "requires_flag": "stones_quest_done" },
	"objectives": [
		{ "text": "Investigate the glowing crystal...", "done_when": { "requires_flag": "touched_crystal" } },
		{ "text": "Find three rune shards...",          "done_when": { "requires_item": { "id": "rune_shard", "count": 3 } } },
		{ "text": "Bring the rune shards to Brannoc.",  "done_when": { "requires_flag": "shards_decided" } },
		{ "text": "Return the rune shards to the crystal.",
		  "show_when": { "requires_flag": "shards_chose_stones" },
		  "done_when": { "requires_flag": "stones_restored" } }
	],
	"outcomes": [
		{ "when": { "requires_flag": "shards_given" },    "text": "I gave the shards to Brannoc..." },
		{ "when": { "requires_flag": "stones_restored" }, "text": "I returned the shards to the stones..." }
	]
}
```

- **Conditions** (`started_when`, `completed_when`, `done_when`, `show_when`, `when`) use exactly
  the dialogue rules: `requires_flag`, `requires_not_flag`, `requires_race`, `requires_item`,
  `requires_gold` (see `systems/conditions.gd`).
- A quest is **active** once `started_when` passes, and **completed** once `completed_when`
  passes (completed counts as started, so you can finish a quest you never formally took).
- **Objectives are done in order:** if a later objective is done, all earlier ones count as
  done too. Handing the shards over ticks "find three shards" even though you no longer carry
  them.
- **`show_when`** hides an objective until the story branches that way. That's how the
  "return to the stones" step only appears if you chose it.
- **`outcomes`:** the first one that passes is shown on a finished quest.

## Making a new quest

1. Write the NPC's dialogue (see DIALOGUE.md). Use `set_flag` to mark the moments that matter:
   accepting, branching, finishing. A node can set several: `"set_flag": ["a", "b"]`. Put the
   "quest done" flag **last** so the notices come out in order.
2. Add the quest to `quests/quests.json`, using those flags in its conditions.
3. Anything outside dialogue that advances it just sets a flag (`GameState.set_flag(...)`),
   like the wolf pack and the crystal do. Item objectives update on their own when items are
   picked up.

## Known limits

- No map markers or compass. Directions live in the objective text.
- No quest-tracking toggle. All active quests are shown.
- Reputation (from the design doc) isn't a system yet. Brannoc's "the captain will hear your
  name" is just a flag (`shards_given`) that later content can check.
