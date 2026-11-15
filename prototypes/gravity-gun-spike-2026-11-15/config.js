// PROTOTYPE - NOT FOR PRODUCTION
// Question: Does shooting a surface to make it the ground feel good for the player and physics objects?
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
  crate_drag: { value: 0.85, min: 0.5, max: 1, step: 0.01 }, // share of a crate's sideways speed kept each step
  respawn_time: { value: 1, min: 0.2, max: 3, step: 0.1 }, // s between a deadly landing and the respawn
};
