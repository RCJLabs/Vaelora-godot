# Combat, Weapons, Wolves, Bandits & Wisps

## Fighting (Phase 1c)

| Input | What it does |
|---|---|
| **Left-click** (tap) | Light attack. Tap again during a swing to **combo** (2–3 swings depending on the weapon; the last hits harder) |
| **Left-click** (hold) | Charge a **heavy attack** (the crosshair grows, then turns gold at full charge). Release to strike. A partial charge does 60–100% |
| **Right-click** (hold) | Whatever your **left hand** does (shown above the Magicka bar): with a free hand, **block** or cast the ready spell (**Q** cycles Block → each spell → Block); with a **shield**, block with it; with a **two-handed** weapon, block with it; with a **bow**, aim (zoom) |
| Left-click while blocking with a shield | **Shield bash**: breaks guards, big poise damage |
| Bow: hold / release left-click | **Draw** (the crosshair grows), release to loose an arrow. Short draws are weaker; under 15% drawn cancels. Uses one Arrow |
| Right-click just before a hit | **Parry**: no damage, the attacker staggers, you get 10 Stamina back, and a gold "Parry!" appears |
| **Alt** (gamepad **B**) | **Dodge** in the direction you're moving (backwards if standing still). Nothing can hit you for the first 0.22 s |

