class_name PhysicsLayers
extends RefCounted
## Collision layer bits, matching [code]layer_names/3d_physics[/code] in project.godot.

## Solid level geometry.
const WORLD := 1
## Dark panels the gravity gun grips: hit by rays only, nothing collides with them.
const GRIP := 2
## The crate.
const CUBE := 4
## The player.
const PLAYER := 8
## The player's limp body parts after a knockdown.
const RAGDOLL := 16

## What the gravity shot can hit.
const SHOT_MASK := WORLD | GRIP | CUBE
## What blocks the traction beam and a fall.
const SOLID_MASK := WORLD | CUBE
