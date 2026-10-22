# Technical Architecture

Back to [[00 - Project Dashboard]] · Decisions: [[11 - Decisions]]

## Principles
- Modular Luau; clear client/server split.
- **Server validates:** discoveries, rewards, coins, purchases, habitat unlocks, saved progress.
- Client may own movement/animation presentation for responsiveness; never rewards.
- RemoteEvents only where needed; validate inputs; rate-limit.
- Balance values in config modules (e.g. `AnimalConfig`).
- Extend existing systems before creating new ones.

## Tool status (verified 2026-10-20)
| Tool | Status |
|---|---|
| Roblox Studio MCP | ✅ Connected — place "baseplate" (placeId 131474966293735), empty baseplate, no scripts |
| Obsidian vault | ✅ Direct file read/write via working directory. `obsidian` MCP configured in settings but not loading in session |
| Git | ✅ Repo at `C:\Users\halll\dev\StampedeSanctuary` (branch `main`). First commit `c8ae952`. Identity: realjurt. Local only — no GitHub remote |
| Claude 3D Design | ❓ Not accessible from Claude Code — export formats unverified |
| Rojo | ✅ 7.4.4 via `aftman.toml`; `rojo build` works; Studio plugin installed. Live sync verified 2026-10-20 (create, edit, delete all reach Studio) |

## Code layout (created 2026-10-20 — [[11 - Decisions#D-003 Code source of truth]])
`C:\Users\halll\dev\StampedeSanctuary`
```
StampedeSanctuary/
├── CLAUDE.md, README.md, .gitignore, aftman.toml, default.project.json
├── src/
│   ├── shared/   → ReplicatedStorage.Shared
│   ├── server/   → ServerScriptService.Server
│   └── client/   → StarterPlayer.StarterPlayerScripts.Client
├── assets/ animals/ environment/ animations/ audio/
├── tools/  tests/  references/
```

## Current architecture (Milestone 2, `d591747`)
**Shared**
- `Config/AnimalConfig` — per-species speed ramp, steering, jump, temper, hitbox, gait.
- `Config/CourseConfig` — obstacle kinds + **course registry** (`courses.Savannah`; tutorial added in M3).
- `Config/SanctuaryConfig` — sanctuary layout offsets.
- `Animals/ZebraBuilder` — placeholder zebra (server mounts + client habitat display). **Animal model contract:** PrimaryPart `Root`, Seat `RiderSeat`, attributes `AnimalId` + `RootHeight`, legs `Leg*` with Weld `Hip`.

**Server**
- `Main` — builds courses + sanctuary, starts services.
- `PlayerDataService` — DataStore `PlayerData_v1`; fields `tutorialCompleted`, `starterZebraUnlocked`, `onboardingDismissed`, `discovered`; mirrored to player attributes; never saves if load failed (`DataSaveDisabled`).
- `Net` — creates `ReplicatedStorage.Remotes.*` with per-player rate limit.
- `SanctuaryBuilder` — shared hub: spawn, entrance, empty habitat + sign, Safari Gate with Start (E) and Skip Tutorial (F, hold) prompts.
- `OnboardingService` — Skip Tutorial (remote or prompt) → dismissed + starter zebra, *not* tutorial completed.
- `SafariService` — gate starts a run (mount, seat, network ownership, `InSafari` attribute); `ReturnToSanctuary` remote, death, or leaving ends it; teleport holds server ownership briefly (BUG-001).
- `CourseBuilder` — builds each course + lighting.

**Client**
- `Main` — starts a ride when seated on a `RiderSeat`; starts onboarding + sanctuary view.
- `RideController` / `RideHud` — riding (free steering, D-007) + HUD with Leave button and Ride again / Back to Sanctuary panel (R = ride again).
- `OnboardingController` — intro card (new players only), goal line, gate arrow, client-side Skip prompt visibility.
- `SanctuaryView` — per-player habitat: sign text + zebra pop-in when `StarterZebraUnlocked`.
- `UiKit` — placeholder UI helpers + toasts.

**Remotes:** `ReturnToSanctuary`, `SkipTutorial`, `CompleteTutorial` (no payloads; server re-checks state).

