extends Node

# Theft and the law. Autoloaded as "Crime". docs/godot-starter/CRIME.md.
#
# Things can belong to someone (a pickup's or a container's `belongs_to`).
# Taking them is theft; picking a pocket (crouched, at an NPC) is too. If anyone
# sees it (witnesses()), you get a bounty in that region. Seen or not, what you
# took is stolen: merchants in the region it came from won't buy it. Guards
# (NPCs with the guard role) stop you while you have a bounty where they serve:
# pay it (they take the stolen goods), talk your way out (Speech), go to the
# cells (days pass, the goods are taken), or run: then they fight (enemies/guard.gd),
# every guard near you. Guards don't kill: beaten by them, you're arrested (the
# cells); beat one and they yield (a bounty for assault); outrun them and they go
# back to their posts. A seen crime also costs you standing with the region's
# people (Reputation, if you've met them).
#
# Who sees: people (interactables/npc.gd, group "people") who are out (not gone
# in for the night), facing you (about 100 degrees each side), with a clear line
# to you, within WITNESS_RANGE: shorter at night, and shorter still crouched
# (Stealth.range_mult(): your Sneak skill, standing still, perks).

signal changed

## Region by level file (the scene's file name). Levels not listed have no law.
const REGIONS := {
	"test_level": "vale",
	"weirholt": "riverlands",
	"grieving_fields": "fields",
	"ilunhall": "capital",
}
const REGION_NAMES := {"vale": "the Greywater Vale", "riverlands": "the Riverlands", "fields": "the Grieving Fields", "capital": "Ilunhall"}

const WITNESS_RANGE := 15.0
const NIGHT_MULT := 0.6          # standing, at the dead of night
const SIGHT_COS := -0.2          # facing: the cosine of the widest angle they see at (about 100 degrees each side)
const MIN_THEFT := 5             # a bounty for a theft is the goods' value, at least this
const PICKPOCKET_CAUGHT := 25    # caught with your hand in a pocket, on top of nothing taken
const RESISTING := 10            # running from a guard adds this
const GUARD_RANGE := 9.0         # a guard stops you this close, if they can see you
const GUARD_COOLDOWN := 60.0     # seconds after you run before guards try again
const JAIL_GOLD_PER_DAY := 100   # a day in the cells per this much bounty (1 to 7 days)
const GUARD_DIALOGUE := "res://dialogue/guard_crime.json"
const ASSAULT := 40              # beating a guard until they yield
const CALL_RANGE := 40.0         # guards this near you join the fight when you run
const GUARD_SCENE := "res://enemies/bandit.tscn"   # loaded when guards first fight, not at startup
const GUARD_SCRIPT := "res://enemies/guard.gd"
## A region's people, and what a seen crime costs you with them.
const FACTIONS := {"vale": "riverwatch", "riverlands": "river_compact", "fields": "ashen_fields", "capital": "ilunar_empire"}
const REPUTATION_LOSS := {"theft": 2, "pickpocket": 3, "resist": 2, "assault": 5}

## Pickpocketing: the base chance at Sneak 15, more per level above, more from behind.
const PICK_BASE := 0.3
const PICK_PER_LEVEL := 0.006
const PICK_BEHIND := 0.25
const PICK_MAX := 0.9
const PICK_XP := 8.0
## What people carry, by role: [gold min, gold max, {item: count} sometimes].
## Guards and inquisitors can't be picked (they'd know).
const POCKETS := {
	"commoner": [3, 12, {"bread": 1}],
	"worker": [5, 15, {"bread": 1}],
	"merchant": [20, 50, {"lockpick": 2}],
	"innkeeper": [15, 40, {"bread": 2}],
	"official": [40, 90, {}],
	"physician": [10, 25, {"minor_healing_potion": 1}],
	"scholar": [10, 30, {}],
	"priest": [2, 8, {}],
	"hunter": [5, 15, {"arrow": 5}],
	"child": [0, 3, {"apple": 1}],
}
## How much harder a role is to pick (taken off the chance).
const WARY := {"official": 0.15, "merchant": 0.1, "scholar": 0.05}

