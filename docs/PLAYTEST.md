# Playtest checklist (about 30 minutes)

Everything here works in automated tests. What the tests can't tell us is whether it **feels**
right, **looks** right in the full renderer, or **sounds** right. These are the numbers and
choices that were guessed and need your verdict. Go in order; skip anything you run out of
time for.

**Setup:** open `godot/` in Godot 4.3, press **F5** (starts at the title screen). Or download
a build from the latest CI run on `main` (Actions → CI → Artifacts). Turn on **Settings →
Graphics → Show FPS** first. If you have a gamepad, keep it nearby for section 7.

At the end, copy the **feedback block** at the bottom into a message, fill in what you
noticed, and send it back. Short answers are fine ("too easy", "parry window feels tight").

---

## 1. Title, creation, first look (3 min)

- [ ] Title screen: does the slow orbit over the stone circle look OK? Any stutter?
- [ ] New Game → make any character (try **Soldier** for the shield, or **Scholar** for spells).
      Each background now starts in its own spot with a short intro card. Is the card readable,
      and up long enough? Do you know where to go (talk to Maren)?
- [ ] Main quest 1, **Wrong Things** (5 min): Maren → the hollow wolf east of Greyfang Hollow
      (press E on it) → Brannoc. Does the hollow wolf feel eerie or just broken?
- [ ] Main quest 2, **The Waking Stones**: after you deal with the shards, touch the crystal
      again. Can you see the thread of light running north? At night, stay near the stones
      (but not too near) for a minute: one wisp should drift into the crystal and streak away.
- [ ] Main quest 3, **Ask the Forest**: follow the line north to the trees and the outlaw camp.
      Is the camp easy to find? Is Mirela's choice (bandits or a garrison crate) clear?
- [ ] Main quest 4, **The Barrow**: after the Guardian, can you find the way on from the vault
      without help (look at the floor)? Free the wisp or take its essence: does either feel
      like a real choice?
- [ ] **Corruption**: take the caged wisp's light, or swallow a few Wisp Essences (each says
      "Corruption +10"). Do you notice the HUD line and the messages? Is the trade (stronger
      spells, slower healing) worth taking? Once the shrine is rekindled, keep a vigil there at
      night: is one tier a night too slow? At Hollowing, the ending changes.
- [ ] **Releasing an essence:** with a Wisp Essence, touch the stone circle's crystal. Is
      "Release a Wisp Essence" a choice you'd make over swallowing it? Did Wisp's Grace (the
      wisps letting you be that night) feel like enough of a reward?
- [ ] **Wisps and corruption:** once corrupted, do night wisps feel more aggressive? Too much?
- [ ] **The Lantern Order and the Mercy:** talk to Inquisitor Hale on the south road, clean,
      then again once you're Touched and Stained. Find the Mercy's camp in the south-east hollow
      (Brannoc mentions it with the bandits). Is Sister Halina sympathetic, or obviously a villain?
- [ ] **Books:** five lie around the valley (by the waystation fire, beside Magister Aurel, at the
      stone circle, at the shrine, at the outlaw camp). Did you find any without looking? Did you
      read them? Too long, too short?
- [ ] Side quests (pick one or two): **Silent Shrine** (the roadside shrine south of spawn),
      **The Lost Wagon** (a yellow wagon north-east of the bandit camp), **Licence to Burn**
      (ask Brannoc for work), **Readings Under the Wanderer** (Magister Aurel at the
      waystation). Were they easy to find? Too long, too short?
- [ ] Main quest 5, **What They Made**: go to the Hollow Oak by day first (it should tell you to
      come back at night), then at night. The First: are the leaking rings readable? How many
      tries did it take (the bot tuning aims for "hard but fair": a careful player wins with
      a third or more of their Health left)? After it
      dies, can you see its light streaming north? Does the ending land?
- [ ] First view of the level: note the **FPS** in the corner, on **High**.
- [ ] The compass at the top: can you tell where the wolves quest points once Maren gives it?
      Press **M**: is the map readable?
