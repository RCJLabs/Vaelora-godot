# NPC daily routines

Townsfolk keep a day by the clock instead of standing in one place forever. It's
a small system on `interactables/npc.gd`. Nobody gets a schedule unless you
turn it on.

## The day

| Hours (defaults) | Phase | Where they are |
|---|---|---|
| Wake Hour (7:00) to Gather Hour (18:00) | DAY | At the spot where they were placed, wandering up to Wander metres and pausing 6–14 s between walks |
| Gather Hour to Sleep Hour (21:30) | GATHER | Near the level's `Gathering` marker, each at their own place on a 2.5 m ring around it |
| Sleep Hour to Wake Hour | HOME | They walk to their own door and go in. In the morning they come out of it and walk back to their spot |

- **No Gathering marker in the level:** they stay at their spot until bedtime.
- **No door:** they stay out all night at their spot.

## Setting it up

On an NPC, the **Routine** group in the Inspector has these settings:

- `routine`: on or off.
- `wake_hour`, `gather_hour`, `sleep_hour`.
- `wander`: metres. 0 means they stand still by day.

The level needs two things:

- **A `Gathering` node.** Any Node3D named that. The builders place a Marker3D with `gathering(pos)`.
- **Doors in the `home_door` group.** The builder's `house()` adds its Door to this group, so every generated house is a home.

When an NPC is set up, it claims the nearest unclaimed door within 60 m of its
spot and records that on the door as meta `home_of`. So five people with
routines get five different houses, and the people placed nearest a house get
it first. The order they claim in is the scene tree order.

Builders turn routines on by name after placing the people:

```gdscript
gathering(Vector3(-14, 0, -11))   # in front of the Lantern Weir
routines(["Wenna", "Ama", "Teodor", "Fenn", "JoryDocks"])
```

## Who has one

| Level | Routine | Stays put (and why) |
|---|---|---|
| Weirholt | Wenna, Ama, Teodor, Fenn, Jory (docks) | Hedda keeps the inn; Captain Varga and Sergeant Dace (the watch); Factor Tarle at the counting house |
| Grieving Fields | Hesk, Corin, Marta, Bram | Listener Ysolde, at the Listening Stone |
| Ilunhall | Bruna, Karra (lives on the quay) | Odo keeps the Long Table open; Cassia, Severin, Magister Rufa, Nob and Saelie (each where a quest sends you) |
| The Vale | nobody yet | Hand-placed scene with no `house()` doors |

The rule of thumb is that innkeepers, guards, trainers and anyone a quest says
is "at X" keep no routine. A quest that sends you to someone shouldn't depend
on the time of day until the quest text says so.

## Rules it keeps

- **The clock jumps, they jump.** If the hour moves more than half an hour in one tick (sleeping, waiting, fast travel, loading a save), they're placed straight at the end of their walk, inside if it's night. They also start where the clock says when a level loads.
- **No walking off mid-sentence.** While any dialogue is open, nobody with a routine moves.
- **They walk on the navmesh** (`NavigationServer3D.map_get_path`). They go in a straight line if there's no path. Walking speed is 1.3 m/s, with a small step bob on the figure.
- **Indoors means gone.** Going in hides them and clears their collision layer. Coming out restores both and puts them on their doorstep.

## Limits

- **There are no interiors.** "Home" is a door they vanish through, so at night you can't find them, talk to them or trade with them. A merchant with a routine (Wenna) can't be traded with after 21:30. That's intended, but players may read it as a bug, so a "they've gone home for the night" line may be wanted.
- **Positions aren't saved.** They're worked out from the clock on load. Someone you saw mid-walk will be at the end of that walk after a load.
- **NPCs are StaticBody3D moved by code.** They don't push or get pushed, and they don't avoid each other or the player. Two people walking the same way can overlap. Promoting them to CharacterBody3D with avoidance is the fix if that becomes noticeable.
- **One gathering place per level** and one schedule shape. There's no market day, no weather, and no work spots away from their placed spot.
- **Story NPCs aren't scheduled.** Anyone can be given a routine, but nothing checks whether a quest expects them at a fixed spot. Check before turning it on for someone a quest points at.

Tests: `tests/test_routines.gd`.
