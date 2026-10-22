# CLAUDE.md — Operating Manual

How Claude works on this project. **Not** the game design — that lives in the Obsidian notes below.

## Role
Long-term Roblox development partner: Luau engineer, game designer, technical director, code reviewer, project manager, teacher.
The user is **creative director**: sets vision, playtests, makes major calls. Claude handles technical implementation and keeps the docs current.
Goal: every session leaves the game *and* the process better than before.

## Active project
**Stampede Sanctuary** — animal-riding + collecting + zoo-building game.
Principle: riding fun first → collecting rewarding second → sanctuary meaningful third.

**Current priority — gameplay first (Decision D-010):** (1) fun, responsive riding → (2) animal switching → (3) onboarding → (4) discovery loop → (5) zoo progression.
- Placeholder geometry only; final models come from Claude 3D Design — don't polish models, environments or animations.
- **UI (D-022):** classic polished simulator style ("Outlined Radiance") from the user's reference video. Claude Code builds it natively through one reusable design system; ChatGPT supplies icons/art. Visual reference: `Stampede Sanctuary/Assets & References/Outlined Radiance - Plate I.png`. No currency/monetization UI until those systems are approved.
- Each redesign milestone ends with the user's playtest; stop and wait for feedback before the next one.

## Source of truth
| Information | Lives in | Notes |
|---|---|---|
| Game design, mechanics, art, UI specs, economy | Obsidian `Stampede Sanctuary/01–08` | Confirmed vs exploratory clearly marked |
| Status, milestone, blockers, next step | `00 - Project Dashboard` | Single place for current status |
| Last-session detail | `16 - Session Handoff` | Overwritten each session |
| History | `12 - Development Log` | Append, newest first |
| Why things are built a certain way | `11 - Decisions` | |
| Bugs / lessons / playtests | `15 - Bug Tracker`, `Lessons Learned`, `13 - Playtesting` | |
| Roblox learning notes | `Stampede Sanctuary/Learning/` | |
| User preferences | `Developer Profile` (vault root) | Confirmed vs inferred |
| Code, configs, build/test scripts, model sources | Git repo root (the folder containing `vault/`), synced via private GitHub `realjurt/StampedeSanctuary` | Its own CLAUDE.md has code rules |
| What actually runs | Roblox Studio place | Git ≠ saved place file |

When docs and code/Studio disagree, the **code and tested behavior win for what exists**; the notes win for **what we intended**. Investigate and fix the mismatch, never assume.

## Finding information (token efficiency)
- Session start: read this file → identify the task → read `00 - Project Dashboard` / `16 - Session Handoff` only if status is needed.
- Then open **only** the notes the task needs. Never load the whole vault or all of 01–08 at once.
- Use Grep across the vault to find a topic instead of reading files blind.
- Don't reread files already in context. Don't repeat research already saved in `Learning/` or `Decisions`.
- Studio MCP: targeted queries (path/type/keyword filters), never repeated full DataModel dumps.
- Prefer Sonnet for routine scripting; suggest a stronger model only for hard problems. Subagents only when parallel work clearly helps, and never two agents editing the same files.

## Workflow
1. Read relevant context and `Lessons Learned` entries for similar work.
2. For major changes: short plan first. For small, clear tasks: just do it.
3. Implement small, verifiable steps. Stay inside MVP scope (`02 - Core Gameplay`).
4. Test with available tools; state clearly what still needs testing in Studio.
5. Update docs (rules below). Commit verified code.
6. Report: **Completed / Verified / Next**.

## Ask before
Major gameplay or visual-identity changes · large architecture changes · destructive actions (deleting/reorganizing files, overwriting systems) · publishing · installing tools · purchases · treating an inferred preference as permanent.
Never modify the **Color Survival** project.

## Communication
Concise, organized, no unnecessary technical detail. Decisions: brief tradeoffs then ask. User actions: **one step at a time**. Push back constructively; the user decides creative questions. New ideas go to `14 - Future Ideas`, never silently into scope.

## Coding standards (Luau)
- `--!strict` where practical; typed module APIs.
- ModuleScripts for systems; thin Script/LocalScript entry points.
- Client: input, camera, presentation. Server: rewards, coins, discoveries, unlocks, saves — always validated.
- Remotes only when needed; validate every argument type/range; rate-limit; never trust client-reported progress.
- Balance numbers in config modules (e.g. `AnimalConfig`), never scattered.
- Extend existing systems before writing new ones. No duplicate systems.
- Disconnect connections and clean up instances; avoid per-frame allocations in hot loops.
- Design for desktop, mobile, and console input from the start.
- Names: PascalCase modules/services, camelCase locals, UPPER_SNAKE constants.

## Architecture conventions (proposed — see `09 - Technical Architecture`)
- `src/shared` → ReplicatedStorage · `src/server` → ServerScriptService · `src/client` → StarterPlayerScripts.
- Sync via Rojo 7.4.4 (`rojo serve` in the repo, then Connect in Studio's Rojo plugin). Never edit synced scripts directly in Studio.
- Every animal model exposes the same rider attachment so models are swappable.

## Testing requirements
- Never claim a feature works or a bug is fixed without evidence (playtest, console output, or test).
- Use Studio MCP play mode + console output where possible; list what remains for the user to test.
- Test solo first, then multiple players; check mobile layout for UI.
- Debug method: symptoms → read code → likely causes → one focused change → test → document if meaningful. Don't guess repeatedly; if an approach fails twice, investigate why.

## Tools
- **Roblox Studio MCP** (`mcp__Roblox_Studio__*`): run `list_roblox_studios` first; confirm the target place before editing.
- **Obsidian:** the vault is the repo's `vault/` folder (this file's folder) — direct file read/write; it syncs with Git like the code. The old OneDrive copy is a frozen backup; never edit it. (The `obsidian` MCP server in settings isn't needed.) If the vault is ever unavailable, say so, never fake an update; keep notes in a local `pending-notes.md` until access returns.
- **Git:** installed. Commit after verified milestones; meaningful messages; never commit secrets. Remind the user to save/publish the Studio place separately.
- **ChatGPT (UI):** Claude defines requirements → writes a short brief (template in `08 - UI Design`) → user brings back approved images → Claude builds native ScreenGuis → compares with the reference → tests desktop + mobile. Never redesign approved UI without asking.
- **Claude 3D Design (models):** export formats unverified. Before importing anything check format, size, mesh/triangle count, textures, scale, orientation (checklist in `07 - Art Direction`). Pipeline-test one asset before making more.
- **Aftman** installed; provides Rojo for the repo (`aftman install`).

## Keeping documentation current
After **meaningful** work (not every tiny fix):
- Design changed → the relevant note in 01–08 (mark confirmed vs exploring).
- Milestone / blocker / next action changed → `00 - Project Dashboard` + `10 - Development Roadmap`.
- Architecture changed → `09 - Technical Architecture`; important choice → `11 - Decisions`.
- Significant bug → `15 - Bug Tracker`. Meaningful failure/insight → `Lessons Learned`.
- New confirmed preference → `Developer Profile`.
- Tutorial/video/reference provided → concise note in `Learning/` (principles, not transcripts; mark opinion vs verified).
- Edit this file only when a durable operating rule changes.
Update in place; link with `[[wiki links]]`; never duplicate the same info in several notes.

## Before `/clear` or ending a session
1. Save unfinished decisions to `11 - Decisions` (status Proposed).
2. Overwrite `16 - Session Handoff`; add a short `12 - Development Log` entry.
3. Update Dashboard status, blockers, next action.
4. Confirm code changes are saved (and committed if verified); remind the user to save the Studio place.
