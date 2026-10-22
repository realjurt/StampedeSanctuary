# Development Roadmap

Back to [[00 - Project Dashboard]]

**Current phase:** Redesign — Milestone 1 (ride feel)
**Rule:** finish a playable, fun core loop before adding features. Priority: [[11 - Decisions#D-010 Gameplay first; art and UI deferred]].

## Progression milestones ([[17 - Reference Game Analysis]] §5) — direction approved 2026-10-22, authorized one at a time
- [ ] **P1 Plots & data v2** — built `bbecf00` ([[11 - Decisions#D-023 Progression plan direction approved; P1 plots + coins/stamina saving built|D-023]]); solo playtest ✓; **two-real-client plot test outstanding**
- [x] **P2 Taming** — built `ba31a5a` ([[11 - Decisions#D-024 P2 Taming design|D-024]]), approved by your playtest
- [x] **P3 Deposit & income** — built `89bc9e6` ([[11 - Decisions#D-025 P3 Deposit & income plan|D-025]]), approved by your playtest
- [x] **P4 Training machine & upgrades** — built `dfbd48d` ([[11 - Decisions#D-026 P4 Training machine & upgrades plan|D-026]]), awaiting your playtest
- [ ] **Open-world redesign** ([[18 - Open-World Redesign Plan]], D-027): R0 directional riding `0216979` (playtested ✓) → R1 species handling `bebccfb` (awaiting playtest) → R2 → R3 → R4. P5+ on hold.
- [ ] P5 Goals tutorial · P6 Collection & selling · P7 Rarity/zones/events · P8 Auras/fuse/leaderboard — not yet authorized

## Redesign milestones (approved 2026-10-20, reordered same day: onboarding before switching) — each ends with your playtest
1. [ ] **Ride feel:** free steering, wide track, gradual speed, camera, believable gait, simple crash feedback → *is steering fun?* — built `79567ba`, playtest feedback pending
2. [ ] **Onboarding A — Sanctuary & Gate:** spawn in placeholder sanctuary, intro card, Safari Gate prompt, return to sanctuary, saved tutorial flag — built `d591747`, playtested ✓, saving verified ✓
3. [ ] **Onboarding B — Tutorial safari:** steer (optional treats) → dodge → jump sections, section checkpoints, earned befriending meter, reserved switch step, first zebra reward + habitat pop-in — built `c7ccf15`, playtested ✓ (feels good; gate walk shortened)
4. [ ] **Client-owned riding + herd animals** running alongside → *do herds feel natural?* — built `d13f01d` + `869bf6c`, playtested ✓
   - [ ] Before any multiplayer playtest: render other riders' mounts locally (D-016)
5. [ ] **Leap / switch:** targeting, arc, camera, temper handoff → *is switching exciting?* — built `3d1bb37`, awaiting your playtest
   - [ ] Enable the reserved tutorial switch step (needs a companion animal in the tutorial)
   - [ ] **UI-1:** design system + Safari HUD (D-022) — built `a82d029`, awaiting your review
   - [ ] **UI-2:** Animal Index (D-022) — built `d4570d3` with a closer-to-reference restyle, awaiting your review
6. [ ] **Course variety:** segments, rolling hills, herd/obstacle patterns
7. [ ] **Discovery loop:** taming ring for new species, reward card, Animal Book data

The phase list below is the original plan; the milestones above supersede Phases 2–4 ordering.

## Phase 0 — Project setup
- [x] Inspect workspace & tools
- [x] Verify Roblox Studio MCP
- [x] Verify vault access (direct files)
- [x] Save design into linked vault notes
- [x] CLAUDE.md
- [x] Choose code folder + init Git
- [x] Decide Rojo vs Studio-only ([[11 - Decisions#D-003 Code source of truth]]) → Rojo
- [x] Set Git name/email + first commit
- [x] Verify Rojo live sync with Studio
- [ ] Verify Claude 3D Design export (user to check)

## Phase 1 — Animal-riding prototype
**Question: Is riding enjoyable?**
- [x] Short straight test course (Sunny Savannah colors) — 950 studs, 3 lanes, generated from `CourseConfig`
- [x] One part-built blocky zebra
- [x] Auto-forward movement
- [x] Lane steering (keyboard verified; touch swipe/tap written but untested)
- [x] Jump
- [x] Follow camera
- [x] Placeholder temper meter
- [x] Rocks, boulders, logs + crash / bucked-off / finish → auto-restart
- [x] **Your playtest** — verdict: not fun yet → redesign (see [[13 - Playtesting]])
- [ ] Mobile test (Studio device emulator)

## Phase 2 — Animal switching
**Question: Does changing animals make it more interesting?**
Elephant · Giraffe · target selection · transfer · species behavior · obstacles · feedback

## Phase 3 — Discovery
**Question: Does discovering an animal feel rewarding?**
Discovery · befriending · collection state · Animal Book data · run results

## Phase 4 — Sanctuary prototype
**Question: Does bringing animals home give a reason to keep playing?**
Plot · 3 habitats · placement · income · basic progression

## Phase 5 — Art & UI polish
Approved voxel models · props · ChatGPT-approved UI · animations · audio/FX

## Phase 6 — Saving & progression
Data persistence · economy balance · upgrades · return incentives

## Phase 7 — Testing & launch
- [ ] **Remove temporary `DevCommands` (`/resetmydata`) before any public release**
Solo · multiplayer · mobile · save/load · performance · onboarding · economy · stability → private playtest. **No public publish without approval.**

## Dependencies
Phase 5 art depends on verified 3D pipeline. Phase 5 UI depends on approved ChatGPT designs.
