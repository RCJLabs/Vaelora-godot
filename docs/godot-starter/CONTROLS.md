# Controls

Keyboard & mouse and gamepad both work, and you can switch at any moment. On-screen prompts
follow whichever you used last ("[E] Talk" / "[X] Talk"). Gamepad names below use the Xbox
layout; PlayStation and Switch pads map to the same positions.

| Action | Keyboard & mouse | Gamepad |
|---|---|---|
| Move | W A S D | Left stick (partial tilt = slower) |
| Look | Mouse | Right stick |
| Sprint | Shift | L3 (click the left stick) |
| Jump | Space | A |
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
