# Safari System

Back to [[00 - Project Dashboard]] · Related: [[03 - Animal System]]

## Riding controls (confirmed)
- Animal auto-runs forward; speed builds gradually during a run.
- **Free horizontal steering** on one wide track ([[11 - Decisions#D-007 Free horizontal steering (replaces lanes)]]).
- **Separate jump and leap** ([[11 - Decisions#D-020 Separate jump and leap controls (supersedes D-008)]]): Space / A / JUMP button = jump only; F / X / LEAP button = leap onto the glowing animal only.
- Keyboard (A/D or ←/→ steer) · touch (drag to steer + JUMP/LEAP buttons) · gamepad (stick, A, X).
- First-time leap lesson with slow motion: [[11 - Decisions#D-021 First-time slow-motion leap lesson]].
- Arcade movement, not physics simulation.
- Feel: speed shown by camera pull-back/FOV, near-track detail rushing past, dust at hooves, gait tied to distance travelled.

## Animal switching (design — next major priority)
- **Herd:** other animals run alongside, spawned on seeded schedules; further in = new species.
- **Targeting:** best animal ahead within reach is auto-selected, biased toward the steering direction; it always shows a marker so the landing spot is known before pressing.
- **Leap:** ~0.45 s arc that homes on the moving target — once committed, the landing always succeeds. Camera lifts/pulls back; early leaps get slight slow-motion; landing gives dust + small speed boost.
- **Temper:** per animal. Switching resets to a calm mount. Bucked off → brief slow-motion window to leap to a nearby animal before the run ends.
- Requires client-owned riding (Milestone 2) for instant response.

## Sunny Savannah (first biome)
Bright blue sky · warm sun · green & golden grass · stylized acacias · flowers · chunky rocks · small ponds · gentle terrain · distant hills · cute blocky animals.
**Start with one short, hand-designed course.** No procedural world.

## Obstacles (starter)
Rocks · fallen logs · small bushes · breakable wooden barriers (Elephant) · simple gaps where appropriate.
Clear silhouettes and collision boundaries. Decorations must never obstruct movement.

## Multiplayer note
Solo reliability first. Each player likely needs their own course instance or offset lane — decide in Phase 1/2. See [[09 - Technical Architecture]].
