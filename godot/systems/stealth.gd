extends Node

# Sneaking: the Sneak skill. Autoloaded as "Stealth". docs/godot-starter/SNEAK.md.
#
# Standing up, enemies notice you exactly as before: the moment you're inside
# their range. Crouched (C / D-pad down, the player's is_sneaking), their range
# shrinks (Sneak skill, darkness, standing still, perks), they need to see you,
# and noticing takes time: awareness fills while you're in range and in sight,
# faster the closer you are, and drains when you're not. Full awareness = seen.
#
# An enemy calls, each physics frame while it's unaware (IDLE):
#   if Stealth.notices(self, foe, aggro_range, dist, delta): start the fight
# and exposes is_unaware() (a sneak attack is possible) and is_hunting() (it's
# after you, for the HUD). Sneak attacks (crouched, on an unaware enemy):
# melee x3, arrows x2, more with perks. Swinging, casting, loosing and killing
# make noise while you sneak (make_noise): nearby unaware enemies hear it.

const RANGE_MULT := 0.65            # crouched at Sneak 15: 65% of an enemy's usual range
const RANGE_PER_LEVEL := 0.005      # -0.5% of that per Sneak level above 15
const RANGE_FLOOR := 0.3            # the skill alone never takes it below 30% of that
const STILL_MULT := 0.7             # standing still
const DARK_MULT := 0.75             # at the dead of night (daylight 0)
const AWARE_RATE := 1.0             # awareness per second: x1.6 right beside them, x0.4 at the edge
const AWARE_DECAY := 0.3            # per second out of range or sight
const SNEAK_ATTACK := {"melee": 3.0, "archery": 2.0}
const NOISE := {"melee": 6.0, "spell": 8.0, "archery": 3.0, "kill": 8.0, "lockpick": 5.0}   # metres heard at
const SNEAK_XP_PER_SECOND := 0.5    # crouched inside an unaware enemy's usual range
const SNEAK_ATTACK_XP := 6.0
const LOSE_TRACK_SECONDS := 4.0     # Master of Shadows
const RECENT_MS := 400              # an enemy that checked this recently is "watching"

var _enemies := {}    # instance id -> WeakRef to an enemy that has called notices()
var _awareness := {}  # instance id -> 0..1 while it's unaware
var _checked := {}    # instance id -> Time.get_ticks_msec() of its last notices()
var _unseen := {}     # instance id -> seconds a hunting enemy hasn't seen you (Master of Shadows)
var _xp_frame := -1


func player() -> Node3D:
	return get_tree().get_first_node_in_group("player") if is_inside_tree() else null


func is_sneaking() -> bool:
	var p := player()
	return p != null and p.get("is_sneaking") == true


func has_perk(id: String) -> bool:
	return id in Character.perks


## How much of an enemy's usual range it notices you at while you sneak, now.
func range_mult() -> float:
	var level: int = Skills.levels.get("sneak", Skills.START_LEVEL)
	var mult := RANGE_MULT * maxf(1.0 - RANGE_PER_LEVEL * (level - Skills.START_LEVEL), RANGE_FLOOR)
	var p := player()
	var still := p != null and Vector2(p.velocity.x, p.velocity.z).length() < 0.3
	mult *= STILL_MULT * Character.modifier("detection_still") if still else Character.modifier("detection_moving")
	mult *= lerpf(DARK_MULT * Character.modifier("detection_night"), 1.0, WorldClock.daylight())
	return mult * Character.modifier("detection") * Armor.noise_mult()   # heavy armour is loud


## Called by an unaware enemy every physics frame: has it noticed `foe` (the
## player, or a companion it would go for) `dist` metres away now?
func notices(enemy: Node3D, foe: Node3D, base_range: float, dist: float, delta: float) -> bool:
	var id := enemy.get_instance_id()
	_enemies[id] = weakref(enemy)
	_checked[id] = Time.get_ticks_msec()
	if foe != player():
		return dist < base_range   # companions don't sneak
	if not is_sneaking():
		if dist < base_range:
			_awareness.erase(id)
			return true
		_awareness[id] = maxf(_awareness.get(id, 0.0) - AWARE_DECAY * delta, 0.0)
		return false
	var reach := base_range * range_mult()
	var level: float = _awareness.get(id, 0.0)
	if dist < reach and sees(enemy):
		level += delta * AWARE_RATE * (0.4 + 1.2 * (1.0 - dist / reach)) * (foe.stats.modifier("awareness_rate") if foe.get("stats") is Stats else Character.modifier("awareness_rate"))   # Lanes-Walk too
	else:
		level -= delta * AWARE_DECAY
	if level >= 1.0:
		_awareness.erase(id)
		return true
	_awareness[id] = clampf(level, 0.0, 1.0)
	if dist < base_range and _xp_frame != Engine.get_physics_frames():
		_xp_frame = Engine.get_physics_frames()   # once a frame, however many are near
		Skills.add_xp("sneak", SNEAK_XP_PER_SECOND * delta)
	return false


