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

**Pitch:** Trapped in a test facility, you shoot a wall to make it the floor, and everything loose falls with you.

**Genre:** first-person 3D puzzle platformer

**Controls:** WASD move, Space jump, mouse or arrow keys look, click or F fire, R restart room, P pause, M mute.

**Question:** Does a three-room level built on the gravity gun make a satisfying puzzle from start to exit?

**Hooks:** The surface you shoot becomes the ground for you and every loose object; a long fall kills.

**Intent:**

## Look and references
- Look: clean and minimal. Pale flat panels; shootable surfaces clearly darker; cyan gun light and ground marker; orange cube; green glowing exit door and pressure plate. Every figure drawn, no emoji, no plain circles.
- References: Portal (the theme only: a sterile test facility, one room one idea). The gravity gun spike, prototypes/gravity-gun-spike-2026-11-15/ (the look and the feel as played).
- View: 3D · Camera: first-person.

## First minute
You start in a small pale room facing a wall too high to climb. One dark panel sits on the ceiling. You shoot it, fall up, walk across the ceiling past the wall, and shoot a dark floor panel to come back down. The door to room two is open ahead. *(guessed)*

## Challenge
The first real think is room two, about a minute in: the next dark panel is far away and the crosshair warns the fall is deadly, so you must break it into two shorter falls. A death puts you back at the room's start. Room three adds the cube: only gravity can move it onto the plate. *(room contents guessed)*

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
- [x] Room 3: move the cube onto the pressure plate by gravity; the plate opens the exit door
- [x] Checkpoint at each room's start; R restarts the room
- [x] Crosshair shows whether a surface can be shot and whether the fall is deadly
- [x] Results screen at the exit: time and deaths *(guessed)*
- [x] Each switch and its door share a colour *(guessed)*

## Your systems
- gravity gun · in the slice
- physics objects fall to the ground plane · in the slice
- pressure plate opens the door · in the slice

## Keep
-

## Avoid
- Portal's name, portals, characters, art and UI *(guessed)*

## Out of scope
- Hints: change it after play
- A speedrun timer beyond the results line: change it after play
- A story told through the levels: grow it
- More levels: grow it
- Ramps, angled surfaces, tumbling objects: not built

## Build order
1. The three linked rooms with the exit door as the goal and the deadly fall as the way to lose.
2. More rooms and new ideas (hazards, moving parts).

---
**Kill condition:** if room three's cube puzzle is not solvable by reading the room after two tuning rounds. *(guessed)*

**Who it's for / what they feel:** solo puzzle fans; the eureka of seeing the room turn the right way up. *(guessed)*

**Games you love / don't:** Portal (the theme).
