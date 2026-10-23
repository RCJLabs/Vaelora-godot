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

When the last wolf dies, `wolves_cleared` is set. Tell Maren and she completes the quest
(`wolf_quest_done`). It's saved like any flag, so the pack stays dead after loading.
**Partly killed packs are not saved:** reload and all three are back.

## Physics layers

Named in **Project Settings → Layer Names → 3D Physics** so the Inspector shows names:

| Layer | Name | On it | Things that collide with it |
|---|---|---|---|
| 1 | world | ground, walls, props, NPCs | player, wolves, interaction ray |
| 2 | player | player | wolves |
| 3 | enemies | wolves | player, other wolves, sword |

## Known limits

- The wolves run straight at you. They can get stuck on walls because there's no pathfinding
  yet (NavigationRegion3D is the next step when levels get obstacles).
- No blocking, power attacks, or attack animations beyond the sword swing tween.
- The wolves and sword are placeholder boxes until real models arrive (see ASSETS.md).
