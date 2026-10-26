# Controls

Keyboard & mouse and gamepad both work, and you can switch at any moment. On-screen prompts
follow whichever you used last ("[E] Talk" / "[X] Talk"). Gamepad names below use the Xbox
layout; PlayStation and Switch pads map to the same positions.

| Action | Keyboard & mouse | Gamepad |
|---|---|---|
| Move | W A S D | Left stick (partial tilt = slower) |
| Look | Mouse | Right stick |
| Sprint | Shift | L3 (click the left stick) |
| Sneak (crouch, toggles) | C | D-pad down |
| Jump / climb a ledge / vault | Space | A |
| Interact / talk / loot | E | X |
| Attack (tap) / heavy attack or draw a bow (hold) | Left-click | RT |
| Left hand: cast, block, shield, aim a bow (hold) | Right-click | LT |
| Dual-cast (nothing in the right hand) | Both buttons | LT + RT |
| Spell-blade: put a charged spell into your weapon | Hold right-click until charged, then left-click | Hold LT until charged, then RT |
| Off-hand weapon swing (dual-wielding) / both weapons at once | Right-click / hold it and left-click | LT / hold it and RT |
| Shield bash | Left-click while blocking | RT while blocking |
| Dodge | Alt | B |
| Switch spell / Block | Q | Y |
| First / third person | V | R3 (press the right stick) |
| Race power / background power | Z / X | LB / RB |
| Class power | R | D-pad left |
| Earned power (the one you hold: Tab → Powers) | T | none by default (every button is taken; bind one in Settings → Controls) |
| Command: send your companion at what you aim at | G | D-pad up |
| Weapon art (the special attack for what you hold; a shield's while blocking) | F | D-pad right |
| Character menu (skills, inventory, magic, journal, map...) | Tab (J opens the journal, M the map) | View |
| Switch menu tabs | Click the tab, or Z / X | LB / RB |
| Pause menu | Esc | Menu |
| In menus: move / pick / back | Mouse, arrow keys, Enter, Esc | D-pad or left stick, A, B |
| In conversations: pick a reply | Number keys, click, or arrows + Enter | D-pad + A (B leaves) |
| Quicksave / quickload | F5 / F9 | (pause menu) |

Prefer tapping to holding? **Settings → Accessibility** has toggle sprint and toggle block
(see STATS_AND_SAVING.md).

Look speed for both the mouse and the right stick is **Settings → Mouse sensitivity**, and
**Invert Y** applies to both. The stick is curved: small tilts aim finely, full tilt turns
about 180° a second.

## First and third person

**V** (R3 on a gamepad) switches between first and third person, any time you're not in a
menu or a conversation. **Settings → Third-person view** does the same, and the game
remembers your choice for every character (`Settings.third_person`).

How it works (`player/player_view.gd`, the player's `View` node):
- The **eye camera** (Head/Camera3D) stays where it is in both views, and everything still
  aims from it: the interact ray, melee and spell casts, bolts and bursts. So switching never
  changes what your attacks can reach.
- **Third person** adds a camera on a spring arm 3.2 m behind your right shoulder. Walls pull
  it in, and your body hides when the camera gets very close.
- **The crosshair is what you hit.** In third person the eye is turned each frame towards
  whatever is under the crosshair (up to 60 m), so the middle of the screen is what you'll
  take, talk to, hit or cast at.
- **What you hold shows on the body.** Each first-person model (weapon, shield, spell
  hands) has a copy on the body that takes the same pose every frame, 1.35× further out from
  the shoulders. So third person swings, blocks, bashes and draws a bow exactly as first
  person does, with no separate animations. Changing equipment rebuilds the copies.
- **Render layers** keep each camera to its own things. The first-person hands, weapons and
  spell glow are on layer 11, which the third-person camera doesn't draw. Your body is on
  layer 12, which the eye camera doesn't draw.

## Climbing (mantle and vault)
- **Jump facing a ledge** 0.45–2.1 m high (from your feet) to climb onto it. Higher than that,
  you just jump.
- **Hold jump in the air** near a ledge to grab it and pull yourself up (up to 1.4 m above
  your feet mid-jump, so about 2.4 m from the ground).
- **Low, thin obstacles** (up to 1.25 m high, 0.9 m thick, like fences) are **vaulted**: you
  go over and land on the far side. Sprinting into a low block vaults it too, instead of
  climbing on top.
- Climbing costs 10 Stamina and gives Athletics XP. It needs room for your head and for you
  to stand at the top.
- Try it on the **fence** north-east of spawn (by the wolf path) and the **boulder** west of
  the waystation (1.8 m).
- Tuning: the constants at the top of `player/player_traversal.gd`.

## Tutorial hints
The first time something comes up, a short tip appears in the lower middle of the screen:
- wolves and bandits hunting you
- a charged spell or a tome
- a level-up
- a ledge in front of you
- your first survival need, and the cold

Each shows once per character. Turn them off in **Settings → Tutorial hints**.

## Changing bindings
**In the game: Esc → Settings → Controls...** Every action has a keyboard-and-mouse binding
and a gamepad binding:
- **Click a binding**, then press the new key, mouse button, gamepad button, trigger or
  stick direction. **Esc** cancels. Pressing a key while it waits for a gamepad button (or
  the other way round) is ignored.
- If another action already used that key, it moves to the new action, and the page says
  which action lost it.
- **Reset to defaults** puts everything back.
- Bindings are saved to `user://controls.cfg` and apply to every character. Prompts ("[E]
  Talk") and the HUD update straight away.
- Mouse/stick look, the pause button (Esc / Menu) and menu navigation can't be rebound.

**In the editor:** Project → Project Settings → Input Map holds the defaults. The list of
actions the Controls page shows is `ACTIONS` in `systems/key_bindings.gd`. `ui_accept` and
`ui_cancel` are overridden there to add the gamepad's A and B (Godot 4.3's defaults have no
gamepad buttons for them).

## Known limits
- No aim assist for the stick yet.
- Third person (greybox): your body is a capsule with no arms or walk animation. What you
  hold floats where your hands would be, posed like the first-person model, so poses meant
  to read from the eye can look odd from behind.
- Typing a name in the character creator needs a keyboard (leave it blank for "Traveller").
- Gamepad was tested with simulated input; it hasn't been tried with a real controller.

## Touch

For phones and tablets (`ui/touch_controls.gd`). On by default on a touch screen; switch it
in **Esc > Settings > Accessibility > Touch controls**.

- **Move:** put your thumb anywhere on the left half of the screen and push; the stick appears
  where you touched. It keeps you moving while you press buttons.
- **Look:** drag anywhere on the right half that isn't a button.
- **Buttons** (right side): ⚔ attack (hold for a heavy), ✋ left hand (cast, block, aim), ⤒ jump,
  ↷ dodge, E use/talk, ▼ sneak, » sprint (tap on, tap off), ★ weapon art, ✦ switch spell, ⚑
  command, ☰ character menu, Esc pause. Top left: Ⅰ race power, Ⅱ background power, Ⅲ class power, Ⅳ earned power.
- **Menus:** tap as you would click. A ✕ at the top right closes whatever's open.
- Sizes scale with the screen's height, so they're the same physical size on a phone with many
  pixels.

The buttons send the same input actions as the keyboard and gamepad, so the game doesn't know
the difference. A touch also arrives as a mouse click; in play that click is swallowed so a tap
isn't also an attack.

Not yet: hints still name keys ("press [M]"); there's no way to move or resize buttons; the
look sensitivity is the mouse's (Settings > Mouse sensitivity) and hasn't been tuned on a phone.
