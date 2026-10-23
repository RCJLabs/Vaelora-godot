extends SceneTree

# Base for the headless tests in this folder. A test extends this file, drives the
# game frame by frame from _process / _physics_process, checks results with ok(),
# near() and between(), and returns done() on its last frame.
#   godot --headless --path godot -s tests/test_move.gd
# Run them all with tools/run_tests.py. A test passes when it reaches done() with
# no failed checks and no script errors.
#
# Test scripts compile before the autoloads exist, so reach them through
# autoload("Name") (or root.get_node("Name")), never by their global name.

var passed := 0
var failed := 0


func ok(condition: bool, what: String, detail: Variant = "") -> bool:
	if condition:
		passed += 1
		print("  ok    %s" % what)
	else:
		failed += 1
		print("  FAIL  %s %s" % [what, str(detail)])
	return condition


func near(value: float, expected: float, tolerance: float, what: String) -> bool:
	return ok(absf(value - expected) <= tolerance, "%s: %.3f (expect %.3f +- %.3f)" % [what, value, expected, tolerance])


func between(value: float, low: float, high: float, what: String) -> bool:
	return ok(value >= low and value <= high, "%s: %.3f (expect %.3f..%.3f)" % [what, value, low, high])


func autoload(autoload_name: String) -> Node:
	return root.get_node(autoload_name)


## Call as the test's last step: `return done()`.
func done() -> bool:
	print("RESULT: %d passed, %d failed" % [passed, failed])
	return true


## The test's command-line argument (after --), or `default`.
func arg(default: String = "") -> String:
	var args := OS.get_cmdline_user_args()
	return args[0] if args.size() > 0 else default
