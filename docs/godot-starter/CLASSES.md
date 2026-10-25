# Classes

Phase 6 of `docs/CHARACTER_BUILDING.md`. A class is the third choice at creation, after race and
background. It never stops you learning anything: hybrids stay encouraged.

- **Its five skills improve 20% faster** (`Classes.XP_MULT`, through `Character.modifier("skill_xp_<skill>")`,
  so it stacks with traits, perks and Adaptable).
- **A class power** only it has, on **R** (gamepad D-pad left; touch Ⅲ), next to the race (Z) and
  background (X) powers. The HUD shows all three and their cooldowns.
- **Changing class:** after Aurel's rite (the 150-gold respec), choose "I'd walk a different road"
  and pick from the class screen (`ui/class_screen.gd`). Skills, perks and levels stay; only the
  XP bonus and the power change.
- Saves keep the class (`Character.class_id`). Saves from before classes load with none; the rite
  gives them one.

Data: `godot/character/classes.json` (name, description, skills, ability). The powers are entries in
`godot/character/abilities.json`; those marked `"class": true` need code and live in
`Classes.activate()` (`godot/systems/classes.gd`). A power that can't go off (nothing aimed at, too
little Health) says why and doesn't start its cooldown.

| Class | Skills | Power | What it does | Cooldown |
|---|---|---|---|---|
| Warrior | One-Handed, Two-Handed, Block, Heavy Armour, Smithing | **War Cry** | Every enemy within 8 m is staggered | 60 s |
| Ranger | Archery, Sneak, Light Armour, Survival, Athletics | **Hunter's Mark** | The enemy you aim at (40 m) takes 30% more from everything for 20 s | 45 s |
| Thief | Sneak, Lockpicking, Light Armour, Speech, One-Handed | **Vanish** | Invisible for 8 s (attacking or casting ends it) | 90 s |
| Mage | Ruin, Shaping, Mending, Runecraft, Alchemy | **Arcane Surge** | Spells cost no Magicka for 8 s | 120 s |
| Spellsword | One-Handed, Ruin, Shaping, Block, Light Armour | **Quickened Blade** | Your ready damage spell goes into your blade at once, for no Magicka (`COMBAT.md`, "Spell-blades") | 60 s |
| Nightblade | Sneak, One-Handed, Glamour, Drawing, Light Armour | **Shadow Feast** | For 20 s, a melee sneak attack heals you by half its damage | 90 s |
| Tide-Warden | Tidecraft, Two-Handed, Heavy Armour, Mending, Sight | **Moon's Favour** | The tide is high for 60 s, whatever the moons say | 300 s |
| Battlemage | Ruin, Heavy Armour, Two-Handed, Binding, Athletics | **Storm Mantle** | For 15 s, enemies within 3 m take 8 damage a second | 90 s |
| Binder | Binding, Command, Runecraft, Sight, Glamour | **Call the Host** | For 2 minutes, hold one more bound creature | 300 s |
| Wayfarer | Unarmed, Athletics, Survival, Mending, Sight | **Second Breath** | Half your Health and half your Stamina back | 150 s |
| Herald | Speech, Command, Glamour, Archery, Light Armour | **Rally** | For 20 s, you and your companions deal 25% more | 120 s |
| Hedge Witch | Drawing, Alchemy, Binding, Glamour, Mending | **Old Bargain** | 30 Health for 60 Magicka (not if it would kill you) | 30 s |

Together the twelve cover all 24 skills (`tests/test_classes.gd` checks).

## Known limits

- The numbers (cooldowns, durations, 30%, 25%) are first guesses, untried in play.
- **Hunter's Mark** uses the Command key's aim (12° around the crosshair), which is tight up close.
- **Shadow Feast** only heals on melee sneak attacks, not sneak-attack arrows.
- **Call the Host** lets you *call* one more; if it ends while you hold the extra, nothing is
  dismissed until one goes.
- **Storm Mantle** has no visual yet: only the damage.
- **Rally** affects your companion; bound creatures aren't counted as companions.
