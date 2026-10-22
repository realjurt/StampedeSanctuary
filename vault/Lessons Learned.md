# Lessons Learned

Cross-project. Review the relevant entries before similar work.
Format: goal · what went wrong · cause · fix · prevention · workflow change? · evidence

## L-001 Too many meshes breaks Roblox import
- **Goal:** Import an AI-generated scene/model into Roblox (previous project).
- **What went wrong:** Import problems caused by thousands of individual meshes.
- **Cause:** Reported by you; exact details not documented.
- **Prevention:** Set asset budgets before generating; validate mesh/triangle count on every export; prefer modular props over one combined scene; test the full pipeline on one asset first.
- **Workflow change:** Yes — import checklist in [[07 - Art Direction]].
- **Evidence:** Your report (2026-10-20). Not independently reproduced.

## L-009 Seated humanoids still report move input; camera mode can't be scripted
- **Finding:** With `Humanoid.Sit = true` (rider welded to a mount), `Humanoid.MoveDirection` keeps updating, camera-relative, from keyboard/thumbstick/gamepad — usable for custom mount steering. `Player.DevComputerCameraMode` (e.g. Follow) can't be set from scripts at runtime.
- **Use:** Read MoveDirection for vehicles/mounts instead of custom input; build a scripted chase camera when follow behaviour is needed. For automated tests, drive `Humanoid:Move()` from a RenderStep bound after `Input` priority.
- **Evidence:** 2026-10-21, R0 spike.

## L-008 Testing server code with the Studio MCP tool
- **Problem:** `require` from the MCP tool's Server context gives a *separate* copy of a ModuleScript (module state not shared with the game's scripts); Edit-mode `GetAsync` returned a cached value right after an `UpdateAsync`, which looked like lost coins; kicking the only player ends the play session.
- **Prevention:** Drive real paths instead (keyboard input on real ProximityPrompts, instance attributes as Studio-only test hooks); read saves with `DataStoreGetOptions.UseCache = false`; after a kick, read results from Edit mode.
- **Evidence:** 2026-10-23, P3 testing.

## L-006 Don't give a method the same name as a nil-initialised field
- **Problem:** Adding a `leap()` method to RideController, which also has a `self.leap` field that is usually nil, made `self.leap` resolve to the method through the metatable → "attempt to index function". Caught in testing before commit.
- **Prevention:** Field names and method names must never overlap on metatable-based classes (nil fields fall through to methods). Name actions as verbs (`leapToTarget`) and state as nouns (`leap`, `leapState`).
- **Evidence:** 2026-10-21.

## L-007 Studio test tool can hide ProximityPrompts
- **Problem:** After tests changed the camera, the Studio MCP tool forced it back to Scriptable and parked it far away; ProximityPrompt visibility is camera-relative, so the gate prompt never appeared.
- **Prevention:** In automated tests, restore `CameraType = Custom` and `CameraSubject` before using prompts. Ride cleanup also resets `CameraSubject`.
- **Evidence:** 2026-10-21.

## L-005 Client-only parts welded to a character must not be the assembly root
- **Problem:** [[15 - Bug Tracker#BUG-003 Server didn't see the rider move on a client-only mount]] — a spike passed, but the real model's higher RootPriority broke replication.
- **Prevention:** When welding local-only parts to a player character, give them the lowest RootPriority and verify the *server-side* HumanoidRootPart position in a playtest, not just the client view. Spikes must match the real setup's properties.
- **Evidence:** Confirmed 2026-10-21.

## L-003 Teleporting a player's character from the server
- **Problem:** Server `PivotTo` on a client-owned character got overwritten ([[15 - Bug Tracker#BUG-001 Return to Sanctuary left player at course start]]).
- **Prevention:** For server teleports, briefly `SetNetworkOwner(nil)` on HumanoidRootPart, pivot, then return ownership. Always verify the landing position in a playtest.
- **Evidence:** Confirmed fix 2026-10-20.

## L-004 Don't depend on PlayerModule's location
- **Problem:** Current Roblox keeps `PlayerModule` under `StarterPlayer`, not `PlayerScripts`; waiting for it stalled ride start 5 s ([[15 - Bug Tracker#BUG-002 Runs started ~5 s after sitting on the zebra]]).
- **Prevention:** Avoid PlayerModule unless essential; prefer CAS high-priority binds + `GuiService.TouchControlsEnabled`. Never use long `WaitForChild` timeouts on engine-provided objects without measuring.
- **Evidence:** Confirmed 2026-10-20.

## L-002 Git commit messages with quotes break in PowerShell
- **Goal:** Commit with a multi-line message.
- **What went wrong:** Windows PowerShell 5.1 split a here-string containing `"double quotes"` into separate arguments; Git failed with "pathspec did not match".
- **Cause:** Confirmed — PowerShell 5.1 native-argument quoting.
- **Fix / prevention:** Write the message to a file in the scratchpad and use `git commit -F <file>`.
- **Workflow change:** Yes, for every commit message.
- **Evidence:** Failed and fixed commit `711dfa5` (2026-10-20).
