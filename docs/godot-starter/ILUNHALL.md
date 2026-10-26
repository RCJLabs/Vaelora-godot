# Ilunhall: the Lower Steps and the Undercroft

The fourth region, built 2026-10-26. It follows V.'s note from the Deep Ring: "Come to me at
Ilunhall. The Empress's light-stone needs us more than she knows."

It's a greybox, like the others, and covers only one district of the capital. The city itself is
in the lore (`docs/lore/WORLD.md`):
- timbered halls with gilded roofs climbing a mountainside above a fjord;
- the Hall of Spears at the top;
- light-stone in the eaves that glows gold at night, and is secretly dimming.

The names, people and quests here are *(suggested)*.

## Getting there

- **From the Grieving Fields:** take the **Imperial Road** at the Fields' east edge, past
  Greyfold. You arrive at the west end of Ilunhall's quay.
- **Back:** the Imperial Road at the quay's west end.
- **Fast travel:** Ilunhall is a region, so it's in fast travel too.

## The place (`levels/ilunhall.tscn`)

Four terraces, stepping up north from the fjord, linked by ramps (the Market Steps, the Hall
Steps, the Spear Steps):

| Terrace | Height | What's there |
|---|---|---|
| **The Quay Steps** | 0 | Piers and longships, harbour houses, Bruna's rune-goods stall, Nob's crates, Saelie by the Passenger boats. Under the Market Steps, a barred gate to **the Undercroft** |
| **The Long Halls** | 4 m | **The Ember College** (red; Magister Ignatia), **the Lantern Order's chapterhouse** (Inquisitor-Captain Severin), Karra's scaffold on the College's eaves |
| **The Feast Steps** | 8 m | **The Long Table**: a feast hall open at the front, where the feast never stops. It has a bed at the back for 10 gold, and the Hundredth Horn in its locked trophy chest. Also **the Rune Bridge**, east, up to the forecourt |
| **The Forecourt** | 12 m | **The Hall of Spears**, its portico held up by a forest of spear-shafts. Its gold doors are shut to you (for now). Steward Cassia stands outside |

**Light-stone** (`props/light_stone.gd`):
- Gold strips along every hall's eaves and ridge, with a light under each.
- They glow softly by day and bright at night, fading with `WorldClock.daylight()`.
- Once `conduit_broken` is set, they all burn at 30%. The city visibly dims.

**The Undercroft** (`levels/ilunhall_undercroft.tscn`):
- An old cistern hall under the Market Steps, with rows of pillars.
- Gold veins of light-stone climb the walls into the city above.
- In the middle is **the conduit**: rune-iron and seam-stone, with caged wisps around it.
- Three Mercy acolytes guard it. **Magister Vessa** sits at her desk by the cistern.

## People

| Who | Look | What |
|---|---|---|
| **Bruna Deepseal** | deepfolk merchant | Rune-goods on the quay: merchant `bruna`, with the four rune and enchanting tomes |
| **Nob Ashby** | small-folk commoner | A fence for the Lampless. Gives The Hundredth Horn |
| **Saelie of the Low Lane** | Passenger priest | A Choir song-keeper. Gives A Verse in the Eaves |
| **Karra Seamwright** | deepfolk worker | An eaves-wright. Light-stone is running out, and this year it came up warm, from below. Gives the main quest's lead |
| **Magister Ignatia Rufa** | orc scholar | The Ember College. Trains **Destruction** to 60 (trainer `ignatia`) |
| **Inquisitor-Captain Severin** | human inquisitor | The Lantern Order. Wants Vessa alive (the other lead). Won't deal with a Stained player |
| **Hallmaster Odo** | human innkeeper | The Long Table. Sells the bed |
| **Steward Cassia Varro** | human official | Keeps the Hall of Spears' door, and the Empress's secrets |
| **Magister Vessa** | human scholar (grey-violet) | In the Undercroft. "V." |