## A clear line from the enemy's eyes to the player's chest (walls and ground block it).
func sees(enemy: Node3D) -> bool:
	var p := player()
	if p == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(enemy.global_position + Vector3.UP * 0.8, p.global_position + Vector3.UP * 1.0, 1)
	return enemy.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func awareness(enemy: Node) -> float:
	return _awareness.get(enemy.get_instance_id(), 0.0)


## A noise at `where` while you sneak ("melee", "spell", "archery", "kill", "lockpick"): every
## watching enemy within its reach (less with perks) gets most of the way to noticing.
func make_noise(where: Vector3, kind: String) -> void:
	if not is_sneaking():
		return
	if kind == "kill" and has_perk("quiet_kill"):
		return
	var radius: float = NOISE[kind] * Character.modifier("noise_" + kind)
	var now := Time.get_ticks_msec()
	for id in _enemies:
		var enemy = _enemies[id].get_ref()
		if enemy == null or now - int(_checked.get(id, 0)) > RECENT_MS:
			continue
		var dist: float = enemy.global_position.distance_to(where)
		if dist < radius:
			_awareness[id] = minf(_awareness.get(id, 0.0) + 0.5 + 0.5 * (1.0 - dist / radius), 0.99)


## The damage multiplier for hitting `target` now ("melee" or "archery"): 1 unless
## you're sneaking and it hasn't noticed you.
func sneak_attack_mult(target: Node, kind: String, weapon: ItemData = null) -> float:
	if not is_sneaking() or not target.has_method("is_unaware") or not target.is_unaware():
		return 1.0
	var mult: float = SNEAK_ATTACK[kind] * Character.modifier("sneak_attack_" + kind)
	if weapon != null and weapon.dagger:
		mult *= Character.modifier("sneak_attack_dagger")
	return mult


## After a sneak attack lands: XP, the notice, and what perks add.
func sneak_attack_landed(target: Node, mult: float) -> void:
	Skills.add_xp("sneak", SNEAK_ATTACK_XP)
	var p := player()
	if p:
		p.hud.notify("Sneak attack for %s damage!" % ("%dx" % roundi(mult) if is_equal_approx(mult, roundf(mult)) else "%.1fx" % mult))
	var stats = target.get("stats")
	var killed: bool = stats != null and stats.health <= 0.0
	if killed and p and has_perk("thrill_of_the_hunt"):
		p.stats.stamina = minf(p.stats.stamina + 25.0, p.stats.max_stamina)
	if killed and target is Node3D:
		make_noise(target.global_position, "kill")


## Master of Shadows: a hunting enemy that hasn't seen you (sneaking) for a few
## seconds gives up. Call it while chasing; true = go home.
func lost_track(enemy: Node3D, delta: float) -> bool:
	if not has_perk("master_of_shadows") or not is_sneaking():
		_unseen.erase(enemy.get_instance_id())
		return false
	var id := enemy.get_instance_id()
	if sees(enemy):
		_unseen[id] = 0.0
		return false
	_unseen[id] = _unseen.get(id, 0.0) + delta
	if _unseen[id] >= LOSE_TRACK_SECONDS:
		_unseen.erase(id)
		return true
	return false


## For the HUD: how close the most watchful enemy is to noticing you (0-1), and
## whether anything nearby is hunting you.
func status() -> Dictionary:
	var now := Time.get_ticks_msec()
	var top := 0.0
	var hunted := false
	var p := player()
	for id in _enemies.keys():
		var enemy = _enemies[id].get_ref()
		if enemy == null:
			_enemies.erase(id); _awareness.erase(id); _checked.erase(id); _unseen.erase(id)
			continue
		if now - int(_checked.get(id, 0)) <= RECENT_MS:
			top = maxf(top, _awareness.get(id, 0.0))
		if p and enemy.has_method("is_hunting") and enemy.is_hunting() and enemy.global_position.distance_to(p.global_position) < 40.0:
			hunted = true
	return {"awareness": top, "hunted": hunted}
