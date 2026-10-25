# Speech

Phase 2's third skill (`docs/CHARACTER_BUILDING.md`). It's Presence's. The code is
`systems/speech.gd` (the autoload `Speech`), the dialogue manager, and a few lines in
`systems/trade.gd`.

## Checks in conversation

A dialogue choice can carry a **check**. Three kinds:

| Kind | Score | Notes |
|---|---|---|
| **Persuade** | Speech + 2 per Presence point above 10 | |
| **Intimidate** | Speech + 2 per Strength point above 10 | |
| **Bribe** | none | Always works if you can pay. Costs the named price × (1 − 0.4% per Speech level above 15, never under half) × perks. |

Perks add to persuade and intimidate scores (`check_bonus`).

**There's no dice.** The choice shows what it needs and what you have:

> 3. [Persuade 60 · you 42] I'm fighting it. Every day. Let me finish what I started.
>
> 4. [Bribe 135 gold] The Order accepts donations, I hear.

- **Pass:** the choice's actions run and it goes to `next`. You learn Speech, 5 XP +
  difficulty ÷ 5 (a bribe counts its gold ÷ 5), once per check.
- **Fail:** it goes to `fail_next` and the choice's own actions don't run. The check isn't
  offered again (flag `speech_failed_<id>`). With Learn From It, a failure still teaches half.

Writing one: DIALOGUE.md, "Speech checks".

### Where they are so far

| Who | Check | Pass | Fail |
|---|---|---|---|
| Maren | Persuade 30: "Any chance of a better price for a regular?" | 10% off her prices from then on (`maren_discount`) | "Prices are prices, love." |
| Inquisitor Hale, the notebook | Persuade 45: "Ilse's dead. Her words can't hurt anyone…" | He gives it to you free (`zora_notebook_persuaded`, its own journal line) | Pay the 100, or nothing |
| Inquisitor Hale, when you're Stained | Persuade 60, Intimidate 55, Bribe 150 | He lets you go (`inquisitor_spared`) and lets you pass from then on | He draws |

The inquisitor's "(Fight.)" is still there. **Walking away (Esc) when he's drawn starts the
fight**, using the new `on_leave` node action, as it did before.

## Haggling

Prices also go by Speech (INVENTORY.md, "Trading"):

- buying gets 0.3% cheaper per level above 15;
- selling gets 0.2% dearer per level;
- the Haggling perks take 5% each way per rank.

Buying never drops under ×0.85 and selling never tops ×0.8, so you can't buy low and sell
high. Every trade teaches Speech: 0.05 XP per gold.

## Perks (22)

| Branch | Perks (level) |
|---|---|
| Haggling | Haggling (15) → II (30) → III (50) → IV (70) → V (90): 5% each way → **Master Trader** (100): merchants restock every day |
| Persuasion | Persuasive (20): +10 → Silver Tongue (40): +15 → Diplomat (60): +15 → Golden Voice (85): +10 to every check |
| Intimidation | Intimidating (25): +10 → Menace (45): +15 → Dread (65): +15 |
| Bribes | Bribery (20): −25% → Deep Pockets (45): a third less again |
| Learning | Good Student (30): trainers −20% → Price of Knowledge (45): books and tomes −30% |
| People | Reputation Precedes You (35): reputation gains +20% → Trusted (50): companion approval +25% |
| — | Fat Purses (40): merchants carry 50% more gold · **Learn From It** (25): failed checks teach half · Smooth Talker (20): Speech +25% XP |

## Not yet

- Only three places use checks. More belong in the quests as they're written; the tools are
  in place.
- The checks are all visible and fixed. Whether to hide the score (or roll) is a playtest
  question (PLAYTEST.md).
- No haggling minigame and no per-merchant reputation beyond Maren's discount.
- Intimidation doesn't look at your armour, weapons or reputation, only Speech, Strength
  and perks.