**New factions:**
- **The Ilunar Empire** (`ilunar_empire`): known once you meet Cassia.
- **The Lantern Order** (`lantern_order`): known once you meet Severin.

## Quests

| Quest | Giver | Steps | Endings |
|---|---|---|---|
| **The Light in the Eaves** (main) | V.'s note (opens on `vessa_note_read`) | Go to Ilunhall; get the lead from Karra (her cistern key) or Severin (his warrant); go down under the Market Steps; defeat the three acolytes; decide Vessa's fate; decide the conduit's; tell Cassia | See below |
| **The Hundredth Horn** | Nob Ashby | Take the gold-bound horn from the Long Table's trophy chest (lock level 2) | Give it to Nob (150 gold, and "a window with no lantern": `lampless_friend`); give it back to Odo (80 gold, Empire +5); or tell Odo about Nob (60 gold, Empire +5; Nob leaves the quay) |
| **A Verse in the Eaves** | Saelie | Read three rune-stones on the Rune Bridge. They can only be read at night | Saelie sings the third verse of "Hallam and the Hundred Lights" the Choir's way: the lanterns were meant to guide the lights home, not keep them out. She gives you the verse as a book (`book_low_lane_verse`) and sets `choir_verse_ilunhall`, for the Lantern Night ending later |

### The Light in the Eaves: the choices

**Magister Vessa** (`dialogue/vessa.json`). She explains why she does it:
- The light-stone is residue, and it's dying.
- A dark capital means panic, and in a panic the Lantern Order burns everyone with grey hands.
- **A.** promised her a cure. A. is "a small woman, old, who deals cards and cheats".

Your options:
- **Turn her** (Persuade 45): she gives you **Vessa's Ledger**, which points to **Karrowdeep**
  next, and leaves. She'll be your way into the Mercy later (`vessa_turned`).
- **Let her go** (`vessa_spared`).
- **Hand her to the Lantern Order** (only if you made Severin's deal): 100 gold, Lantern Order
  +15. She burns on Lanternfast eve (`vessa_handed`).
- **Attack her**: she fights as a strong Mercy caster (`vessa_killed`).

**The conduit:**
- **Break it:** the wisps go free, the veins go grey, and every eave in the city dims
  (`conduit_broken`).
- **Leave it running:** the city stays gold, fed by the caged wisps (`conduit_spared`).

**Steward Cassia:**
- **If you broke the conduit,** she offers 200 gold to keep quiet (`light_hushed`, Empire +10).
  If you refuse, you get `light_told` and Empire −10.
- **If you left it running,** you get 150 gold and the Empire's thanks (Empire +15).

**Engine change:** a new condition, `requires_any_flag` (at least one of these flags), in
`systems/conditions.gd`. It's used for "whatever you did with Vessa" and for the horn's three
endings. `tools/quest_flow.py` knows about it.

## Building and editing the level

- Run `godot --headless --path . -s levels/builders/build_ilunhall.gd` from `godot/`.
- It writes both scenes, like the other builders.
- The Fields builder (`build_grieving_fields.gd`) adds the Imperial Road east.

## Known limits

- A greybox of one district. The Hall of Spears is shut, and the Empress isn't in the game yet.
- Taking the horn is not a crime: the trophy chest isn't marked as anyone's (CRIME.md).
- Nobody moves. The feast "never stops", but nobody is feasting.
- Vessa's ledger points to Karrowdeep: see KARROWDEEP.md. The Deep Road runs east off the quay.

## Tests

`tests/test_ilunhall.gd` plays the road both ways, every person, the merchant, the trainer, the
bed, fast-travel arrival points and all three quests. It has three variants:

| Variant | Vessa | Conduit | Horn | Cassia |
|---|---|---|---|---|
| `turn` | turned | broken | to Nob | kept quiet |
| `hand` | handed to the Order | left running | reported to Odo | — |
| `fight` | killed | broken | returned to Odo | refused to keep quiet |