**Milestone 5 changes (`3d1bb37`) — [[11 - Decisions#D-018 Animal switching rules (Milestone 5)]]**
- `RideController`: states countdown / running / **leaping** / ended; `jump()` leaps if `herds.target`; `startLeap` → `herds:take(wild)`, `herds:release(oldMount)`, fire `SwitchMount(id)`; `updateLeap` homing arc; `land` → `setMount(target)`. `reset()` restores starting Zebra, smashed rocks, fires `RestartRun`. Camera follows course distance.
- `AnimalAgent.setRidden(bool)` switches anchoring/RootPriority between wild and ridden.
- `HerdController.take/release`; released mounts not targetable.
- `CourseObstacles.hit` returns the obstacle (kind, smashed flag) for elephant smashing.
- `SafariService`: per-run `herdMembers` (from HerdSchedule), `usedMembers`, `switches`; remotes `SwitchMount`, `RestartRun`.

**Milestone 4 changes (`d13f01d`, `869bf6c`) — see [[11 - Decisions#D-016 Riding architecture: client-predicted mounts, replicated rider, server-tracked run state]]**
- **No server mounts any more.** `SafariService` publishes run state as player attributes: `InSafari`, `SafariCourse`, `SafariSeed`, `MountSpecies`. Client `Main` starts/stops the ride from `InSafari`.
- `shared/Animals/AnimalBuilder` (replaces ZebraBuilder): Zebra, Elephant, Giraffe placeholders. Contract adds `RiderOffset`; no Seat.
- `client/AnimalAgent` — one animal: model + course-space state (distance, x, speed, steer velocity, jump) + `pose()`. Used by the ridden mount (unanchored, rider welded, `RootPriority -127` so the character stays assembly root and replicates) and herd animals (anchored).
- `client/RideController` — now builds its mount as an AnimalAgent and welds the rider; steering/camera/temper/tutorial hooks unchanged.
- `client/CourseObstacles` — shared obstacle boxes + hit test (rider crashes, herd avoidance).
- `shared/Herds/HerdSchedule` — deterministic herds from course + seed (identical on server and client, verified).
- `client/HerdController` — spawns herds ≤160 studs ahead, despawns 60 behind, cap 12; brain: amble far ahead (catchable), pace a species share of rider speed when near, wander, herd spacing, gentle rider sidestep only when overlapping (D-017), rock avoidance last, log jumping. Picks `target` (6–30 ahead, ≤14 side, steering-biased) — Milestone 5 hook.
- `client/TargetIndicator` — placeholder ring + "▼ Species" label.
- **Planned before multiplayer playtest:** render other riders' mounts locally from their character + `MountSpecies`.

**Milestone 3 additions (`c7ccf15`)**
- `CourseConfig.courses.Tutorial` (origin x=600, 520 studs, speed ×0.75, temper off) with `tutorial` spec: sections, treats, points.
- `client/TutorialDirector` — attaches to RideController via hooks `onCrash` / `onFinish` / `onStep` and `respawnAt(distance)`; owns prompts, treats, meter, checkpoints, reward card + confetti.
- `SafariService.getRun` + gate routing (tutorial unless completed or dismissed); `OnboardingService.completeTutorial` validation (D-014).
- `SanctuaryView` — ghost zebra + "?" in empty habitat; real zebra pops in only once the player is back from safari.
- Studio saves to `PlayerData_v1_Studio` (D-015).

## Multiplayer
Separate per-player progress. Safari runs per-player (client-side mounts, D-016).
**Plots (P1, `bbecf00`):** `PlotService` assigns one of 6 plots (`SanctuaryConfig.plotOffsets`) on join, frees it on leave. Publishes plot `OwnerUserId` + player `PlotId` attributes; owner sign updated server-side so everyone sees it. `claim/release` keyed by UserId (testable without a 2nd client).
**Data v2:** `coins`, `stamina` (+ `Coins`/`Stamina` attributes, read by `CurrencyHud`). Values only ever written by the server; no remotes added. Balance in `EconomyConfig`.
**Deposit & income (P3, `89bc9e6`, D-025):** pen `DepositPrompt` (server ProximityPrompt; client `PenView` shows it only on your own pen) → `DepositService` (owner, range 22, not on safari, carried > 0, pen < 8, per-player busy lock) → `AnimalCollection.depositCarried` in one non-yielding update → `PlayerDataService.saveNow` → `PenService.reveal` (server models one by one in `Plot.PenAnimals`, `Fresh` attribute) → `DepositResult` to the depositor. `PenService` rebuilds pens on join, clears on leave, publishes plot `IncomePerSecond`/`PenCount` + sign. `IncomeService` 1 s tick from server data only (`deferSave`), cosmetic `IncomeTick` (unreliable). Studio-only test hooks: `TestSaveDelay` / `TestFailSaves` attributes on the PlayerDataService script.

**Open-world riding (R0, `0216979`, D-027):** client `FreeRide` — practice zebra (`AnimalAgent.newAt`, client-only) with a client Ride prompt; while riding, PreSimulation step reads `Humanoid.MoveDirection` (camera-relative) → heading/speed with `FreeRideConfig.handling` → sphere cast forward (blocks surfaces above step height, slides) + ray down (ground follow, step-up, no riding where there's no ground) → `AnimalAgent:poseFree` (sets velocity so the welded rider replicates). Scriptable chase camera at RenderPriority.Camera+1. Field built by server `OpenWorldBuilder` (`Workspace.OpenWorld`, north of the sanctuary). Straight-course riding untouched except the shared `AnimalAgent:attachRider`.
**R1 (`bebccfb`, D-028):** motion moved into client `FreeRideMotion` (one object per mount: AnimalAgent + position/heading/speed/yaw-rate state; `steer(dt, moveDir, cameraYaw)` → `move(dt)` returns `{landed, pushed}` → `pose(dt)` computes body CFrame + leg angles → `AnimalAgent:poseFree(cframe, legAngles, velocity)`). `FreeRide` keeps input, camera, prompts, mount/dismount for three practice animals (zebra, giraffe, elephant). Server `PushableService` validates `PushObstacle` and moves `OpenWorld.Pushables` (server network owner, reset loop).

**Training & upgrades (P4, `dfbd48d`, D-026):** `UpgradeService` — plot prompts `MachinePrompt` (kiosk) / `PenUpgradePrompt` (plaque) → check owner, range 14, not on safari, level, coins, per-player busy lock → coins + level in one non-yielding update → `saveNow` → publish plot attributes `MachineLevel`/`PenLevel`/`PenCapacity` + sign text → `PurchaseResult`. `MachineService` — builds the machine in `Plot.Machine` (seat `Disabled`, server `Seat:Sit` from `TrainPrompt`, non-owners ejected on `Occupant` change), 0.5 s tick adds stamina for owners seated on their own machine (`deferSave`), BOOST windows per session on `TrainingBoost` (server→client window/boost/miss; client→server hit, rate-limited, checked against server time + 0.35 s latency, once per window), cosmetic `TrainingTick` (unreliable); plot attributes `Training`/`Boosted` drive client animation. `DepositService` grants `EconomyConfig.starterDepositReward` once in the deposit update. **Data v4:** `machineLevel` (0–4), `penLevel` (1–3), `starterRewardClaimed`; attributes `MachineLevel`, `PenLevel`. Grip: `TamingConfig.gripCurve` (piecewise-linear points). Balance in `TrainingConfig` + `EconomyConfig.penLevels`. Client `TrainingView`.

**Taming (P2, `ba31a5a`, D-024):** client `RideController` fills grip/tame locally → `TameAnimal` remote → `TameService.check` (current server-confirmed mount, stamina, time since switch ≥ tameTime − 0.25 s, carry cap) → `SafariService.markTamed` (single duplicate gate, survives Ride again) → `AnimalCollection.addCarried` + immediate save → reply on same remote. **Data v3:** `animals: {id, species, state: carried|pen, caughtAt}`, `nextAnimalId`; attributes `CarriedCount`, `CarriedSpecies`. Balance in `TamingConfig` + `AnimalConfig.requiredStamina/tameTime`.

## Notes
Studio place files and Git source are not automatically the same — keep place backups.
