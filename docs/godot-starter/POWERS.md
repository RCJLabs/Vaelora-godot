# Earned powers

Phase 7 of `docs/CHARACTER_BUILDING.md`, as decided: active powers are earned through play too
(shrines, quests, the stones); **one slot, on its own key, that you can exchange**; and earned
powers sit **sideways** to the race, background and class powers, not above them.

- **The fourth power slot:** T (touch Ⅳ; no gamepad button by default, since every one is taken,
  so bind one in Settings → Controls). The HUD shows it with the other three.
- **Exchanging:** Tab → Powers lists your four powers and every earned power: Hold puts one in the
  slot; the ones you haven't earned yet say how to earn them. The first you earn goes into an empty
  slot by itself.
- **Earning** is worked out from quests and story flags, like the journal, so it's saved with them;
  only the slot and which ones have been announced are saved (`Character.earned_power`,
  `earned_seen`). Saves from before this announce anything already earned once, on loading.
- **Releasing Wisp Essences** at the stone circle is now counted (flags `released_wisp_1`,
  `_2`...; `EarnedPowers.essences_released()`).

Data: entries in `godot/character/abilities.json` with an `"earned"` source (`{"quest": id}`,
`{"essences": n}` or `{"flag": name}`). Those marked `"scripted"` need code
(`EarnedPowers.activate()`, `godot/systems/earned_powers.gd`); the rest are a status effect.

| Power | Earned by | What it does | Cooldown |
|---|---|---|---|
| **Shrine's Peace** | Silent Shrine | Enemies within 10 m stop fighting for 10 s (`Glamour.calm`); striking one ends it for that one. Wisps don't heed it | 120 s |
| **Stone-Skin** | Releasing 3 Wisp Essences | Half damage for 8 s, but 30% slower | 120 s |
| **Wisp-Step** | Releasing 6 Wisp Essences | Blink up to 6 m the way you face (stops short of walls) | 20 s |
| **Lantern's Glare** | Wrong Things | Enemies within 10 m in a 60° cone in front reel; wisps also take 40 | 60 s |
| **Greenward** | Ask the Forest | 3 Health a second for 20 s | 120 s |
| **Wanderer's Eye** | Readings Under the Wanderer | True Sight for 30 s: enemies within 40 m marked through walls | 180 s |
| **Roadwise** | The Lost Wagon | Sprinting costs no Stamina for 30 s | 180 s |
| **Kindle** | Licence to Burn | Everything within 3 m of where you aim (20 m) catches fire | 45 s |

## Known limits

- Numbers are first guesses, untried in play.
- **No gamepad button** by default (see above).
- **Shrines:** only the Silent Shrine gives one; there's one shrine in the world so far.
- **Greenward** was proposed as "more outdoors"; there's no indoors/outdoors test yet, so it's flat.
- **Wisp-Step** checks for walls at chest height only: it can step off a ledge.
