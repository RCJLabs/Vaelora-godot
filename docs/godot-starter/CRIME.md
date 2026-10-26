# Theft and crime

You can steal, and get caught doing it. The rules are in `systems/crime.gd` (autoload
**Crime**).

## What's someone's

Two kinds of thing can belong to someone. Each has a **Belongs To** field set to a
display name, such as `"Wenna Pike"`:

- **Pickups** (`interactables/pickup.gd`). The prompt says **Steal Bread** instead of Take.
- **Containers** (`interactables/loot_container.gd`). The prompt says **Steal from Jory's crate**. Emptying one is theft.

The builders place owned things with these helpers:

- `goods(name, item, count, pos, who, gold, label)`: something on a stall, counter or table. Use item `""` with gold for a purse.
- `stores(name, what, contents, gold, pos, who, lock)`: a crate or strongbox. It can also be locked.

| Where | What | Whose |
|---|---|---|
| Weirholt market | bread, lockpicks, a dagger on the stall behind her | Wenna Pike |
| Weirholt inn | a coin purse on the counter | Hedda Marrow |
| Weirholt counting house | strongbox (Adept lock, 120 gold) | Factor Tarle |
| Weirholt docks | a crate of ingots and leather | Jory Vell |
| Weirholt surgery | potions on a table | Physician Fenn |
| Ama's farm | a basket of apples | Goodwife Ama |
| Grieving Fields | a crate behind the wagon | Marta Coil |
| Ilunhall quay | ingots and a tonic on the stall | Bruna Deepseal |
| The Long Table | a strongbox at the back (Apprentice lock) | Hallmaster Odo |
| Karrowdeep, the Market Bridge | ingots and lockpicks on the stall | Grima Coldiron |
| Karrowdeep, the Anvil College | the Seal College's rune-slate, on the bench (The Anvil and the Seal) | Master Bek |
| Karrowdeep, the Table | the Guildmaster's strongbox (Expert lock): the seal-key to Seam Nine, 60 gold | Guildmaster Hrodna |
| Karrowdeep, the Lamp and Pick | the till (Apprentice lock) | Torvald of the Lamp |
| Ithmarren, the Lantern Gardens | potions and blue moss on the stall | Tamsin Leafwright |
| Ithmarren, the Sennaveth Bough | House Sennaveth's coffer (Expert lock): the root-key, 90 gold | Lady Ithariel Sennaveth |
| Ithmarren, the Sennaveth Bough | the house letter-box (Apprentice lock): this week's letter (A Lie Well Told) | Steward Lirael |
| The Glass Coast, Sarabh | water flasks and bread on the stall | Nadira |
| The Glass Coast, Sarabh | the collector's tally-chest (Apprentice lock): Samira's tally-stone, 70 gold (The Sovereign's Due) | Collector Amir Tahan |

## Who sees

A crime is seen if anyone who could see it does, at the moment it happens. A witness
is any NPC (`interactables/npc.gd`, group `people`) who meets all of these:

- **Out**: not gone in for the night (ROUTINES.md) and not hidden by a story presence.
- **Facing you**: within about 100 degrees each side of the way they face. Behind them, they don't see.
- **In clear sight**: a clear line from their eyes to you. Walls, stalls and other people block it.
- **Close enough**:
  - 15 m in daylight, falling to 9 m at the dead of night.
  - Crouched, it's shorter still. The 15 m is multiplied by the Sneak detection multiplier (SNEAK.md: your skill, standing still, darkness, perks, armour). At Sneak 15 that's about 10 m moving and 7 m standing still by day, and less at night.

Any prompt for a crime ends in **(watched)** while someone would see it. The prompt
uses the same check as the crime, so it doesn't lie.

People turn back to their work when they stop (ROUTINES.md). Wenna faces the square
with her stall behind her, Hedda faces her counter, and the Quay warden watches Bruna's
stall.

## Stolen goods

Everything you take that belonged to someone is **stolen**, whether or not anyone saw.
Each item remembers the region it was stolen in. Merchants in that region won't buy it;
the trade screen marks it "(N stolen here)". Any other region's merchant will buy it.

Stolen goods are counted per item, not per copy. If you have 3 lockpicks and 2 were
stolen, selling or using one leaves 2 stolen. Your own copies go first.

## Bounties

A seen crime puts a bounty on you in that region (`Crime.REGIONS`, one per region level):

| Crime | Bounty |
|---|---|
| Theft (seen) | what it's worth: the items' value plus any gold, at least 5 |
| Caught picking a pocket | 25 |
| Running from a guard | +10 |
| Beating a guard until they yield | +40 |

A seen crime also costs you standing with the region's people, once you've met them
(`Crime.FACTIONS`; see FACTIONS.md):

| Region | Faction | Theft | Pickpocket | Running | Assault |
|---|---|---|---|---|---|
| The Greywater Vale | Riverwatch Garrison | −2 | −3 | −2 | −5 |
| The Riverlands | The River Compact | −2 | −3 | −2 | −5 |
| The Grieving Fields | The Ashen of the Fields | −2 | −3 | −2 | −5 |
| Ilunhall | The Ilunar Empire | −2 | −3 | −2 | −5 |
| Karrowdeep | The Deep Guilds | −2 | −3 | −2 | −5 |
| Ithmarren | The Great Houses | −2 | −3 | −2 | −5 |
| The Glass Coast | The Oasis Thrones | −2 | −3 | −2 | −5 |

Bounties never fade. **Tab → World** lists where you're wanted, under the Wanted heading.

## Pickpocketing

Crouched, **E** at a person picks their pocket instead of talking. The prompt shows the
chance, for example "Pickpocket Hedda Marrow (55%)".

**The chance**

| Factor | Effect |
|---|---|
| Base, at Sneak 15 | 30% |
| Each Sneak level above 15 | +0.6% |
| From behind | +25% |
| Officials / merchants / scholars | −15% / −10% / −5% |
| Perks | can multiply it (a `pickpocket` modifier) |
| Limits | at least 5%, at most 90% |

**Success**
- You take their coin, and some of the time what they carry (by role: bread, lockpicks, a potion, arrows).
- You get 8 Sneak XP.
- Anyone else who sees it makes it a seen theft.

**Failure**
- A 25-gold bounty.

**Limits**
- One try per person per day.
- Guards and inquisitors can't be picked.

## Guards

NPCs with the **guard** role keep the law where they stand:

- **The Riverlands:** Captain Varga and Sergeant Dace.
- **The Grieving Fields:** Warden Ashlock, on the road into Greyfold.
- **Ilunhall:** the Warden of the Quay and the Bridge Warden.
- **Karrowdeep:** the Warden of the Bridge and the Gallery Warden (the Table's wardens).
- **Ithmarren:** the Bough Warden and the Root Warden (the Houses' wardens).
- **The Glass Coast:** the Square Warden and the Mole Warden (the Sovereign's wardens).

While you have a bounty in their region, a guard who sees you within 9 m stops you. Talking
to a guard while you're wanted does the same. The conversation is `dialogue/guard_crime.json`:

- **Pay**, if you can afford it. You pay the bounty, and they take everything you stole in this region.
- **Talk your way out**. Only for bounties under 100: a Persuade 45 check. Pass and the bounty's gone, and you keep the goods. Fail and, as with every Speech check, it isn't offered again.
- **Go quietly**. A day in the cells per 100 gold of bounty, 1 to 7 days. The clock and your needs go on (you're fed and you sleep). Your stolen goods are taken. You come out at the level's `JailRelease` marker: the barracks door in Weirholt, the road into Greyfold, the quay in Ilunhall, the Gate Hall in Karrowdeep, the forest road in Ithmarren, Sarabh's oasis on the Glass Coast. In Hardcore it autosaves, as a defeat does.
- **Run**. Esc does the same. The bounty grows by 10, and they fight (below).

### When they fight

Run, and every guard within 40 m of you takes up arms. Each guard NPC steps out of
the scene, and a fighter steps in (`enemies/guard.gd`). The fighter is `bandit.tscn` with
the guard's name, race and clothes, and it fights like a bandit: telegraphed swings, a raised
guard, sometimes a parry. Each has 90 health and hits for 12.

- **They don't kill.** Beaten by a guard, you're **arrested**: the cells, as if you'd gone quietly, in any mode. You go to the cells with half your health, instead of dying or reloading.
- **You can't kill them either.** Beat one down to a quarter of their health and they **yield**: they're themselves again, where they stood, and you've a 40-gold bounty for assault.
- **Surrender:** E at a fighting guard. Everyone lowers their weapons, and the guard you surrendered to talks again: pay, the cells, or run once more.
- **Lose them:** guards run slower than you sprint and won't chase more than 28 m from their post. Lose them, and once they're back at their posts they go back to being people. Guards then leave you be for a minute before they'll stop you again.

Quest people who are guards (Varga, Dace) can't die this way, so nothing in their quests breaks.

## Fences

Quill, in Ilunhall's Low Lane, buys stolen goods from anywhere ("fence": true in
`systems/trade.gd`). His prices are the usual ones.

## Saving

Saves keep bounties, stolen goods and the pockets picked today, under `"crime"`. This is
save version 12; older saves load with a clean slate.

## Dialogue hooks

A dialogue can use:

- **Actions:** `"crime": "pay" / "pardon" / "jail" / "resist"`.
- **Conditions:** `"requires_bounty_affordable": true` and `"requires_bounty_below": 100`.
- **Text:** `{bounty}` and `{region}` in any line or choice are filled in. See DIALOGUE.md.

## Limits

- **No breaking out of the cells.** You serve the time.
- **The Greywater Vale has no law yet.** It has no owned goods and no guards (it's a hand-placed scene). Levels not in `Crime.REGIONS` (dungeons, interiors) have no law: nothing there is stolen.
- **No other crimes.** There's no trespassing, and you can't attack ordinary NPCs, so there's no assault or murder beyond the guards.
- **A yielded guard stays where they yielded** until you leave the level. Their watch spot only comes back with the level.
- **Guards in a fight don't call for help.** Only guards near you when you run take up arms.
- **Owners don't react.** A robbed merchant trades with you as before.
- **Witnesses report at once.** Nobody has to run and tell a guard, and killing a witness isn't a thing.
- **Pockets are generated by role**, not stocked per person.

Tests: `tests/test_crime.gd`, `tests/test_guards.gd`.
