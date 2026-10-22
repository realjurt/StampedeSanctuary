# Open-World Redesign Plan

Back to [[00 - Project Dashboard]] · Status: **APPROVED 2026-10-21** with adjustments (see [[11 - Decisions#D-027 Open-world taming redesign|D-027]]): simpler first Wild Ride (steer against pull + one timed reaction), starter zebra within ~10 s of the start area, ride tamed animal home, progress resets when thrown, straight course kept as test mode.
Goal: make riding and taming genuinely fun in the first five minutes. No new features, currencies, art or models.

## 1. Current game vs the target
| | Now | Target |
|---|---|---|
| World | Sanctuary hub → Safari Gate teleport → 950-stud straight course | Sanctuary opens straight onto a small savannah; no teleport, no finish line |
| Movement | Auto-run forward, steer left/right only | Free movement on foot and mounted, any direction, player controls speed |
| Animals | Seeded herds spawned along the course during a run | Animals roam the savannah all the time; you see them from afar and pick one |
| Mounting | Leap between herd animals while running | Approach on foot (or from a mount), leap onto the one you chose |
| Taming | Stay on until a bar fills (waiting) | Short active challenge: counter swerves, time bucks, jump obstacles |
| Failure | Crash/bucked off ends the run | Thrown off onto your feet, the animal bolts, chase it again |
| Coordinates | Everything in "course space" (distance, sideways x) | World space (position + heading) |

**Note on the reference** (frame-sampled, [[17 - Reference Game Analysis]]): its main capture mode is also a forward stampede run (distance meter, zones). What makes it better is the first catch happening at spawn, in an open area, plus longer runs and zones. The open world goes further than the reference in player control. Your call.

## 2. What changes, what stays
**Changes:** forced forward running · course-space movement · run start/finish/crash · herd schedule along a track · passive tame bar · gate teleport as the main route · scripted ride camera.
**Stays (reused as is):** plots, pens, deposits, income, training machine, upgrades, saving, `AnimalCollection` records, carry cap 7, stamina + `gripCurve`, `requiredStamina` gate, `TameService` checks (generalized), `AnimalBuilder` models, leg/gait pose, leap arc, `TargetIndicator`, UiKit, HUD, onboarding flags, the rider-weld replication fix (BUG-003).
**Kept for testing:** the straight course stays behind the Safari Gate, labelled as a test course, until the new mode is approved.

## 3. Recommended architecture (simplest that stays multiplayer-ready)
**A. Riding = a client-side kinematic mount controller (new `FreeRide` module).**
- The mount is the same client-side `AnimalAgent` model with the rider welded on (proven, and the character still replicates). It moves in world space instead of course space.
- Input: the standard Roblox move direction (WASD / thumbstick / gamepad stick), camera-relative. The animal turns toward it at a species turn rate, with acceleration, top speed and momentum. That's what makes a zebra feel different from an elephant.
- Ground: a raycast down each frame keeps the animal on hills; a forward shape-cast stops it at rocks and trees. Jump hops logs. No physics simulation, so it's predictable (same idea as D-002).
- Camera: the normal Roblox orbit camera (mobile drag and right-mouse already work), following the mount, with a speed-based FOV and pull-back. No scripted camera.
- On foot: the normal Roblox character, unchanged.

**B. Wild animals = server-owned, client-rendered (new `WildAnimalService` + `WildView`).**
- The server keeps a small registry: id, species, current movement plan (from, to, start time, speed, behaviour). It picks a new plan every few seconds (graze, wander, flee from a nearby player) and replicates only the plan, a few times per animal per minute.
- Every client computes the animal's exact position from the plan and server time and draws it smoothly with the existing gait. The server can compute the same position, so it validates leaps by distance. Every player sees the same animals, which is ready for multiplayer.
- About 12–18 animals in the area; tamed ones respawn after a delay.

**C. Server checks (extending current ones):** leap request → animal exists, is free, is within reach of the player's real position (with tolerance), stamina ≥ requirement → server *claims* it for that player. Tame request → still claimed by them, minimum challenge time passed, not already tamed, carry space → `AnimalCollection.addCarried` + save (same as today). Thrown off → claim released, animal flees from where it was.

**Why not the alternatives:** a Humanoid with high WalkSpeed is free to build but turns instantly and feels like a fast person, not an animal. Server-physics mounts make leaps laggy (rejected in D-016). Client-only wild animals are simpler today but need a rewrite for multiplayer and can't be validated.

## 4. Interactive taming: "Wild Ride"
After you land on a wild animal, it tries to throw you. Controls: **steer + one button (JUMP)**, the same as riding, so it works on mobile.
- **Balance meter:** a bar with a marker. The animal pulls you sideways; steering against the pull keeps the marker in the green zone.
- **Swerves:** telegraphed about 0.6 s ahead (head flick + arrow). Counter-steer the other way to stay balanced.
- **Bucks:** a closing timing ring with "HOLD ON!". Press JUMP as it closes: success gives a big boost to tame progress, failure knocks your balance.
- **Terrain:** the wild animal partly steers itself (you share control). Jumping a log or rock on the way gives bonus progress.
- **Progress** fills while you're in the green zone. "Almost tamed!" shows at 75%. Success: "IT'S YOURS!"
- **Grip = how long you can be out of the green before you're thrown.** It comes from stamina through the existing `gripCurve`, so training matters directly.
- **Thrown off:** you land on your feet, the animal bolts, and you can chase it again. No run ends.

| Species | Feel when riding | Taming personality | Wild behaviour |
|---|---|---|---|
| Zebra (⚡5) | Quick, sharp turns | Frequent small swerves, few bucks (easy, about 8 s) | Small herds; startle and zig-zag away when you get close |
| Giraffe (⚡12) | Long stride, wide turns | Slow, strong sways you must hold against (about 10 s) | Solo/pairs, calm until close, then lope away in a straight line |
| Elephant (⚡25) | Slow start, unstoppable, smashes bushes | Rare but heavy rear-up bucks that need precise timing (about 12 s) | Slow family group; ignores you |

All numbers live in config (`TamingConfig` / `AnimalConfig`).

## 5. How it connects to existing progress
- Successful tame → `TameService` → carried record (state `carried`) → **you keep riding your now-tame animal home** (calm, fully controllable). Dismount or leap to another wild animal → it simply stays carried. Deposit at the DEPOSIT sign exactly as now; pen, income, starter bonus unchanged.
- Stamina: `requiredStamina` locks species (🔒 label, leap refused). Grip from stamina keeps you on longer. The training machine stays the way to unlock elephants.
- Carry cap 7, upgrades, saving: unchanged.
- `InSafari` currently hides prompts and blocks deposits. The new mode uses a `Riding` state instead; every `InSafari` check gets reviewed one by one.
- Onboarding: a lone zebra waits just outside the sanctuary ("Catch your first zebra!"), the same idea as the reference's first catch. The old tutorial course stays reachable for testing.

## 6. Milestones (each ends with your playtest)
| # | Milestone | Done when you can… | Reuses |
|---|---|---|---|
| R0 ✅ built `0216979`, playtested ✓ (approved 2026-10-21) | **Spike** (short): world-space mount on a flat test field | Ride a practice zebra anywhere with the normal camera on PC, mobile emulator and gamepad; server sees you move | AnimalAgent, rider weld |
| R1 ✅ built `bebccfb`, awaiting playtest | **Free riding feel** | Leap on/off a practice zebra, giraffe and elephant near the sanctuary; each handles differently; jump, rocks block, hills followed | R0, AnimalConfig |
| R2 | **Savannah + roaming animals** | Walk out of the sanctuary into a small savannah, see animals from afar, pick one, chase and leap on (stamina gate); bucked off after Grip, no taming yet | WildAnimalService, TargetIndicator |
| R3 | **Wild Ride taming** | Tame an animal through the balance/buck challenge; species feel different; failure → chase again | TameService, AnimalCollection, gripCurve |
| R4 | **Loop + first five minutes** | Spawn → first zebra → ride it home → deposit → buy machine → train → tame a giraffe/elephant; Safari Gate shows "Test course" | All existing systems |
| (later) | Multiplayer view | Others see your mount; two-client test | Server-owned animals already |

## 7. Technical risks and protections
| Risk | Mitigation |
|---|---|
| Reading the move direction while welded to a mount (the Humanoid is sitting) | R0 tests this first; fallback = our own key/stick/touch input (current touch code) |
| Kinematic mount clipping hills or sticking on rocks | Gentle placeholder terrain from simple parts; ray + shape casts; a dedicated collision group for ride ground |
| Server not seeing the rider (BUG-003 again) | Same RootPriority fix; R0 verifies the server-side position |
| Wild animal sync / leap validation latency | Plans replicate rarely and positions come from server time; reach tolerance like `REACH_SLACK` |
| Breaking working systems | New modules beside the old (`FreeRide`, `WildAnimalService`, `WildView`); `RideController`/course untouched; small extensions only to `AnimalAgent` (world-space pose), `TameService` (mount source), prompts (`Riding` state) |
| Camera conflicts (mobile drag vs thumbstick) | Use the default camera/controls, which already handle this |
| Scope creep | One small area, 3 species, one challenge; new ideas → [[14 - Future Ideas]] |

## 8. Decisions needed from you
1. Approve the direction and the R0 → R4 order.
2. After a tame, ride the animal home (recommended) or have it go straight into your carry slots?
3. Thrown off = chase again with tame progress reset (recommended), or keep partial progress?
4. Keep the straight course only as a test mode behind the gate (recommended), or remove the gate from new players' view entirely?
