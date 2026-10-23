# Health, Stamina, Magicka & Saving

## Stats

The bars at the bottom of the screen: **Magicka** (blue, left), **Health** (red, centre),
**Stamina** (green, right). Maximums come from your race (`races/*.tres`).

| | What uses it now | Regen |
|---|---|---|
| Health | Fall damage. Landing faster than 9 m/s (about a 4 m drop) hurts; ~25 m kills | 0.5/s |
| Stamina | Sprinting drains 12/s. At 0 you're **exhausted** and can't sprint until it's back to 20 | 15/s, after a 1 s pause |
| Magicka | Nothing yet (spells later) | 3/s |

All numbers are `@export`s. Click **Player → Stats** in `player.tscn` for regen, or **Player**
itself for sprint cost and fall damage.

**Death:** "You have died." Then, after 2.5 s, your **last save loads** (like Skyrim). With no
save, you respawn at the level start.

`systems/stats.gd` (`class_name Stats`) is a reusable node. Enemies get one too, so
`take_damage()` works the same on anything.

```gdscript
$Stats.take_damage(20)
if $Stats.try_use_stamina(15): ...   # false if not enough
$Stats.died.connect(_on_died)
```

## Saving

| Key | |
|---|---|
| **F5** | Quicksave |
| **F9** | Quickload |
| **Continue** (start screen) | Loads the save. Only shown if one exists |
| **Begin new journey** | Starts fresh and clears story flags (the save file stays until you F5 again) |

You can't save while talking or dead.

**Saved:** level, race, story flags, player position and look direction, and current
Health/Stamina/Magicka.
**Not saved yet:** anything not driven by a flag. Open doors reset on load, for example. Give
things a flag (like the crystal's `touched_crystal`) if they need to persist.

The file is `user://savegame.json`, readable JSON. Find it via **Project → Open User Data
Folder** in the editor. Delete it to wipe your save.

**F5 in the editor:** F5 is also the editor's "Run" shortcut, but while the game window has
focus, the game gets the key. If you use Godot 4.4+'s embedded game view and F5 restarts the
game instead of saving, click inside the game first, or turn embedding off (Game tab →
⋮ → uncheck "Embed Game on Next Play").
