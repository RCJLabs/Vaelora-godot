# Health, Stamina, Magicka & Saving

## Stats

The bars at the bottom of the screen: **Magicka** (blue, left), **Health** (red, centre),
**Stamina** (green, right). Maximums come from your race (`races/*.tres`).

| | What uses it now | Regen |
|---|---|---|
| Health | Fall damage. Landing faster than 9 m/s (about a 4 m drop) hurts; ~25 m kills | 0.5/s |
| Stamina | Sprinting drains 12/s. At 0 you're **exhausted** and can't sprint until it's back to 20 | 15/s, after a 1 s pause |
| Magicka | Spells (see MAGIC.md) | 5/s, after a 1 s pause |

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

| Key / button | |
|---|---|
| **F5** | Quicksave (its own slot) |
| **F9** | Load the **most recent** save, whichever slot it's in |
| **Esc → Save Game** | 5 manual slots. Clicking a used slot asks "click again to overwrite" |
| **Esc → Load Game** | Every save, newest first, with **Delete** (asks "Sure?") |
| **Title: Continue** | Loads the most recent save |
| **Title: Load Game** | Same list as Esc → Load Game |
| **Title: create a character → Begin journey** | Starts fresh (story, skills, items, spells, reputation, play time). Saves stay |

Each slot shows name, race and background, character level, location, play time and when it was saved, e.g.
"Slot 2 - Grukka (Orc Soldier), level 3 - Test Level - 0h 42m played - 2026-10-23 16:31". Play time only
counts while you're in a level and not paused.

You can't save while talking or dead. Dying loads your most recent save (or respawns you if
there's none).

**Saved:** level, race, story flags, skills, inventory, spells, reputation, play time,
player position and look direction, current Health/Stamina/Magicka. Quest progress is
worked out from flags and items.
**Not saved:** anything not driven by a flag. Open doors reset on load, for example.

Saves are readable JSON in `user://saves/` (`quicksave.json`, `slot_1.json` …). Open that
folder with **Project → Open User Data Folder** in the editor. A save from before slots
existed (`user://savegame.json`) is moved to the quicksave automatically. Older save
versions still load.

## Title screen, pause menu & settings

The game opens on the **title screen** (`ui/title_screen.tscn`, the project's main scene): the
stone circle at dusk with the camera slowly circling it, and **Continue** (the most recent save;
only shown if there is one), **New Game**, **Load Game**, **Settings**, **Report a Bug**, **Quit**.
The name on it is `GAME_TITLE` in `ui/title_screen.gd`, a placeholder until the title is
decided. The version under it is **Project Settings → Application → Config → Version**.

![Title screen](../images/title_screen.png)

**Esc** pauses: Resume, Save Game, Load Game, Settings, Report a Bug, Quit to Title, Quit Game.
While talking or in the Tab menu, Esc closes those first. In a sub-page, Esc (or B) goes back
one page.

**Settings** apply immediately and are kept in `user://settings.cfg`, separate from saves, so
they apply to every character:

| Setting | Range |
|---|---|
| Mouse sensitivity | 0.2x - 3.0x |
| Invert mouse Y | on/off |
| Field of view | 60 - 100 |
| Volume | 0 - 100% |
| Tutorial hints | on/off |
| **Graphics...** | see below |
| **Controls...** | rebinding (CONTROLS.md) |
| **Accessibility...** | toggle sprint, toggle block, camera shake, interface size (below) |

### Graphics

| Setting | What it does |
|---|---|
| Quality | Low / Medium / High / Ultra (below). High is the look as designed, plus 2x MSAA (the project had no anti-aliasing before) |
| Render scale | 50 - 100%. Below 100% the 3D picture renders smaller and is upscaled with AMD FSR 1 (the menus stay sharp) |
| Fullscreen, VSync | on/off |
| Show FPS | frame rate and frame time, top right, in every scene |

![Graphics settings](../images/graphics_settings.png)

| | Low | Medium | High | Ultra |
|---|---|---|---|---|
| Volumetric fog | off | off | on | on, finer |
| Ambient occlusion (SSAO) | off | low | medium | high, full size |
| Glow | off | on | on | on |
| Shadow map | 1024 | 2048 | 4096 | 8192 |
| Shadow distance | 50% | 75% | 100% | 150% |
| Soft shadows | hard | very low | low | high |
| Anti-aliasing | FXAA | FXAA | MSAA 2x | MSAA 4x |

The presets only switch effects **off** relative to how a scene was built: a level without
volumetric fog doesn't gain it on Ultra. Shadow distance multiplies each sun's own **Directional
Shadow → Max Distance**. To change a preset, edit `QUALITY` in `systems/settings.gd`. New
scenes need nothing: `Settings` applies the preset to every WorldEnvironment and
DirectionalLight3D as it enters the game.

**Not measured yet:** these are standard Godot settings with typical costs, but nobody has
profiled this game on real hardware. Run the benchmark below on your PC, and on a low-end
laptop if you can, before trusting the presets.

### Accessibility

| Setting | What it does |
|---|---|
| Toggle sprint | Tap the sprint key **while moving** to run; tap again to walk. Stopping, or running out of Stamina, ends it |
| Toggle block | Tap the left-hand button to raise your guard (weapon or shield), tap again to lower it. Parrying still works: the parry window starts when the guard goes up. Doesn't affect spells or bows, which stay hold-to-use |
| Camera shake | 0–100%: how much hits, swings, dodges and landings jolt the view. 0% turns it off. (Hit-stop, the brief freeze on a heavy hit, isn't affected) |
| Interface size | 100 / 115 / 130 / 150%: menus, HUD and text. The 3D view isn't affected. On narrow screens the bottom bars shrink to fit |

Not there yet: subtitles (there's no speech), colour-blind modes (health, stamina and magicka
are red, green and blue), and remapping the menu buttons.

### Benchmark

**Title screen → Settings → Graphics → Run benchmark** (about 3 minutes; or start the game
with `-- --benchmark`, e.g. `HighFantasySandboxRPG.exe -- --benchmark`). A camera circles
three scenes (the open level by day, the stone circle at night with wisps, the barrow arena)
at each preset, Low to Ultra, with VSync off. For each it records the average FPS, the
**1% low** (the FPS of the slowest 1% of frames: what stutter feels like) and the worst frame.

Your settings are put back afterwards. The results show on screen, are copied to the
clipboard, and saved to `user://benchmark.txt` (on Windows:
`%APPDATA%\Godot\app_userdata\High Fantasy Sandbox RPG\benchmark.txt`). Paste them back
and the presets can be tuned from real numbers. It only runs from the title screen, because
it loads levels.

### Report a Bug

**Report a Bug** (pause menu and title screen) copies a block of diagnostics to the clipboard
and shows it: game and Godot version, OS, CPU, GPU and driver API, screen size, graphics
settings and FPS, the scene, the player's position, level, race, background and modes, the
in-game time, and the last 40 lines of the log (`user://logs/godot.log`). The player pastes
it wherever you collect reports. To add an **Open bug report page** button, set `REPORT_URL`
in `systems/bug_report.gd` (empty for now: there's no public tracker yet).

**F5 in the editor:** F5 is also the editor's "Run" shortcut, but while the game window has
focus, the game gets the key. If you use Godot 4.4+'s embedded game view and F5 restarts the
game instead of saving, click inside the game first, or turn embedding off (Game tab →
⋮ → uncheck "Embed Game on Next Play").
