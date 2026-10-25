# Phase 1a Foundations

Systems the later features build on (ROADMAP.md, Phase 1a): status effects,
attributes, equipment, world state with interiors, and (added later) footsteps and ambience.

---

## Status effects

Temporary conditions on any character (player, wolves, NPCs): **Bleeding**, **Burning**,
**Poisoned** so far. The player's show above the health bar ("Bleeding x2 4s", red =
harmful, green = helpful).

| Effect | What it does | Comes from |
|---|---|---|
| Bleeding | −1.5 health/s per stack, stacks ×3, 6 s | Wolf bites (25% chance) |
| Burning | −3 health/s, +10% damage taken, 3 s | Flames spell |
| Poisoned | −0.5 health/s, half health and stamina regen, 20 s | Nothing yet (for poisons and traps later) |

- **Data:** one `.tres` per effect in `effects/` (`StatusEffectData`): duration, stacking
  (refresh / stack / ignore), health/stamina/magicka per second, and **modifiers**.
- **Modifiers** are named multipliers other systems ask for: `move_speed`, `damage_taken`,
  `damage_dealt`, `health_regen`, `stamina_regen`, `magicka_regen`. Battle Fury (Phase 1b)
  is `{"damage_dealt": 1.25, "damage_taken": 0.8}`, with no new code. More names (from traits
  and perks) are listed in CHARACTER.md.
- **Damage over time ignores armour**; hits don't.
- **Code:** `$StatusEffects.apply("bleeding")`, `.has("burning")`, `.remove(...)`,
  `.modifier("move_speed")`. A new effect: duplicate a `.tres`, edit it, add it to
  `EFFECT_FILES` in `systems/effect_library.gd`.
- **Spells** can leave one (`applies_effect` on a spell, like Flames → burning).
- Saved with the player.

## Attributes

Six attributes, base **10**, changed by race. **This is the draft list.** Names,
descriptions and amounts all live in `systems/attributes.gd`, so they're easy to change.

| Attribute | Per point above 10 | Human | Elf | Orc |
|---|---|---|---|---|
| Strength | +3% melee damage, +10 carry weight | 10 | 9 | **13** |
| Endurance | +5 max Health, +3 max Stamina | 10 | 8 | **12** |
| Agility | +1% move speed, +4% Stamina regen | 10 | **12** | 10 |
| Intellect | +5 max Magicka, +2% spell power | 10 | **12** | 8 |
| Willpower | +5% Magicka regen, harmful effects on you 4% shorter | 11 | 11 | 10 |
| Presence | +3% reputation gains | **12** | 10 | 9 |

With the race's own base pools, that makes Human 100/100/100, Elf 75/94/140, and Orc
140/121/60 for Health/Stamina/Magicka.

- **Every attribute governs some skills:** +3% XP for each of them per point above 10 (the
  table is in SKILLS.md). The skills list shows it: "One-Handed (STR)".
- **Carry weight:** 120 at Strength 10, +10 per point (`Attributes.carry_capacity()`).
  Everything you carry counts, worn or not (`Inventory.total_weight()`; Tab → Inventory shows
  "Carrying: 34 / 120"). Over it you're **Over-encumbered** (an effect in the HUD): half
  speed, no sprinting, until you put something down.
- **Willpower** shortens harmful effects on you (burning, chilled, wounded...): 4% per point
  above 10, from 40% to 160% of their time. Not enemies'. Helpful effects aren't touched.
- **Heavy weapons want Strength:** anything over 10 weight wants Strength 10 plus 1 per 2
  weight over (iron axe 11, iron mace 11, steel greatsword 14). Short of it, −4% damage and
  +6% stamina per swing for each point short (damage never below 60%). You can always use it;
  the item details say "Heavy: wants Strength 14".
- Presence's prices and persuasion come with the trading screen and Speech.

- Shown on the race screen and at the top of **Tab → Skills** (hover for details).
- Race sets the starting values; backgrounds, traits, 4 creation points and 1 point per
  level-up add to them (see CHARACTER.md).
- Saved; older saves get their race's values.

## Equipment

Weapons and armour are items with extra stats (`items/*.tres`, type Weapon or Armor).

| Item | Slot | Stats | Where |
|---|---|---|---|
| Iron Sword | Main hand | 15 damage, 0.55 s, reach 1.8 m, 10 stamina | Starting kit |
| Hunting Dagger | Main hand | 9 damage, 0.35 s, reach 1.35 m, 6 stamina | On the ground at the wolf den |
| Leather Cuirass | Body | 20 armour | Starting kit |
| Leather Boots | Feet | 6 armour | Starting kit |
| Iron Helmet | Head | 12 armour | The chest in the waystation cellar |
| Axe, mace, greatsword, wooden shield, hunting bow | | See COMBAT.md → Weapons | Bandits, Maren, starting kits |
| (no weapon) | — | Fists: 4 damage, 0.45 s, reach 1.3 m | — |

