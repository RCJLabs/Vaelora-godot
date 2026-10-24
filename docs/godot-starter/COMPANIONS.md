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

The orders are command flags (`companion_cmd_wait`, `_follow`, `_dismiss`) that Companions
acts on and clears at once (`GameState.clear_flag`, which StoryPresence also listens for).

## Fighting

While following, they fight the nearest enemy within 15 m of you that's after you (not idle,
heading home, fleeing or charmed). Brannoc hits for 12 in melee every 1.2 s; Zora throws
fire for 9 from 6 m every 1.6 s. Numbers are in `DEFS` in `systems/companions.gd`.

## Known limits (greybox)

- They're capsules (`companions/companion.gd`), and enemies only ever target you, so
  companions can't be hurt or killed.
- No companion quests, approval, or banter yet; their dialogue is only orders.
- Adding one: a `DEFS` entry, a `dialogue/companion_<id>.json`, a recruiting choice that
  sets `companion_<id>`, and a StoryPresence with `hide_flag companion_<id>` around the NPC.

Tests: `tests/test_companions.gd`.
