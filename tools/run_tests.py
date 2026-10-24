"""Runs the game's headless tests (godot/tests/test_*.gd) and reports which pass.

    python3 tools/run_tests.py --godot /path/to/godot             all tests
    python3 tools/run_tests.py --godot godot.exe test_melee test_wisp
    GODOT=/path/to/godot python3 tools/run_tests.py -j 2

Each test runs in its own Godot process with its own user:// folder (saves,
settings, key bindings), so tests can run in parallel without touching each other
or your real saves. A test passes when it prints "RESULT: N passed, 0 failed" with
N > 0, exits normally and logs no script errors. Logs go to build/test-logs/.

A failed test is run once more (--retries). If it passes then, it's reported as
FLAKY: it doesn't fail the run, but it's listed at the end so it can be looked at.
"""
import argparse
import concurrent.futures
import os
import platform
import re
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJECT = os.path.join(ROOT, "godot")
TESTS = os.path.join(PROJECT, "tests")
LOGS = os.path.join(ROOT, "build", "test-logs")
TIMEOUT = 300

# Tests that run more than once, with different arguments. Every other
# tests/test_*.gd runs once with none.
VARIANTS = {
    "test_attrs": [["orc"]],
    "test_barrow": [["free"], ["take"]],
    "test_ask_forest": [["bandits"], ["supplies"], ["outlaw"]],
    "test_bandit_fight": [["skilled"]],   # "naive" (never defends) is a balance check: run it by hand
    "test_combat": [["human"]],
    "test_floor": [["res://levels/test_level.tscn"], ["res://levels/waystation_cellar.tscn"]],
    "test_nav": [["nav_kill"]],
    "test_quest": [["riverwatch"], ["stones"]],
    "test_race": [["human"], ["elf"], ["orc"]],
    "test_rep": [["human_give"], ["keep"]],
    # Broken collision setups from FIRST_PERSON_SETUP.md: the first five fall, the rest stand.
    "test_wrong_things": [["mercy"], ["spare"], ["weapon"]],
    "test_variants": [["human"], ["empty_ground_shape"], ["shape_under_mesh"], ["default_box_size_offcenter"],
                      ["player_mask_zero"], ["player_shape_empty"], ["ground_layer_not_in_mask"],
                      ["ground_scaled_body"], ["centered_capsule_at_y0"], ["centered_capsule_at_y_minus_0_3"]],
}
# Engine noise from the headless dummy renderer, not from the game.
NOISE = re.compile(r'Parameter "m" is null|mesh_get_surface_count')


def isolated_env(home):
    env = dict(os.environ)
    system = platform.system()
    if system == "Windows":
        env["APPDATA"] = home
    elif system == "Darwin":
        env["HOME"] = home
    else:
        env["XDG_DATA_HOME"] = home
    return env


def run(godot, name, args):
    label = " ".join([name] + args)
    log_path = os.path.join(LOGS, re.sub(r"[^A-Za-z0-9_.-]", "_", label) + ".log")
    with tempfile.TemporaryDirectory(prefix="godot-test-") as home:
        start = time.time()
        command = [godot, "--headless", "--path", PROJECT, "-s", "res://tests/%s.gd" % name]
        if args:
            command += ["--"] + args
        try:
            proc = subprocess.run(command, env=isolated_env(home), capture_output=True, text=True,
                                  timeout=TIMEOUT, errors="replace")
            output, code = proc.stdout + proc.stderr, proc.returncode
        except subprocess.TimeoutExpired as e:
            output = (e.stdout or "") if isinstance(e.stdout, str) else (e.stdout or b"").decode(errors="replace")
            code = "timeout"
    output = "\n".join(line for line in output.splitlines() if not NOISE.search(line))
    with open(log_path, "w", encoding="utf-8") as f:
        f.write(output)
    problems = []
    result = re.search(r"RESULT: (\d+) passed, (\d+) failed", output)
    if code != 0:
        problems.append("exit code %s" % code)
    if "SCRIPT ERROR" in output:
        problems.append("%d script errors" % output.count("SCRIPT ERROR"))
    if not result:
        problems.append("never finished (no RESULT line)")
    elif int(result.group(2)) > 0:
        problems.append("%s checks failed" % result.group(2))
    elif int(result.group(1)) == 0:
        problems.append("no checks ran")
    fails = [line.strip() for line in output.splitlines() if line.strip().startswith("FAIL")]
    return label, problems, fails, time.time() - start, log_path


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("tests", nargs="*", help="test names (default: all)")
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"), help="Godot 4.3 executable")
    parser.add_argument("-j", "--jobs", type=int, default=os.cpu_count() or 2)
    parser.add_argument("--retries", type=int, default=1, help="extra tries for a failed test (default 1)")
    options = parser.parse_args()

    names = sorted(f[:-3] for f in os.listdir(TESTS)
                   if f.startswith("test_") and f.endswith(".gd") and f != "test_base.gd")
    if options.tests:
        unknown = set(options.tests) - set(names)
        if unknown:
            sys.exit("unknown tests: %s" % ", ".join(sorted(unknown)))
        names = options.tests
    jobs = [(name, args) for name in names for args in VARIANTS.get(name, [[]])]
    os.makedirs(LOGS, exist_ok=True)

    failures = 0
    flaky = []

    def run_with_retries(name, args):
        first = run(options.godot, name, args)
        result = first
        for _ in range(options.retries):
            if not result[1]:
                break
            os.replace(result[4], result[4][:-4] + ".first-try.log")   # keep the failure's log
            result = run(options.godot, name, args)
        return first, result

    with concurrent.futures.ThreadPoolExecutor(max_workers=options.jobs) as pool:
        futures = [pool.submit(run_with_retries, name, args) for name, args in jobs]
        for future in concurrent.futures.as_completed(futures):
            first, (label, problems, fails, seconds, log_path) = future.result()
            if problems:
                failures += 1
                print("FAIL  %-40s %5.0fs  %s" % (label, seconds, "; ".join(problems)), flush=True)
                for line in fails[:10]:
                    print("        " + line)
                print("        log: %s" % os.path.relpath(log_path, ROOT))
            elif first[1]:
                flaky.append((label, first[1], first[2]))
                print("FLAKY %-40s %5.0fs  failed once, passed on retry" % (label, seconds), flush=True)
            else:
                print("pass  %-40s %5.0fs" % (label, seconds), flush=True)
    if flaky:
        print("\nFlaky (failed, then passed on retry):")
        for label, problems, fails in flaky:
            print("  %s: %s" % (label, "; ".join(problems)))
            for line in fails[:5]:
                print("        " + line)
    print("\n%d of %d passed%s" % (len(jobs) - failures, len(jobs), " (%d flaky)" % len(flaky) if flaky else ""))
    sys.exit(1 if failures else 0)


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:   # output piped into `head` and cut short
        sys.exit(1)