- **Tab → Inventory:** select an item → **Equip / Unequip**. Equipped items say
  "(equipped)"; the header shows your total **Armor**.
- **Armour** cuts hit damage by `armor / (armor + 100)`: the starting 26 means −21%, and
  all three pieces (38) mean −28%.
- **First-person models:** each weapon has a `Held Scene` (`items/models/*_fp.tscn`). Swap
  in a real sword model later by changing that one field.
- **Slots:** main hand, off hand, head, body, hands, feet, ring, amulet (hands, ring and
  amulet have no items yet). Shields go in the off hand.
- Equipped items stay in your inventory. Selling or dropping the last one unequips it.
- Old saves from before equipment get the starting kit.

## World state & interiors

**WorldState** remembers what changed in each location, saved with the game:
- **Dead wolves stay dead,** where they fell, until skinned (then they're gone). A
  half-killed pack stays half-killed.
- **Doors** stay open or closed.
- **Chests** stay emptied.

Pickups and quest steps still use story flags, as before.

**Location doors** move you between levels and interiors. Your health, effects, items,
spells and everything else come with you, and you arrive at a named **Marker3D**.

**The waystation cellar:** a hatch on the ground just south-east of Maren
("[E] Climb down into the waystation cellar"). It's a torchlit cellar with crates and an
**old chest** (iron helmet, a healing potion, 15 gold). Climb the wooden steps and press E
at the hatch above to go back up.

### Making your own interior
1. New scene, root `Node3D`, **add it to the group `navmesh_source`** (Node tab → Groups).
   Build floor, walls and props as StaticBody3D on layer 1.
2. Add a **Player** instance (`player/player.tscn`), a **Marker3D** where you arrive, a
   **WorldEnvironment** (interiors usually: no sky, low ambient, torches), and a
   **NavigationRegion3D** (copy the one from `levels/waystation_cellar.tscn`).
3. Add a door out: a StaticBody3D with `interactables/location_door.gd`, **Target Scene**
   = the outside level, **Target Marker** = a Marker3D there.
4. In the outside level, add a door in with the reverse settings.
5. Chests: a StaticBody3D with `interactables/loot_container.gd` and its **Contents** (item
   id → count) and **Gold**.

### Making something remember itself
Add the node to the group `persistent` and give it `get_persist_state()` /
`apply_persist_state(state)`, then call `WorldState.restore(self)` at the end of
`_ready()`. See `interactables/door.gd` for the smallest example.

### Technical note: scene changes happen at the end of the frame
`change_scene_to_file()` removes the current level from the tree immediately, which broke
the rest of the player's update when a door was used from inside it. Travel and loading now
switch scenes at the end of the frame (`SaveSystem._change_scene_at_end_of_frame`).

---

## Footsteps & ambience

**Footsteps** (`player/player_footsteps.gd`, the player's Footsteps node): one step every
1.6 m walking and 2.3 m sprinting, and a louder one when landing from a fall. The sound
depends on the floor's StaticBody3D group:

| Group | Sound | Used on |
|---|---|---|
| `surface_stone` | `footstep_stone_1..3` | the stone block, the boulder, the cellar floor |
| `surface_wood` | `footstep_wood_1..3` | the fence, chests, crates, the cellar stairs and bed |
| (none) | `footstep_soft_1..3` | grass and dirt: everything else |

To mark a new floor: select its StaticBody3D → **Node** dock → **Groups** → add
`surface_stone` or `surface_wood`. Each step picks one of the three takes at random. For a
new surface type (mud, water), add the group name to `surface()` and three files named
`footstep_<name>_1..3`.

**Ambience** (`levels/ambience.gd`, an Ambience node in each level): outdoors, a day loop
(wind and birds) and a night loop (wind and crickets) crossfade with the time of day over
3 seconds, so sleeping doesn't snap. With **Indoor** ticked it plays one room-tone loop
(`ambience_cellar`: low hum and drips). Campfires play a 3D crackle loop you hear from about
20 m.

Every sound is a synthesised placeholder from `tools/make_placeholder_sfx.py`, so nothing
needs licensing. Replace any file in `assets/sfx/` with a recording of the same name (`.wav`
or `.ogg`). Loops are looped in code (`Sfx.loop`), so a replacement doesn't need its import
settings changed. **Nobody has listened to these yet:** they were checked as waveforms
(levels, step rate, seamless loops), not by ear.
