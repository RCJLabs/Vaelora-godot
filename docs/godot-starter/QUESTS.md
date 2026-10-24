# Quests & the Journal

Press **J** (or **Tab → Quests**) for the journal. It lists active quests first, then
completed ones, with main quests (`"main": true`) at the top of each. For the selected quest it shows who gave it, the description, objectives
(`[x]` done, `[  ]` to do), and, once finished, how it ended.

Top-left notices announce progress: **Quest started**, **Objective complete** (with the
next objective), **Quest completed**.

## The quests

| Quest | Giver | Steps | Endings |
|---|---|---|---|
| **Wrong Things** (main quest 1) | Started by every background's opening; Maren tells you about it | Talk to Maren → find the hollow wolf east of Greyfang Hollow and copy the mark on it → show the mark to Brannoc | **Put it down** (in its dialogue, or with a weapon) or **leave it standing**; the journal remembers which. +5 Riverwatch reputation. Leads into The Waking Stones |
| The Greyfang Pack | Maren (waystation) | Kill the wolves NE of spawn → return to Maren | 50 gold + healing potion, +10 Riverwatch reputation |
| **Ask the Forest** (main quest 3) | Starts when the crystal shows the drain-line | Follow the line north to the outlaw camp in the Thornwood → Mirela's terms: **clear the bandit camp** or **bring a garrison supply crate** (Brannoc gives one, −10 Riverwatch) → her scouts' report | The lead to the Old Barrow: hooded folk carrying cages in and out after dark. +15–20 Thornwood Free reputation. The Outlaw can skip the terms by showing their wanted notice. The bandit leader's **marked coin** gets an extra line |
| **The Barrow** (main quest 4) | Mirela's scouts' report | Search the Old Barrow → past the Stone Guardian, the vault's scrape marks lead to a **secret wall** → the hidden chamber: two hooded cultists, jars of stolen light, the notes and map → **the last caged wisp** | **Free it:** it follows you as a light from then on (+5 Thornwood Free when Mirela sees it). **Take its essence:** +25 max Magicka, −15 Thornwood Free ("You did what they do") |
| Thieves by the Fire | Brannoc ("Anything else I should know about out here?") | Clear the bandit camp south-west of the stone circle → tell Brannoc | 75 gold, +10 Riverwatch reputation |
| **The Waking Stones** (main quest 2) | Brannoc (Riverwatch scout, between spawn and the stone circle) | Touch the crystal → find 3 rune shards (glowing, scattered around the circle) → bring them to Brannoc → **choose** → look into the crystal again: it shows the **drain-line**, a thread of light running north into the Thornwood | **Riverwatch:** 60 gold, +15 Riverwatch reputation. **The stones:** return the shards to the crystal yourself: +10 max Magicka, the crystal burns brighter (and shows the line straight away). **Keep them:** −15 Riverwatch reputation, Brannoc goes cold. Afterwards, tell Brannoc about the line: he points you at the outlaws in the Thornwood |

Brannoc has extra lines for Elves, and the quests remember what you did. In Wrong Things the
Hunter can read the hollow wolf's tracks (they come out of the forest to the north) and the
Scholar can read its mark (something was drawn *out* through it); each gets a line with
Brannoc for it. Kill the wolves
*before* Maren asks and you can still report it. Touch the crystal before meeting Brannoc
and that objective is already ticked when he gives you the quest.

## Background openings

A new game starts with the background's own first scene (`systems/openings.gd`, data in
`quests/openings.json`): the player appears at that background's marker in the level
(`StartSoldier`, `StartScholar`, ...), facing its way, gets its items (posting orders, a
letter from the Collegium, a wanted notice, a wagon manifest), and a short intro card shows
for a few seconds (interact, jump or Enter skips it). It also starts Wrong Things, and Maren's
first conversation has a line for each background.

| Background | Starts | Looking at |
|---|---|---|
| Soldier | On the north road, outside the gate | The waystation |
| Scholar | South-east of the stone circle | The stones |
| Outlaw | On a bedroll behind the waystation | The fire and Maren |
| Hunter | East of the waystation, on the wolf's trail | The waystation |
| Acolyte | At the roadside shrine (its prayers have stopped working) | The shrine |
| Merchant | Down the road, south | Up the road |

Loading a save, or running a level on its own (F6), plays no opening.

## Quest markers

An objective can name what it's about (`"marker": "Maren"`); the compass and the map then
point there while it's the quest's next objective. See MAP.md.

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

- No quest-tracking toggle. All active quests are shown.
- Quest rewards that change reputation are dialogue actions (`add_reputation`). See FACTIONS.md.
