// Codex text, keyed by enemy id (sim/content/enemies.ts): what the enemy does,
// a few trait chips and a tip for dealing with it. Keep these in sync with the
// behaviours in sim/systems/enemies.ts and sim/systems/bosses/.

export interface CodexEntry {
  text: string;
  traits: string[];
  tip: string;
}

export const CODEX_ENTRIES: Record<string, CodexEntry> = {
  bat: {
    text: 'Fast and fragile. Arrives in flocks, zig-zags toward you and flies over obstacles.',
    traits: ['Flying', 'Flock'],
    tip: 'Area weapons and orbiting attacks clear a flock in one pass.',
  },
  zombie: {
    text: 'A slow, sturdy walker that simply shambles toward you.',
    traits: ['Sturdy'],
    tip: 'Easy to outpace. Just never let a crowd of them box you in.',
  },
  swarm: {
    text: 'Tiny and weak on its own, but comes in packs of 7-11 to surround you.',
    traits: ['Pack'],
    tip: 'Keep moving so the pack trails behind you, then sweep it with area damage.',
  },
  archer: {
    text: 'Keeps its distance and shoots an arrow every few seconds.',
    traits: ['Ranged'],
    tip: 'Arrows fly straight: strafe sideways, or dash in to close the gap.',
  },
  slime: {
    text: 'A bulky blob that splits into two Slimelets when it dies.',
    traits: ['Splits'],
    tip: 'Pop it away from other crowds so the Slimelets don\'t pile up.',
  },
  charger: {
    text: 'When you get close it stops, shakes for a moment, then dashes in a straight line at high speed.',
    traits: ['Charge'],
    tip: 'The shake is your warning. Step sideways out of its line.',
  },
  exploder: {
    text: 'Runs at you, lights its fuse when close and blows up shortly after, hurting everything nearby.',
    traits: ['Explodes'],
    tip: 'Kill it at range, or dash away the moment the fuse lights.',
  },
  ghost: {
    text: 'Floats through walls. Every few seconds it fades out: while faded it cannot be hit or hurt you, and moves faster.',
    traits: ['Flying', 'Phasing'],
    tip: 'Save your burst for when it turns solid again.',
  },
  shaman: {
    text: 'Hangs back and pulses a healing aura every 3.5 s, restoring 15% HP to nearby enemies (bosses only 1%).',
    traits: ['Healer', 'Keeps distance'],
    tip: 'Make it your first target: it undoes your damage on everything around it.',
  },
  slimelet: {
    text: 'A small, quick slime. Pops out of dying Slimes and off the Slime King as it takes damage.',
    traits: ['Fast'],
    tip: 'Weak alone. Any area attack mops them up.',
  },
  egg: {
    text: 'Laid by the Brood Mother. Never moves or attacks, but hatches into 5 Swarmlings after 5 s.',
    traits: ['Stationary', 'Hatches'],
    tip: 'Break eggs within 5 seconds or face a fresh swarm.',
  },
  skeleton: {
    text: 'Raised by the Necro Lord in a ring around it. A plain chaser, but they keep coming.',
    traits: ['Summoned'],
    tip: 'Thin them out, but focus the Necro Lord: it raises more every 7 s.',
  },
  slimeking: {
    text: 'Leaps onto you: a warning circle marks the landing spot and it cannot be hit while airborne. Each landing sends out a shockwave ring (two when enraged). Every 7% of HP it loses splits off two Slimelets.',
    traits: ['Leap', 'Shockwave', 'Splits'],
    tip: 'Leave the warning circle before it lands, then jump the ring as it passes.',
  },
  necrolord: {
    text: 'Keeps its distance and circles you, firing rings of skulls. Summons skeletons every 7 s (4, or 6 when enraged). Enraged, it also fires aimed triple skull volleys.',
    traits: ['Ranged', 'Summoner'],
    tip: 'Skull rings have gaps. Slip through them while you close in.',
  },
  broodmother: {
    text: 'Skitters toward you in bursts, spits fans of webs and lays egg sacs that hatch into swarms. Enraged, it pounces after a short windup and lands with a shockwave.',
    traits: ['Summoner', 'Webs', 'Pounce'],
    tip: 'Smash the egg sacs early and sidestep the web fan.',
  },
  golem: {
    text: 'Slow but hits hard. Telegraphs a straight charge and a ground slam that bursts into a shockwave ring. Enraged, it moves faster and attacks more often.',
    traits: ['Charge', 'Slam', 'Shockwave'],
    tip: 'Back out of the slam circle, and step aside when it lines up a charge.',
  },
  wyrm: {
    text: 'A serpent that weaves around you; its whole body hurts on contact. Breathes cones of ice shards and dives at you, ending in a frost nova. Enraged, icicles rain down around you.',
    traits: ['Serpent', 'Ranged', 'Dive'],
    tip: 'Never get pinned against its body. Dash across the tail, not the head.',
  },
  voideye: {
    text: 'Drifts around you spraying spiral bullet streams, then sweeps the arena with a laser (two when enraged) and bursts into a ring of void orbs.',
    traits: ['Bullet hell', 'Laser'],
    tip: 'Move with the laser\'s sweep, not against it, and weave between the spirals.',
  },
  // Secret boss (Secrets chapter)
  goldfang: {
    text: 'A greedy goblin merchant who rarely replaces a boss. He never attacks, keeps just out of reach and escapes with his treasure after 25 seconds. Every third coin he drops is a fake that explodes. Catch him and his sack holds a unique weapon or perk.',
    traits: ['Secret', 'Fleeing', 'Unique loot'],
    tip: 'Chase him with ranged weapons and dashes. Coins that do not fly to you are fakes.',
  },
};
