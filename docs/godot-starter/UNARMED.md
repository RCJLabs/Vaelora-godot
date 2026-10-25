# Unarmed

Phase 2's last skill (`docs/CHARACTER_BUILDING.md`). It's Strength's, one of my two additions
to make four skills per attribute. Fists already worked (a jab, and a power punch when you
hold the attack); now they have their own skill and tree. The code is in
`player/player_combat.gd` (fists, `_unarmed_damage` and `_unarmed_landed`).

## The skill

- **Fists use Unarmed:** `weapon_skill = "unarmed"` with nothing in your right hand. Before
  this, punches trained One-Handed.
- **Damage:** +1% per level (like every weapon skill), times `weapon_damage_unarmed` from
  perks. A plain jab does 4.
- **Training:** 3 XP a jab that lands, 5 a power punch.
- **Fists of Steel** (Heavy Armour) still adds heavy gauntlets' armour to a punch.

## Perks: bare-handed only

Most Unarmed perks carry `"when_unarmed": true`. They only work with nothing in your right
hand, checked live like the armour conditions (`Armor.perk_applies`). Draw a sword and
Flurry stops; sheathe it and it's back.

| Branch | Perks (level) |
|---|---|
| Fists | Iron Fist (15) → II (30) → III (50) → IV (70) → V (90): +25% punch damage each → **Quivering Palm** (100): a power punch on anyone below 15% Health finishes them |
| Rhythm | Flurry (20): attacks cost half the Stamina → **Combination** (35): each punch in a quick run on the same foe (within 1.5 s) +15%, up to +60% → **Knockout** (55): a power punch on a staggered foe ×3 |
| Weight | Haymaker (25): your blows stagger twice as well → **Open Wounds** (45): punches have a 20% chance to make them bleed |
| Guard | Martial Guard (20): fists block 50% instead of 30% → Deflecting Palms (40): parry window +50% → Counter-Punch (60): for 2 s after a parry, punches do double |
| Footwork | Light on Your Feet (20): +10% speed, dodging −25% Stamina → **Brawler's Recovery** (35): each punch that lands gives 2 Stamina → Unbreakable (75): −15% damage taken |
| Hybrids | **Spirit Fist** (30): each punch that lands gives 3 Magicka → **Elemental Fist** (50): with a Ruin spell readied, power punches +50% · Sucker Punch (25): bare-handed sneak attacks ×6 |
| — | Brawler (15): Unarmed +25% XP |

Bold perks are mechanics in code. The rest are modifiers (`attack_stamina`, `poise_dealt`,
`fist_block`, `parry_window`, `riposte_damage`, `move_speed`, `dodge_stamina`,
`damage_taken`, `sneak_attack_melee`, `skill_xp_unarmed`), limited to bare hands.

Knockout reads the target's `is_staggered()`. Wolves, bandits (and their variants) and
wisps have it.

## Not yet

- Fists still have one jab and one power punch, no combo string. Weapon arts (phase 5) are
  the place for a real moveset.
- No grapples, throws or disarms.
- Elemental Fist adds damage, not the spell's effect (no burning or chill).
