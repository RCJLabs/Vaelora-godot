extends "res://tests/test_base.gd"
# The Greyfang quest's journal states and notices follow its flags, including
# reporting the wolves dead without ever having accepted the quest.
var f := 0
var started := false
var seen := []

func _physics_process(_d: float) -> bool:
	var QL = autoload("QuestLog"); var GS = autoload("GameState")
	if not started:
		started = true; QL.notice.connect(func(t): seen.append(t)); return false
	f += 1
	match f:
		1:
			GS.set_flag("wolf_quest_accepted")
			ok(QL.status("greyfang")["state"] == "active", "accepted -> active", QL.status("greyfang")["state"])
			ok(seen.size() == 2 and seen[0] == "Quest started: The Greyfang Pack", "start notice + first objective", seen)
			seen = []
		2:
			GS.set_flag("wolves_cleared")
			ok(seen == ["Objective complete", "  Return to Maren."], "cleared notice", seen)
			seen = []
		3:
			GS.set_flag("wolf_quest_done")
			ok(seen == ["Quest completed: The Greyfang Pack"], "completed notice", seen)
			ok(QL.status("greyfang")["state"] == "completed", "state completed")
			ok(QL.status("greyfang")["outcome"].begins_with("The north road is safe again."), "outcome text", QL.status("greyfang")["outcome"])
			seen = []
		4:
			GS.flags = {}; QL.reset_baseline(); GS.set_flag("wolves_cleared"); GS.set_flag("wolf_quest_done")
			ok(QL.status("greyfang")["state"] == "completed", "never accepted but reported -> completed", QL.status("greyfang")["state"])
			ok(seen == ["Quest completed: The Greyfang Pack"], "only the completed notice", seen)
			return done()
	return false
