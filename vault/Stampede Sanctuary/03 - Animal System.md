# Animal System

Back to [[00 - Project Dashboard]] · Related: [[04 - Safari System]], [[05 - Sanctuary System]], [[07 - Art Direction]]

## Starter animals (design directions — values not final)
| Animal | Role | Speed | Handling | Tolerance | Special |
|---|---|---|---|---|---|
| **Zebra** | Fast starter, teaches riding | Fast | Responsive | Average | — |
| **Elephant** | Obstacle breaker | Slow | Heavy | TBD | Breaks designated light obstacles, strong impact feedback |
| **Giraffe** | Tall explorer | Moderate | Distinct gait | TBD | Reveals distant collectibles / special animal opportunities |

**Rule:** all speed, timing, and tolerance values live in a config module, never hardcoded in unrelated scripts.

## Temper (riding tolerance)
- Each animal has a temper meter that fills while ridden.
- Harder to ride as it rises → encourages switching before losing control.
- Must always be visually warned before failure. Forgiving in the first biome.
- Readable and accessible (not color-only).

## Discovery & befriending
- Animals are discovered through gameplay, not bought.
- **Taming ring:** while riding a wild animal a ring fills; fill it before temper maxes out to befriend the species ([[11 - Decisions#D-009 Befriending via taming ring]]). Timings TBD by playtest.
- On success: discovery notification → recorded in Animal Book → available for sanctuary placement.
- **Server validates** all discoveries.

## Animal Book
- Eventually: name, model/image, discovery status, habitat, ability, info, variants.
- Undiscovered species shown as silhouettes.
- MVP: 3 species only. UI designed in ChatGPT first (see [[08 - UI Design]]).

## Rarity
🟡 Not designed yet. The MVP has 3 common starter species; rarity tiers and variants (golden, crystal…) are in [[14 - Future Ideas]]. Design them before adding a 4th species.

## Animations
States: idle, run, jump, land, ridden, restless, befriended.
Use the simplest reliable approach — procedural motion is likely fine for blocky animals. Never pretend an unrigged mesh supports skeletal animation.
**Mount point:** every animal model exposes a consistent rider attachment (name TBD in [[09 - Technical Architecture]]).
