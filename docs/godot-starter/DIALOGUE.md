# Dialogue System

Walk up to Maren (blue figure near the sign), press **E**. Pick answers with the **mouse** or
**number keys 1–9**. **Esc** leaves. You can't move while talking.

## How it fits together

| Piece | File | What it does |
|---|---|---|
| `GameState` (autoload) | `systems/game_state.gd` | Holds `race` and `flags` (story memory) for the whole game |
| `DialogueManager` (autoload) | `ui/dialogue_box.tscn` + `ui/dialogue_manager.gd` | Loads a JSON file, shows the panel, applies conditions and flags |
| NPC | `interactables/npc.gd` | An interactable, so E calls `DialogueManager.start(file, name)` |
| Conversation | `dialogue/maren.json` | The lines and choices |

"Autoload" means Godot creates the node once at startup and any script can use it by name.
They're listed in **Project → Project Settings → Globals → Autoload** (already set up in
`project.godot`).

## Adding a new NPC (no code)

1. Copy `dialogue/maren.json` to e.g. `dialogue/guard.json` and edit the text.
2. In your level: **+** → `StaticBody3D`, rename it (e.g. `Guard`).
3. Give it a `MeshInstance3D` (CapsuleMesh) and a `CollisionShape3D` (CapsuleShape3D) as
   **direct children**. Set both to Position `(0, 0.9, 0)` so the NPC stands on the ground.
4. Drag `interactables/npc.gd` from the FileSystem panel onto the Guard node.
5. Inspector: **Display Name** = `Guard`, **Dialogue File** → pick `guard.json`.
6. F5, walk up, press E.

## JSON format

```json
{
  "start": [
    { "node": "greet_again", "requires_flag": "met_guard" },
    { "node": "greet" }
  ],
  "nodes": {
    "greet": {
      "text": "Halt. State your business.",
      "set_flag": "met_guard",
      "choices": [
        { "text": "Just passing through.", "next": "end" },
        { "text": "Lok'tar, friend.", "next": "orc_reply", "requires_race": "Orc" },
        { "text": "I'll help with the wolves.", "next": "thanks", "set_flag": "offered_help" }
      ]
    }
  }
}
```

- **`start`**: either a node name (`"start": "greet"`) or a list. If it's a list, the first
  entry whose conditions pass is used. Always end the list with one entry that has no
  conditions.
- **Node**: `text` (what the NPC says), `choices`, and an optional `set_flag` (set when the line
  is shown).
- **Choice**: `text`, `next` (a node name, or `"end"` to close), an optional `set_flag` (set
  when picked), and optional conditions.
- **Conditions** (on choices or `start` entries): `requires_flag`, `requires_not_flag`,
  `requires_race` (`"Human"`, `"Elf"`, `"Orc"`). The flag ones take one name or a list, which
  means all of them: `"requires_not_flag": ["wolf_quest_accepted", "wolves_cleared"]`.
- **More conditions:** `requires_item` (`"wolf_pelt"` or `{"id": "wolf_pelt", "count": 3}`),
  `requires_not_item` (`"wanted_notice"`: you carry none),
  `requires_gold` (a number), `requires_reputation` / `requires_reputation_below`
  (`{"riverwatch": 10}`), `requires_background` (`"soldier"` or a list: any of them) and
  `requires_trait` (`"charming"` or a list: all of them). See CHARACTER.md.
- **Trading:** `"open_trade": "maren"` on a choice (with `"next": "end"`) opens the buy and
  sell screen once the conversation closes (INVENTORY.md, "Trading").
- **Lessons:** `"open_training": "brannoc"` likewise opens a trainer's lesson screen
  (SKILLS.md, "Skill books and trainers").
- **Speech checks:** a choice with
  `"check": {"id": "maren_discount", "kind": "persuade", "difficulty": 30}` goes to `"next"`
  if you pass and to `"fail_next"` if you don't. Its actions only run on a pass.
  - `kind` is `persuade` (Speech + Presence), `intimidate` (Speech + Strength) or `bribe` (with
    `"gold": 150`; it always works if you can pay, and costs less with Speech).
  - The choice shows "[Persuade 30 · you 23]". A failed check isn't offered again. See SPEECH.md.
- **Walking away:** `"on_leave": {<actions>}` on a node runs if the player Escs out of it. The
  inquisitor uses it so leaving when he's drawn still starts the fight.
- **Skills:** `requires_skill` / `requires_skill_below` (`{"tidecraft": 50}`: a skill's level,
  by its id in `systems/skills.gd`). Aurel keeps his mastery primer for Tidecraft 50.
- **Actions**, on a node (run when the line is shown) or a choice (run when picked):
  `set_flag` (one name or a list), `give_gold`, `take_gold`, `give_item`, `take_item`,
  `add_reputation` (`{"riverwatch": 10}`). The item ones take the same
  forms as `requires_item`. Example, Maren buying a pelt:
  `"buy_pelt": {"text": "Fifteen gold.", "take_item": "wolf_pelt", "give_gold": 15, "choices": [...]}`
- **The law** (CRIME.md): `"crime": "pay"`, `"pardon"`, `"jail"` or `"resist"` as an action;
  the conditions `"requires_bounty_affordable": true` and `"requires_bounty_below": 100`; and
  `{bounty}` and `{region}` in any line or choice text are filled in with your bounty here and
  the region's name. `dialogue/guard_crime.json` is the guards' version.
- A node with no choices that pass gets an automatic **(Leave)** button.

Put flags you want to keep even if the player presses Esc (quest accepted, secret learned) on
the **node**, not on its Goodbye choice.

Other scripts can read flags too: `if GameState.has_flag("wolf_quest_accepted"): ...`.
The condition rules are shared with quests and live in `systems/conditions.gd`. See
QUESTS.md for turning flags into journal entries.

## Mistakes and what you'll see

The Output panel shows a clear error and the conversation closes:
- File path wrong → `Dialogue: file not found: ...`
- JSON typo (missing comma or quote) → `Dialogue: <file> line N: <reason>`. A free checker
  like jsonlint.com finds these quickly.
- `next` points to a node that doesn't exist → `Dialogue: no node called '...'`

## Known limits

- **Exporting the game:** Godot leaves `.json` files out of exports by default. In
  **Project → Export → (your preset) → Resources → Filters to export non-resource files**,
  add `*.json`, or dialogue will be missing in the exported build.
- Flags are not saved to disk yet. That comes with a save system.
- To test race lines, pick that race on the start screen (F5). F6 on a level plays as Human.
