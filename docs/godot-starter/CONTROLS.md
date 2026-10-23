# Controls

Keyboard & mouse and gamepad both work, and you can switch at any moment. On-screen prompts
follow whichever you used last ("[E] Talk" / "[X] Talk"). Gamepad names below use the Xbox
layout; PlayStation and Switch pads map to the same positions.

| Action | Keyboard & mouse | Gamepad |
|---|---|---|
| Move | W A S D | Left stick (partial tilt = slower) |
| Look | Mouse | Right stick |
| Sprint | Shift | L3 (click the left stick) |
| Jump / climb a ledge / vault | Space | A |
| Interact / talk / loot | E | X |
| Attack (tap) / heavy attack or draw a bow (hold) | Left-click | RT |
| Left hand: cast, block, shield, aim a bow (hold) | Right-click | LT |
| Dual-cast (nothing in the right hand) | Both buttons | LT + RT |
| Shield bash | Left-click while blocking | RT while blocking |
| Dodge | Alt | B |
| Switch spell / Block | Q | Y |
| Race power / background power | Z / X | LB / RB |
| Character menu (skills, inventory, magic, journal...) | Tab (J opens the journal) | View |
| Switch menu tabs | Click the tab, or Z / X | LB / RB |
| Pause menu | Esc | Menu |
| In menus: move / pick / back | Mouse, arrow keys, Enter, Esc | D-pad or left stick, A, B |
| In conversations: pick a reply | Number keys, click, or arrows + Enter | D-pad + A (B leaves) |
| Quicksave / quickload | F5 / F9 | (pause menu) |

Look speed for both the mouse and the right stick is **Settings → Mouse sensitivity**, and
**Invert Y** applies to both. The stick is curved: small tilts aim finely, full tilt turns
about 180° a second.

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
**Project → Project Settings → Input Map.** Each action lists its key, mouse and gamepad
events; add or remove events there. The prompts read the Input Map, so they update by
themselves. `ui_accept` and `ui_cancel` are overridden there to add the gamepad's A and B
(Godot 4.3's defaults have no gamepad buttons for them).

## Known limits
- No aim assist for the stick yet, and no rebinding screen in the game (only the editor's
  Input Map).
- Typing a name in the character creator needs a keyboard (leave it blank for "Traveller").
- Gamepad was tested with simulated input; it hasn't been tried with a real controller.
