# Tests, CI and builds

## Running the tests

The game has headless tests in `godot/tests/`: each one loads a level, plays it frame by
frame (walking, fighting, saving, loading...) and checks the results. Run them all with:

```
python3 tools/run_tests.py --godot "C:/path/to/Godot_v4.3-stable_win64.exe"
python3 tools/run_tests.py --godot ~/bin/godot test_melee test_dungeon     # just these
GODOT=~/bin/godot python3 tools/run_tests.py -j 2                          # 2 at a time
```

- A test **passes** when it finishes, prints `RESULT: N passed, 0 failed`, and logs no script
  errors. Failed checks are listed under the test's name. Full logs: `build/test-logs/`.
- A failed test is **run once more**. If it passes then, it's reported as **FLAKY**: the run
  still passes, but the flaky tests are listed at the end (the first try's log is kept as
  `*.first-try.log`). A test that keeps showing up there has a timing or randomness problem
  worth fixing. `--retries 0` turns this off.
- Each test runs in its **own user folder**, so tests never touch your real saves, settings or
  key bindings, and can run in parallel.
- The whole suite takes about 4 minutes on GitHub's runners (2 at a time) and 5–10 on a laptop. Some tests are timing-sensitive
  (combat bots, wolves): on a heavily loaded machine, use fewer jobs (`-j 2`).
- Run one test by hand to watch its output:
  `godot --headless --path godot -s res://tests/test_move.gd`

## Writing a test

Copy `godot/tests/test_move.gd`. A test `extends "res://tests/test_base.gd"`, drives the game
from `_physics_process`, checks things with `ok(condition, "what")`, `near(value, expected,
tolerance, "what")` or `between(value, low, high, "what")`, and ends with `return done()`.
New `test_*.gd` files are picked up automatically. If a test takes an argument (a race, a
scene), list its runs in `VARIANTS` in `tools/run_tests.py`.

Things that trip tests up:
- Autoloads aren't available by name when a test script compiles: use `autoload("Inventory")`.
- Pressed keys (`Input.action_press`) take effect on the next frame.
- Hit-stop slows the game for a moment after a heavy hit or parry, so count on wider timing.
- Wolves wander randomly and AI fights vary: check ranges, not exact numbers. Call `seed(n)`
  in `_initialize` when a test needs the same random rolls every time. An **idle wolf
  still wanders** (even with `aggro_range = 0`): if a test aims at one, also set
  `wander_speed = 0.0`. (`test_magic` once missed its wolf completely because it had
  wandered out of the Flames stream: reproducible with `seed(14)`.)
- Even with a seed, a long AI fight doesn't repeat exactly, so balance tests
  (`test_bandit_fight`, `test_first_fight`) guard against big changes rather than hit exact
  numbers.

## Whole-game and balance tests

- **`test_playthrough`** (variants `normal`, `hardcore`) plays the entire demo in one run:
  the Hunter's opening, all five main quests (into the barrow and back), every side quest
  and the ending, saving and loading four times (once inside the dungeon), then checks
  every quest in `quests.json` is complete and stays so after one more load. In Hardcore
  the bandits also capture you before quest 3, so you wake in their cage next to Jory.
  It drives the game through the same calls a key press makes and kills by dealing damage
  directly, so it tests that the quests fit together, not the fights. **When you add a
  quest, add it here too**: the final check fails for any quest it doesn't finish.
- **`test_first_fight`** (`naive`, `skilled`): bots fight The First. See DUNGEONS.md.
- **`test_migration`**: an old (version 9) save brought up to date. See STATS_AND_SAVING.md.

## CI (GitHub Actions)

`.github/workflows/ci.yml` runs the tests on every pull request (each push to it) and every push
to `main` (Actions tab). Pushes to a branch without a pull request aren't tested; use **Run
workflow** for those. If
a test fails, the run's **test-logs** artifact has the logs.

On pushes to `main`, tags, and manual runs (**Actions → CI → Run workflow**), it then exports
**Windows** and **Linux** builds; download them from the run's Artifacts. Godot and the export
templates are downloaded once and cached.

**Cost:** GitHub gives private repositories 2,000 free Action minutes a month (public: free).
A test run takes about 4 minutes on GitHub's runners (measured; the first run also downloads
Godot, about 1 minute more), so roughly 450 runs a month. An export run adds a few minutes,
more the first time (the 1 GB template download, then cached). To use fewer minutes: run
tests only on pull requests (change `on:` in the workflow), or push less often.

## Builds

`godot/export_presets.cfg` has two presets, **Windows Desktop** and **Linux**, each exporting
one executable with the game data embedded (the `tests/` folder is left out). In the editor:
**Project → Export → Export Project** (install the 4.3 export templates first when it asks).
Builds go to `build/windows/` and `build/linux/` (not committed).

Not set up yet (each needs a decision or an account): a game icon, Windows code signing
(unsigned builds get a SmartScreen warning), macOS (needs an Apple developer account to sign
and notarise), and uploading to itch.io (butler, with an API key stored as a GitHub secret).
