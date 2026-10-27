# Drawing

The ninth school and the last of phase 3 (`docs/CHARACTER_BUILDING.md`). It's Willpower's,
and forbidden. It's built to the lore bible (`docs/lore/MAGIC.md`, "Drawing"): *taking life
and power from living things. The vampire mage. The most powerful school, and the only one
that corrupts you.* The code is `systems/drawing.gd` (the autoload `Drawing`). It's how
corruption option D ("the Draw spell", `docs/CORRUPTION.md`) comes back, as a whole school.

## The spells

| Spell | Kind | Magicka | What it does | Where |
|---|---|---|---|---|
| **Draw** | stream (hold) | 12/s | A grey beam (6 m) that takes life: half of what it takes comes back to you as Health | Halina, when you're Stained; or at Hollowing, on its own |
| **Siphon Magic** | stream (hold) | 4/s | Takes less, but every point comes back as 1.5 Magicka | *A Drawer's Litany*, a black book on the cult's worktable in the Barrow |
| **Hollowing Touch** | charged, 0.8 s | 35 | The enemy within 3.5 m takes 25 and is **hollowed** for 10 s (60% speed, takes a quarter more); you take 25 Health | Halina's second lesson, at Hollowing |
| **The Great Drawing** | charged, 2.0 s | 90 | Every living enemy within 8 m gives up 20 Health, and all of it is yours | The mastery: it comes on its own at Drawing 75 |

**No college teaches it, and nobody sells it.**

### The cost: corruption

- **What it adds:** everything Drawing takes adds corruption, 0.05 per point (20 Health
  taken = 1 corruption). The Touch adds 2, the Great Drawing 5. Quiet Hunger reduces it.
- **What it gives back:** the more corrupted you are, the stronger Drawing gets: +15% per
  tier (Embrace the Stain: +30%). That's on top of the +10–30% spell power every school gets
  from corruption.
- **Where it leads:** a Drawing build drifts toward Hollowing, unless you cleanse at the shrine
  (which gives up the power too).
- **Only what it takes counts.** Drawing at empty air costs Magicka but doesn't stain you.

### The Mercy cast it too

Mercy Drawers (`enemies/cultist.gd`, `caster = true`) use the school against you: a Draw
beam that heals them, a hollow bolt, and a Mend for a hurt friend. COMBAT.md, "Mercy casters".

### Halina

Sister Halina of the Mercy has two new lines:

- **"Teach me to do what you do."** Stained or worse: *Halina's Lesson* (Draw).
- **"Teach me the rest."** Hollowing, after the first: *The Second Lesson* (Hollowing Touch).

Asked who taught her, she says only "the ones before me", and that "it's how it was done,
once. Before the lanterns." That's a hint at the 🔒 (it's how the Hunt was done), no more.

## Perks (21)

| Branch | Perks (level) |
|---|---|
| Taking | Deep Draw (15) → II (35) → III (60): +25% Health back each · Thirst (25) → II (50): +25% taken each |
| The stain | Quiet Hunger (25) → II (55): −25% corruption each · **Embrace the Stain** (60): +30% a tier → **Feast** (70): a kill by Draw or Siphon gives 10 Magicka and 10 Stamina → **Hunt's Echo** (90): the Great Drawing leaves everything hollowed |
| Fuel | Wellspring (40): Siphon +50% · **Stolen Breath** (30): a quarter as Stamina too → **Bloodbound** (45): Health past full becomes Stamina |
| The Touch | Hollow Grip (40): hollowing twice as long → **Gnawing** (55): and they bleed |
| Mastery | Great Thirst (80): the Great Drawing reaches 50% further |
| — | **Desperate Hunger** (50): below a quarter Health, it heals twice as much · Cold Hands (20) → II (45): −20% cost each · Quick Hands (30): charge 30% faster · The Mercy's Lesson (15): Drawing +25% XP |

New modifiers: `drain_share`, `siphon_share`, `drawing_corruption`, `hollowed_duration`,
`great_draw_radius`. New effect: `hollowed`.

## Not yet

- Drawing from **wisps** (souls, in the lore) isn't in. It should be the most corrupting act
  of all, and it ties into the Wisp Essence choice.
- Draw doesn't hurt **companions** or your called things (the stream skips them). The lore's
  "every living thing nearby" for the Great Drawing could include them as a cost.
- The beam is the flame stream's grey cousin; it needs its own effect.
- Outlaws turning cold at Hollowing (`docs/CORRUPTION.md`) aren't changed by casting Drawing
  where they see.
