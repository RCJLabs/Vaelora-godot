# Character Creation, Traits, Powers & Perks

ROADMAP Phase 1b. **Every name and number here is a placeholder draft.** They all live in
JSON files in `godot/character/` (plus `systems/character.gd` for the rules), so renaming or
rebalancing doesn't need code.

---

## The creator

**New Game** on the title screen (`ui/title_screen.tscn`) opens a five-step creator. **Title**
on step 1 goes back to the title screen.

| Step | What you pick |
|---|---|
| 1. Race | Human, Elf, Orc (attributes, pools, race power on **Z**) |
| 2. Background | Soldier, Scholar, Outlaw, Hunter, Acolyte, Merchant (skills, gear, gold, reputation, power on **X**) |
| 3. Traits | Up to 2 strengths. Taking 1 flaw allows a 3rd strength. None is fine too |
| 4. Attributes | Spend **4** points. **Next** stays disabled until all are spent |
| 5. Name & mode | Name (blank = "Traveller"), **Survival** and **Hardcore** checkboxes, summary |

**Begin journey** resets everything (story, skills, items, reputation, world) and applies
the choices. Every step shows the resulting Health/Stamina/Magicka and attributes, using the
same formulas as the player. They're tested to match.

## Backgrounds (`character/backgrounds.json`)

| Background | Attributes | Skills | Gear and items | Gold | Riverwatch | Power (X) |
|---|---|---|---|---|---|---|
| Soldier | STR +1, END +1 | One-Handed +5, Athletics +5 | Iron Sword, Leather Cuirass, Leather Boots, Iron Helmet, a Wooden Shield (not equipped), 1 potion | 20 | +10 | Second Wind |
| Scholar | INT +2 | Destruction +5, Restoration +5, knows **Flames, Firebolt, Candlelight** | Hunting Dagger, Boots, 2 potions | 40 | | Clarity |
| Outlaw | AGI +1, PRE +1 | One-Handed +5, Athletics +5 | Dagger, Cuirass, Boots | 60 | **−15** | Shadowstep |
| Hunter | AGI +1, END +1 | Athletics +10 | Hunting Bow (equipped) and 24 arrows, Dagger, Cuirass, Boots, a wolf pelt | 25 | | Hunter's Focus |
| Acolyte | WIL +1, PRE +1 | Restoration +10, knows **Healing Ward, Mending** | Iron Sword, Boots, 3 potions | 15 | | Blessing |
| Merchant | PRE +2 | | Iron Sword, Cuirass, Boots | 150 | +5 | Steady Nerves |

Gear is equipped automatically. A background's fields are all optional: `attributes`,
`skills`, `gear`, `items`, `gold`, `spells`, `reputation`, `ability`.

## Traits (`character/traits.json`)

**Strengths:** Hardy (+2 END), Strong Arm (+2 STR), Nimble (+2 AGI), Bookish (+2 INT),
Quick Learner (skills +10% faster), Fleet-Footed (+5% speed), Thick-Skinned (−8% damage
taken), Charming (+15% reputation gains), Arcane Spark (+10% spell power).

**Flaws:** Frail (−2 END), Clumsy (−2 AGI), Dim (−2 INT), Glass Jaw (+10% damage taken),
Slow Learner (skills −10%), Bad Reputation (Riverwatch −15).

A trait can have `attributes`, `modifiers` (multipliers, see below), `stat_bonus`
(`{"health": 20}`) and `reputation`. The limits (2 strengths, 1 flaw) are constants at the
top of `systems/character.gd`.

## Powers (`character/abilities.json`)

**Z** uses your race power and **X** your background power. They show bottom right on the HUD
with their cooldowns, and a notice says when one is ready again.

| Power | Effect | Cooldown |
|---|---|---|
| Adaptable (Human) | Skills improve twice as fast for 60 s | 5 min |
| Innate Focus (Elf) | Spells cost half and hit 25% harder for 20 s | 3 min |
| Battle Fury (Orc) | +25% damage dealt, −20% taken for 15 s | 2 min |
| Second Wind | +50 Stamina, +20 Health now | 2 min |
| Clarity | +60 Magicka now | 2 min |
| Shadowstep | +40% speed for 6 s | 1 min |
| Hunter's Focus | +15% damage for 20 s | 90 s |
| Blessing | +4 Health/s for 10 s | 90 s |
| Steady Nerves | −20% damage taken, +50% Stamina regen for 12 s | 90 s |

A power either applies a **status effect** (`"effect": "battle_fury"`, an `effects/*.tres`
file) or **restores** pools instantly (`"restore": {"stamina": 50}`). Cooldowns are saved.

## Level-ups: perks and attribute points

Each character level gives **1 perk point** and **1 attribute point** (you start with 1 perk
point), on top of the existing +10 Health/Stamina/Magicka choice. Spend them in
**Tab → Skills** (a **+** next to each attribute; the **Perks** button there jumps to the tree) and **Tab → Perks** (`ui/perk_tree.gd`).

The Perks tab lists every skill with how many of its perks you have (`One-Handed 1/3`, and a
**•** when one is ready to take). The chosen skill's perks are drawn as a tree: a perk sits
one row under the perk it requires, with its level on the label. Its first follow-on carries
on down its column; each other follow-on opens the next column to the right, joined by an
elbow line. Every branch keeps its columns to itself, so no line crosses another perk or
line. Gold is taken, bright is ready (or would be, with a point), dim is locked. Click a perk to
see what it does and what it needs ("needs One-Handed 35", "needs Armsman"), then **Take** it.
The tree scrolls both ways and scrolls to the perk you pick, so a skill can hold 20+ perks
(Sneak has 22; the test also lays out 25).