- [ ] Is it too dark / too bright / washed out? (Screenshots so far were all from the simpler
      renderer; this is the first look in the real one.)

- [ ] **Third person** (V): walk around, fight a wolf, take something, talk to someone. Does
      the crosshair land where you expect? Does the camera get stuck behind walls or trees?

## 2. Sound (2 min, with headphones if you can)

Every sound is a synthesised placeholder, and nobody has listened to them yet.

- [ ] Walk on grass, then onto the stone block (a few metres north-east of spawn): do steps sound like steps?
- [ ] Stand still for 20 s: is the wind/bird bed pleasant, annoying, or too loud?
- [ ] Walk up to the campfire at the waystation: crackle OK?
- [ ] Story moments now have sounds too: the opening and closing cards (a low chord), the
      shrine (a bell), a wisp drained into the line (a falling whistle), freeing or taking the
      caged wisp, corruption rising, the ritual starting, The First's rings, and the wolves
      breaking. Any that feel wrong for the moment, or too loud?
- [ ] Rate the worst sound you hear today, so it gets replaced first.

## 3. Melee feel (5 min) — the wolves, north-east of spawn

- [ ] Light attacks: do swings feel weighty or floaty? Is the windup too slow?
- [ ] Hold for a heavy: is the charge time OK?
- [ ] **Parry** (right-click just as a bite lands, when its eyes flare): too easy, about right,
      or too tight? (Window: 0.2 s.)
- [ ] Dodge (Alt): does it get you out of a bite? Too long / too short?
- [ ] The pack of three: fair, too easy, or overwhelming at the start?
- [ ] Did the pack **break and run** (after you killed one and hit another, or burned them)?
      Did you notice, and did it feel earned or like they cheated you out of the fight?
      Could you tell they weren't coming back? (Maren hints at this when she gives the quest.)

## 4. The bandit camp (4 min) — south-west of the stone circle

- [ ] One bandit at a time attacks: does it feel like a duel or like they're waiting their turn?
- [ ] Do you notice them blocking and parrying you? Readable or frustrating?

## 5. Magic (3 min)

- [ ] Flames on a wolf, then a **Firebolt** (hold to charge, release): satisfying?
- [ ] Dual-cast (both buttons with nothing in the right hand): does it feel worth the Magicka?
- [ ] **Trading and lessons:** Maren's "Let's trade." (does the screen read? are prices
      fair?), a lesson from Brannoc, Ostap, Zora or Aurel (worth the gold?), and a skill book
      (Maren sells two; three lore books in the world teach too).
- [ ] **The moons** over a few nights: Ilun (white) and the Wanderer (green) rise in the east,
      cross the south and set in the west, at different times as their phases change. Does
      the sky read? Are nights with Ilun down too dark?
- [ ] Night (rest at a fire until 21:00, or wait): **wisps** at the stone circle. Can you read
      their charge-up and parry a bolt back at them?
- [ ] **Glamour** (Zora teaches it: "What do you really do?"): a **Mirror Image** in front of the
      wolves, then **Fear**, then **Charm** one wolf of the pack. Readable? Fun, or fiddly?
      Then her second lesson: **Frenzy** one wolf, and **Invisibility** while they hunt you.
- [ ] **Tidecraft** (Magister Aurel sells it: "The Tide College. Do you teach?"): **Pull** a
      wolf out of the pack, **Shove** the rest off you, drop a **Gravity Well** on them
      (after his readings), then **Moon-Crush** the pinned pack (after the well), and try the **Lifting Tide** on
      the whole pack (after Moon-Crush). Is Moon-Crush
      too strong at high tide (it kills a wolf at the middle outright)? Try it at high tide and at low tide (the rest menu says which):
      can you feel the difference? Is high tide too common?
