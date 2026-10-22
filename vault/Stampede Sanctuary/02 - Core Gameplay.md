# Core Gameplay

Back to [[00 - Project Dashboard]]

## Main loop (confirmed)
Start Safari → Ride Animal → Dodge Obstacles → Leap Between Animals → Discover/Befriend Species → Return to Sanctuary → Place Animal → Earn Coins → Upgrade → Unlock New Safari Content

Every feature must improve some part of this loop. Unrelated mechanics are cut.

## Game spaces
- **Sanctuary** — home base. See [[05 - Sanctuary System]].
- **Safari Expeditions** — action runs. See [[04 - Safari System]].

## Development priority (confirmed — [[11 - Decisions#D-010 Gameplay first; art and UI deferred]])
Riding feel → switching → onboarding → discovery loop → zoo progression.

## First-time onboarding (confirmed; first fun within 30–45 s)
1. **Spawn in a small starter sanctuary:** entrance path, empty "Zebra Habitat" sign, visible Safari Gate. One fading line: *"Ride wild animals, discover new species, and build your own animal sanctuary."* An arrow points to the gate.
2. **Start Safari** via a gate prompt (E / tap). Never forced.
3. **Tutorial safari (~30 s, forgiving, checkpoints on crash):** steer along a pickup trail → dodge spaced rocks → jump a log (first-time slow-mo + prompt) → leap to a second animal (once switching exists).
4. **First reward:** "You befriended a Zebra!" card + confetti → back at the sanctuary the zebra pops into its habitat.
5. **Returning players** skip onboarding (saved tutorial flag + discovered animals); the gate also offers "Skip tutorial".

No long dialogue or unskippable cutscenes. Teach mechanics when they become relevant.

## MVP scope (confirmed)
**In:** Sunny Savannah biome · Zebra, Elephant, Giraffe · one short course · one switching mechanic · basic obstacles · one discovery system · one starter sanctuary · three habitats · Coins · one progression path · basic Animal Book · saving · desktop + mobile UI.

**Out:** dozens of animals · breeding · trading · huge procedural maps · multiple biomes · realistic AI · visitor pathfinding · large multiplayer races · complex monetization · free-form building · seasonal events. → parked in [[14 - Future Ideas]]
