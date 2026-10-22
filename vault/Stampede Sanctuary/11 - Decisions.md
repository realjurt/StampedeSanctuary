# Decisions

Back to [[00 - Project Dashboard]]
Format: decision · why · alternatives · tradeoffs · affected systems · date · status (Proposed / Accepted / Superseded)

## D-028 R1 species handling & pushable obstacles
- **Decision:** each species gets a full handling + body-feedback profile in `FreeRideConfig.handling` (not `AnimalConfig`, which stays the safari's). One `FreeRideMotion` object per mount (input-agnostic, so herd brains / server-owned animals can drive it later).
- **Feel targets (user, R1):** Zebra = fast acceleration, responsive turning, agile jumps · Giraffe = long strides, wide turns, high floaty jumps · Elephant = heavy acceleration, slow weighty steering (turn acceleration — it keeps turning briefly after you let go), pushes through small obstacles.
- **Pushing:** small crates/bushes in `OpenWorld.Pushables` are unanchored, server-owned parts. The elephant ignores them in its casts and asks the server to shove them (`PushObstacle`); the server checks part, rider seated, distance and direction, then moves them, so all players see the same result. They return home after 10 s untouched. Species isn't checked server-side yet (mount is client-only) — add when mounts become server-known (R2).
- **Alternatives:** client-only knock-over visuals (not multiplayer-consistent); physical collision pushing (client mount can't push server-owned parts reliably).
- **Date / Status:** 2026-10-21 · Accepted · built `bebccfb`, awaiting your playtest

## D-027 Open-world taming redesign
- **Problem (user playtest):** the game feels like an obstacle-course prototype — forced forward running, short straight course, passive tame bar.
- **Proposal:** replace the safari runner as the main mode with a small savannah connected to the sanctuary: free on-foot and mounted movement, server-owned roaming wild animals, an interactive "Wild Ride" taming challenge (balance + telegraphed swerves + timed bucks; Grip from stamina), ride the tamed animal home. Existing economy, pens, saving, training reused; the straight course stays as a test mode. Full plan: [[18 - Open-World Redesign Plan]].
- **Architecture:** client-side kinematic mount in world space (reuses AnimalAgent + rider weld), default Roblox camera/controls; wild animals as server-owned movement plans rendered by clients (multiplayer-ready, validatable).
- **Alternatives:** Humanoid-as-mount (instant turning, weak feel); server-physics mounts (laggy leaps, D-016); client-only wild animals (rewrite for multiplayer).
- **Supersedes if approved:** parts of D-002/D-007 (auto-run, horizontal-only steering) and the run model in D-016; D-016's client-predicted mount + replicated rider is kept.
- **User decisions (approval 2026-10-21):** R0 → R4 order approved · ride the tamed animal home (no auto-teleport to inventory) · thrown off = that animal's tame progress resets, chase and retry · straight course kept as a temporary test mode behind the Safari Gate (not deleted).
- **Adjustments:** Wild Ride starts simple — steering against the animal's pull + **one** clearly telegraphed timed reaction; add more only if it improves play. **Starter wild zebra just outside the sanctuary**, met within ~10 s of leaving the start area. No large map before movement feels good. Stop after R0 for playtest.
- **R0 as built (`0216979`):** steering = `Humanoid.MoveDirection` (still updates while seated — verified), so WASD / thumbstick / gamepad come free; own chase camera (scripts can't switch Roblox's Follow camera mode at runtime); straight back (±25°) brakes then reverses, diagonal back turns round; jump = standard jump input with the Jumping state disabled.
- **Date / Status:** 2026-10-21 · Accepted · R0 playtested ✓ (approved) → R1 built (D-028) — P5 on hold

## D-026 P4 Training machine & upgrades plan
- **Loop:** tame → deposit → earn → buy/upgrade machine → train stamina → unlock stronger animals.
- **Step 0 (user request):** tall "DEPOSIT ANIMALS" sign at the pen front with the deposit prompt on it; shows "🐾 N to deposit" while carrying. Placeholder only.
- **Machine:** per-plot placeholder machine on the existing pad (pedestal + blocky animal on a treadmill). Buy $300 at a sign prompt. Walk in → server seats the owner on it; animal gallops (client animation, seen by all). Jump to leave.
- **Training:** server tick every 0.5 s while the owner is seated on their own machine; gain per tick L1 0.2 · L2 0.3 · L3 0.4 · L4 0.5. Floating "⚡ +0.2" pops. Boost rhythm: server opens a ~1.2 s BOOST window every ~6 s; pressing Jump/tapping inside it doubles gains for 3 s (server-checked). Panel shows progress to the next unlock ("Elephant ⚡25 — 3.2 to go"); unlock toasts.
- **Upgrades (coins, server-validated, saved at once):** machine L2 $1,500 · L3 $5,000 · L4 $15,000. Pen L2 (10 slots) $1,000 · L3 (12 slots) $4,000; pen built to fit 12 from the start.
- **Data v4:** `machineLevel` (0 = not owned), `penLevel` (1); sanitized on load.
- **Safeguards:** only the owner can sit (others ejected by the server); gains computed per player from server time only; purchases: owner + range + coins + level checks, per-player lock, one update + immediate save; boost hits rate-limited and checked against server windows.
- **User decisions (approval 2026-10-21):** grip keeps improving past stamina 40 with diminishing returns — targets 20 ×1.0 · 40 ×1.5 · 60 ×1.7 · 80 ×1.85 · 100 ×2.0, capped at ×2.0; stamina itself keeps growing past 100 and is saved. Curve is a configurable point list (`TamingConfig.gripCurve`). BOOST stays optional. **One-time $300 starter reward** on the first deposit (server-only, saved with the deposit, never repeated). Machine prices/gains and pen prices as planned.
- **As built:** prompts — Deposit **E** on the DEPOSIT sign; Upgrade pen **F** (hold 0.5 s) on the plaque below it; Buy/Upgrade machine **F** (hold 0.5 s) on the kiosk; **Train E** on the machine. Seat is `Disabled` (no touch-sitting); server `Seat:Sit()` from the Train prompt. Jump/LEAVE exits; during a BOOST window Space/gamepad A boost instead of leaving. Pen enlarged to 28 × 38 (4 × 3 grid). Saves from before P4 that already had pen animals count as having claimed the starter reward.
- **Date / Status:** 2026-10-21 · Accepted · built `dfbd48d`, awaiting your playtest

## D-025 P3 Deposit & income plan
- **Loop:** tame → carry home → deposit at own pen → animal appears (everyone sees it) → coins every second.
- **Deposit:** server-side ProximityPrompt "Deposit animals" on each pen; server checks the triggering player owns that plot, is close, and not on safari, then moves all carried records → `pen` (up to capacity) in one update, saved immediately. Other players' prompts hidden on their clients; server rejects anyway.
- **User adjustments (approval):** reveal animals one at a time with "+$X/s" each and a confirmation of how many; server data updated + saved *before* the reveal; one deposit at a time per player; careful DataStore-failure handling; disconnect-during-deposit tested; owner-only; animals visible to all.
- **Pen models:** new server `PenService` spawns anchored placeholder `AnimalBuilder` models with "Zebra · $1/s" labels; rebuilt from saved `pen` records when the owner joins, removed when they leave.
- **Income:** new server `IncomeService`, 1 s tick, coins += sum of pen income (server data only), `deferSave` + 60 s autosave + save on leave. Plot sign shows owner's total $/s; client shows "+$N" pops over own pen.
- **Approved values (`EconomyConfig`):** Zebra $1/s · Giraffe $2/s · Elephant $5/s; pen capacity 8; no offline earnings. Pen enlarged 20 → 28 studs so 8 animals fit (4 × 2 grid).
- **No data migration:** `pen` state already exists in data v3.
- **Out of scope:** removing/selling pen animals (P6), pen upgrades (P4), offline income, rarity.
- **Save safety:** a deposit only flips the state of existing records (can't create/duplicate). A failed write keeps the in-memory data authoritative and is retried by autosave and on leave (3 attempts); shutdown waits for in-flight saves.
- **Date / Status:** 2026-10-23 · Accepted · built `89bc9e6`, awaiting your playtest

## D-024 P2 Taming design
- **Summary:** Temper → **Grip** (stay-on time, scaled by stamina). Wild herd animals show **Required ⚡N**; leaping needs stamina ≥ requirement (server-checked). Staying on a wild animal fills a **Tame** bar; only a completed, server-validated tame captures it — switching alone never collects. Captures are saved as **carried** animal records (persistent inventory, state `carried`), deposited into the plot pen in P3. Run-end "GREAT RUN" summary.
- **Approved values (user):** requirements Zebra 5 · Giraffe 12 · Elephant 25; starting stamina 20 → elephants intentionally locked until P4 training. Tame time Zebra 4 s · Giraffe 6 s · Elephant 9 s. Carry capacity 7.
- **Grip formula (configurable, `TamingConfig`):** species base (`temperDuration`) × clamp(0.5 + stamina × 0.025, 0.5, 1.5). Stamina 20 → ×1.0 (unchanged feel), cap ×1.5 at stamina 40.
- **Anti-duplication:** server `markTamed` per herd member, kept across "Ride again" (same seed); one record created per accepted tame, saved immediately; unique monotonically increasing record ids; sanitize drops duplicate ids on load.
- **Income rule for P3:** only records with state `pen` earn income; `carried` never does.
- **Date / Status:** 2026-10-22 · Accepted · built `ba31a5a`

## D-023 Progression plan direction approved; P1 plots + coins/stamina saving built
- **Decision:** The user approved the overall gameplay direction in [[17 - Reference Game Analysis]] and authorized **P1 only**: one plot per player around the shared hub (owner sign, empty pen, training-machine pad), coins + stamina saved server-side, $/⚡ HUD. This lifts D-022's "no currency UI" clause for coins/stamina only; still no monetization UI.
- **How:** same DataStore keys (`PlayerData_v1[_Studio]`), data `version` 2; `reconcile` fills missing fields, so v1 saves load unchanged. Numbers sanitized (finite, clamped). `update(..., deferSave)` + 60 s autosave for future per-second changes. Plots are session-only (assigned on join, freed on leave); 6 plots → server size should be ≤ 6.
- **Kept as-is (for later decisions):** shared-hub Zebra habitat; players still spawn in the hub (spawning at own plot → P5).
- **Tradeoff:** an older server build saving again would drop coins/stamina — acceptable while unpublished.
- **Date / Status:** 2026-10-22 · Accepted (P2+ awaiting approval)

## D-022 UI direction: classic polished simulator style ("Outlined Radiance") — supersedes D-010's UI clause
- **Decision:** All UI follows the reference video's simulator language: dark charcoal windows with faint diamond texture, thick black contours, saturated green/cyan header bars with diagonal gloss stripes, red X close buttons, bold white text with black outline (FredokaOne), gradient item/animal cards with clear borders, bright green action buttons, compact colored side buttons, small corner radii (6–14), quick scale open/close animations. Not the earlier wooden/rounded fantasy HUD.
- **Who builds what:** Claude Code builds the UI natively (UIStroke, UIGradient, UICorner, ViewportFrame silhouettes) through one reusable design system; ChatGPT supplies icons and art (icon set, panel texture, sunburst card art, biome banners) to drop in later. Emoji placeholders for icons until then.
- **Approved plan:** UI-1 design system + Safari HUD (animal + temper + distance + ability + target/leap chip, side buttons Sanctuary / Index / Shop / Settings, control hints, mobile JUMP/LEAP), UI-2 Animal Index (Zebra/Giraffe/Elephant, colored vs silhouette, real stat values, collection progress). Menus pause the local safari while open. Shop and Settings are "Coming soon" windows — no purchases. Rarity left blank until designed. No currency UI until currency exists.
- **Reference:** video `C:\Users\halll\Videos\Desktop\Desktop 2026.10.20 - 22.32.24.01.mp4`; plate [[Assets & References/Outlined Radiance - Design Philosophy|Outlined Radiance]] + `Outlined Radiance - Plate I.png`. Never copy the reference game's logos, art or assets.
- **Date / Status:** 2026-10-21 · Accepted

## D-019 One local simulation clock
- **Decision:** `RideController` owns the safari's time scale and steps the herds itself with the scaled dt (herds no longer run their own loop or use `os.clock`). Rider, herds, temper, jumps and leaps all share it; steering keeps ≥ 60% of real time so players can line up in slow motion. Camera and lesson timers use real time.
- **Why:** Slow motion must never let rider and herds drift apart; the server only checks wall-clock plausibility, which slow motion can only make easier to pass (client reaches animals later, never earlier).
- **Date / Status:** 2026-10-21 · Accepted

## D-020 Separate jump and leap controls (supersedes D-008)
- **Decision:** Jump = Space / W / ↑ / gamepad A / mobile JUMP button. Leap = F / gamepad X / mobile LEAP button (lit only with a target). Leap does nothing without a target; jump never leaps. Tap-anywhere-to-jump removed on mobile.
- **Why:** Playtest — Space doing both caused accidental switches.
- **Date / Status:** 2026-10-21 · Accepted (user confirmed)

## D-021 First-time slow-motion leap lesson
- **Decision:** First targetable animal on a herd course → local slow motion to 20% (0.3 s ease), device-specific prompt, Skip (button / Backspace). Ends on leap (normal speed over 0.25 s, "Nice leap!"), skip, 8 s timeout, 1.5 s without a target, crash/restart, or leaving — all restore normal speed; failed attempts retry after 3 s. Saved as `leapTutorialDone` (separate from onboarding). Server accepts "learned" only after a validated switch in the current run; "skipped" only during a run on a herd course. Skip counts as learned (user confirmed).
- **Date / Status:** 2026-10-21 · Accepted

## D-018 Animal switching rules (Milestone 5)
- **Leap:** Space/tap with a target → 0.45 s homing arc onto the moving animal (always lands once started). No target → normal hop.
- **Targeting:** 6–30 studs ahead, ≤ 11 studs to the side (requires lining up), steering-biased; target glows (Highlight) + ring + "▼ Species — SPACE/TAP to leap".
- **Landing benefits:** temper → 0, ×1.2 speed boost for 1.5 s, 0.5 s crash grace. Old mount rejoins the herd (not re-targetable).
- **Species identity:** Zebra quick/nimble (temper 20 s) · Elephant slow/heavy, smashes Rocks (temper 16 s) · Giraffe floaty 9.8-stud jump clears Boulders (temper 18 s). Shorter temper makes switching necessary.
- **Server validation:** `SwitchMount(memberId)` accepted only if the member exists in the run's seeded schedule, hasn't been ridden this run, and is plausibly reachable (spawn distance − 40 ≤ elapsed × 70); then `MountSpecies` is updated. `RestartRun` resets run timer/used members on Ride again.
- **Date / Status:** 2026-10-21 · Accepted (tuning pending playtest)

## D-016 Riding architecture: client-predicted mounts, replicated rider, server-tracked run state
- **Decision:**
  - The player's mount and all herd animals are **client-side visuals** driven by a shared `AnimalAgent`. The rider's character is welded to their own mount on their client.
  - The **character replicates** normally (client-owned physics) — verified by spike 2026-10-20: server saw the welded character move ~30 studs/s and `Humanoid.Sit` replicated; the local mount did **not** replicate (as expected).
  - The **server owns run state**: course, start time, herd seed, and the rider's `MountSpecies` (player attributes). Herds are generated deterministically from the seed (`HerdSchedule`) so the server can rebuild them to validate switches/discoveries (Milestone 5+).
  - **Multiplayer visibility (planned, before any multiplayer playtest):** each client renders *other* riders' mounts locally from their replicated character + `MountSpecies` attribute. No server-physics mounts.
- **Why:** Instant leaps (no server round trip), one architecture for solo and multiplayer, no rewrite later. Replaces D-002's server-seated mount.
- **Alternatives:** server-created mount re-seated on each switch (laggy leaps); server mount + client prediction handoff (complex).
- **Tradeoffs:** other players see a riderless character until the remote-mount view is built; rewards rely on server sanity checks, not authoritative movement.
- **Date / Status:** 2026-10-20 · Accepted

## D-017 Herd animals never crash the rider
- **Decision:** Wild herd animals are pass-through for the rider. They gently sidestep only when overlapping the rider (not when merely ahead), so catching/targeting them is never frustrating. They steer around rocks and jump logs themselves.
- **Date / Status:** 2026-10-20 · Accepted (user approved)

## D-013 Tutorial befriending meter is earned, not distance-based
- **Decision:** Meter points: first steer 15, each rock passed 6, each log jumped 12, each optional treat 1.5; capped at 99 until the finish line, which completes it. Treats are a bonus, never required. Crashes restart at the current section's checkpoint; points already earned are kept.
- **Why:** User adjustment — the meter should reflect real tutorial progress.
- **Date / Status:** 2026-10-20 · Accepted

## D-014 Server validates tutorial completion
- **Decision:** `CompleteTutorial` is accepted only during an active Tutorial run lasting ≥ 85% of the fastest possible ride time, and only once.
- **Tradeoffs:** Can't verify the route itself (client-driven movement); reward is one-time and small.
- **Date / Status:** 2026-10-20 · Accepted

## D-015 Studio uses a separate DataStore
- **Decision:** Studio playtests save to `PlayerData_v1_Studio`; live servers use `PlayerData_v1`.
- **Why:** User requirement — testing and resets must never touch real player data.
- **Date / Status:** 2026-10-20 · Accepted

## D-011 Shared sanctuary hub, per-player contents shown client-side
- **Decision:** One shared placeholder sanctuary per server; each player's own habitat contents (zebra, sign text) render locally from their saved flags.
- **Why:** Personal home feel without building per-player plots yet (Phase 4 scope).
- **Tradeoffs:** Players don't see each other's animals; revisit with player-owned plots.
- **Date / Status:** 2026-10-20 · Accepted

## D-012 Separate onboarding flags
- **Decision:** `tutorialCompleted`, `starterZebraUnlocked`, `onboardingDismissed` are independent. Skipping sets dismissed + starter zebra only. Intro card shows only when all three are false; Skip prompt only while not completed and not dismissed.
- **Why:** User requirement — skipping must not count as completing the tutorial; returning players are never forced through it.
- **Date / Status:** 2026-10-20 · Accepted

## D-010 Gameplay first; art and UI deferred
- **Decision:** Priority order: (1) fun, responsive riding → (2) satisfying animal switching → (3) clear onboarding → (4) rewarding discovery loop → (5) zoo progression. Placeholder geometry and temporary UI only until Claude 3D Design models and ChatGPT UI designs are ready.
- **Why:** Phase 1 playtest felt like a basic obstacle course ([[13 - Playtesting]]).
- **Date / Status:** 2026-10-20 · Accepted

## D-007 Free horizontal steering (replaces lanes)
- **Decision:** Continuous left/right control on one wide track. Keyboard: hold A/D or ←/→. Touch: drag anywhere and the animal follows your thumb's sideways position. Gamepad: left stick.
- **Why:** More fluid and skillful, and essential for lining up leaps between animals. Lanes reduce switching to "press when an animal is in the next lane".
- **Alternatives:** Improved 3-lane movement — snappier but robotic, weak fit with switching.
- **Tradeoffs:** Collision and obstacle layout use free positions; touch needs careful tuning.
- **Date / Status:** 2026-10-20 · Accepted

## D-008 One button for jump and leap
- **Decision:** Space / tap / gamepad A leaps onto the highlighted target animal if one is in range; otherwise performs a normal hop.
- **Why:** Two controls total (steer + one button) — simple on mobile, easy to learn.
- **Date / Status:** 2026-10-20 · Accepted

## D-009 Befriending via taming ring
- **Decision:** While riding a wild animal, a taming ring fills. If it fills before the animal's temper maxes out, the species is befriended.
- **Open:** exact timings; presentation must keep the two meters easy to tell apart.
- **Date / Status:** 2026-10-20 · Accepted (design direction)

## D-001 Vault structure
- **Decision:** Numbered notes in `Stampede Sanctuary/`; cross-project notes ([[Developer Profile]], [[Lessons Learned]]) at vault root. Game Design Document = notes 01–08 (no separate GDD file, avoids duplication).
- **Why:** Matches the master brief; one source of truth per topic.
- **Alternatives:** single giant GDD file.
- **Date / Status:** 2026-10-20 · Accepted

## D-005 Source-of-truth split
- **Decision:** Obsidian = design, status, decisions, learning. Git repo = code, configs, build/test scripts, model sources. Studio place = what runs (saved separately). CLAUDE.md = operating rules only (~100–150 lines). Full table lives in CLAUDE.md.
- **One CLAUDE.md:** while sessions open in the vault, the vault's CLAUDE.md is the main one. When the code repo exists, its CLAUDE.md holds the coding and architecture rules and points to the vault, so rules aren't kept twice.
- **Why:** Avoid conflicting copies; keep context small.
- **Date / Status:** 2026-10-20 · Accepted

## D-006 Course generated from config at runtime (Phase 1)
- **Decision:** The test course, obstacles, scenery and lighting are built by `CourseBuilder` from `CourseConfig` when the server starts.
- **Why:** Obstacle layout is easy to tune in one file, Git-tracked, and the client reads the same data for collision checks.
- **Tradeoffs:** Course is invisible in Edit mode; hand-built art (Phase 5) will need a different approach, e.g. Studio-built scenery with config-driven obstacles.
- **Date / Status:** 2026-10-20 · Accepted (prototype only)

## D-002 Arcade movement for riding
- **Decision:** Client-driven arcade movement (scripted CFrame motion along the course, lane steering) instead of physics-based animal simulation.
- **Why:** Brief prioritizes responsive, reliable feel. Client ownership removes network lag from controls.
- **Alternatives:** Humanoid-based animals; physics constraints (LinearVelocity etc.).
- **Tradeoffs:** Must code our own collisions/obstacle checks; server must validate results later.
- **Affected:** Safari, animals, camera.
- **Implementation:** server seats the player on the zebra's `RiderSeat` and gives the client network ownership; client sets the zebra Root CFrame every physics step; obstacle hits are our own box checks, not physics.
- **Date / Status:** 2026-10-20 · Accepted (implemented in Phase 1)

## D-003 Code source of truth
- **Decision:** Code lives as files in a Git repo at `C:\Users\halll\dev\StampedeSanctuary`, synced to Studio with **Rojo 7.4.4**; Studio MCP used for building, testing, and reading output.
- **Why:** Git history and recovery only work on files. Scripts edited only inside Studio aren't tracked.
- **Alternatives:** Edit scripts directly in Studio via MCP, export occasionally (simpler setup, weaker history).
- **Tradeoffs:** Rojo adds one install + a plugin; you'd run `rojo serve` while working.
- **Location:** outside OneDrive, because OneDrive syncing can corrupt `.git` folders.
- **Date / Status:** 2026-10-20 · Accepted (approved by user)

## D-004 Part-built placeholder animals for Phase 1
- **Decision:** Build the Phase 1 zebra from simple Roblox parts.
- **Why:** Tests whether riding is fun without waiting on the 3D pipeline.
- **Tradeoffs:** Throwaway art; must keep mount-point layout consistent so real models drop in. Model contract is documented at the top of `ZebraBuilder.luau`.
- **Date / Status:** 2026-10-20 · Accepted
