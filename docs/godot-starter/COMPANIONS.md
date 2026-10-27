# Companions

Someone who travels with you: **Brannoc** or **Zora**, one at a time (greybox).

## Recruiting

Both first say they'd travel with you (act one):
- **Brannoc**, after Wrong Things: "What will you do, after all this?" (`brannoc_would_travel`).
- **Zora**: "Would you ever leave this place?" (`zora_would_travel`). Not if you told the
  Lantern Order where she lives.

Then "Come with me." sets `companion_brannoc` / `companion_zora`. That flag *is* the
companion: it saves and loads with the rest of the story, and `systems/companions.gd`
(autoload **Companions**) brings them into whatever level you're in, behind you. The person
at their post is inside a StoryPresence with `hide_flag companion_<id>`, so they step out of
the world while they're with you, and back in when you send them home.

## Orders

Talk to them (E) for `dialogue/companion_<id>.json`:
- **Wait here.** They stand where they are.
- **Follow me.** They keep about 3 m behind; left more than 40 m behind (a door, a cellar,
  a fast travel) they simply arrive behind you.
- **Go home.** The flag is cleared and they're back at their post.
- **About something else.** Their usual conversation (`npc_dialogue` in `DEFS`), since the
  person at their post is away while they travel with you: Brannoc's garrison business,
  Zora's lessons.

The orders are command flags (`companion_cmd_wait`, `_follow`, `_dismiss`, `_talk`) that
Companions acts on and clears at once (`GameState.clear_flag`, which StoryPresence also listens for).

**Point it out:** aim at an enemy and press **Command** (G, or D-pad up) and they go for it,
even one that hasn't noticed you (an ambush) and even if they were told to wait. It's the
Command skill's key (below).

## The Command skill

Presence's fourth skill, one of my two additions in `docs/CHARACTER_BUILDING.md`. The code is
`systems/command.gd` (the autoload `Command`).

- **Your companion** does +1% damage and has +1% health per Command level above 15 (Brannoc's
  150 health is 225 at Command 65). It's worked out live, so a level-up mid-fight counts.
- **The Command key** picks the enemy nearest your aim (within 12° and 40 m) and sends your
  companion at it. With Pack Leader, things you've called (Binding) go for it too.
- **XP:** a tenth of the damage your companion deals, and 1 per order.
- A hint explains the key the first time someone joins you.

| Branch | Perks (level) |
|---|---|
| Their blows | Leadership (15) → II (35) → III (60): +15% damage each → **Vanguard** (70): their blows stagger twice as hard · Battle Drill (30): attack 20% faster |
| Their health | Steadfast (20) → II (45): +20% health each → **Commander's Aura** (80): they take a quarter less · Hardened (40): health back twice as fast · Battlefield Aid (25): helping them up gives full health → **Unbowed** (50): up on their own in 8 s |
| Orders | **Marked Target** (25): what you point out takes 15% more for 10 s → **Coordinated Strike** (45): hit it yourself and their next blow doubles · **Pack Leader** (35): called things obey too · Swift Escort (20): they run 25% faster → **Hold the Line** (45): waiting, they take half |
| Together | **Bodyguard** (40): with them up and within 6 m, you take 10% less → **Battle-Brothers** (55): while they're down, your blows do 25% more |
| Loyalty | Inspiring (20): approval rises half as fast again → **Beloved** (60): they only leave at −80 |
| — | Command Presence (15): +25% XP |

New modifiers: `ally_damage`, `ally_health` (and Inspiring uses Speech's `approval_gain`).
New effects: `commanded`, `guarded`, `avenging`.

Not yet: two companions at once (the Binder class's "two bound creatures" is the nearest
thing); orders by a radial menu (wait / follow by key, not only by talking).

## Fighting

While following, they fight an enemy within 15 m of you or them that's in the fight (not
idle, heading home, fleeing or charmed). Told to wait, they stay put but still hit back at
whatever is hitting them. How they fight (`companions/companion.gd`):

- **What they go for.** The one you pointed out (Command) first. Otherwise each enemy is
  scored by its distance from them, less a bonus for each reason to go for it (`_score()`):
  - on you, within 4 m: −4 m, or −8 m while you're under 35% Health;
  - an archer or a caster: −8 m for Zora, −3 m for Brannoc, and −3 m more mid-draw or
    mid-cast, since a hit breaks a cast;
  - after them: −2 m. Staggered (free hits): −2 m.
  - They keep the target they have unless another scores 3 m better, so they don't flip
    between two enemies standing side by side.
- **Brannoc flanks.** On an enemy fighting you, he goes round its side to the far side
  (about 115° round from you) before he swings. It can't face you both, and a blow from
  behind gets past a guard. He gives up after 3 s on the same enemy if it keeps turning.
- **Zora keeps her distance.** She backs off from anything after her that's within 3.5 m,
  works round a wall if she backs into one, steps sideways when something blocks her
  line, and throws from 6 m.