- [ ] **A companion** (Brannoc after Wrong Things, or Zora): "Come with me." Do they keep up,
      get stuck, or get in your way in a fight? Try Wait here / Follow me / Go home.
      Do the wolves split between you and them in a way that reads? Let one go down and help
      them up (E): is it clear when that happens?
      Do their remarks and banter come too often, or not often enough? Try their quests:
      Zora's ("You said the Order burned your teacher") and Brannoc's ("Your father's story").
- [ ] **Lanternfast** (rest until 18:00 on day 7; the rest menu says how many days are left):
      do the lanterns read as a festival? Talk to Maren and Zora. Do the wisps leave you be?
      Look north after dark: is the one small light in the sky noticeable, without explanation?
      Stand by the fire for the song; talk to the crowd (and the woman sitting in the dark).
      On other nights: can you see the green moon change from night to night?

## 6. The dungeon (8 min) — the wooden door in a stone mound, about 35 m south-west of spawn

- [ ] Corridor 1: did you **spot the pressure plates** before stepping on one? Try disarming one (E).
- [ ] Corridor 2: the swinging blades — fun to time, or annoying? Too fast?
- [ ] Lever room: the riddle on the east wall — solvable without reading DUNGEONS.md?
- [ ] **Stone Guardian:** can you read the slam (arms up) vs the sweep (arm out)?
  - [ ] How many tries did it take? (Target: a first-time player should usually win in 1–3.)
  - [ ] Did the 1.5x hit after a slam feel like a reward you noticed?
  - [ ] Phase 2 shockwaves: did you realise you had to jump?
  - [ ] Is the arena **lit well enough** to see its arms?
- [ ] Vault chest and the way out work?

## 7. Gamepad (3 min, if you have one)

- [ ] Stick look speed: too slow / OK / too fast?
- [ ] Menus with the D-pad (pause, Tab menu, a conversation): anything you couldn't reach?
- [ ] Tab → Perks: can you tell at a glance what's taken, ready and locked, and what leads to what?
- [ ] Sneak (C): crouch toward the Greyfang wolves by day, then at night. Does getting close feel fair, and does the marker under the compass warn you in time?
- [ ] A sneak attack on an idle bandit with the dagger, then with the bow. Does x3 / x2 feel right, or too strong for a level-1 character?
- [ ] Buy Maren's iron set and fight the bandits in it, then in leather. Is the heavy set worth the sprint cost and weight at the start?
- [ ] Speech checks show your score next to what they need. Does seeing "[Persuade 60 · you 23]" feel fair, or does it take the tension out? (The alternative is a hidden roll.)
- [ ] Get Stained and meet the inquisitor: are the three ways out (talk, threaten, pay) priced right?
- [ ] Try **Settings → Accessibility → Toggle sprint / Toggle block**: better or worse than holding?
- [ ] Any button that felt wrong where it is? (Rebind it in Settings → Controls, then tell me
      the new layout.)

## 8. Performance (4 min)

- [ ] Back on the title screen: **Settings → Graphics → Run benchmark** (about 3 minutes, hands
      off). It copies a results table to the clipboard: paste it into the feedback block.
- [ ] While you played: did anything stutter? Where?
- [ ] Switch to **Low** for a minute: does it still look acceptable?

---

## Feedback block (copy, fill in, send back)

```
Benchmark results: (paste the table)
Stutter anywhere?:

Look (dark/bright/OK):
Opening card / Wrong Things (clear? eerie? too short?):
Main quests 2-5 (which was best? which dragged?):
Side quests tried (and how they felt):
Compass / map (useful? cluttered?):
Worst sound:
Melee feel (floaty/weighty, windup, heavy charge):
Parry window (easy / right / tight):
Dodge:
Wolf pack (easy / fair / too hard):
Bandits:
Magic:
Wisps:
Plates spotted? Blades fun? Riddle solved without help?
Guardian tries to win: ___   The First tries to win: ___   Slam/sweep readable? ___   Noticed shockwaves needed jumping? ___
Gamepad (look speed, menus, layout):
Anything broken:
Anything that made you smile:
```
