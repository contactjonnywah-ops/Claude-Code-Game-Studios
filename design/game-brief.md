# Game Brief: Groundshift

## In your words
I want to build a 3D game. This is a 3D puzzle platformer. Think the theme of Portal.

This game is about the player trapped in a futuristic facility. This must use their gravity gun to alter the gravitational pull of the environment in order to traverse the facility.

How the gravity gun works:

When the player shoots a surface, that new surface becomes "the ground plain". The player will gravitate to that plain orientation. If the player shoots a distant surface, they will fall toward it and potentially die.

Any objects or assets that have physics will also fall toward the ground plain.

Make a demo room to test the physics and mechanics.

After play: Physics and mechanics are sound for a prototype.

make a brief and a demo level with a goal to reach

1. Goal: The goal is to reach the exit door. A puzzle is to move a cube to a pressure plate to open the door.
2. Feel: calm and thoughtful
3. How hard: three linked rooms, each teaching one idea
4. Gun limits: specific surfaces can be only shot. These surfaces should be darker than the others for testing purposes.
5. Look: Keep the look clean and minimal for testing purposes.

After play: There was an issue with the cube - it got stuck in the doorway and I couldn't complete the puzzle.

After play: 1. in a sense - but with flavour. This uses a different setting on the gun (gravitational traction) It slowly locks the target in a ball of stasis and allows you to manipulate its direction. This works by locking a beam onto the object, and the object stays attached to the beam while in use.
2. The camera should be free while flipping as it increases the disorientation. Have the player orient themselves.
3. landing feedback
4. real physics

After play: My machine is too low spec to test this prototype. Provide me access to your virtual machine so I can test.

**Pitch:** Trapped in a test facility, you shoot a wall to make it the floor, and everything loose falls with you.

**Genre:** first-person 3D puzzle platformer

**Controls:** WASD move, Space jump, mouse or arrow keys look, Q switch the gun's setting, click or F fire (GRAVITY) or hold to lock and carry (TRACTION), R restart room, P pause, M mute, L low-spec mode.

**Question:** Does a three-room level built on the gravity gun make a satisfying puzzle from start to exit?

**Hooks:** The surface you shoot becomes the ground for you and every loose object; a long fall kills. The gun's second setting, gravitational traction, locks an object in a ball of stasis and carries it on the beam.

**Intent:**

## Look and references
- Look: clean and minimal. Pale flat panels; shootable surfaces clearly darker; cyan gun light and ground marker; orange cube; green glowing exit door and pressure plate; violet for the traction beam and its ball of stasis. Every figure drawn, no emoji, no plain circles.
- References: Portal (the theme only: a sterile test facility, one room one idea). The gravity gun spike, prototypes/gravity-gun-spike-2026-11-15/ (the look and the feel as played).
- View: 3D · Camera: first-person.

## First minute
You start in a small pale room facing a wall too high to climb. One dark panel sits on the ceiling. You shoot it, fall up, walk across the ceiling past the wall, and shoot a dark floor panel to come back down. The door to room two is open ahead. *(guessed)*

## Challenge
The first real think is room two, about a minute in: the next dark panel is far away and the crosshair warns the fall is deadly, so you must break it into two shorter falls. A death puts you back at the room's start. Room three adds the cube: the plate sits at the bottom of a glass tube too tall for the beam, so the cube is carried to the mark on the ceiling and dropped in by gravity. *(room contents guessed)*

## Core loop
- Read the room: find the dark panels and the way out.
- Shoot a panel; you and loose objects fall to it.
- A wrong or long shot kills or strands you: restart the room at once and try another order.
- The door opens; walk to the next room.

## Goal & fail state
- Win: put the cube on the pressure plate in room three and walk through the exit door.
- Fail: a landing that is too fast kills; you restart at the current room. R restarts the room any time.

## Features
- [x] Gravity gun that grabs only dark panels
- [x] Room 1: flip to cross a wall (safe)
- [x] Room 2: a deadly long fall broken into two safe ones
- [x] Room 3: carry the cube with the traction beam, drop it onto the pressure plate by gravity; the plate opens the exit door
- [x] Checkpoint at each room's start; R restarts the room
- [x] Crosshair shows whether a surface can be shot and whether the fall is deadly
- [x] Results screen at the exit: time and deaths *(guessed)*
- [x] Each switch and its door share a colour *(guessed)*
- [x] Gravitational traction: a second gun setting that slowly locks an object in a ball of stasis and carries it on the beam
- [x] Landing feedback scaled to how hard you land
- [x] Real physics: the cube tumbles, a ramp, gravity can point along any surface
- [x] Low-spec mode (L): half resolution and flat light

## Your systems
- gravity gun · in the slice
- physics objects fall to the ground plane · in the slice
- pressure plate opens the door · in the slice
- gravitational traction · in the slice
- real physics · in the slice

## Keep
-

## Avoid
- Portal's name, portals, characters, art and UI *(guessed)*
- No camera that levels or orients itself for the player during a flip: "Have the player orient themselves."

## Out of scope
- Hints: change it after play
- A speedrun timer beyond the results line: change it after play
- A story told through the levels: grow it
- More levels: grow it

## Build order
1. The three linked rooms with the exit door as the goal and the deadly fall as the way to lose.
2. More rooms and new ideas (hazards, moving parts).

---
**Kill condition:** if room three's cube puzzle is not solvable by reading the room after two tuning rounds. *(guessed)*

**Who it's for / what they feel:** solo puzzle fans; the eureka of seeing the room turn the right way up. *(guessed)*

**Games you love / don't:** Portal (the theme).
