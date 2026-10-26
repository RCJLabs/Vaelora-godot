# Race Selection

Press **F5**: the game now opens on **Choose your people**. Click any of the seven peoples to see the
stats, then **Begin journey**. **F6** on a level skips the screen and plays as Human.

## What a race changes right now

| | Health | Stamina | Magicka | Speed | Jump height | Other |
|---|---|---|---|---|---|---|
| Human | 100 | 100 | 100 | normal | normal | Skill XP ×1.15, reputation gains ×1.2 |
| Elf | 85 | 100 | 130 | +8% | +15% | Melee ×0.9, Athletics and Destruction start at 25, knows Flames |
| Orc | 130 | 115 | 70 | −5% | −5% | Melee ×1.2, One-Handed starts at 25 |
| Passenger | 90 | 100 | 120 | +5% | +5% | Sneak and Speech start at 20; reputation gains ×0.85 (blamed for the Hollowing) |
| Ashen | 115 | 105 | 85 | normal | normal | Survival and Sight start at 20; Endurance and Willpower +2, Presence −2 |
| Small Folk | 85 | 115 | 60 | −5% | −10% | Melee ×0.9, Speech starts at 25, reputation gains ×1.1, **no race spell** (a background like Scholar can still teach some) |
| Deepfolk | 120 | 110 | 80 | −5% | −5% | Melee ×1.05, Smithing starts at 25 |

The last four were made playable on 2026-10-26, from `docs/lore/PEOPLES.md` (names kept in round
four; the rest of their identity there is still *suggested*). Their numbers and powers are first
drafts. **They have no art of their own yet:** in third person every people uses the same
placeholder body, so for now a race is its numbers, its power and its dialogue. Maren has a line
for each (`test_race` checks all seven).

- **You can feel these now:** speed, jump height, and race-only dialogue choices (talk to
  Maren as an Elf or an Orc).
- **Also in use now:** Health/Stamina/Magicka maximums, melee damage, skill XP rate and
  starting skill bonuses.
- **Race powers (Z):** all seven are real; see `CHARACTER.md`, "Powers".

All numbers are placeholders from `docs/races.md`. Tune them once there's combat to test
against.

## Files

| File | Purpose |
|---|---|
| `systems/race_data.gd` | Defines what a race *is* (`class_name RaceData`) |
| `races/*.tres` | The seven races' numbers and text (human, elf, orc, passenger, ashen, small_folk, deepfolk) |
| `ui/character_creation.tscn` + `.gd` | The creator, opened by **New Game** on the title screen |
| `systems/game_state.gd` | Stores the choice: `GameState.race` (name) and `GameState.race_data` (everything) |
| `player/player_first_person.gd` | `_apply_race()` applies speed and jump on spawn |

## Editing a race (no code)

Double-click e.g. `races/orc.tres` in the FileSystem panel. The Inspector shows every field,
grouped into *Starting stats*, *Modifiers* and *Flavour*. Change a value, save (Ctrl+S), F5.

## Adding another race

1. In the FileSystem panel, right-click `races/human.tres` → **Duplicate** → name it
   `dwarf.tres`.
2. Double-click it and edit the name, stats and text in the Inspector.
3. Open `ui/character_creation.gd` and add `"res://races/dwarf.tres",` to `RACE_FILES`.
4. Dialogue can check for it with `"requires_race": "Dwarf"` (it matches **Display Name**).

## Using race data in new systems

```gdscript
var max_health := GameState.race_data.health
var damage := base_damage * GameState.race_data.melee_damage_mult
```
