# Stampede Sanctuary

Roblox animal-riding, collecting & zoo-building game.

Design docs live in the Obsidian vault: `C:\Users\halll\OneDrive\Desktop\roblox development\Roblox Development\Stampede Sanctuary\`

## Setup
1. Install tools: `aftman install` (provides Rojo 7.4.4)
2. In Roblox Studio, make sure the Rojo plugin is installed (`rojo plugin install`)

## Develop
1. `rojo serve`
2. In Studio: Plugins → Rojo → Connect
3. Edit files in `src/`; they sync live into Studio.

| Folder | Syncs to |
|---|---|
| `src/shared` | ReplicatedStorage.Shared |
| `src/server` | ServerScriptService.Server |
| `src/client` | StarterPlayer.StarterPlayerScripts.Client |

Other folders (`assets/`, `tools/`, `tests/`, `references/`) are not synced.

## Important
Git saves code, **not** the Studio place. Save/publish the place in Studio separately and keep backups outside this repo.
