# Combat & the Greyfang Wolves

## Fighting

**Left-click** swings your sword. (If the mouse isn't captured, the first click only grabs
the mouse.)

| | Value | Where to change it |
|---|---|---|
| Damage | 15 × race melee bonus (Orc 18, Human 15, Elf 13.5) | Player → Melee → Attack Damage, `races/*.tres` |
| Stamina per swing | 10. No stamina means no swing | Player → Melee |
| Swing cooldown | 0.55 s | Player → Melee |
| Reach | ~1.8 m in front of the camera, forgiving 0.45 m radius | Player → Head → Camera3D → AttackCast |

When a hit lands, the crosshair flashes red and the target's health bar appears at the top of
the screen. When you get hurt, the screen edges flash red.

**Making something hittable:** give it a method `take_hit(damage, from_position)`. Give it
a `Stats` child named `Stats`, and a `stats` variable pointing to it, if you want the top
health bar. Put it on physics layer 3 **enemies** so the sword can find it.

## Wolves

Three **Greyfang** wolves den about 30 m north-east of spawn (`GreyfangPack` in the level).

- **Idle**: wander around their den.
- **Chase**: when you come within 14 m, or when you hit one. They run at 6 m/s: walking (5)
  won't escape them, sprinting (8) will.
- **Bite**: 5 damage every 1.5 s each, so three wolves together can kill a careless player.
- **Give up**: dragged 30 m from home, a wolf runs back and heals.
- They freeze while you're in a conversation.
- 35 Health each: Orcs need 2 hits per wolf, Humans and Elves 3.

Dead wolves can be skinned with **E** for a Wolf Pelt. When the last wolf dies, `wolves_cleared` is set. Tell Maren and she completes the quest
(`wolf_quest_done`). It's saved like any flag, so the pack stays dead after loading.
**Partly killed packs are not saved:** reload and all three are back.

## Pathfinding

Wolves find their way **around** walls, rocks and buildings instead of running straight at
you.

- **`NavigationRegion3D`** in the level holds the *navigation mesh*: a map of where a
  wolf-sized creature can walk. It's built from every StaticBody3D on layer 1 "world" (the
  level root is in the group `navmesh_source`, so the whole level counts).
- **It builds itself when the level loads** (a few milliseconds here), so it always matches
  your level after you move things. For big levels later: select **NavigationRegion3D** and
  click **Bake NavigationMesh** in the toolbar, then save. The script sees a baked mesh and
  leaves it alone. Remember to re-bake after editing the level.
- **See it:** **Debug → Visible Navigation**, then play. The walkable area shows as a
  coloured overlay.
- **Each wolf has a `NavigationAgent3D`** that plans the path. With no NavigationRegion3D in
  a level, wolves fall back to running straight at you.
- **Pack behaviour up close:** within 4 m, each wolf heads for a spot on its own side of you,
  and circles further round if a packmate blocks it. Usually two bite at once, and a third
  waits right behind and steps in when there's room.
- **The door counts as solid** (the mesh is baked with it closed), so wolves path around the
  wall rather than through the doorway.

Tested with a U-shaped wall between the pack and the player: without pathfinding, the lead
wolf stayed stuck against the back of the U, 6 m away. With it, the wolves went around and
were biting within ~6 s.

## Physics layers

Named in **Project Settings → Layer Names → 3D Physics** so the Inspector shows names:

| Layer | Name | On it | Things that collide with it |
|---|---|---|---|
| 1 | world | ground, walls, props, NPCs | player, wolves, interaction ray |
| 2 | player | player | wolves |
| 3 | enemies | wolves | player, other wolves, sword |
| 4 | loot | pickups, dead wolves | interaction ray only (the player walks through) |

## Known limits

- Wolves don't jump or climb. Anything over 0.5 m tall (like the stone block) is a wall to
  them, so standing on top of it keeps you out of reach.
- No blocking, power attacks, or attack animations beyond the sword swing tween.
- The wolves and sword are placeholder boxes until real models arrive (see ASSETS.md).
