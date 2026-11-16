# Game Brief: [Working Title]

## In your words

> The theme - horror, story, survival
>
> The story - you're a scientist that has woken up in a biological testing facility on a tropical island. Something terrible has happend, all of your colleagues are dead, you're the only survivor. The subjects your team were testing were living creatures made with ancient fossilised DNA - dinosaurs. After a catastrophic system failure, the test subjects broke loose and killed everyone.
>
> Your objective - discovery what went wrong by reading notes from dead colleagues or listening to recordings. Document evidence ofmehat happened with a camera, including the creatures, then find a way off the island.
>
> The dangers - the creatures roaming the island are volatile and dangerous. You have no ways or means of fighting them. You must run, hide, and do everything you can to stay alive.

> No multiplayer.
> No crafting.
> No skill trees.
> Many creature types.
> Open world with blocked areas that require puzzle solving or collecting to enter.
> Voice acting will be done.

> Your flashlight - it's a crank-wound rechargeable flashlight that uses a dynamo to charge. It's slow to charge and noisy.

> Saving the game requires you to reach a checkpoint at a safe location. These are small facility outposts dotted around the map.
>
> In order to access an outpost, you need to solve a puzzle or collect something to open the door.
>
> When you are caught, you must reload at an outpost and lose any progress you made after the save.

> Let's make a playable demo with a small facility escape and into a small open world.
>
> Create two creatures - use basic shapes that you can draw.
>
> Creature 1 - the howler - it's blind and navigates with echolocation. It will move toward sounds aggressively.
>
> Creature 2 - the skulker - it hides in dark places and waits. It moves very fast. If it senses the player close, it will dive and snatch. If light is cast on it while it's hiding, it will dash to another dark point.
>
> The player's journey - the player wakes up, disoriented in the destroyed facility. They can find a note nearby and a torch. They also find the camera near the exit of the facility.
>
> The player encounters the howler inside the facility and the skulker outside of the facility.

After play: The player gets caught right at the beginning all the time. Seemingly through the wall as well.

After play: It's very difficult. I get caught every time, even when standing still.

After play: The demo is pretty fun and tense to play. However you need a croch button to sneak. The howler runs straight to you if any sort of movement or sound is made. There should be a trigger radius around the howler for it to run straight to the source of the sound.

**Pitch:** You are the last scientist alive on an island of escaped dinosaurs, armed only with a torch and a camera, and the proof you need is standing next to the thing that will kill you.

**Genre:** First-person stealth survival horror, no combat.

**Controls:** Move, look, crouch, sprint, torch on/off, wind the torch, raise camera and shoot, interact. Keyboard and mouse, or touch stick and buttons.

**Question:** Is it tense and fun to creep close enough to a creature to photograph it, with no way to fight back?

**Hooks:** The camera is your only tool and your objective: a clear shot means being close, lit and exposed. Your torch is hand-cranked: light costs you time and noise, and the creatures hear it.

**Intent:** staged failure: caught means reload at the last outpost, progress since the save is lost *(you said)* · open world with gated areas *(you said)*

## Look and references

- Look: bit-crushed low-res 3D with modern light. Night jungle, volumetric fog, moon shafts, one hand-cranked torch. Facility interiors under red emergency lighting. Creatures are mostly silhouette and eyes at fog's edge. (From the visual prototype.)
- References: none named yet.
- View: 3D · Camera: first person.

## First minute

You wake on a lab floor under emergency lighting. A dead colleague lies nearby with a note and a torch; you take both. The corridor beyond is dark, and something blind and heavy clicks its way along it. You find the camera by the exit, and the first photo you take is logged as evidence. Then the thing in the corridor turns toward the shutter.

## Challenge

The first creature encounter comes within three to five minutes. Sound and light both carry a cost: sprinting, cranking the torch, its beam and the camera flash. Being caught sends you back to your last outpost save, and the notes, photos and progress gathered since are gone. Each creature type hunts differently, so one hiding habit does not work on all of them: the howler is blind and hunts sound, the skulker waits in the dark and flees light.

## Core loop

- Roam the island for notes, recordings and evidence.
- Manage light: crank the torch where it is safe to be loud, go dark where it is not.
- Avoid or outwait the creatures in each area: listen, hide, break line of sight.
- Photograph what matters, at a risk you choose.
- Reach an outpost, solve its puzzle or bring what its door needs, and save inside.

## Goal & fail state

- Win: collect enough evidence to know what happened, then reach the way off the island alive.
- Fail: a creature catches you. You reload at the last outpost you saved in and lose everything since.

## Features

- [x] First-person movement with crouch, sprint and noise
- [x] Crank-wound dynamo torch: slow to charge, noisy to wind, drains in use
- [x] Camera: frame, shoot, and a judged evidence log
- [x] Creatures that hunt differently, in several types (howler and skulker built)
- [ ] Hiding spots and line-of-sight breaking
- [ ] Notes and voiced recordings that tell the story (one written note built)
- [ ] Outposts: small safe facility buildings, each opened by a puzzle or a collected item, where you save (thin stand-in)

## Your systems

- reading notes and listening to voiced recordings · in the slice
- camera evidence · in the slice
- run and hide from creatures · in the slice
- crank-wound dynamo torch · in the slice
- many creature types · in the slice
- outposts as save points, opened by puzzle or collecting · thin stand-in
- finding a way off the island · later

## Keep

- "The demo is pretty fun and tense to play." *(you said)*

## Avoid

- No weapons, no way to fight or kill a creature.
- No multiplayer.
- No crafting.
- No skill trees.

## Out of scope

- More than two creature types in the first build
- More than one outpost in the first build
- The way off the island (step 5)

## Build order

1. One creature stalking you, with hide, sprint, the crank torch and a caught state. Prove the fear first. *(built: the howler)*
2. Camera and evidence log, with creatures reacting to the flash. *(built)*
3. Notes and voiced recordings, plus one outpost with one door puzzle and a working save. *(one note and a keycard door built; no save, no voice)*
4. Second creature type that hunts differently. *(built: the skulker)*
5. Open the island out, add the exit as the goal.

---

**Kill condition:** if being stalked by one creature is not tense after two tuning rounds, the stealth design needs rethinking before anything else is built.

**Who it's for / what they feel:** solo horror players who want dread and helplessness, not power.

**Games you love / don't:** not given.

<!--
Decisions confirmed in conversation (2026-11-16):
- An opened outpost stays open. Creatures cannot enter an outpost. The lab you wake in is the first outpost and first save.
- You cannot crank while sprinting. A full wind gives about a minute of light.
- Collected key items are a simple list of what you hold, not an inventory to manage.
- The howler catches only a player it heard a moment ago; silent and still is safe.
- The howler has a trigger radius: close sounds make it charge, distant ones make it curious.
Playable demo: prototypes/ps1-jungle/index.html
-->
