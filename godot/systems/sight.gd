extends Node

# Sight: seeing far, and seeing ahead. Autoloaded as "Sight". Its aimed spells
# (SpellData.sight) are cast by player_magic.gd through cast(); its self spells
# are plain status effects that the rest of the game reads.
# docs/godot-starter/SIGHT.md; the lore is docs/lore/MAGIC.md ("Sight"): the
# duellist-seer.
#   weak_point   the enemy nearest your aim is marked: it takes 50% more for 10 s
#   ill_fortune  the enemy nearest your aim is cursed for 15 s: a third of its
#                blows at you go astray, and it stumbles (85% speed)
#   foresight          (self) 8 s: parry window x3, dodges untouchable twice as long
#   true_sight         (self) 30 s: every enemy within 40 m is marked, through walls
#   moment_of_clarity  (self, mastery) 6 s: nothing lands on you, your blows do double

const TRUE_SIGHT_RANGE := 40.0
const ILL_FORTUNE_MISS := 0.33
const SPREAD_RADIUS := 4.0

var _marks := {}   # enemy -> its True Sight marker (Label3D)


## An aimed Sight spell going off at `center`. Returns how many enemies it touched.
func cast(spell: SpellData, center: Vector3, power: float, caster: Node3D) -> int:
	var targets := Binding._enemies_near(caster, center, spell.radius)
	if targets.is_empty():
		return 0
	var target: Node3D = targets[0]
	match spell.sight:
		"weak_point":
			_apply(target, "weak_point", spell.duration * power * Character.modifier("mark_duration"))
			if "exposed" in Character.perks:
				_apply(target, "weak_point_deep", spell.duration * power * Character.modifier("mark_duration"))
			if "marked_for_death" in Character.perks and target.get("stats") and not target.has_meta("death_marked"):
				target.set_meta("death_marked", true)
				target.stats.died.connect(_on_marked_died.bind(target), CONNECT_ONE_SHOT)
			return 1
		"ill_fortune":
			var cursed := [target]
			if "spreading_misfortune" in Character.perks:
				cursed = Binding._enemies_near(caster, target.global_position, SPREAD_RADIUS)
			for enemy in cursed:
				_apply(enemy, "ill_fortune", spell.duration * power)
				if "bad_omen" in Character.perks:
					_apply(enemy, "bad_omen", spell.duration * power)
			return cursed.size()
	return 0


func _apply(enemy: Node, id: String, seconds: float) -> void:
	var effects = enemy.get("effects")
	if effects == null:
		return
	effects.apply(id)
	if effects.active.has(id):
		effects.active[id]["time_left"] = seconds


func _on_marked_died(target: Node) -> void:
	var effects = target.get("effects") if is_instance_valid(target) else null
	var player := get_tree().get_first_node_in_group("player")
	if player and effects and effects.has("weak_point"):   # Marked for Death: it fell while marked
		player.stats.heal(25.0)


## Does an attack from `attacker` go astray? (Ill Fortune, Prescience, Moment of Clarity.)
func blow_misses(attacker: Node, player: Node) -> bool:
	if player.effects.has("moment_of_clarity"):
		return true
	var effects = attacker.get("effects") if is_instance_valid(attacker) else null
	if effects and effects.has("ill_fortune"):
		var miss := 0.5 if "jinx" in Character.perks else ILL_FORTUNE_MISS
		if randf() < miss:
			return true
	return "prescience" in Character.perks and randf() < 0.1


## The extra on your own blows: Moment of Clarity doubles, Read the Fight (during Foresight) +25%.
func damage_mult(player: Node) -> float:
	var mult := 1.0
	if player.effects.has("moment_of_clarity"):
		mult *= 2.0
	if player.effects.has("foresight") and "read_the_fight" in Character.perks:
		mult *= 1.25
	return mult


func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var seeing: bool = player != null and player.get("effects") != null and player.effects.has("true_sight")
	var reach := TRUE_SIGHT_RANGE * Character.modifier("true_sight_range")
	var keep := {}
	if seeing:
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if enemy is Node3D and enemy.is_visible_in_tree() and not Glamour._dead(enemy) and not Binding.is_bound(enemy) \
					and enemy.global_position.distance_to(player.global_position) <= reach:
				keep[enemy] = true
				if not _marks.has(enemy) or not is_instance_valid(_marks[enemy]):
					_marks[enemy] = _make_mark(enemy)
				if "hunters_eye" in Character.perks and enemy.get("stats"):
					_marks[enemy].text = "◆ %d%%" % roundi(100.0 * enemy.stats.health / maxf(enemy.stats.max_health, 1.0))
	for enemy in _marks.keys():
		if not keep.has(enemy):
			if is_instance_valid(_marks[enemy]):
				_marks[enemy].queue_free()
			_marks.erase(enemy)


func is_marked_by_true_sight(enemy: Node) -> bool:
	return _marks.has(enemy) and is_instance_valid(_marks[enemy])


func _make_mark(enemy: Node3D) -> Label3D:
	var label := Label3D.new()
	label.name = "TrueSightMark"
	label.text = "◆"
	label.font_size = 64
	label.modulate = Color(1.0, 0.85, 0.4)
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true   # seen through walls
	label.fixed_size = true
	label.pixel_size = 0.0008
	label.position = Vector3(0, 2.0, 0)
	enemy.add_child(label)
	return label