(If the mouse isn't captured, the first click only grabs it.)

### How a swing works
Every swing has three parts. **Windup** is the telegraph, before it can hit. **Active** is
when anything that enters your reach gets hit, once. **Recovery** is when you're committed
and can't swing again. Clicking during a swing queues the next one in the combo, and it
starts halfway through the recovery, so combos flow faster than single clicks. Stop for 0.4 s
and the combo starts over.

| Iron Sword (15 damage) | Windup / active / recovery | Damage | Stamina | Poise |
|---|---|---|---|---|
| 1. Right-to-left slash | 0.14 / 0.12 / 0.26 s | ×1.0 | 10 | 8 |
| 2. Left-to-right slash | 0.12 / 0.12 / 0.28 s | ×1.0 | 10 | 8 |
| 3. Overhead chop | 0.20 / 0.12 / 0.42 s | ×1.4 | 13 | 14 |
| Heavy (0.6 s charge, lunges forward) | 0.08 / 0.14 / 0.50 s | ×2.2 | 20 | 25 |

The Hunting Dagger is faster and weaker (a thrust, two slashes, and a lunging heavy stab at
×2.5). Fists jab, and have a heavy punch.

**Tuning:** each swing is an **AttackData** inside the weapon's `.tres`. Open
`items/iron_sword.tres` and expand **Light Attacks** / **Heavy Attack** in the Inspector.
Global feel (parry window, dodge speed, hit stop, combo timing) is in the constants at the
top of `player/player_combat.gd`.

### Weapons

| Weapon | Hands / skill | Damage | Combo | Feel | Where |
|---|---|---|---|---|---|
| Iron Sword | 1H / One-Handed | 15 | 3 | Balanced and quick; blocks 60% | Most starting kits |
| Hunting Dagger | 1H / One-Handed | 9 | 3 | Fastest; ×2.5 lunging heavy stab; blocks 40% | Wolf den |
| Iron Axe | 1H / One-Handed | 14 | 3 | Every hit can cause **Bleeding** (25%, the finisher 40%, the heavy 75%) | Bandit's body |
| Iron Mace | 1H / One-Handed | 16 | 2 | Slow, huge **poise** damage: two hits stagger a wolf; heavy 40 poise | Bandit Leader's body |
| Steel Greatsword | **2H** / Two-Handed | 26 | 3 | Slow, wide swings that **cleave** (hit everyone in front); blocks 70% | Bandit camp chest |
| Wooden Shield | Off hand / Block | bash 5 | – | Blocks **85%**, +8 armour, bash breaks guards. Takes your casting hand | Soldiers start with one; equip it from Tab → Inventory |
| Hunting Bow | **2H** / Archery | 16 at full draw | – | 0.8 s draw, arrows drop with distance. Can't block | Hunters start with one (and 24 arrows); Maren sells one (60 gold) and arrows (10 for 10) |

- **Two-handed weapons and shields** can't be used together: equipping one takes off the
  other. While holding a two-handed weapon or a shield, you can't cast spells.
- **New skills:** **Two-Handed** and **Archery** (+1% damage per level), with perks:
  Barbarian / Reaver (heavy attacks −25% Stamina) / Barbarian II, and Overdraw / Quick Draw
  (draw 30% faster) / Overdraw II.
- **Reach** is a box in front of you (0.9 m wide, 1.8 m when cleaving, and a little lower
  than your view, so wolves are easy to hit). A normal swing hits the enemy nearest the
  crosshair; cleaving swings hit everyone in it.

### Defending
- **Blocking** stops 60% of a hit with a sword, 40% with a dagger, 30% unarmed, 85% with a
  shield. The Block
  skill adds 0.5% per level, up to 95%. Each point of damage stopped costs **1.5 Stamina**.
  Run out and your **guard breaks**: you take the rest of the hit and stagger for 1 s.
- Blocks only work against attacks from within **75°** of where you're looking. You move at
  half speed while blocking, and can't attack.
- **Parry window:** 0.2 s after you start blocking (the Deflection perk makes it 0.3 s).
- **Dodge** costs 18 Stamina, can cancel a recovery or a charging heavy, but not a swing
  that's already coming down.
- **Poise:** every hit wears it down, and when it breaks you (or the enemy) **stagger**:
  no attacking or blocking for a moment. It refills after 1.5 s without being hit. Player
  30, wolves 25. A full light combo (8 + 8 + 14) or a fully charged heavy staggers a wolf.

### Feedback
- **Hit stop:** the game freezes for 0.045 s on a light hit, 0.09 s on a heavy, and 0.12 s on a
  parry. This is the biggest single thing that makes hits feel solid.
- **Camera kick** on every swing and when you're hit. The weapon jolts on impact.
- **Sounds** for swings, hits, blocks, parries, guard breaks, dodges, wolf growls and bites.
  They're synthesised placeholders (see below).
- Crosshair: red when a hit lands, blue on a block, gold on a parry. The Stamina bar blinks
  when you can't afford an attack or dodge.

### The Block skill
It improves when you block (by damage stopped) and parry. Perks: **Steady Guard** (20,
blocking costs 25% less Stamina), **Deflection** (25, 50% longer parry window), **Riposte**
(35, after Deflection: +50% damage for 2 s after a parry).

### Making something hittable
Give it `take_hit(damage, from_position, knockback = 5.0, poise_damage = 0.0, heavy = false) -> String`
and return `"hit"`, or `"blocked"` / `"parried"` to make the player's swing bounce (that's
how bandits guard). `heavy` is true for heavy attacks and shield bashes. Spells call it
with no knockback or poise damage. For the top
health bar, give it a `Stats` child and a `stats` variable pointing to it. Put it on physics
layer 3 **enemies**. To make an enemy's attack blockable, call
`player.receive_attack(damage, self, poise_damage)` when it lands, instead of damaging the
player's Stats directly. It returns `"hit"`, `"blocked"`, `"parried"`, `"dodged"` or
`"guard_broken"`, so the attacker can react (wolves stagger on `"parried"`).

## Animation: now and later

**Now:** `player/weapon_animator.gd` moves the held weapon between named **poses**
(`rest`, `high_right`, `low_left`, `overhead`, `block`, `parry`, `stagger`...) with easing,
an arc on strikes, walking bob and a tremble while charging. Tweak a pose's numbers in
`POSES` at the top of the file. It's deliberately simple: the point is that **combat
timing lives in AttackData, not in the animation**.

