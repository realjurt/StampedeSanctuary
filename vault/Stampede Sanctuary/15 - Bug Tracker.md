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