| Skill | Perks (skill level needed) |
|---|---|
| One-Handed | Armsman +20% damage (15) · Fighting Rhythm, swings −25% Stamina (25) · Armsman II +20% (35, needs Armsman) |
| Athletics | Wind Runner, sprint −25% Stamina (20) · Sure-Footed, half fall damage (25) · Marathon +20 max Stamina (30, needs Wind Runner) |
| Destruction | Augmented Flames +25% (20) · Efficient Destruction −20% cost (25) · Searing +25% (35, needs Augmented Flames) |
| Restoration | Recovery, Magicka +25% faster (20) · Potent Healing +30% (25) · Efficient Restoration −20% cost (30, needs Potent Healing) · Ward Mastery, wards +20% (30, needs Recovery) |
| Block | Steady Guard, blocking −25% Stamina (20) · Deflection, parry window +50% (25) · Riposte, +50% damage for 2 s after a parry (35, needs Deflection) |
| Two-Handed | Barbarian +20% (15) · Reaver, heavy attacks −25% Stamina (25) · Barbarian II +20% (35, needs Barbarian) |
| Alteration | Efficient Alteration −25% cost (20) · Arcane Reserve +25 max Magicka (25) · Focused Mind, Magicka +25% faster (35, needs Arcane Reserve) |
| Archery | Overdraw +20% (15) · Quick Draw, bows draw 30% faster (25) · Overdraw II +20% (35, needs Overdraw) |
| Sneak | 22 perks in five branches: see SNEAK.md |
| Light Armour, Heavy Armour | 21 perks each, some only in armour or a full set: see ARMOUR.md |
| Speech | 22 perks: haggling, check bonuses (`check_bonus`), bribes, trainers, companions: see SPEECH.md |

### Respec

Magister Aurel's "rite of unlearning" (Tide College → "Can the College undo what I've
learned?", **150 gold**; the dialogue action `"respec": true`, `Character.respec()`):
- every perk comes back as a perk point;
- attributes go back to race + background + traits, and every point you chose comes back to
  spend (the 4 from creation plus 1 per level);
- the +10 Health / Stamina / Magicka level bonuses come back too (`Skills.level_spent`);
  bonuses from quest rewards stay. Saves from before this didn't record level spends, so they
  have none to give back.
- Skills, race, background and traits are untouched. Classes will change here too, once they
  exist.

## Modes

- **Hardcore:** you take 50% more damage, deal 20% more, and Health regenerates at a quarter
  of the speed. You can only save by resting at a bed or campfire. Defeat doesn't reload:
  you wake up wounded, captured or rescued (SURVIVAL.md).
- **Survival:** hunger, thirst, fatigue and cold (see SURVIVAL.md).

Modes can't be changed after creation (no in-game toggle yet).

## Modifiers: how traits, perks, powers and Hardcore stack

Everything is a named multiplier, and they multiply together. For example, Glass Jaw (1.1)
× Hardcore (1.5) × Thick-Skinned (0.92) = **1.518×** damage taken. Status effects (like Battle
Fury) multiply in too. Names you can use in traits, perks or effects:

`move_speed`, `damage_taken`, `damage_dealt`, `health_regen`, `stamina_regen`,
`magicka_regen`, `skill_xp`, `reputation_gain`, `spell_cost`, `spell_power`,
`spell_cost_<skill>` / `spell_power_<skill>` (e.g. `spell_power_destruction`),
`weapon_damage_<skill>` (e.g. `weapon_damage_one_handed`), `attack_stamina`,
`sprint_stamina`, `fall_damage`; and from the phase 2 skills, `skill_xp_<skill>`,
`armor_light` / `armor_heavy`, `dodge_stamina`, `dodge_iframes`, `parry_window`,
`block_stamina`, `dot_damage_taken`, `harmful_duration`, `heavy_attack_damage`,
`poise_dealt`, `poise_damage_taken`, `detection` (and `_still`, `_moving`, `_night`),
`awareness_rate`, `sneak_speed`, `sneak_attack_<melee|archery|dagger>`, `noise_<kind>`;
from Speech, `buy_price`, `sell_price`, `bribe_cost`, `merchant_gold`, `training_cost`,
`book_price`, `approval_gain`. A perk's `"check_bonus": {"persuade": 10}` (or `intimidate`,
or `all`) adds to Speech checks.

A perk can be limited to armour with `"when_wearing": "light"` (any light piece) or
`"when_full": "heavy"` (all four pieces); see ARMOUR.md.

## Dialogue that reacts to who you are

Two new conditions (see DIALOGUE.md for the rest):
- `"requires_background": "soldier"` or `["soldier", "hunter"]` (any of them)
- `"requires_trait": "charming"` or a list (all of them)

So far: **Maren** has a line for Soldiers and Hunters, and **Brannoc** for Outlaws (he half
recognises you from a wanted notice) and Scholars. Outlaws (and Bad Reputation) also start
at −15 with Riverwatch (Distrusted), so the garrison's potion sales, which need Friendly
(10), take longer to unlock.

## Adding your own

- **A background:** copy an entry in `backgrounds.json`, give it a new id, and pick an
  `ability`. It appears in the creator automatically.
- **A trait:** add an entry to `traits.json` with `"positive": true` or `false`.
- **A perk:** add an entry to `perks.json` with `skill`, `level`, an optional `requires`
  (another perk id), and `modifiers` or `stat_bonus`. The Perks tab places it by its level
  and `requires`; there's no layout to edit.
- **A power:** add an entry to `abilities.json`. If it uses an effect, create the `.tres`
  in `effects/` and add it to `EFFECT_FILES` in `systems/effect_library.gd`.

Saves from before characters existed load as "Traveller", with no background, traits or
perks.
