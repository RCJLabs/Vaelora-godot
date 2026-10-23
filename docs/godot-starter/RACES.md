# Race Selection

Press **F5**: the game now opens on **Choose your people**. Click Human, Elf or Orc to see the
stats, then **Begin journey**. **F6** on a level skips the screen and plays as Human.

## What a race changes right now

| | Health | Stamina | Magicka | Speed | Jump height | Other |
|---|---|---|---|---|---|---|
| Human | 100 | 100 | 100 | normal | normal | Skill XP ×1.15 |
| Elf | 85 | 100 | 130 | +8% | +15% | Melee ×0.9 |
| Orc | 130 | 115 | 70 | −5% | −5% | Melee ×1.2 |

- **You can feel these now:** speed, jump height, and race-only dialogue choices (talk to
  Maren as an Elf or an Orc).
- **Stored for later:** Health, Stamina, Magicka, skill XP and melee damage. No system uses
  them until health/combat/skills exist.
- **Shown as text only:** the signature abilities (Adaptable, Innate Focus, Battle Fury).

All numbers are placeholders from `docs/races.md`. Tune them once there's combat to test
against.

## Files

| File | Purpose |
|---|---|
| `systems/race_data.gd` | Defines what a race *is* (`class_name RaceData`) |
| `races/human.tres`, `elf.tres`, `orc.tres` | The three races' numbers and text |
| `ui/character_creation.tscn` + `.gd` | The selection screen (now the main scene) |
| `systems/game_state.gd` | Stores the choice: `GameState.race` (name) and `GameState.race_data` (everything) |
| `player/player_first_person.gd` | `_apply_race()` applies speed and jump on spawn |

## Editing a race (no code)

Double-click e.g. `races/orc.tres` in the FileSystem panel. The Inspector shows every field,
grouped into *Starting stats*, *Modifiers* and *Flavour*. Change a value, save (Ctrl+S), F5.

## Adding a fourth race

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