- **They read telegraphs**, three times in four: a bandit's wind-up or a wolf's crouch,
  0.25 s before it lands. Brannoc raises his guard (0.6 s; a blow from in front does a
  quarter). Zora jumps back out of reach (0.3 s, untouchable while she does).
- **They fall back when badly hurt.** Under a quarter Health, with something after them,
  they go behind you for up to 5 s (once every 12 s). Whatever was on them is nearer you
  then, and turns on you. Not if you pointed them at something.
- Measured on the Vale camp with a bot that never defends (`tests/test_bandit_fight.gd` with
  a companion along): with Zora you end on 72–83 Health (46–67 before this), and Brannoc on
  126–142 of 150 (91–127). With Brannoc, that camp was already easy before (90–100 for you).

Brannoc has 150 health and hits for 12 in melee every 1.2 s;
Zora has 90 and throws fire for 9 from 6 m every 1.6 s: a bolt (`combat/spell_bolt.tscn`,
`"ranged": true` in her def) that flies from her chest and hurts what it lands on, so
something in the way stops it. Numbers are in `DEFS` in `systems/companions.gd`.

**Enemies fight them too.** Wolves and bandit-kind ask `Targeting.foe_for()`
(`systems/targeting.gd`) who to go after: Glamour first (decoys, charm), then the nearer of
you and a companion who's on their feet. An enemy sticks with whoever it's after unless the
other is 2.5 m closer, and a companion who hits an enemy draws it. Wisps, the stone guardian
and The First still only go for you.

**Down, not dead.** At 0 health a companion is down: out of the fight, and enemies leave them
alone. A notice says so. Help them up (E) for half their health, or they get up on their own
after 20 s with 30%, and go back to what they were told to do. Out of a fight (not hit for
6 s) they heal 3 a second. A floating name and health show while they're hurt.

**Health carries over.** `Companions.health` keeps it as it is, through doors and into the
save: hurt when you left a level, hurt when they arrive in the next. Down when you left means
getting up as they arrive (30%). Sent home, they're rested by the time you see them again.

## Approval, remarks and banter

Each companion has an **approval** of you, from −100 to 100, starting at 0 and saved with the
game (`Companions.approval`).
- **Remarks.** While they're following you, story flags they care about move it, with a
  line on screen ("Zora: \"I felt that from here...\""). The flags, amounts and lines are in
  `companions/<id>.json` under `"reactions"`. Brannoc likes clearing the road, returned
  property and the law; he hates theft and drawing on the Lantern Order. Zora likes released
  wisps and anything that annoys the Order; she hates you swallowing a wisp's light.
- **Banter.** Every 150 s of following, out of a fight, they say the next line from
  `"banter"` that they haven't said and whose conditions pass (any dialogue condition:
  flags, corruption, Lanternfast...). Each line once; what's been said is saved.
- **Walking out.** At −40 or below they say their `"leave_line"`, go, and set
  `left_you_<id>`; "Come with me." isn't offered again.
- **Dialogue** reads it with `"requires_approval": {"zora": 10}` and
  `"requires_approval_below"`, and changes it with `"add_approval": {"zora": 15}`. Their
  own dialogue greets you warmly at 40 or more, coldly below −15.

## Their quests

- **Zora, "Her Teacher's Notebook"** (approval 10+: "You said the Order burned your
  teacher."). Inquisitor Hale carries Ilse Marrow's notebook (`book_ilse_notebook`, a
  readable book). Buy it with a 100-gold "donation", or fight him for it (it's in his loot).
  Give it to Zora: +15.
- **Brannoc, "What Riverwatch Was Founded On"** (approval 10+: "Your father's story...").
  The Riverwatch Roll (`book_riverwatch_roll`) is in the old barrow's first hall: Riverwatch's
  founders were Hallam's hunters, paid in land, and Brannoc's family is on it. Tell him the
  truth (`brannoc_knows_hunt`, +10), or that it's only names (`brannoc_spared_truth`, −3).
  This is the start of his arc in STORY.md: loyal until he learns what the Empire was
  founded on.

## Known limits (greybox)

- They're capsules (`companions/companion.gd`), with no attack animations; Zora's bolt
  just leaves her chest.
- Wisps and bosses ignore them. They read only bandit-kind and wolf telegraphs (not a
  boss's, an archer's draw or a caster's spell), and their own blows have no wind-up.
- Remarks and banter are on-screen text, not voiced or spoken in the world, and they can
  talk over other messages.
- No romance, no gifts, and approval doesn't change how they fight.
- **Fixed:** enemies couldn't see a companion. The sight ray (`Stealth.clear_line`) hit the
  companion's own body (they're on the world's collision layer), so an enemy that lost
  contact for a moment "lost" them and went searching.
- Adding one: a `DEFS` entry, a `dialogue/companion_<id>.json`, a recruiting choice that
  sets `companion_<id>`, and a StoryPresence with `hide_flag companion_<id>` around the NPC.

Tests: `tests/test_companions.gd`, `tests/test_companion_tactics.gd` (how they fight).
