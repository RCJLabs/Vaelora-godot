# Light and Heavy Armour

Phase 2's second piece (`docs/CHARACTER_BUILDING.md`). Two skills: **Light Armour** (Agility)
and **Heavy Armour** (Endurance). The code is `systems/armor.gd` (the autoload `Armor`).

## The armour

Every armour piece has an **Armor Class**, light or heavy (`ItemData.armor_class`). Shields
have neither; they belong to Block.

| Piece | Slot | Class | Armour | Weight | Where |
|---|---|---|---|---|---|
| Leather Cap | head | light | 7 | 1.5 | Maren |
| Leather Cuirass | body | light | 20 | 6 | starting gear |
| Leather Gloves | hands | light | 5 | 1 | Maren |
| Leather Boots | feet | light | 6 | 2 | starting gear |
| Iron Helmet | head | heavy | 12 | 4 | the Soldier's start, the waystation cellar |
| Iron Cuirass | body | heavy | 32 | 18 | Maren |
| Iron Gauntlets | hands | heavy | 10 | 4 | Maren |
| Iron Boots | feet | heavy | 10 | 5 | Maren |

- **Armour:** a piece gives its armour × (1 + 1% per level of its skill above 15) × its
  class's perks. At skill 100 that's ×1.85 before perks.
- **Damage:** the rating cuts a hit by `rating / (rating + 100)`, as before. So 26 (the
  starting leather) stops 21%, and 100 stops half.
- **Heavy pieces** each make sprinting cost **6%** more Stamina. Each also makes you
  noticed sneaking **8%** further away (SNEAK.md).
  - A full heavy set is +24% and +32%.
  - Steel Lungs and Padded Plate take these away.
- **Weight** counts toward carry weight (Strength), unless Unhindered (light) or
  Conditioning (heavy) makes it weightless.
- **The menu** shows a piece as "Armor 30 (base 20) - Light, Body".

## Raising them

Being hit while wearing armour trains the skill: 0.3 XP per point of the hit (before
armour). It's shared by how many of head, body, hands and feet are that class. Two light
pieces get half, and a mixed set trains both. Blocked, warded and dodged hits don't count.

## Perks: in armour, or in a full set

A perk can carry an armour condition. `Character.modifier()` checks it on every use, so a
perk switches on and off as you change armour.

- `"when_wearing": "light"`: at least one light piece on.
- `"when_full": "heavy"`: head, body, hands and feet all heavy.

Perks that raise max Health or Stamina are always on (an armour condition there would let
you refill by swapping armour).

### Light Armour (21)

| Branch | Perks (level) |
|---|---|
| Armour | Agile Defender (15) → II (30) → III (50) → IV (70) → V (90): +15% light armour each → **Ghost Armour** (100): in all light armour, one blow every 15 s passes through you |
| The set | Custom Fit (25): all light +25% → **Unhindered** (35): light armour weighs nothing → Wind Walker (45): all light, Stamina +50% faster → Fleet (60): all light, +10% speed → **Deft Movement** (75): all light, 10% chance to slip any blow |
| Footwork | Quick Step (20): any light, dodging −25% Stamina → Evasion (40): any light, dodge i-frames +50% → **Counter-Strike** (55): any light, a dodged blow makes your next hit within 2 s +50% |
| Reflexes | Light Reflexes (30): any light, parry window +25% → Second Skin (45): any light, bleeding, poison and burning −25% |
| Shadows | Light Feet (25): any light, noticed sneaking at −10% range → Shadow-Cut (50): all light, melee sneak attacks +50% → Hide and Seek (65): all light, bow sneak attacks +50% |
| — | Supple (35): +20 max Stamina · Leather Wisdom (20): Light Armour +25% XP |

### Heavy Armour (21)

| Branch | Perks (level) |
|---|---|
| Armour | Juggernaut (15) → II (30) → III (50) → IV (70) → V (90): +15% heavy armour each → **Last Stand** (100): all heavy, below a quarter Health, blows do half |
| The set | Well Fitted (25): all heavy +25% → Tower of Strength (35): all heavy, staggered half as easily → **Conditioning** (50): heavy armour weighs nothing → **Reflect Blows** (75): all heavy, 10% chance to turn a blow back on the attacker |
| The cost | Steel Lungs (20): no sprint cost → Padded Plate (35): no sneaking penalty → Cushioned (45): any heavy, half fall damage |
| Holding | Bulwark (20): any heavy, blocking −25% Stamina → Shrug It Off (40): any heavy, harmful effects last half as long → Ironclad Recovery (60): all heavy, Health +50% faster |
| Hitting | Momentum (30): any heavy, power attacks +25% → Crushing Weight (55): any heavy, blows stagger 50% better |
| — | **Fists of Steel** (30): punching in heavy gauntlets adds their armour to the blow · Battle-Hardened (40): +25 max Health · Drillmaster (20): Heavy Armour +25% XP |

Bold perks are mechanics in code: `Armor.adjust_hit` (Ghost Armour, Deft Movement, Reflect
Blows, Last Stand), `PlayerCombat` (Counter-Strike, Fists of Steel) and `Armor.weightless`
(Unhindered, Conditioning). The rest are modifiers.

New modifier names this adds (see CHARACTER.md, "Modifiers"):

- `armor_light` and `armor_heavy`;
- `dodge_iframes`, `dot_damage_taken`, `harmful_duration`;
- `heavy_attack_damage`, `poise_dealt`;
- `skill_xp_<skill>` (XP for one skill, e.g. `skill_xp_heavy_armor`).

Existing names reused: `dodge_stamina`, `parry_window`, `block_stamina`, `fall_damage`,
`poise_damage_taken`, `stamina_regen`, `health_regen`, `move_speed`, `detection` and
`sneak_attack_<kind>`.

## Not yet

- Armour isn't visible on the body (first person shows none; third person shows the plain
  model).
- No more armour than the eight pieces above. Smithing (phase 4) is where better armour
  will come from.
- A reflected blow does its full damage to the attacker, with no animation beyond the
  enemy's flinch.
- Hits from traps and spell bolts that don't go through `receive_attack` don't train the
  skills.