var bounty := {}        # region -> gold
var stolen := {}        # region -> {item id: count} you carry, stolen there
var picked := {}        # "<level>/<npc>" -> the day their pocket was last picked
var next_roll := -1.0   # tests: the next pickpocket roll (0-1), then back to random
var _guard_quiet_until := 0.0   # Time in seconds: guards leave you be until then (you ran)
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	Inventory.changed.connect(_forget_gone)


func reset() -> void:
	bounty = {}
	stolen = {}
	picked = {}
	_guard_quiet_until = 0.0
	changed.emit()


## This level's region ("" if there's no law here).
func region() -> String:
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene == null:
		return ""
	return REGIONS.get(scene.scene_file_path.get_file().get_basename(), "")


func region_name(r: String) -> String:
	return REGION_NAMES.get(r, r)


func bounty_in(r: String) -> int:
	return int(bounty.get(r, 0))


func bounty_here() -> int:
	return bounty_in(region())


func player() -> Node3D:
	return get_tree().get_first_node_in_group("player") if is_inside_tree() else null


# --- Who sees ---------------------------------------------------------------

## How far people see a crime from, now.
func witness_range() -> float:
	if Stealth.is_sneaking():
		return WITNESS_RANGE * Stealth.range_mult()
	return WITNESS_RANGE * lerpf(NIGHT_MULT, 1.0, WorldClock.daylight())


## Whether `person` (an NPC) sees the player now, within `reach` metres.
func sees(person: Node3D, reach: float) -> bool:
	var p := player()
	if p == null or person == null or not person.is_visible_in_tree() or person.get("inside") == true:
		return false
	var to := p.global_position - person.global_position
	if to.length() > reach:
		return false
	var forward := -person.global_basis.z
	var flat := Vector3(to.x, 0, to.z)
	if flat.length() > 0.5 and Vector3(forward.x, 0, forward.z).normalized().dot(flat.normalized()) < SIGHT_COS:
		return false   # behind them
	var query := PhysicsRayQueryParameters3D.create(person.global_position + Vector3.UP * 1.4, p.global_position + Vector3.UP * 1.0, 1)
	if person is CollisionObject3D:
		query.exclude = [person.get_rid()]
	return person.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Everyone who'd see a crime now (not `except`).
func witnesses(except: Node = null) -> Array:
	var reach := witness_range()
	return get_tree().get_nodes_in_group("people").filter(func(n): return n != except and sees(n, reach))


func watched(except: Node = null) -> bool:
	return region() != "" and not witnesses(except).is_empty()


## " (watched)" while someone would see, for a prompt.
func watched_tag(except: Node = null) -> String:
	return " (watched)" if watched(except) else ""


# --- Crimes -----------------------------------------------------------------

## You took `items` ({id: count}) and `gold` that belong to `owner_name`. Marks
## the goods stolen; if anyone sees, a bounty of their worth. True = seen.
func theft(items: Dictionary, gold: int, owner_name: String, except: Node = null) -> bool:
	var r := region()
	if r == "":
		return false
	var worth := gold
	for id in items:
		_mark_stolen(r, id, int(items[id]))
		var item := Inventory.get_item(id)
		worth += (item.value if item else 0) * int(items[id])
	if witnesses(except).is_empty():
		return false
	_add_bounty(r, maxi(worth, MIN_THEFT), "Seen stealing from %s!" % owner_name, "theft")
	return true


func _mark_stolen(r: String, id: String, count: int) -> void:
	if not stolen.has(r):
		stolen[r] = {}
	stolen[r][id] = int(stolen[r].get(id, 0)) + count
	changed.emit()


