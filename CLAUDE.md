# CLAUDE.md — Stampede Sanctuary code repo

The full operating manual (role, workflow, approvals, testing, docs rules) is in the Obsidian vault:
`C:\Users\halll\OneDrive\Desktop\roblox development\Roblox Development\CLAUDE.md`
Read it at session start. Project status: `...\Stampede Sanctuary\00 - Project Dashboard.md` and `16 - Session Handoff.md`. Only open other vault notes when the task needs them.

## This repo
- Rojo 7.4.4 (via `aftman.toml`). Mapping in `default.project.json`:
  - `src/shared` → ReplicatedStorage.Shared (configs, shared modules)
  - `src/server` → ServerScriptService.Server
  - `src/client` → StarterPlayer.StarterPlayerScripts.Client
- Files: `Name.luau` = ModuleScript, `Name.server.luau` = Script, `Name.client.luau` = LocalScript, `init.*.luau` makes a folder into that script.
- `assets/` (animals, environment, animations, audio), `tools/`, `tests/`, `references/` are not synced.

## Rules specific to code
- Code here is the source of truth for scripts. Never edit synced scripts directly in Studio — edit files; Rojo pushes them.
- Use Studio MCP for building objects, play-testing, and reading console output.
- Git does not save the Studio place. Remind the user to save/publish it separately.
- Commit after verified milestones; never commit secrets or `.rbxl` files.
- Balance values in config modules under `src/shared`.
