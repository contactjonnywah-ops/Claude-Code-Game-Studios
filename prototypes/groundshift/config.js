// PROTOTYPE - NOT FOR PRODUCTION
// Question: Does a three-room level built on the gravity gun make a satisfying puzzle from start to exit?
// Date: 2026-11-15
// Every tuning value lives here, each with value, min, max and step. The game reads them live
// through tune.<name> (index.html); the tweak panel, an add-on, writes them back here.
window.CONFIG = {
  seed: 1, // every gameplay random call reads rng(), seeded from this (or ?seed= in the address)
  volume: { value: 0.5, min: 0, max: 1, step: 0.05 },
  gravity: { value: 18, min: 4, max: 40, step: 1 }, // m/s^2 toward the shot surface
  lethal_speed: { value: 19, min: 8, max: 40, step: 1 }, // m/s landing speed that kills (about a 10 m fall)
  move_speed: { value: 6, min: 2, max: 12, step: 0.5 }, // m/s walking
  jump_height: { value: 1.4, min: 0.5, max: 4, step: 0.1 }, // m
  ground_grip: { value: 0.25, min: 0.02, max: 1, step: 0.01 }, // share of the speed gap closed each step on the ground
  air_control: { value: 0.03, min: 0, max: 0.3, step: 0.01 }, // the same, in the air, while a move key is held
  flip_time: { value: 0.45, min: 0, max: 1.5, step: 0.05 }, // s the view takes to roll to the new ground
  look_sens: { value: 0.0022, min: 0.0005, max: 0.006, step: 0.0001 }, // rad per mouse pixel
  key_turn: { value: 2.2, min: 0.5, max: 5, step: 0.1 }, // rad/s looking with the arrow keys
  traction_lock_time: { value: 0.8, min: 0.1, max: 3, step: 0.1 }, // s the beam takes to lock an object in stasis
  traction_hold: { value: 3, min: 1.5, max: 4, step: 0.25 }, // m in front of the eye a locked object floats
  traction_range: { value: 10, min: 3, max: 30, step: 1 }, // m the beam reaches to lock on
  traction_pull: { value: 10, min: 2, max: 30, step: 1 }, // 1/s how hard a locked object follows the beam
  traction_break: { value: 2.5, min: 0.5, max: 6, step: 0.25 }, // m a snagged object may lag behind the beam
  traction_snag_time: { value: 0.5, min: 0.1, max: 2, step: 0.1 }, // s it may lag that far before the lock breaks
  cube_mass: { value: 20, min: 2, max: 200, step: 1 }, // kg; the player is 80
  friction: { value: 0.4, min: 0, max: 1, step: 0.05 }, // objects on surfaces
  bounce: { value: 0.1, min: 0, max: 0.9, step: 0.05 }, // objects on surfaces
  land_dip: { value: 0.35, min: 0, max: 0.5, step: 0.05 }, // m the view dips on the hardest landing you survive
  respawn_time: { value: 1, min: 0.2, max: 3, step: 0.1 }, // s between a deadly landing and the respawn
};