func _add_bounty(r: String, amount: int, what: String, kind := "") -> void:
	bounty[r] = bounty_in(r) + amount
	var p := player()
	if p and p.get("hud"):
		p.hud.notify("%s Bounty in %s: %d gold." % [what, region_name(r), bounty_in(r)])
	var faction: String = FACTIONS.get(r, "")
	if kind != "" and faction != "" and Reputation.known(faction):
		Reputation.add(faction, -int(REPUTATION_LOSS[kind]))
	changed.emit()


## How many of `id` you carry that were stolen in `r` (all regions if "").
func stolen_count(id: String, r: String = "") -> int:
	if r != "":
		return int(stolen.get(r, {}).get(id, 0))
	var total := 0
	for each in stolen:
		total += int(stolen[each].get(id, 0))
	return total


## The goods are gone from your pack (sold, eaten, dropped): stop counting them.
## Your own copies go first; a count only drops when you carry fewer than were stolen.
func _forget_gone() -> void:
	var dirty := false
	for r in stolen.keys():
		for id in stolen[r].keys():
			var extra := stolen_count(id) - Inventory.count(id)
			if extra <= 0:
				continue
			var drop := mini(extra, int(stolen[r][id]))
			stolen[r][id] -= drop
			if stolen[r][id] <= 0:
				stolen[r].erase(id)
			dirty = true
	if dirty:
		changed.emit()


## The law takes back what was stolen in `r`.
func confiscate(r: String) -> int:
	var taken := 0
	var goods: Dictionary = stolen.get(r, {}).duplicate()
	stolen.erase(r)   # first, so _forget_gone doesn't move the count to another region
	for id in goods:
		var n := mini(int(goods[id]), Inventory.count(id))
		if n > 0:
			Inventory.remove(id, n)
			taken += n
	changed.emit()
	return taken


# --- Pickpocketing ----------------------------------------------------------

func _pick_key(person: Node) -> String:
	var scene := get_tree().current_scene
	return "%s/%s" % [scene.scene_file_path.get_file().get_basename() if scene else "", person.name]


## Can `person` be picked now? ("" = yes, else why not.)
func why_not_pick(person: Node) -> String:
	if not POCKETS.has(person.get("role")):
		return "no"
	if int(picked.get(_pick_key(person), -1)) == WorldClock.day:
		return "Nothing more on %s today." % person.get("display_name")
	return ""


## The chance to pick `person`'s pocket now (0-1).
func pick_chance(person: Node3D) -> float:
	var level: int = Skills.levels.get("sneak", Skills.START_LEVEL)
	var chance := PICK_BASE + PICK_PER_LEVEL * (level - Skills.START_LEVEL) - float(WARY.get(person.get("role"), 0.0))
	var p := player()
	if p:
		var to := p.global_position - person.global_position
		to.y = 0.0
		var forward := -person.global_basis.z
		if to.length() > 0.01 and Vector3(forward.x, 0, forward.z).normalized().dot(to.normalized()) < 0.0:
			chance += PICK_BEHIND
	chance *= Character.modifier("pickpocket")
	return clampf(chance, 0.05, PICK_MAX)


func _roll() -> float:
	if next_roll >= 0.0:
		var r := next_roll
		next_roll = -1.0
		return r
	return _rng.randf()


## Try `person`'s pocket. True = you got something (you may still have been seen by others).
func pickpocket(person: Node3D) -> bool:
	var p := player()
	if why_not_pick(person) != "":
		return false
	picked[_pick_key(person)] = WorldClock.day
	var name: String = person.get("display_name")
	if _roll() >= pick_chance(person):
		var r := region()
		if r != "":
			_add_bounty(r, PICKPOCKET_CAUGHT, "%s catches your hand in their pocket!" % name, "pickpocket")
		elif p:
			p.show_message("%s catches your hand in their pocket!" % name)
		return false
	var pocket: Array = POCKETS[person.get("role")]
	var gold := _rng.randi_range(int(pocket[0]), int(pocket[1]))
	var items := {}
	if _rng.randf() < 0.6:
		items = pocket[2]
	var got := []
	for id in items:
		Inventory.add(id, int(items[id]))
		got.append("%s x%d" % [Inventory.get_item(id).display_name, int(items[id])] if int(items[id]) > 1 else Inventory.get_item(id).display_name)
	if gold > 0:
		Inventory.add_gold(gold)
		got.push_front("%d gold" % gold)
	Skills.add_xp("sneak", PICK_XP)
	if p:
		p.show_message("You lift %s from %s." % [", ".join(got) if not got.is_empty() else "nothing worth having", name])
	theft(items, gold, name, person)   # stolen, and seen if anyone else saw
	return true


