# Sneak

The first of the phase 2 skills (`docs/CHARACTER_BUILDING.md`). The skill is Agility's.
The code is `systems/stealth.gd` (the autoload `Stealth`), plus a few lines each in the
player, the enemies, the arrow and the HUD.

## Crouching

**C** (gamepad **D-pad down**) toggles sneaking. Crouched, you:

- move at **55%** of walking speed (Low Profile: faster);
- see from lower down;
- stand up again if you **sprint, jump or dodge** (Shadow Step: dodging doesn't stand you up).

The HUD shows a marker under the compass while you sneak:

| Marker | Means |
|---|---|
| **HIDDEN** | No enemy is noticing you. |
| **hidden?** | An enemy is starting to notice you (white turning amber). |
| **NOTICED** | An enemy is more than halfway to seeing you. |
| **SEEN** (red) | Something nearby is hunting you. |

## Being noticed

**Standing up:** an enemy notices you the moment you're inside its range (wolves 14 m,
bandits 12 m, wisps 16 m), except that **enemies that hunt by sight** (bandits, guards,
cultists, inquisitors: `hunts_by_sight`) also have to **see** you:
- in front of them, within about 100 degrees each side of where they face;
- with a clear line from their eyes to you.

Right beside them (2 m) they notice you whichever way they face. Wolves and wisps go by
scent and sense, as before.

**Crouched:**

- **Range shrinks.** It's the enemy's range × 65% × (1 − 0.5% per Sneak level above 15),
  floored at 30% of that 65%. Then:
  - × 0.7 if you're standing still;
  - × 0.75 at the dead of night (scaling with daylight);
  - × whatever your perks give.

  For a wolf, at Sneak 15 in daylight, that's 9.1 m moving and 6.4 m still. At Sneak 100,
  standing still at night, it's 2.1 m.
- **It has to see you.** A ray from its eyes to your chest must be clear, so walls and
  terrain hide you.
- **Noticing takes time.** Awareness fills while you're in range and in sight: about
  0.6 s right beside it, about 2.5 s at the edge. It drains when you're not. When it's full,
  the enemy comes for you.
- **Losing you:** an enemy heading home after losing you rechecks the same way (at half
  its range).
- **Companions don't sneak.** An enemy after your companion notices them as usual.

### Noise

These are heard through walls. While you sneak, they push a watching enemy's awareness
to between half and nearly full. Standing or sneaking, an enemy that hears one comes to
look (below). Standing up, they carry half as far again (×1.5).

| Noise | Heard within (sneaking) | Perk |
|---|---|---|
| A swing | 6 m | Quiet Blade: 40% |
| A spell (cast, or every moment of a stream) | 8 m | Silent Casting: 25% |
| Loosing an arrow | 3 m | Soft Release: silent |
| A sneak-attack kill | 8 m around the body | Quiet Kill: silent |
| A lockpick snapping | 5 m | Silent Picking (Lockpicking): silent |

**Footsteps** (`Stealth.step`, from `player/player_footsteps.gd`):

| Step | Heard within |
|---|---|
| Walking | 3 m |
| Sprinting | 7 m |
| Landing from a fall | 6 m |
| Crouched | silent, or 1.5 m × your armour's noise in heavy armour |

All of these are multiplied by your armour's noise (`Armor.noise_mult()`).

### Hearing and searching

Enemies that hunt by sight (`enemies/bandit.gd`) don't just notice or not:

- **Hearing:** a noise or footstep in reach sends it to **look** (`INVESTIGATE`): it walks to
  where the sound was, then **searches** round about (`SEARCH`), wandering up to 5 m and
  turning to look, for 8 s. Then it gives up and goes back to its post.
- **Searching, it's on its guard:** its range is ×1.4 and awareness fills ×1.4 as fast. It
  still hasn't found you, so a sneak attack still lands.
- **Losing you:** chasing, it heads for where it **last saw you**, not where you are. After
  2.5 s out of its sight it goes there and searches. Master of Shadows still makes it give up
  and go home (4 s unseen while you sneak).
- **Shouting:** when one starts a fight it shouts. Anyone within 15 m comes to look, not only
  its own band; its own band joins the fight, as before.
- **Bodies:** on watch, a dead friend it can see within 14 m sets it searching where they lie.
- **The HUD** says **SEARCHING** (amber) while you sneak and something nearby is looking.

