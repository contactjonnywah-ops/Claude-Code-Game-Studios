// PROTOTYPE - NOT FOR PRODUCTION
// Question: is reshaping the ground under the rival camp more fun than fighting it?
// Date: 2026-11-14
// Every tuning value lives here, each with value, min, max and step. The game reads them live
// through tune.<name> (index.html); the tweak panel, an add-on, writes them back here.
// Distances are in world units on a moon of radius 10; times in seconds.
window.CONFIG = {
  seed: 1, // every gameplay random call reads rng(), seeded from this (or ?seed= in the address)
  volume: { value: 0.5, min: 0, max: 1, step: 0.05 },

  // --- Moon and ground ---
  deepWater: { value: -0.3, min: -1, max: 0, step: 0.05 },     // below this height: impassable sea
  cliff: { value: 1.7, min: 1, max: 3, step: 0.05 },           // above this height: impassable wall
  wadeSpeed: { value: 0.45, min: 0.1, max: 1, step: 0.05 },    // speed multiplier in shallow water

  // --- Your tribe ---
  startFollowers: { value: 6, min: 1, max: 20, step: 1 },
  followerSpeed: { value: 1.1, min: 0.3, max: 3, step: 0.05 }, // units per second
  followerHp: { value: 3, min: 1, max: 10, step: 1 },
  followerDmg: { value: 1, min: 0.2, max: 5, step: 0.1 },      // per hit
  popBase: { value: 6, min: 1, max: 30, step: 1 },             // followers allowed with no huts
  popPerHut: { value: 3, min: 1, max: 10, step: 1 },
  hutSpawn: { value: 18, min: 3, max: 60, step: 1 },           // seconds between new followers per hut
  hutCost: { value: 4, min: 1, max: 20, step: 1 },             // wood
  hutWork: { value: 8, min: 1, max: 40, step: 1 },             // builder-seconds to finish a hut
  hutHp: { value: 8, min: 1, max: 30, step: 1 },
  chopTime: { value: 2, min: 0.3, max: 8, step: 0.1 },
  treeWood: { value: 4, min: 1, max: 20, step: 1 },
  startWood: { value: 4, min: 0, max: 50, step: 1 },

  // --- Totems ---
  totemQuota: { value: 4, min: 1, max: 20, step: 1 },          // followers each totem claims
  totemMax: { value: 5, min: 1, max: 12, step: 1 },            // planting past this pulls the oldest
  gatherRadius: { value: 4, min: 1, max: 10, step: 0.5 },      // trees this close to a Gather totem
  warAggro: { value: 2.5, min: 0.5, max: 6, step: 0.1 },       // War-totem followers attack this close
  defendRange: { value: 1.2, min: 0, max: 4, step: 0.1 },      // any follower fights back this close

  // --- Mana ---
  startMana: { value: 30, min: 0, max: 100, step: 1 },
  manaMax: { value: 100, min: 20, max: 300, step: 5 },
  manaWork: { value: 0.3, min: 0, max: 2, step: 0.05 },        // per working follower per second
  manaIdle: { value: 0.15, min: 0, max: 2, step: 0.05 },       // per resting follower per second
  manaHut: { value: 0.1, min: 0, max: 2, step: 0.05 },         // per hut per second

  // --- Shaman ---
  shamanSpeed: { value: 1.3, min: 0.3, max: 4, step: 0.05 },
  shamanHp: { value: 4, min: 1, max: 20, step: 1 },
  shamanRespawn: { value: 10, min: 1, max: 60, step: 1 },

  // --- Spells ---
  emberCost: { value: 10, min: 0, max: 100, step: 1 },
  emberRange: { value: 5, min: 1, max: 12, step: 0.5 },
  emberRadius: { value: 0.9, min: 0.2, max: 3, step: 0.1 },
  emberDmg: { value: 3, min: 1, max: 10, step: 0.5 },          // units; huts take a third
  emberFlight: { value: 0.8, min: 0.2, max: 3, step: 0.1 },
  raiseCost: { value: 25, min: 0, max: 100, step: 1 },
  raiseRange: { value: 5, min: 1, max: 12, step: 0.5 },
  raiseRadius: { value: 1.3, min: 0.4, max: 3, step: 0.1 },
  raiseHeight: { value: 0.9, min: 0.1, max: 3, step: 0.05 },
  fissureCost: { value: 50, min: 0, max: 150, step: 1 },
  fissureRange: { value: 3.2, min: 1, max: 10, step: 0.1 },
  fissureRadius: { value: 1.5, min: 0.5, max: 4, step: 0.1 },
  fissureDepth: { value: 2.4, min: 0.5, max: 5, step: 0.1 },
  fissureCool: { value: 30, min: 3, max: 120, step: 1 },       // seconds to cool shut

  // --- Rival tribe ---
  rivalHuts: { value: 5, min: 1, max: 10, step: 1 },
  rivalHutHp: { value: 6, min: 1, max: 30, step: 1 },
  startGuards: { value: 5, min: 0, max: 20, step: 1 },
  guardSpawn: { value: 30, min: 5, max: 120, step: 1 },        // seconds per rival hut
  guardCap: { value: 8, min: 0, max: 30, step: 1 },
  guardAggro: { value: 2.6, min: 0.5, max: 6, step: 0.1 },
  guardLeash: { value: 4, min: 1, max: 10, step: 0.5 },
  warriorSpeed: { value: 1.0, min: 0.3, max: 3, step: 0.05 },
  warriorHp: { value: 4, min: 1, max: 15, step: 1 },
  warriorDmg: { value: 1.2, min: 0.2, max: 5, step: 0.1 },
  hitEvery: { value: 1, min: 0.2, max: 3, step: 0.05 },        // seconds between melee hits
  meleeRange: { value: 0.45, min: 0.1, max: 1.5, step: 0.05 },

  // --- Raids ---
  raidFirst: { value: 180, min: 20, max: 600, step: 5 },       // seconds until the first raid
  raidEvery: { value: 80, min: 20, max: 300, step: 5 },
  raidWarn: { value: 15, min: 3, max: 60, step: 1 },
  raidBase: { value: 3, min: 1, max: 20, step: 1 },
  raidGrow: { value: 2, min: 0, max: 10, step: 1 },            // more raiders each raid
};
