// Codex text: what every enemy does, keyed by enemy id (sim/content/enemies.ts).
// Keep these in sync with the behaviours in sim/systems/enemies.ts and sim/systems/bosses/.

export const CODEX_ENTRIES: Record<string, string> = {
  bat: 'Fast and fragile. Arrives in flocks, zig-zags toward you and flies over obstacles.',
  zombie: 'A slow, sturdy walker that simply shambles toward you.',
  swarm: 'Tiny and weak on its own, but comes in packs of 7-11 to surround you.',
  archer: 'Keeps its distance and shoots an arrow every few seconds. Close in or outrange it.',
  slime: 'A bulky blob that splits into two Slimelets when it dies.',
  charger: 'When you get close it stops, shakes for a moment, then dashes in a straight line at high speed. Sidestep the charge.',
  exploder: 'Runs at you, lights its fuse when close and blows up shortly after, hurting everything nearby. Back off or dash away.',
  ghost: 'Floats through walls. Every few seconds it fades out: while faded it cannot be hit or hurt you, and moves faster.',
  shaman: 'Hangs back and pulses a healing aura every 3.5 s, restoring 15% HP to nearby enemies (bosses only 1%). Kill it first.',
  slimelet: 'A small, quick slime. Pops out of dying Slimes and off the Slime King as it takes damage.',
  egg: 'Laid by the Brood Mother. Never moves or attacks, but hatches into 5 Swarmlings after 5 s unless you destroy it.',
  skeleton: 'Raised by the Necro Lord in a ring around it. A plain chaser, but they keep coming.',
  slimeking: 'Leaps onto you: a warning circle marks the landing spot and it cannot be hit while airborne. Each landing sends out a shockwave ring (two when enraged). Every 7% of HP it loses splits off two Slimelets.',
  necrolord: 'Keeps its distance and circles you, firing rings of skulls. Summons skeletons every 7 s (4, or 6 when enraged). Enraged, it also fires aimed triple skull volleys.',
  broodmother: 'Skitters toward you in bursts, spits fans of webs and lays egg sacs that hatch into swarms. Enraged, it pounces after a short windup and lands with a shockwave.',
  golem: 'Slow but hits hard. Telegraphs a straight charge and a ground slam that bursts into a shockwave ring. Enraged, it moves faster and attacks more often.',
  wyrm: 'A serpent that weaves around you; its whole body hurts on contact. Breathes cones of ice shards and dives at you, ending in a frost nova. Enraged, icicles rain down around you.',
  voideye: 'Drifts around you spraying spiral bullet streams, then sweeps the arena with a laser (two when enraged) and bursts into a ring of void orbs.',
};