## Sneak attacks

Hitting an enemy that **hasn't noticed you**, while you're **sneaking**, is a sneak attack.
Melee does **×3** and arrows **×2** (the arrow counts if you were crouched when you loosed
it and still are when it lands). With perks:

- Backstab: melee ×6.
- Assassin's Blade: a dagger ×15 (the hunting dagger has `dagger = true`).
- Deadly Aim: arrows ×3.
- Poised Strike: triple poise damage, and the hit counts as heavy (it staggers).

A notice says "Sneak attack for 3x damage!". The enemy knows about you afterwards.

Enemies that can be sneak attacked have `is_unaware()`. So far that's wolves (and the hollow
wolf), bandits (and cultists and the inquisitor) and wisps, while idle. The stone guardian
and The First can't be.

## Raising it

- **Sneaking near enemies:** 0.5 XP a second while you're crouched inside an unaware
  enemy's *usual* range (once a frame, however many there are).
- **Sneak attacks:** 6 XP each.

## Perks (22)

Five branches. Each line is a chain, top to bottom (the skill level each perk needs).

| Branch | Perks |
|---|---|
| Unseen | Stealthy (15) → II (30) → III (50) → IV (70) → V (90): each −10% range |
| Footwork | Low Profile, +25% sneaking speed (20) → Muffled Steps, −20% range while moving (30) → Light Foot, sneaking doesn't set off pressure plates (40) → Shadow Step, dodging doesn't stand you up (60) |
| Patience | Patient Hunter, −25% range standing still (25) → Night Prowler, −20% in the dark (35) → Slip Away, enemies take 30% longer to notice (55) → Master of Shadows, out of sight for 4 s while sneaking, hunters lose your trail and go home (80) |
| The knife | Backstab, melee ×6 (25) → Poised Strike, sneak attacks stagger (40) → Thrill of the Hunt, a sneak-attack kill gives back 25 Stamina (60); and Backstab → Assassin's Blade, dagger ×15 (50) |
| The bow and the quiet | Deadly Aim, arrows ×3 (30) → Soft Release, silent arrows (40); Quiet Blade, swings heard at 40% (35) → Silent Casting, spells at 25% (45) → Quiet Kill, sneak-attack kills are silent (65) |

The perk modifiers (see CHARACTER.md, "Modifiers") are `detection`, `detection_still`,
`detection_moving`, `detection_night`, `awareness_rate`, `sneak_speed`,
`sneak_attack_melee`, `sneak_attack_archery`, `sneak_attack_dagger` and `noise_<kind>`.
Light Foot, Shadow Step, Poised Strike, Thrill of the Hunt, Quiet Kill and Master of
Shadows are checked by id (`Stealth.has_perk`).

## Pickpocketing

Crouched, E at a person picks their pocket instead of talking. The prompt shows the
chance: "Pickpocket Hedda Marrow (55%)". It's 30% at Sneak 15, +0.6% per level, +25% from
behind, less on wary people (officials, merchants, scholars), capped at 90%. Success gives
their coin (and sometimes what they carry, by role) and 8 Sneak XP. Failure is a 25 gold
bounty. One try per person per day either way. Guards can't be picked. See CRIME.md.

## Adding it to a new enemy

In its "unaware" state, replace the range check with:

```gdscript
if Stealth.notices(self, foe, aggro_range, dist, delta):
	start_the_fight()
```

Then add `is_unaware()` (true while idle) and `is_hunting()` (true while it's after
someone). Optionally, call `Stealth.lost_track(self, delta)` while it chases, so Master of
Shadows works on it.

To give it sight and hearing like a bandit's: `hunts_by_sight = true`, a `hear(where)` that
sends it to look, and `is_alert()` (true while it's looking). `enemies/bandit.gd` has the
whole thing: `_investigate()`, `_search()`, `_look_for_bodies()`.

## Not yet

- Wolves and wisps have no vision cone and don't hear: they still notice anything in range.
- Ordinary townsfolk don't react to noise (only Crime's witnesses, who see).
- Searching enemies wander towards random spots near the noise; they don't check doorways
  or hiding places on purpose.
- Lights (a lantern, a spell in your hand) don't give you away.
- In third-person view the body doesn't crouch (only the first-person camera drops).
- Light Foot has no automated test (the pressure plate needs its scene); it's two lines in
  `props/traps/pressure_plate.gd`.
