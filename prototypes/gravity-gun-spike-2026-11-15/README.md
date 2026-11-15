# Gravity Gun Spike

PROTOTYPE - NOT FOR PRODUCTION

- **Question:** Does shooting a surface to make it the ground feel good for the player and physics objects?
- **Run:** open `index.html` in a browser (works offline, from a double-click).
- **Controls:** WASD move, Space jump, mouse or arrow keys look, click or F fire, R reset room, P pause, M mute.
- **Status:** concluded 2026-11-15.
- **Findings:** YES, the mechanic works: "Physics and mechanics are sound for a prototype." See `SPIKE-NOTE.md`.
- **One-file copy:** `gravity-gun-single.html`, for viewers that load no sibling files.

Tuning values are in `config.js`. Shortcuts taken: every surface is axis-aligned, crates and the
player are boxes that never rotate, no shadows.
