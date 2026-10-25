# Time, Survival, Resting & Hardcore

## Day and night
- **WorldClock** (`systems/world_clock.gd`): one in-game day lasts **72 real minutes**
  (time runs 20× faster, like Skyrim). It stops in menus and conversations. New characters
  start at 08:00 on day 1. The time is shown in **Tab → Skills** (top) and in the rest menu.
- **Day/night lighting** (`levels/day_night.gd`, the `DayNight` node in the test level):
  - The sun arcs across the sky and is a dim blue moon at night.
  - The sky, ambient light and fog colour blend through **night → dawn → day → dusk**.
  - Dawn (06:30) and dusk (18:30) use the colours the level was first tuned with. The other
    keyframes are drafts: edit `KEYS` in the script.
  - To freeze the look while you work on a level, untick **Enabled** and set **Fixed Hour**.
    The editor always shows Fixed Hour.
- Interiors (like the cellar) have no DayNight node, so they never change, and they count as
  **indoors** for survival.

### The Wanderer and Lanternfast
- The **Wanderer**, the small green moon, is **dark every 7th day** (days 7, 14, 21...):
  `WorldClock.wanderer_dark()`, `days_until_dark()`, and `wanderer_text()` ("The Wanderer is
  waxing. Lanternfast in 6 days.", shown in the rest menu).
- **In the sky** (`levels/wanderer_moon.gd`, the `WandererMoon` node): a green disc far to the
  north-west that follows the camera, lit by `WorldClock.wanderer_phase()` (0 dark at 18:00
  on a dark day, 0.5 full, a little over three days later) through a small shader
  (`levels/wanderer_moon.gdshader`), and faded out by day. On Lanternfast it's a faint ghost.
- **Ilun**, the old white moon, is drawn by the same script (the `IlunMoon` node, `moon =
  "ilun"`): bigger, white, in the south-east, on a slower 14-day cycle
  (`WorldClock.ilun_phase()`: full on the night of day 1, dark a week later). The 14 days is
  a game choice, not from the lore. The night light comes from Ilun (`levels/day_night.gd`,
  `night_moon_path`), a little dimmer when it's a sliver; it no longer draws its own disc in
  the sky. Tidecraft is stronger or weaker by both moons (MAGIC.md, "Tidecraft").
- **Lanternfast** is that night, from **18:00 until 2:00** (`WorldClock.is_lanternfast()`).
  `systems/lanternfast.gd` (autoload **Lanternfast**) keeps the flag `lanternfast_now` set for
  exactly that long (and sets `saw_lanternfast` the first time, with a message). Everything
  else hangs off the flag:
  - **Lanterns**: the `Lanternfast` StoryPresence in the test level (`show_flag
    lanternfast_now`) holds ten `props/festival_lantern.gd` lanterns around the waystation.
  - **People**: Maren, Ostap and Zora each have a `lanternfast` start node (once each,
    `lanternfast_<name>`), with their people's idea of what the lanterns are for.
  - **Wisps** leave you be for the night (`wisp.gd` `_graced`).
  - **The crowd** at the waystation, in the same StoryPresence: Pim (a human child: "so
    the lights can't get in"), Hettie Kettlewick (small folk: "because it's a party", and a
    Lantern Cake, once), Orrin of the Mill Lane (a Passenger: "so the lost ones can find their
    way home") and, outside the light, Moss (Ashen: no lantern, "we remember instead").
  - **The song** (`props/lanternfast_song.gd`, at the fire): within 12 m, "Hallam and the
    Hundred Lights" a verse every 10 s, then one Passenger voice singing the last line
    differently. Sets `heard_hallam_sung`.
- To wait for it: rest until 18:00 on a dark day. For testing, set `WorldClock.day = 7` and
  `hour = 18`.
- Greybox: the crowd are capsules that stand still; the song is on-screen text, not sung;
  the moons are flat discs, fixed in the sky (they don't rise or set).

## Survival mode (optional, chosen in the character creator)
Four needs run from **0% (fine) to 100% (dire)**. Each passes through three stages at 25%,
50% and 75%. The stages are status effects, so they show in the effect row above the bars,
and the current percentages are in **Tab → Skills**.

| Need | Rises | Stage 1 → 2 → 3 | Fixed by |
|---|---|---|---|
| Hunger | 3 per in-game hour (half while asleep) | Peckish → Hungry (Stamina regen −20%) → **Starving** (−40%, no natural healing, slow Health loss) | Food |
| Thirst | 4 per hour (half while asleep) | Thirsty → Parched (Magicka regen −25%) → **Dehydrated** (half Magicka regen, slow Health loss) | Water |
| Fatigue | 3.5 per hour awake | Tired (skills −5%) → Weary (−15%, Stamina regen −15%) → **Exhausted** (skills −30%, Stamina regen −40%, 10% less damage) | Sleep (8 hours clears it) |
| Cold | Outdoors at night (+12/h, more when sleeping rough), a little at dawn/dusk | Chilly → Cold (5% slower) → **Freezing** (15% slower, Health loss) | Daytime (−10/h), **campfires** within 4 m or **indoors** (−60/h) |

**Food and drink** (use from Tab → Inventory; it also heals a little in any mode):

| Item | Eases | Where |
|---|---|---|
| Bread | Hunger −30, +5 Health | Every character starts with 2; Maren sells it (3 gold) |
| Flask of Water | Thirst −40, +10 Stamina | Everyone starts with 2; Maren (2 gold) |
| Apple | Hunger −12, Thirst −5 | Bandits |
| Raw Wolf Meat | Hunger −10, **35% chance of Poisoned** | Skinning a wolf |
| Cooked Wolf Meat | Hunger −35, +15 Health | Cook raw meat at a campfire |

The rates are first drafts (a day without food gets you to Hungry, not Starving). Tune them
in `RATES` and the `COLD_*` constants at the top of `systems/survival.gd`, and the stage
penalties in `effects/survival_*.tres`.

## Resting: beds and campfires
- **Campfires:** by the waystation (just east of spawn) and in the bandit camp. **Bed:**
  in the waystation cellar. Press E to open the rest menu.
- **Options:** Cook raw wolf meat (campfires), Rest 1 hour / 4 hours, Sleep 8 hours, Sleep
  until dawn.
- **What resting does:**
  - Time passes.
  - Health, Stamina and Magicka refill.
  - Timed harmful effects (bleeding, poison, burning) wear off.
  - Fatigue goes down (Survival), and 6+ hours gives **Well Rested** (+10% skill gains for
    the next 8 in-game hours).
  - **The game autosaves** (the "Autosave" slot).
- You can't rest with an enemy hunting you within 30 m.

## Hardcore saves
Hardcore characters can **only save by resting**. F5 and the pause menu's Save Game say
so instead of saving. Loading works as normal.

## Hardcore defeat: you wake up wounded

In Hardcore, falling in a fight doesn't load a save (Normal mode still does). You wake up
hours later, **Wounded**, in one of three ways (`systems/defeat.gd`, the `Defeat` autoload):

| Outcome | When | What happens |
|---|---|---|
| **Captured** | Beaten by people who take prisoners (bandits; the group `captors`), in a level with a cell | You wake in their cage, 6 hours later, at 30% Health. Your gear and gold are in the **bandits' stash** outside it. Press E on the cage door a few times to work the lock, then get your things back (re-equip them yourself). The cage sits just outside the bandits' sight, and its door faces away from their camp |
| **Found** | Otherwise, 60% of the time when the level has a refuge | Someone brings you to safety (in the test level, Maren and the waystation; in the barrow, its entrance hall). 8 hours pass, you're at 40% Health, and it costs a fifth of your gold |
| **Left for dead** | Otherwise | You wake where you fell, 5 hours later, at 25% Health |

Every time:
- **Wounded** until you sleep 8 hours: Health recovers at half speed, you tire faster, you
  move 10% slower, and hits do 15% more.
- **Enemies reset:** they go back to where they were, healed and calm. A boss goes back to
  its statue and its arena's gates to how they were, so you can try again.
- **Autosave:** the game saves, so a defeat can't be undone by loading.
- **Who beat you:** the last thing that hit you within 10 seconds. Falls, hunger and cold
  count as the wild.

**Adding it to a level:**
- **A refuge:** a Marker3D with `props/refuge.gd`, and **Found Text** saying who found you.
- **A captors' cell:** a Marker3D named `CaptiveCell` (where you wake), a door with
  `props/puzzle/cage_door.gd` (its collision shape named `Shape`), and a loot container named
  `CaptorStash`. Copy `BanditCage` in the test level.
- **Other captors:** add an enemy to the group `captors`.

Not yet: anything that *rescues* you from a capture, or companions who find you. Those wait
for the companion system.

## Making your own
- **A campfire:** a StaticBody3D with `props/campfire.gd` (Heat Radius) and a small collision
  shape. Put the logs, flame and light under it (copy `WaystationFire` in the test level).
- **A bed:** a StaticBody3D with `interactables/bed.gd` (copy the cellar's `Bed`).
- **Food:** an item with type Consumable and the **Ease Hunger / Thirst / Fatigue / Cold**
  values (and optionally a **Side Effect** with a chance).
- Anything in the group `heat_source` with a `heat_radius` property keeps you warm.
