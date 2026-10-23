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
- The whole suite takes about 5–10 minutes with 4 at a time. Some tests are timing-sensitive
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
  in `_initialize` when a test needs the same random rolls every time.

## CI (GitHub Actions)

`.github/workflows/ci.yml` runs the tests on every pull request (each push to it) and every push
to `main` (Actions tab). Pushes to a branch without a pull request aren't tested; use **Run
workflow** for those. If
a test fails, the run's **test-logs** artifact has the logs.

On pushes to `main`, tags, and manual runs (**Actions → CI → Run workflow**), it then exports
**Windows** and **Linux** builds; download them from the run's Artifacts. Godot and the export
templates are downloaded once and cached.

**Cost:** GitHub gives private repositories 2,000 free Action minutes a month (public: free).
A test run takes roughly 10–15 minutes on GitHub's 2-core runners, so about 130 runs a month.
To use fewer minutes: run tests only on pull requests (change `on:` in the workflow), or push
less often.

## Builds

`godot/export_presets.cfg` has two presets, **Windows Desktop** and **Linux**, each exporting
one executable with the game data embedded (the `tests/` folder is left out). In the editor:
**Project → Export → Export Project** (install the 4.3 export templates first when it asks).
Builds go to `build/windows/` and `build/linux/` (not committed).

Not set up yet (each needs a decision or an account): a game icon, Windows code signing
(unsigned builds get a SmartScreen warning), macOS (needs an Apple developer account to sign
and notarise), and uploading to itch.io (butler, with an API key stored as a GitHub secret).
