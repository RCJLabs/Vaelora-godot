extends Node

# Light Armour and Heavy Armour: the skills, and what the armour you wear does.
# Autoloaded as "Armor". docs/godot-starter/ARMOUR.md.
#
# Every armour piece is light or heavy (ItemData.armor_class; shields are
# neither: they're Block's). A piece's armour rises 1% per level of its skill
# above 15, times its class's perks (armor_light / armor_heavy). Being hit in it
# trains the skill, shared by how much of each you wear. Heavy pieces each make
# sprinting cost more and make you easier to notice sneaking; perks take those
# away (and can make the armour weigh nothing).
#
# Perks can apply only in armour: "when_wearing": "light" (at least one light
# piece on) or "when_full": "heavy" (head, body, hands and feet all heavy); or
# only bare-handed: "when_unarmed": true (the Unarmed skill's perks).
# Character.modifier() and stat_bonus() check it (perk_applies).

const SLOTS := ["head", "body", "hands", "feet"]
const KINDS := {ItemData.ArmorClass.LIGHT: "light", ItemData.ArmorClass.HEAVY: "heavy"}
const SKILL_FOR := {"light": "light_armor", "heavy": "heavy_armor"}
const PER_LEVEL := 0.01               # +1% of a piece's armour per skill level above 15
const XP_PER_DAMAGE := 0.3            # skill XP per point of a hit (before armour), shared by pieces worn
const HEAVY_SPRINT := 0.06            # +6% sprint Stamina per heavy piece
const HEAVY_NOISE := 0.08             # +8% to how far away you're noticed sneaking, per heavy piece
const GHOST_COOLDOWN := 15.0          # Ghost Armour: a hit shrugged off at most this often
const COUNTER_TIME := 2.0             # Counter-Strike: seconds after a dodge
const COUNTER_MULT := 1.5

var ghost_left := 0.0                 # Ghost Armour cooldown


func _process(delta: float) -> void:
	ghost_left = maxf(ghost_left - delta, 0.0)


## "light", "heavy" or "" for an item.
func kind_of(item: ItemData) -> String:
	return KINDS.get(item.armor_class, "") if item else ""


## How many of head, body, hands and feet are `kind` ("light" / "heavy").
func pieces(kind: String) -> int:
	var count := 0
	for slot in SLOTS:
		if kind_of(Inventory.equipped_item(slot)) == kind:
			count += 1
	return count


func is_full(kind: String) -> bool:
	return pieces(kind) == SLOTS.size()


## Does this perk work right now? (Its armour condition, if it has one.)
func perk_applies(perk: Dictionary) -> bool:
	if perk.has("when_wearing") and pieces(perk["when_wearing"]) == 0:
		return false
	if perk.has("when_full") and not is_full(perk["when_full"]):
		return false
	if perk.get("when_unarmed", false) and Inventory.equipped_item("main_hand") != null:
		return false   # Unarmed perks: only with bare fists
	return true


## The perk is taken and its condition holds (for perks checked by id).
func has_perk(id: String) -> bool:
	return id in Character.perks and perk_applies(Character.perk_list[id])


## One piece's armour now: its own, times its skill and perks.
func piece_armor(item: ItemData) -> float:
	var kind := kind_of(item)
	var base := item.armor * Smithing.armor_mult(item) + Smithing.armor_bonus(item)   # improved at a forge
	if kind == "":
		return base
	var level: int = Skills.levels.get(SKILL_FOR[kind], Skills.START_LEVEL)
	return base * (1.0 + PER_LEVEL * (level - Skills.START_LEVEL)) * Character.modifier("armor_" + kind)


## Everything you wear, added up (Stats.armor_rating).
func rating() -> float:
	var total := 0.0
	for id in Inventory.equipped.values():
		var item := Inventory.get_item(id)
		if item and item.type == ItemData.Type.ARMOR:
			total += piece_armor(item)
	return total


## A hit got through (before armour): train the skills you're wearing.
func hit_taken(damage: float) -> void:
	for kind in ["light", "heavy"]:
		var share := pieces(kind) / float(SLOTS.size())
		if share > 0.0:
			Skills.add_xp(SKILL_FOR[kind], damage * XP_PER_DAMAGE * share)


## Sprint Stamina multiplier from heavy pieces (Steel Lungs: none).
func sprint_mult() -> float:
	return 1.0 if has_perk("steel_lungs") else 1.0 + HEAVY_SPRINT * pieces("heavy")


## How much further away you're noticed sneaking, from heavy pieces (Padded Plate: none).
func noise_mult() -> float:
	return 1.0 if has_perk("padded_plate") else 1.0 + HEAVY_NOISE * pieces("heavy")


## Weight of worn armour that perks say weighs nothing (Unhindered, Conditioning).
func weightless() -> float:
	var total := 0.0
	for slot in SLOTS:
		var item := Inventory.equipped_item(slot)
		var kind := kind_of(item)
		if (kind == "light" and has_perk("unhindered")) or (kind == "heavy" and has_perk("conditioning")):
			total += item.weight
	return total


## An unblocked hit is about to land on you: what the armour perks make of it.
## Returns the damage to take (0 = none); when it's none, outcome["result"] is
## "dodged" (what the attacker is told).
func adjust_hit(damage: float, attacker: Node, player: Node, outcome: Dictionary) -> float:
	if has_perk("ghost_armor") and ghost_left <= 0.0:
		ghost_left = GHOST_COOLDOWN
		player.hud.notify("Ghost Armour turns the blow")
		outcome["result"] = "dodged"
		return 0.0
	if has_perk("deft_movement") and randf() < 0.1:
		player.hud.notify("Deft Movement: you slip the blow")
		outcome["result"] = "dodged"
		return 0.0
	if has_perk("reflect_blows") and randf() < 0.1 and attacker != null and attacker.has_method("take_hit"):
		attacker.take_hit(damage, player.global_position, 4.0)
		player.hud.notify("Reflected!")
		outcome["result"] = "dodged"   # to the attacker it's a miss (no bleed, no follow-up)
		return 0.0
	if has_perk("last_stand") and player.stats.health < player.stats.max_health * 0.25:
		damage *= 0.5
	return damage