# --- The law ----------------------------------------------------------------

## Guards may stop you now (not just after you ran).
func guards_may_stop() -> bool:
	return Time.get_ticks_msec() / 1000.0 >= _guard_quiet_until


## Pay the bounty here: the gold, and the stolen goods.
func pay() -> void:
	var r := region()
	var owed := bounty_in(r)
	if owed <= 0 or Inventory.gold < owed:
		return
	Inventory.add_gold(-owed)
	bounty.erase(r)
	var taken := confiscate(r)
	_tell("You pay %d gold.%s" % [owed, " They take what you stole." if taken > 0 else ""])


## Talked your way out: the bounty's gone; you keep the goods.
func pardon() -> void:
	bounty.erase(region())
	changed.emit()


## Ran from a guard: more bounty, and every guard near you comes after you.
## (Lose them and they leave you be for a minute.)
func resist() -> void:
	var r := region()
	if r == "":
		return
	_quiet()
	_add_bounty(r, RESISTING, "You run from the guard.", "resist")
	call_guards()


func _quiet() -> void:
	_guard_quiet_until = Time.get_ticks_msec() / 1000.0 + GUARD_COOLDOWN


## Every guard within CALL_RANGE of you takes up arms. Returns how many.
func call_guards() -> int:
	var p := player()
	if p == null:
		return 0
	var called := 0
	for person in get_tree().get_nodes_in_group("people"):
		if person.get("role") == "guard" and person.is_visible_in_tree() and not person.has_meta("armed") \
				and person.global_position.distance_to(p.global_position) < CALL_RANGE:
			_to_arms(person)
			called += 1
	return called


