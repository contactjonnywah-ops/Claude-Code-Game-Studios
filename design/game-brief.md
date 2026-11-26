# Game Brief: Groundshift

## In your words
"I want you to completely rebuild this game within Godot, with realistic gravity physics and sounds."
(The game is the Groundshift browser prototype, `groundshift-single_3.html`, dated 2026-11-15: three.js + cannon-es.)

**Pitch:** A first-person puzzle where your gun picks which wall is the floor, and real gravity decides whether the fall kills you.

**Genre:** First-person physics puzzle.

**Controls:** WASD move · Space jump · mouse or arrows look · click or F fire · Q switch GRAVITY/TRACTION · R restart room · P/Esc pause · M mute · L low-spec.

**Question:** Does the three-room gravity-gun level still solve, and feel weightier, under real-world gravity and air drag?

**Hooks:** Shooting a dark panel makes it the ground for you *and* the crate; the crosshair predicts the fall and whether it is lethal.

## Look and references
- Look: clean test-lab rooms: pale tiled panels, dark grippable panels, a braced orange-on-steel crate, green for the plate and exit, cyan gravity, violet traction. *(kept from the prototype)*
- View: 3D · Camera: first person; the horizon rolls to the new ground over 0.6 s.

## Core loop
- Read the room → shoot a panel to choose the ground → fall, walk, carry the crate → reach the exit.

## Goal & fail state
- Reach the green exit door in room 3. A landing faster than 17 m/s (a ~15.5 m fall) kills; you restart at the room's start.

## Features
- [x] Three rooms (wall to cross, 22 m shaft, crate-into-tube plate puzzle), data-driven from `assets/data/level_rooms.json`
- [x] GRAVITY mode: world gravity turns toward the shot panel; crate and player both fall that way
- [x] TRACTION mode: lock the crate in stasis, carry it weightless, release with momentum
- [x] Realistic physics: g = 9.81 m/s², quadratic air drag (terminal ≈ 48 m/s player, ≈ 17 m/s crate), Jolt rigid-body crate (20 kg) with friction and restitution, player pushes it with momentum and loads it with body weight
- [x] Fall preview: distance and impact speed (drag-corrected), red when lethal
- [x] Synthesised sound: footsteps, landings scaled by impact, bone-crunch death, modal crate impacts, crate scrape, wind rising with fall speed, gravity-shift rumble, gun zap/whump, beam hum, door motor, plate clunk, room tone, all through a room reverb

## Out of scope
- New rooms, story, gamepad aim, localisation (HUD strings are inline; see Avoid)

## Build order
1. Tuning + level data → 2. GravityMath/ViewFrame (tested) → 3. Level, crate, door → 4. Player and gun → 5. Synth audio → 6. HUD and states → 7. Scripted playthrough

## Keep
- Every room's solution from the prototype; the panel layout is unchanged.

## Avoid
- Hardcoded tuning (all in `game_tuning.json`). Known gap: HUD text is not routed through a localisation table.

## Data schemas
- `assets/data/game_tuning.json`: `{ "<key>": { "value": number, "why": "rationale and units" } }`. Every key is read by `Tuning.num()`.
- `assets/data/level_rooms.json`: boxes are `[x0, x1, y0, y1, z0, z1]` metres with an optional 7th value (turn about z, radians). `panels` entries are `{ "box": [...], "center"?: [x, y, z] }`. `rooms` entries are `{ "name", "start": [x, y, z], "from_z" }` (you enter a room once `z > from_z`). Also `end_glow`, `door`, `plate_zone`, `plate_pad`, `plate_mark`, `cube_start`, `win_z`, `lights`, `title_camera`.

---
**Kill condition:** If the shaft can't be climbed without dying at 9.81 m/s², raise `lethal_speed`, not gravity.

**Who it's for / what they feel:** Puzzle players who want a fall to feel like a fall.
