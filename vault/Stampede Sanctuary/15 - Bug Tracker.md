# Bug Tracker

Back to [[00 - Project Dashboard]] · Only significant bugs. Never mark Fixed without test evidence.

## Template
```
### BUG-000 Short title
- System:
- Status: Open / Investigating / Fixed (verified) / Won't fix
- Repro steps:
- Suspected cause:
- Confirmed root cause:
- Fix attempted:
- Test results:
```

## Open
_None._

## Closed
### BUG-004 Free-ride camera shake
- **Reported:** 2026-10-22 by you after the R1 tuning pass ("camera feels shaky").
- **Cause (confirmed by measurement):** ride motion stepped in PreSimulation (fixed 1/240 s physics slices) → animal moved 0.575 / 0.767 / 0.958 studs on alternating frames at a steady gallop; camera also aimed at the bobbing body.
- **Fix:** `8030a42` — ride step moved to a render step just before the camera; camera aims at the motion path with eased height (`FreeRideConfig.camera.heightFollowRate`). See [[Lessons Learned#L-010 Step script-driven movement per rendered frame, not in PreSimulation|L-010]].
- **Verified:** Studio, real keys: zebra uneven frames 17/92 → 1/92; camera aim wobble 0.58° → 0.08°/frame; elephant crate pushes still reach the server; jump/landing OK. Landing shake is intentional and unchanged. You confirmed the camera feels steady (2026-10-22).

### BUG-003 Server didn't see the rider move on a client-only mount
- System: RideController / AnimalAgent · Status: Fixed (verified 2026-10-21)
- Root cause: the mount's Root had `RootPriority 10`, making a client-only part the assembly root; physics replication is sent relative to the root, which doesn't exist on the server.
- Fix: ridden mounts set `RootPriority -127` so HumanoidRootPart stays root. Test: server saw the rider advance ~35 studs/s.

### BUG-001 Return to Sanctuary left player at course start
- System: SafariService · Status: Fixed (verified 2026-10-20)
- Root cause: client owns its character's physics; its next position update overwrote the server's `PivotTo`.
- Fix: server takes network ownership of HumanoidRootPart, teleports, returns ownership after 0.3 s. Test: lands at (-400, 3.3, 50) every time.

### BUG-002 Runs started ~5 s after sitting on the zebra
- System: RideController · Status: Fixed (verified 2026-10-20)
- Root cause: code waited up to 5 s for `PlayerScripts.PlayerModule`, which current Roblox keeps under `StarterPlayer`; requiring it also yielded on first use.
- Fix: removed the PlayerModule dependency; only `GuiService.TouchControlsEnabled` is toggled. Test: "Ready..." at 0.0 s, "Go!" at 1.1 s.
