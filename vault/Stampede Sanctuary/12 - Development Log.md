# Development Log

Back to [[00 - Project Dashboard]] · Newest first. One short entry per significant session.

## 2026-10-21 — R0 approved → R1: species handling
- R0 playtest: approved (directional riding a much better foundation; exploring/jumping work; camera stable; zebra looked stiff) — [[13 - Playtesting]].
- Commit `bebccfb` ([[11 - Decisions#D-028 R1 species handling & pushable obstacles|D-028]]): `FreeRideMotion` (per-mount motion + placeholder body feedback), practice zebra/giraffe/elephant, `PushableService` + crates/bushes in the test field; `FreeRideConfig` per-species handling.
- Verified in Studio — deterministic sim of the real motion code on a flat test plate: time to 90 % top speed zebra 0.95 s / giraffe 2.35 s / elephant 2.95 s; 90° turn at speed settles in 0.63 / 1.07 / 1.40 s, no overshoot; jump height 6.7 / 9.7 / 4.3 studs, airtime 0.63 / 1.23 / ~0.5 s; top speed 46 / 52 / 36. Field geometry sim: zebra + giraffe blocked by crates, stump and rock; all three step the 1.5/2/4 ledge stairs and climb the hill; jump clears the stump; elephant ploughs through crates, blocked by rock and stump unless it jumps from close in.
- Verified with real keyboard input: E mounts each species (seated, HUD, species hint toast), W/D/Space ride, turn and jump (lean, nose-up/down pitch, ~0.25-stud landing squash seen in samples), E dismounts (standing, normal camera), on foot walks 17 studs/s and jumps; elephant ride → server saw the rider 76 studs on and moved 3 pushables 5–10 studs, back home after 10 s; pushes on foot / bad direction / non-pushable rejected; safari course still starts and runs, practice prompts hidden during it. No new console errors. Saves blocked during tests — your save unchanged.
- Fixed during testing: elephant stepped over 3-stud stumps (step height 3 → 2.5); elephant jump window too tight (jump 3.8 → 4.5); ball bushes rolled 119 studs (now blocks).
- Not verified: how it feels, mobile touch, gamepad, multiplayer view of pushes.

## 2026-10-21 — R0: directional riding prototype
- D-027 approved with adjustments (simpler first Wild Ride, starter zebra within ~10 s, ride tamed animal home, progress resets when thrown, straight course kept for testing). Commit `0216979`: `FreeRide`, `OpenWorldBuilder`, `FreeRideConfig`; `AnimalAgent.newAt/poseFree/attachRider`.
- Verified in Studio (keyboard + scripted move input on the real controller): `MoveDirection` updates while seated (camera-relative); mount/ride/get off/remount; ~46 studs/s top speed; turning; server saw the rider move (10.7 studs in 0.5 s); stops at a stump, backs up with S, jumps it with Space (~6.5 studs air); climbs a 6-stud hill smoothly; steps up 2- and 4-stud ledge steps; blocked head-on by a rock; stops at the field edge; on foot after dismount: walk 17 studs/s, jump OK, normal camera; straight safari still starts and steers. Fixed during testing: reversed hill ramps, stump not blocking (rounded top), riding off the world edge, "diagonal back" reversing instead of turning. Saves blocked during tests — your save unchanged.
- Not verified: mobile touch (thumbstick, camera drag, JUMP), gamepad, mouse camera drag, feel.

## 2026-10-21 — Open-world redesign planned (no code)
- User: core gameplay feels like an obstacle-course prototype; wants open-world exploring, roaming animals, interactive taming. Claude inspected riding/herd/safari code (all course-space) and wrote [[18 - Open-World Redesign Plan]] (D-027, approved 2026-10-21): R0 spike → R1 free riding → R2 savannah + roaming animals → R3 Wild Ride taming → R4 full loop. Awaiting approval.

## 2026-10-21 — P4 approved; multiplayer test prepared
- User approved P4 core gameplay after playtest. Asked for a real two-client test before P5.
- Claude's Studio MCP can only start single-player Play (no "Clients and Servers"), so the test can't be run by Claude; wrote a step-by-step procedure in [[13 - Playtesting#Outstanding multiplayer test]]. Multiplayer **not verified**.
- Code review: other riders' mounts are not rendered on other clients (D-016 "remote-mount view" never built) → step 8 expected to fail. No code changed.

## 2026-10-21 — P4: training machine, upgrades, starter reward
- User approved P4 with decisions (grip curve to ×2.0 at stamina 100, $300 one-time starter reward, BOOST optional). Commit `dfbd48d`: new `MachineService`, `UpgradeService` (server), `TrainingView` (client), `TrainingConfig`, shared `Format`; data v4 (`machineLevel`, `penLevel`, `starterRewardClaimed`); `TamingConfig.gripCurve`; pen 28 × 38 / 4 × 3 grid; DEPOSIT ANIMALS sign, pen upgrade plaque, machine kiosk; `UiKit.floatText` (moved from PenView); HUD stamina shows one decimal. [[11 - Decisions#D-026 P4 Training machine & upgrades plan|D-026]].
- Verified in Studio (real prompts via keyboard, seeded saves): deposit sign "🐾 3 to deposit" → deposit gave "STARTER BONUS +$300" (saved, flag true); second deposit later gave no bonus (coins only rose by income); buy machine $300 → machine built, kiosk "Lv 1 → 2 · $1,500"; Train prompt seats owner, panel shows stamina/grip/"Next: Elephant ⚡25", stamina +0.2 per tick; BOOST hit outside a window → "miss"; hit inside → ×2 (2.4 gained in 3 s at Lv1); second hit same window ignored; Space during a window boosts and stays seated, Space otherwise leaves; leaving stops gains; dummy forced onto seat → server ejected it, owner gained nothing; machine L2+L3 and pen L2+L3 bought (coins deducted, pen prompt hidden at max, 12 slots); L4 with too few coins → "Need $5,608 more!", nothing changed; rejoin → machine Lv3, pen Lv3, stamina 84.8 restored; 12 animals incl. 4 elephants fit the pen; other plots' prompts hidden; safari ride starts, purchase/Train prompts hidden on safari; grip curve values exact. No new console errors. Studio save restored to pre-test state.
- Not verified: two real clients; mobile layout of the training panel / prompts; gamepad; feel of BOOST timing and training speed.

## 2026-10-23 — P3: deposits & passive income
- User approved P2 after playtest and P3 plan with adjustments. Commit `89bc9e6`: `DepositService`, `PenService`, `IncomeService`, client `PenView`; `AnimalCollection` deposit/income helpers; `PlayerDataService` `saveNow`/`peek`, failed-save retry, leave/shutdown wait for in-flight saves; pen 28 studs with deposit prompt. [[11 - Decisions#D-025 P3 Deposit & income plan|D-025]].
- Verified in Studio (real prompts via keyboard, seeded saves): deposit 3 → card "3 ANIMALS DEPOSITED! +$8/s", animals pop in one by one, sign $8/s, coins +8/s (88→112 in 3 s); pen rebuilt on rejoin without replaying reveal, cleared + "Empty Plot" on leave; coins persisted on leave (392 → 400 stored); 7 carried + 3 pen → 5 moved, 2 stay carried, next press "pen is full (8/8)"; re-enabled prompt on another player's plot → rejected `notOwner`, nothing changed; simulated failed save → warned, leave-save retry stored 8 pen/2 carried, 10 unique records; kick during a 3 s save → all 3 deposits saved, no duplicates; forced second trigger during save → ignored (busy); safari ride starts, prompt hidden on safari, income continues. No new errors. Studio save restored to pre-test state.
- Lesson L-008 (MCP require isolation, Edit-mode GetAsync cache).
- Not verified: two real clients; mobile prompt/card layout; feel of reveal timing.

## 2026-10-22 — P2: animal taming
- Commit `ba31a5a`. New `TamingConfig`, `AnimalCollection`, `TameService`; `SafariService` tracks current mount + tamed set and gates switches by stamina; data v3 (`animals`, `nextAnimalId`); client grip bar, tame bar, ⚡ labels on wild animals, locked target, carried pill. [[11 - Decisions#D-024 P2 Taming design|D-024]].
- Verified in Studio (real remotes, live server): rejections for no mount, number id, long id, unknown id, elephant switch (stamina), premature tame, non-current member, duplicate, re-tame after Ride again, 8th animal (full); 7 valid tames; v3 save had 7 unique records, flags intact; rejoin showed 7/7; crash mid-tame captured nothing. Live leap → tame bar + labels seen on screen. Successful tame UI on screen not captured (scripted steering couldn't survive 4 s) — playtest item. Test records cleared afterwards.

## 2026-10-22 — P1: player plots + coins/stamina saving
- Commit `bbecf00`. New `PlotService`, `EconomyConfig`, `CurrencyHud`; `PlayerDataService` v2; plots built in `SanctuaryBuilder`; "YOUR PLOT" marker in `SanctuaryView`. See [[11 - Decisions#D-023 Progression plan direction approved; P1 plots + coins/stamina saving built|D-023]].
- Verified in Studio: real v1 save loaded with all flags; v2 written on exit; coins 42 / stamina 33.5 round-tripped; plot claim/release/reuse/full-server with 6 simulated players; ride regression OK; no new errors. User's Studio save restored to coins 0 / stamina 20.

## 2026-10-22 — Stud texture polish
- User references: L-bevel Roblox-stud texture on colored panels/buttons. Commit `ba7651e`: generated stud tile (`assets/ui/stud.png`, `tools/make_stud.py`), uploaded as `rbxassetid://115925519940442`; tiled on all surfaces + bar fills (0.58 transparency), faint on dark panels/insets; darker bottom lip on surfaces.
- Verified via screenshots (Index, HUD, end panel); no game errors.

## 2026-10-21 — UI restyle toward reference + Animal Index (UI-2)
- Feedback: UI-1 didn't look like the reference. Commit `d4570d3`: heavier text outlines, brighter headers/gloss, larger windows, lighter panel + dark insets, "-- SECTION --" titles, floating HUD ability text; Animal Index in Pet Index layout (banner, ViewportFrame cards/silhouettes, detail panel with real stats, area + Discovered bars); server publishes `Discovered` attribute.
- Verified via screenshots: Index matches reference layout; HUD; no errors.

## 2026-10-21 — UI-1: design system + Safari HUD
- Commit `a82d029`: UiKit rebuilt as the Outlined Radiance design system (surfaces, CanvasGroup-clipped gloss stripes, windows, buttons with hover/press, bars, keycaps, side buttons, toasts, viewport autoscale, pop animations). New Safari HUD; `MenuController` (Index/Shop/Settings "Coming soon"), menus pause the ride; sanctuary side menu; intro + reward cards as windows.
- Verified in Studio with screenshots: side buttons, Shop window, HUD layout; menu pauses ride (0 movement) and resumes; tutorial befriending bar; no errors.
- Lesson: UIGradient stripe patterns don't keep a fixed angle across aspect ratios — rotated frames in a CanvasGroup do.
- Not verified: mobile layout/scale on a device, gamepad hint swap, end panel look.

## 2026-10-21 — Separate jump/leap controls + first-leap lesson
- Commit `0688d5c` (D-019, D-020, D-021): ride-owned simulation clock steps herds; Space/A jump only, F/X leap only, mobile JUMP/LEAP buttons (LEAP hidden on tutorial course), tap-to-jump removed; `LeapTutorial` slow-motion lesson; `leapTutorialDone` saved; `CompleteLeapTutorial` validation; `getRun` returns switch count.
- Verified (harness + real run): herd clock runs at 0.198× real time in slow motion (in sync); lesson triggers on first target with highlight + "Press F to leap onto the Giraffe!"; Space with target only jumps; F with target leaps, lesson completes, speed restored; F without target does nothing; timeout, lost target, crash, restart, exit and Backspace skip all restore speed and clean up. Server under 0.3 s simulated lag: "skipped" outside a run, "learned" before a switch, bad reason → rejected; switch + "learned" → saved; persists after restart (lesson not shown again). Tutorial course unchanged. No errors. Studio lag reset to 0; Studio save's `leapTutorialDone` set back to false for the playtest.
- Found + fixed before commit: method/field name clash (`leap`) — L-006. Test-only: prompts hidden by tool-forced camera — L-007.
- Not verified: mobile buttons on a touch device/emulator, gamepad X, how the slow-motion moment feels.

## 2026-10-21 — Milestone 5: animal switching
- Commit `3d1bb37` (D-018): leap state with homing arc, landing hand-off (temper reset, boost, grace), old mount released to herd, target Highlight + labelled ring (side reach 14 → 11), species handling + abilities (elephant smashes Rocks, giraffe high jump), shorter temper, server `SwitchMount` validation + `RestartRun`.
- Verified by Claude (test ride harness + real run): no target → normal hop; target + highlight + label; leap ~27 frames, 7.2-stud arc; landed on Giraffe with temper 0.8 → 0, boost, grace, rider welded, old mount released; elephant leap + rock smash (hidden locally, run continues); Ride again → Zebra at start, rocks restored, herds reset; cleanup leaves 0 animals. Server: unknown id / too-early far member / bad payload / reused member / same member right after restart all rejected; valid near member accepted → MountSpecies=Elephant; restart → Zebra. Tutorial unchanged, no herds there. No errors.
- Test-only finding: Studio MCP tool forces the camera back to Scriptable, which hides ProximityPrompts (visibility is camera-relative). Ride cleanup now also resets `CameraSubject`.
- Not verified: feel/timing of leaps in real play, giraffe boulder clears in real play, touch tap-to-leap, other players' view.

## 2026-10-21 — Milestone 4: client-side mounts, herds, targeting
- Spike: character welded to a client-only part replicates position + Sit; the part itself doesn't replicate → D-016 architecture; D-017 herds never crash the rider.
- `d13f01d` Step A: AnimalAgent/AnimalBuilder (Zebra, Elephant, Giraffe), client-side mount with welded rider, server run-state attributes. Found + fixed BUG-003 (RootPriority). Regression-verified: Savannah ride, steering, crash, end panel, R, return teleport, tutorial prompts/checkpoints/meter.
- `869bf6c` Step B: HerdSchedule (verified identical server/client for a seed), HerdController brain, TargetIndicator.
- Verified: herds spawn/despawn, max 8 active seen (cap 12), species mix, lane always ≥ 22.8 studs open, rock overlaps 0 after fixes (look-ahead scales with speed, obstacle avoidance applied last, spawn clearance ahead of obstacles), target picked when rider 15 studs behind an animal, none when not running, herds reset on Ride again, full cleanup, 60 FPS (worst 19 ms), no errors.
- Fixed during testing: herds uncatchable (now amble when far ahead), rock pass-through, label child named "Name".
- Not verified: how herds feel, target ring look in-game during a real ride, mobile perf, multiplayer view of others' mounts (not built yet).

## 2026-10-20 — Shorter walk to the Safari Gate
- Playtest: tutorial feels good; walk to gate too long ([[13 - Playtesting]]).
- Gate moved 100 → 60 studs from spawn on a straight path, habitat alongside; entrance arch lowered so the SAFARI sign is visible from spawn.
- Verified: spawn at (-400, 3.3, 50); holding W shows the gate prompt after ~3 s (~4 s to reach it, ~5–6 s with the intro card); E starts a run (Savannah for this completed save); return to sanctuary works; no errors. Tutorial routing unchanged (not re-run — would need a data reset).

## 2026-10-20 — Temporary dev reset command
- `/resetmydata confirm` (developer UserId only) resets own save and kicks to rejoin. Verified: without "confirm" no change; with confirm → stored data back to defaults (not re-saved over), rejoin shows intro card, ghost zebra, "Start Tutorial Safari". Removal tracked in Phase 7.

## 2026-10-20 — Saving verified; Milestone 3 (tutorial safari) built
- Saving verified with Studio API access: skip → restart → flags persisted, no intro, zebra in habitat. Studio now uses its own DataStore (D-015); Studio test save reset afterwards.
- Commit `c7ccf15`: tutorial course + TutorialDirector, earned befriending meter (D-013), checkpoints, reward card, server completion validation (D-014), ghost zebra + goal steps + clearer intro (M2 feedback).
- Verified by Claude: fake completion outside a run rejected; early completion during run rejected; gate routes new players to Tutorial; crash → "Oops" → respawn at section checkpoint; points for steering/dodges/jumps/treats; full run → 100% + reward card + server sets T=true/Z=true/D=false; zebra pops in only after returning; returning player: no intro, "Start Safari" → Savannah; no script errors.
- Not verified: feel/pacing (your playtest), touch controls, tutorial UI on small screens.

## 2026-10-20 — Milestone 2 (sanctuary & Safari Gate) built
- Commit `d591747`: placeholder sanctuary hub, intro card, goal line, gate arrow, Start/Skip prompts, SafariService run lifecycle, Ride again / Back to Sanctuary, PlayerDataService with separate onboarding flags (D-011, D-012), course registry.
- Verified by Claude: spawn in sanctuary (no auto-ride), intro shows for new players, walking, gate E starts run instantly, R = ride again, return teleports to sanctuary, death mid-run → clean respawn in sanctuary, skip → flags T=false/Z=true/D=true + habitat zebra + sign + card closes, no script errors.
- Fixed during testing: BUG-001 teleport race, BUG-002 5 s ride start delay, cut-off goal text, banner hidden by posts, intro card lingering after skip.
- Not verified: saving across sessions (Studio API access off), mobile layout, multiple players.

## 2026-10-20 — Redesign approved; Milestone 1 (ride feel) built
- Playtest verdict on Phase 1: boring obstacle course, no onboarding → redesign plan approved (D-007 to D-010).
- Commit `79567ba`: lanes → free steering (keys, stick, touch drag, tap = jump) on a 44-stud track; speed ramps 28→50 over 10 s; gait phase tied to distance; body pitch/bob, turn yaw/lean; camera pull-back + FOV 68→84 with speed, lateral lag, rumble; hoof dust; track bands + edge tufts; crash stops instantly; new obstacle layout with gaps and slaloms.
- Verified by Claude: steering responds smoothly both ways, speed ramp, FOV change, jump, crash detection, no script errors.
- Not verified: feel (your playtest), touch drag/tap, gamepad.

## 2026-10-20 — Phase 1 zebra prototype built
- Added configs, course builder, block zebra, ride service, ride controller, placeholder HUD (commit `711dfa5`).
- Verified by Claude in a Studio playtest: player auto-seated on zebra; forward run; A steers to left lane; Space jump reaches ~7 studs; crash on first rock; crash → Ready → Go restart loop; no script errors.
- Fixed: camera raised so the rider no longer blocks the track ahead; camera re-asserts itself if another script resets it.
- Not verified: game feel, full course completion, temper bucking off, touch controls, multiplayer.
- Known: after a crash the zebra skids through the obstacle (cosmetic).

## 2026-10-20 — Code repo created
- Repo at `C:\Users\halll\dev\StampedeSanctuary` (outside OneDrive), branch `main`.
- Rojo 7.4.4 via Aftman; `default.project.json` maps `src/shared|server|client`. `rojo build` succeeds. Studio plugin installed.
- Repo `CLAUDE.md` holds code rules only and points to the vault manual (D-005).
- Git identity set to realjurt; first commit `c8ae952`.
- Rojo live sync verified with a temporary test module: create, edit and delete all reached Studio. Test file removed.

## 2026-10-20 — Documentation system finalized
- Rewrote `CLAUDE.md` as a lean operating manual (~105 lines): source-of-truth table, coding standards, testing rules, token efficiency, pre-`/clear` checklist.
- Added [[Learning Index]], ChatGPT UI brief template ([[08 - UI Design]]), rarity placeholder ([[03 - Animal System]]).
- Accepted [[11 - Decisions#D-005 Source-of-truth split]].
- Audit: no duplicate notes; `Welcome.md` is Obsidian's default note, left untouched.

## 2026-10-20 — Phase 0 kickoff
- Inspected workspace: vault was fresh (only `Welcome.md`); sibling `baseplate` folder empty; no Color Survival files found on Desktop.
- Roblox Studio MCP connected to "baseplate" place (empty, no scripts).
- `obsidian` MCP configured in settings but not loading; using direct file access instead.
- Created project notes 00–16, [[Developer Profile]], [[Lessons Learned]], and `CLAUDE.md`.
- Proposed decisions D-002 to D-004.