# The guard NPC steps out of the scene; a fighter in their clothes steps in.
func _to_arms(person: Node3D) -> void:
	var fighter: CharacterBody3D = load(GUARD_SCENE).instantiate()
	var kept := {}   # the scene's own settings (its swings, its sword), which a new script would drop
	for prop in fighter.get_property_list():
		if prop["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE and prop["usage"] & PROPERTY_USAGE_STORAGE:
			kept[prop["name"]] = fighter.get(prop["name"])
	fighter.set_script(load(GUARD_SCRIPT))
	for key in kept:
		fighter.set(key, kept[key])
	fighter.name = "%sArmed" % person.name
	fighter.display_name = person.display_name
	fighter.look_race = person.race if person.race != "" else "human"
	fighter.look_cloth = person.clothes()
	fighter.max_health = 90.0
	fighter.attack_damage = 12.0
	fighter.guard_chance = 0.6
	fighter.parry_chance = 0.15
	fighter.gold = 0
	fighter.loot = {}
	fighter.post = person
	fighter.transform = person.global_transform
	person.set_meta("armed", fighter)
	person.visible = false
	person.collision_layer = 0
	get_tree().current_scene.add_child(fighter)


# The fighter goes; the guard NPC is back (where the fighter stood, if `here`).
func _back_to_post(fighter: Node3D, here: bool) -> void:
	var person: Node3D = fighter.post
	if person and is_instance_valid(person):
		person.remove_meta("armed")
		person.visible = true
		person.collision_layer = 1
		if here:
			person.global_position = fighter.global_position
			person.rotation.y = fighter.rotation.y
	fighter.remove_from_group("guards_fighting")
	fighter.name = "%sStoodDown" % fighter.name   # free the name now: they may take up arms again this frame
	fighter.queue_free()


## A fighting guard has lost you and is back at their post.
func stand_down(fighter: Node3D) -> void:
	_back_to_post(fighter, false)
	_quiet()


## Beaten down: they yield, and you've assaulted a guard.
func guard_yields(fighter: Node3D) -> void:
	if fighter.is_queued_for_deletion():
		return
	_back_to_post(fighter, true)
	_quiet()
	var r := region()
	if r != "":
		_add_bounty(r, ASSAULT, "%s yields." % fighter.display_name, "assault")


## E at a fighting guard: everyone lowers their weapons, and they talk again.
func surrender(fighter: Node3D) -> void:
	var person: Node3D = fighter.post
	for each in get_tree().get_nodes_in_group("guards_fighting"):
		_back_to_post(each, each == fighter)
	_guard_quiet_until = 0.0
	if person and is_instance_valid(person):
		DialogueManager.start(GUARD_DIALOGUE, person.display_name)


## Beaten by the guards: not death, the cells. (The player calls it instead of dying.)
func arrest(p: Node3D) -> void:
	for each in get_tree().get_nodes_in_group("guards_fighting"):
		_back_to_post(each, false)
	for id in p.effects.active.keys():
		var data: StatusEffectData = p.effects.active[id]["data"]
		if data.is_harmful and data.duration > 0.0:
			p.effects.remove(id)
	p.stats.refill()
	p.stats.health = p.stats.max_health * 0.5
	p.stats.changed.emit()
	p.is_dead = false
	Engine.time_scale = 1.0
	if bounty_here() <= 0:
		bounty[region()] = RESISTING   # (you can't be beaten by a guard with nothing owed, but just in case)
	jail()


## The cells: days pass, the goods are taken, the bounty's served. You come out at
## the level's "JailRelease" marker, if it has one. Returns the days served.
func jail() -> int:
	var r := region()
	var owed := bounty_in(r)
	if owed <= 0:
		return 0
	var days := clampi(ceili(owed / float(JAIL_GOLD_PER_DAY)), 1, 7)
	WorldClock.advance(days * 24.0)
	Survival.tick(days * 24.0, true)   # fed (badly) and slept
	bounty.erase(r)
	var taken := confiscate(r)
	var p := player()
	var release := get_tree().current_scene.find_child("JailRelease", true, false) as Node3D
	if p and release:
		p.global_position = release.global_position
		p.rotation.y = release.global_rotation.y
		p.velocity = Vector3.ZERO
	_tell("You serve %d day%s in the cells.%s" % [days, "" if days == 1 else "s", " Your stolen goods were taken." if taken > 0 else ""])
	if Character.modes.get("hardcore", false):
		SaveSystem.save_game(SaveSystem.AUTOSAVE, true)   # like a defeat: no loading your way out of it
	return days


func _tell(text: String) -> void:
	var p := player()
	if p:
		p.show_message(text)
	changed.emit()


## "{bounty}" and "{region}" in dialogue text.
func fill(text: String) -> String:
	if not "{" in text:
		return text
	return text.replace("{bounty}", str(bounty_here())).replace("{region}", region_name(region()))


func to_dict() -> Dictionary:
	return {"bounty": bounty.duplicate(), "stolen": stolen.duplicate(true), "picked": picked.duplicate()}


func from_dict(data: Dictionary) -> void:
	reset()
	for r in data.get("bounty", {}):
		bounty[r] = int(data["bounty"][r])
	for r in data.get("stolen", {}):
		stolen[r] = {}
		for id in data["stolen"][r]:
			stolen[r][id] = int(data["stolen"][r][id])
	for key in data.get("picked", {}):
		picked[key] = int(data["picked"][key])
	changed.emit()