**Later (when you're at your PC):** the combat code only calls
`animator.go(pose_name, seconds)` plus a few small helpers (`kick`, `set_charge`,
`set_movement`). A replacement animator for a bought first-person arms pack only needs to:
1. Instance the arms scene (an AnimationPlayer plus a Skeleton3D with a BoneAttachment3D on
   the hand bone, and the weapon model as its child).
2. In `go()`, play the clip whose name matches the pose (rename the clips, or map them), at
   a speed that makes it last `seconds`: `anim.play(clip, -1, clip_length / seconds)`.
3. Keep the same function names, so `player_combat.gd` doesn't change.

**Options** (researched from search results, because this cloud session can't open shop
pages; **check each licence and price on the page before buying**):

| Option | Cost | What it is | Notes |
|---|---|---|---|
| *FPP Melee Animset* by Kubold (Fab) | ~$75 | ~360 first-person arm animations: sword/axe/mace (+ shield), greatsword, spear, halberd, dagger | The closest match to this roadmap. Uses the Unreal mannequin skeleton (FBX included). Fab's FAQ says Standard-licence assets can be used in any engine. You'd need your own arms mesh, because the Unreal mannequin mesh's licence outside Unreal is unclear |
| *Sword and Shield First Person Animation Set* (Fab) | ~$30 | ~35 arm animations including block and shield bash | Smaller, cheaper way to test the pipeline |
| Quaternius *Universal Animation Library 2* | Free (CC0) | Third-person humanoid set with armed combos and deaths | Best free source for **humanoid enemies** (bandits). Not first-person arms |
| Kevin Iglesias *Human Melee Animations* (itch.io) | ~$23 | ~280 third-person melee animations: block, parry, dodge, stun, deaths | Good for enemies. Licence not checked |
| Mixamo | Free | Third-person clips, royalty-free in games | Mixed quality for sword combat; no redistribution of raw files |

**Recommendation:** keep the procedural animator until the combat *feels* right (timing,
parry window, poise). Then try one Fab first-person pack on your PC. Godot 4.3 imports FBX
directly (the built-in "ufbx" importer), and the arms only need to look right through the
camera. Use Quaternius UAL2 for the first humanoid enemies.

**First-person gotchas to expect:** clipping into walls (render the arms in a SubViewport or
with a separate camera layer), Unreal files being in centimetres and Z-up (check the import
scale), turning off shadows on the arms, and A-pose vs T-pose retargeting (twisted hands).

## Wolves

Three **Greyfang** wolves den about 30 m north-east of spawn (`GreyfangPack` in the level).

- **Idle**: wander around their den.
- **Chase**: when you come within 14 m, or when you hit one. **The pack hunts together:**
  when one starts chasing, the rest join in, wherever they've wandered. They run at 6 m/s:
  walking (5) won't escape them, sprinting (8) will.
- **Bite**: 7 damage, telegraphed. The wolf crouches back, its **eyes flare** and it
  **growls** for 0.5 s, then lunges. During the windup it barely turns, so a sidestep or
  dodge makes it miss, and a block or parry stops it. 1.2 s between bites. Three wolves
  together can still kill a careless player.
- **Stagger**: a parried bite, or broken poise, makes a wolf reel for about a second.
  Every other hit makes it flinch.
- **Give up**: dragged 30 m from home, a wolf runs back and heals.
- They freeze while you're in a conversation.
- 35 Health each: Orcs need 2 sword hits per wolf, Humans and Elves 3 (or one full combo).

Dead wolves can be skinned with **E** for a Wolf Pelt. When the last wolf dies, `wolves_cleared` is set. Tell Maren and she completes the quest
(`wolf_quest_done`). It's saved like any flag, so the pack stays dead after loading.
**Partly killed packs are not saved:** reload and all three are back.

## Bandits

A camp **south-west of the stone circle** (around x −34, z −34): two bandits (axe, sword)
and a **Bandit Leader** (mace), two tents, a campfire and a chest. Brannoc can tell you about
them ("Anything else I should know about out here?") and pays a **75 gold bounty** and +10
Riverwatch reputation when the camp is cleared (quest *Thieves by the Fire*).

They fight with the same swing system you do (`enemies/bandit.gd`, swings in
`enemies/bandit.tscn`):
- **Telegraphs:** the sword arm winds up and the blade **glints**, white for a normal swing
  (0.45–0.55 s) and **red for a heavy overhead** (0.95 s, ×1.8 damage, staggers if it lands).
  Block, parry or sidestep.
- **They guard.** When you start a swing they often raise their weapon. A guarded light hit
  **bounces** (you lose a moment, they take 15%). **Heavy attacks and shield bashes break the
  guard** and stagger them, as does running their stamina out. **Spells go straight
  through** a guard.
- **The leader parries** about 30% of guarded hits: your weapon is thrown back and you
  stagger for a second.
- **Parrying a bandit's swing** staggers it for about 1.4 s: free hits.
- **One at a time:** only one bandit swings at you at once; the others circle and guard.
  Without that, three swinging together was close to unwinnable for a normal player.
- 60 Health each (the leader 90), slower than your sprint, and they give up 28 m from camp.
- **Search the bodies** (E) for gold and their weapons. They stay dead and searched.

- **Hooded cultists** (`enemies/cultist.gd`, in the barrow's hidden chamber) fight exactly
  like bandits, in grey-violet robes. They don't take prisoners in Hardcore, and can wait
  (frozen) for a story flag before they wake.

Tested with two bots: one that only swings (dies with the leader on about 15 HP, so one
potion would have turned it) and one that blocks and parries every telegraphed swing
(clears the camp with 57/100 Health). Real players will land somewhere in between.

## Wisps

Knots of cold light that drift around the **stone circle at night** (20:00–06:00). Three
appear when night falls and fade at dawn, and killed ones come back the next night. They're
spawned by `StoneWisps` (`enemies/wisp_spawner.gd`); the wisp is `enemies/wisp.gd`/`.tscn`
(glowing spheres, so no animation needed).
- **They fight from range:** hovering about 8 m away, circling, and throwing slow arcane bolts
  (12 damage, 14 m/s).
- **The telegraph:** a wisp stops, **swells and brightens** for 0.9 s with a rising hum, then
  throws.
- **Defending:** block, a shield or a ward stops the bolt like a blow (from the front).
  **Dodge** and it flies past. **Parry it and the bolt flies back at the wisp** (homing, ×1.5
  damage).
- **Blink:** get within 3.5 m and a wisp flashes away 5–7 m (every 4 s or so).
- **Resistant to magic** (half damage from spells) but fragile to blades and arrows (30
  Health). A heavy attack, a shield bash, or enough poise damage **knocks it out of the
  air** for 1.6 s: it sinks to the ground and can't cast.
- **Wisp Essence** drops where one dies: +40 Magicka when used, and it sells for 20 gold.
- You can't rest while a wisp is hunting you.
- **Drained wisps:** once the main quest has started (`drain_flag` on the spawner,
  "wrong_things_started" by default), about 30 s into each night one *calm* wisp drifts into
  the crystal, dims, and streaks away north. Only one a night, never one that's fighting you,
  and the first time you're within 25 m a message tells you what you saw.

Enemy bolts (`combat/spell_bolt.gd` with `hits_player`) go through the same
`player.receive_attack()` as melee, so any future caster gets blocking, wards, dodging and
parry-reflects for free.

## Pathfinding

Wolves find their way **around** walls, rocks and buildings instead of running straight at
you.

- **`NavigationRegion3D`** in the level holds the *navigation mesh*: a map of where a
  wolf-sized creature can walk. It's built from every StaticBody3D on layer 1 "world" (the
  level root is in the group `navmesh_source`, so the whole level counts), plus the painted
  navigable areas of a Terrain3D if there is one (see TERRAIN3D.md).
- **It builds itself when the level loads** (a few milliseconds here), so it always matches
  your level after you move things. A mesh baked in the editor is used as-is instead (and
  must be re-baked after edits). For the test level with a Terrain3D, **don't** bake in the
  editor (TERRAIN3D.md explains why).
- **See it:** **Debug → Visible Navigation**, then play. The walkable area shows as a
  coloured overlay.
- **Each wolf has a `NavigationAgent3D`** that plans the path. With no NavigationRegion3D in
  a level, wolves fall back to running straight at you.
- **Pack behaviour up close:** within 4 m, each wolf heads for a spot on its own side of you,
  and circles further round if a packmate blocks it. Usually two bite at once, and a third
  waits right behind and steps in when there's room.
- **The door counts as solid** (the mesh is baked with it closed), so wolves path around the
  wall rather than through the doorway.

Tested with a U-shaped wall between the pack and the player: without pathfinding, the lead
wolf stayed stuck against the back of the U, 6 m away. With it, the wolves went around and
were biting within ~6 s.

## Physics layers

Named in **Project Settings → Layer Names → 3D Physics** so the Inspector shows names:

| Layer | Name | On it | Things that collide with it |
|---|---|---|---|
| 1 | world | ground, walls, props, NPCs | player, wolves, interaction ray |
| 2 | player | player | wolves |
| 3 | enemies | wolves, bandits, wisps | player, other enemies, weapons, arrows, spells |
| 4 | loot | pickups, dead wolves and bandits | interaction ray only (the player walks through) |

## Martial perk trees

One-Handed, Two-Handed, Block, Archery and Athletics have 21 perks each (phase 5 of
`docs/CHARACTER_BUILDING.md` brings deeper fighting; these are the perk trees). Plain numbers
are ordinary perk modifiers. Many only count with the right thing in your hand: a perk's
`when_skill` (the weapon's skill: `one_handed`, `two_handed`, `archery`, `unarmed`),
`when_weapon` (`ItemData.weapon_type`: `sword`, `dagger`, `axe`, `mace`, `greatsword`, `bow`)
or `when_shield`. The rest are fields `systems/arms.gd` (the autoload `Arms`) reads.

| Skill | Perks (level) |
|---|---|
| One-Handed | Armsman I–IV (15/35/55/75): +20% each → **Weapon Master** (95): one blow in ten double · Fighting Rhythm I–II (25/50): −25% swing Stamina · Quick Blades I–II (30/60): +15% attack speed · Swords: Bladesman I–II (30/60): one in ten, then five, double · Axes: Hack and Slash → Deep Cuts (30/60): a third, then two thirds, bleed · Maces: Bone Breaker (30): one in five staggers → Skull Cracker (60): staggered enemies take +50% · Daggers: Knife Fighter (25): +25% speed · Duellist (35): +20% with no other enemy within 8 m · **Flowing Strikes** (40): +5% a hit in a row, to +25% → **Blade Dance** (80): after a kill, a free swing · Lunging Strike (45): +50% from a sprint · Executioner (70): +50% under a quarter health |
| Two-Handed | Barbarian I–IV → **Colossus** (95): heavy +50% · Reaver I–II · Iron Grip (20): −15% Stamina · Wide Arcs (25): +20% reach · Crushing Blows (30): +50% stagger · Devastating Blow (35): heavy +25% → **Cleave** (40): half a heavy blow hits everything within 2.5 m → **Earthshaker** (65): and staggers everything within 3 m → **Juggernaut** (90): heavy blows always stagger · **Unstoppable** (45): you can't be staggered mid-swing · Berserker (50): +25% under half health → Bloodlust (60): +25 Stamina a kill · Headsman (70) · Great Critical (35, greatswords) · Relentless (40) · Battering Ram (45) |
| Block | Steady Guard I–II · Shield Wall I–III (15/35/60): blocks stop +10% each → **Unbroken Guard** (70): your guard never breaks · **Last Guard** (55): under a quarter health, a block stops everything · Deflection I–II → Perfect Timing (80): +20 Stamina a parry · Riposte I–II · **Counterweight** (45): a parry staggers them → **Aegis** (90): a parry heals 15 · Retaliation (35): +25% for 2 s after a block · Shields: Power Bash (25) → Deadly Bash (45): ×3 → **Staggering Bash** (65) · Quick Bash (30) · Battle-Ready (40): +20 Stamina · Guardian's Lore (15) |
| Archery | Overdraw I–IV · Quick Draw I–II → **Snapshot** (60): half-drawn, almost full damage · Steady Aim (30): arrows 30% faster · Critical Shot I–II (30/55) → **Deadeye** (90): full draw does double · Power Shot (45): stagger ×2 → Bullseye (70): one in six staggers · **Pinning Shot** (50): one in four pins (40% speed, 3 s) · Arrow Recovery (25): a third come back · Ranger (35): half Stamina · Hunter (20): +25% on beasts · Long Shot (40): +25% past 25 m · Headhunter (70) · Hunter's Rhythm (65) · Fletcher's Eye (15) |
| Athletics | Wind Runner I–II → Tireless (75) → **Runner's High** (85): sprinting heals 1 a second · Marathon I–II · Sure-Footed I–II: no fall damage · Fleet Foot I–II: +5% speed each · Sprinter (35) → Long Strides (65): +10% sprint each · Catch Your Breath (25) → Deep Lungs (60): Stamina +20% faster each · Nimble (20) → Evasive (45): dodge sooner · High Jump (30): +20% · **Charging Blow** (40): any attack from a sprint +30% · Pack Mule I–II (20/50): carry +25, +50 · Athlete (15) |

New modifiers: `attack_speed`, `reach`, `block_share`, `bash_stamina`, `arrow_speed`,
`dodge_cooldown`, `jump_height`, `sprint_speed`, and `carry` (a stat bonus). A crit says
"Critical!". Wolves are in the group `beast`.

## Weapon arts

Phase 5 (`docs/CHARACTER_BUILDING.md`), from the questionnaire: "a special attack for each
weapon type, earned by skill". Press **Weapon Art** (F, or D-pad right). Each is learned at 25
in its skill (you're told when), and is a quarter stronger at 50 and again at 75. It costs 30
Stamina and then waits 8 seconds; it's 8 XP in its skill. The blows go through the usual
pipeline, so skill, perks and crits count. The rules are `systems/weapon_arts.gd`; what each
does is `PlayerCombat.weapon_art_pressed()`.

| Weapon | Art | What it does |
|---|---|---|
| Sword | **Flurry** | Three quick cuts at 70% of a heavy blow each |
| Dagger | **Gutting Strike** | A lunge: double a heavy blow, triple on an enemy that hasn't noticed you, and it bleeds |
| Axe | **Rend** | 140%, and three stacks of bleeding |
| Mace | **Skull Crack** | 150%, and it always staggers |
| Greatsword | **Whirlwind** | 150% to everything within reach, all the way round |
| Bow | **Volley** | Three arrows at once, 6° apart (uses three) |
| Shield (while blocking) | **Shield Charge** | A rush; everything in a 70° cone within 3.5 m takes double a bash and is staggered |
| Fists | **Palm Strike** | 150%, hurls them back and staggers them |

## Known limits

- Wolves don't jump or climb. Anything over 0.5 m tall (like the stone block) is a wall to
  them, so standing on top of it keeps you out of reach.
- Animation is procedural poses (see above), and the sounds are synthesised placeholders
  from `tools/make_placeholder_sfx.py`. To replace one, drop a recording with the same name
  in `assets/sfx/` (`.wav` or `.ogg`). Footsteps and ambience: see FOUNDATIONS.md.
- Wolves can't block or parry you; bandits can. Bandits don't use bows or chase you into
  interiors yet.
- Arrows can't be picked back up after they land.
- The wolves and sword are placeholder boxes until real models arrive (see ASSETS.md).
- Gamepad: see CONTROLS.md (RT attacks, LT is the left hand, B dodges).
