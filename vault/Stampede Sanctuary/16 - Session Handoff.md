# Session Handoff

Back to [[00 - Project Dashboard]] · Overwritten at the end of each significant session. History lives in [[12 - Development Log]].

**Last updated:** 2026-10-21

## Worked on
R0 approved → **R1 Free Riding Feel**: zebra, giraffe and elephant now ride differently, with placeholder body feedback ([[11 - Decisions#D-028 R1 species handling & pushable obstacles|D-028]]). Two-client multiplayer test still outstanding ([[13 - Playtesting#Outstanding multiplayer test]]).

## Changed
Commit `bebccfb`: new `FreeRideMotion` (client), `PushableService` (server); `FreeRide` now runs three practice animals; `FreeRideConfig` per-species handling; crates/bushes in the test field; `AnimalAgent.poseFree` simplified. Straight safari, economy and saving untouched.
Your Studio save: unchanged — saves were blocked during tests.

## Tested / verified (by Claude, in Studio)
Species numbers, terrain, mount/dismount, elephant pushing (server-side), push validation, safari mode — details in [[12 - Development Log]].

## Not yet verified
How it feels · mobile touch · gamepad · two players seeing pushes.

## Waiting on you — R1 playtest
1. Play → walk north to the **RIDING TEST FIELD** sign. Three animals stand in a row: **giraffe** (left), **zebra** (middle), **elephant** (right).
2. Ride each (**E**). Compare: zebra quick and twitchy; giraffe slow to build, wide turns, big floaty jump; elephant slow and heavy, keeps turning a moment after you let go.
3. On the elephant, ride straight ahead into the **row of crates/bushes** (also a crate cluster by the big hill) — they get shoved aside. Zebra and giraffe are blocked by them (jump them).
4. Watch the bodies: lean in turns, walk → gallop change, nose up when speeding up, squash on landing.
5. Tell me per animal: too fast/slow, too twitchy/sluggish, jump feel, anything still stiff.
Don't start R2 until approved.

## Next recommended task
Tune from feedback → R2 (savannah + roaming animals).

## Testing tips
- Values to tune: `src/shared/Config/FreeRideConfig.luau` (one block per species).
- Session start: Claude runs `rojo serve`; you click **Connect** in Studio's Rojo plugin.
- Known unrelated console warning: `rbxassetid://203785492` asset-type mismatch.
