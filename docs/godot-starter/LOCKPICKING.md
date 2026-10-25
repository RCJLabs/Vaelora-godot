# Lockpicking

Phase 4's third skill (`docs/CHARACTER_BUILDING.md`). It's Agility's. The lore bible's thieves
are the Lampless, who "work on the dark of the Wanderer"; one perk takes that literally. The
rest is my design. The rules are `systems/lockpicking.gd` (the autoload `Lockpicking`), the
screen `ui/lockpick_screen.gd` (`LockpickScreen`).

## How it works

- **A locked container** (`loot_container.gd`, `lock_level` 0–4) says "Pick the lock (Adept)".
  E with a lockpick opens the lockpick screen; without one it tells you so. With its `key_id`
  in your pack it just opens.
- **Picking:** a marker sweeps back and forth along the lock. Press **Space**, **E**, **click**
  or **(A)** while it's in the gold sweet spot to set a pin. Set them all and it opens, and you
  take what's inside. **Esc** gives up (pins you set are lost).
- **A miss** drops a pin back. Half the time the pick snaps, too, and a snapped pick makes noise
  if you're sneaking (5 m, `Stealth.NOISE["lockpick"]`).
- **Picked locks stay open** (saved with the container).

| Lock | Pins | Sweet spot | Marker speed |
|---|---|---|---|
| Novice | 2 | 24% of the lock | 0.7 a second |
| Apprentice | 3 | 20% | 0.85 |
| Adept | 4 | 16% | 1.0 |
| Expert | 5 | 12% | 1.2 |
| Master | 6 | 9% | 1.45 |

- **Skill:** +1% sweet spot and 0.5% slower marker per level above 15 (the spot tops out at
  60% of the lock).
- **XP:** 1 a pin, and 6 × (lock level + 1) for opening it.
- **Lockpicks:** Maren sells ten (4 gold each). The cellar strongbox holds two.

## Where

| Lock | Container | Inside |
|---|---|---|
| Novice | Strongbox in the waystation cellar | 25 gold, 2 lockpicks, a healing potion |
| Apprentice | The bandits' lockbox, next to their chest | 60 gold, 2 iron ingots, a lockpick |
| Adept | The cult coffer in the Barrow's worktable chamber | 90 gold, a steel ingot, 2 moth wings |

None of the existing chests got locks: the bandit chest holds the Lost Wagon's strongbox.

## Perks (21)

| Branch | Perks (level) |
|---|---|
| The spot | Light Touch (15) → II (35) → III (60): +20% each · Steady Hands (20) → II (45): the marker 15% slower each |
| Picks | Sturdy Picks (20): snap half as often → **Lucky Break** (45): one in three snaps sets the pin anyway → **Unbreakable** (85) |
| Locks | Apprentice Locks (25) → Adept (50) → Expert (70) → Master (90): one pin fewer each → **Spring the Lock** (95): once a day, open any lock outright |
| Quiet | Silent Picking (20): snaps make no noise → **Under Pressure** (55): sneaking and unnoticed, +25% spot |
| — | **Nimble Fingers** (40): a miss doesn't drop a pin · **Locksense** (30): the first pin sets itself · **The Lampless Way** (40): +25% spot while the Wanderer is dark · **Treasure Hunter** (50): locked chests hold +50% gold · Scavenger (25): a lockpick or two in every locked chest · Burglar's Eye (15): +25% XP |

New modifiers: `lock_spot` and `lock_speed`.

## Not yet

- **Locked doors.** Only containers lock. `door.gd` and `location_door.gd` would take the same
  `lock_level` / `key_id`.
- **No Expert or Master locks are placed** yet; they want later places worth breaking into.
- **Crime.** Picking anyone's lock is fine: there are no owners, guards or bounties yet.
- **The cage** you wake in when captured (`cage_door.gd`) still opens by working at it, no
  pick needed, so a capture can never trap you.
- **Unlock spells.** A Shaping spell could open locks; not built.
