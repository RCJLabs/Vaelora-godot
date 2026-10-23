# Time, Survival, Resting & Hardcore Saves

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
so instead of saving. Loading works as normal. Whether Hardcore death should be permanent is
still an open question (ROADMAP).

## Making your own
- **A campfire:** a StaticBody3D with `props/campfire.gd` (Heat Radius) and a small collision
  shape. Put the logs, flame and light under it (copy `WaystationFire` in the test level).
- **A bed:** a StaticBody3D with `interactables/bed.gd` (copy the cellar's `Bed`).
- **Food:** an item with type Consumable and the **Ease Hunger / Thirst / Fatigue / Cold**
  values (and optionally a **Side Effect** with a chance).
- Anything in the group `heat_source` with a `heat_radius` property keeps you warm.
