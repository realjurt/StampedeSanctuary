# Art Direction

Back to [[00 - Project Dashboard]]

## Animals — cute chunky voxel style
**Do:** blocky geometry · big recognizable heads · compact toy-like bodies · simple expressive eyes · short chunky legs · readable silhouettes · bright cheerful colors · minimal surface detail · consistent proportions.
**Avoid:** realistic fur · photoreal textures · heavy geometry · sharp scary features · mixed styles.
Original designs only — references guide principles, never copied.

## Asset priority order
1. Zebra → 2. Elephant → 3. Giraffe → 4. Acacia tree → 5. Rock → 6. Wooden barrier → 7. Small habitat → 8. Zoo entrance
**One at a time.** Validate the full pipeline with the zebra first.

## Pipeline (to verify)
Concept → 3D asset → Export → Roblox import → Rig/animate → Gameplay integration

- Planned modeling tool: **Claude 3D Design** — export formats **unverified**. Do not assume a 3D preview is an exportable model.
- Roblox accepts FBX, OBJ, glTF/GLB.
- Alternative available now: Roblox Studio MCP has mesh/model generation tools — worth comparing.

## Import checklist (per asset)
Mesh count · triangle count · texture sizes · file size · scale · orientation · materials · rigging needs · collision geometry.

## Budgets (starting proposal — tune after first import)
- Animal: ≤ 10 mesh parts, ≤ 5k triangles, ≤ 1 texture at 512px
- Prop: ≤ 3 mesh parts, ≤ 1.5k triangles
- Prefer modular props over one big combined scene. See [[Lessons Learned#L-001 Too many meshes breaks Roblox import]].

## Phase 1 note
Phase 1 uses **placeholder animals built from Roblox parts** so riding can be tested before the art pipeline exists. See [[11 - Decisions#D-004 Part-built placeholder animals for Phase 1]].
