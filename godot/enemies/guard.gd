extends "res://enemies/bandit.gd"

# A guard who's done talking (systems/crime.gd, docs/godot-starter/CRIME.md). When
# you run from the law, every guard near you swaps their NPC (interactables/npc.gd,
# hidden meanwhile) for one of these: bandit.tscn with this script, dressed as
# the guard. They fight like bandits, but they're the law, not killers:
#   - beat one down (a quarter of their health) and they yield: they're the NPC
#     again, and you've a bounty for assault;
#   - beaten by them, you're arrested: the cells, not death (Crime.arrest);
#   - lose them (outrun them past their leash) and they go back to their post;
#   - E at one: you surrender, and they talk again (pay, the cells...).

const YIELD_AT := 0.25

var post: Node3D   # the guard NPC this stands in for


func _ready() -> void:
	look_role = "guard"
	look_vary = false
	super()
	remove_from_group("captors")      # arrests, not cages
	remove_from_group("persistent")   # made at runtime: nothing to remember
	add_to_group("guards_fighting")
	prompt = "Surrender to %s" % display_name
	state = State.CHASE


func _physics_process(delta: float) -> void:
	super(delta)
	if state == State.IDLE and not is_queued_for_deletion():
		Crime.stand_down(self)   # back at the post: they've lost you


func _on_damaged(amount: float) -> void:
	super(amount)
	if state != State.DEAD and stats.health <= stats.max_health * YIELD_AT:
		Crime.guard_yields(self)


func _on_died() -> void:
	Crime.guard_yields(self)   # guards don't die here: a killing blow is a yield


func interact(_player: Node) -> void:
	Crime.surrender(self)
