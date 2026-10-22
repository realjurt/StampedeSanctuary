# Reference Game Analysis & Progression Plan

Back to [[00 - Project Dashboard]] · Status: **Direction APPROVED 2026-10-22; P1 authorized + built (`bbecf00`), P2+ awaiting approval** · 2026-10-22
Source: user video `Downloads\Video Project 2.mp4` (2:38, frame-sampled; 1:15–1:23 partly unseen). Original branding/animals/art only — we reproduce *systems*, never assets.

## 1. Scene log (condensed)
| Time | What happens (on-screen evidence) |
|---|---|
| 0:09–0:12 | Spawn; banner "The stampede left one behind. Catch the Dodo!"; GOAL panel "Catch a dino for your pen"; HUD ⚡20, $0; 7-slot hotbar |
| 0:12–0:28 | "Press Drop!" ring → lands on dino; "Stay on the Dodo to catch it!", "Steer left/right"; 2nd dino "Stay on to tame…", "Hold on! It's almost tamed!", "You tamed a Pachycephalosaur!" |
| 0:30–0:36 | Back at base carrying dino (label "Common · Pachycephalosaur · $2/s", hotbar slot 1); "Go to your pen!"; walk/click pen → "…is in your pen!", "Your dinos earn money every second!"; pen sign "therealjurt $2/s"; other players' pens with $/s |
| 0:31 | AURAS shop: Silver x1.5 Stamina $100 · Lime x1.75 $5K · Cyan x2 $75K · Cobalt x2.25 (price cut off) |
| 0:40–0:44 | "+$2" pops over pen; GOAL "Buy your first Dino Machine $12/$300" (checklist: tame 1 new, put in pen, save $300); "Upgrade Pen Level 1→2" sign; Fuse Machine "0/3"; SELL / AURAS stands |
| 0:48 | Sell window: sort Value/Rarity, Select All, "Dinos equipped in your pen cannot be sold", locked until tutorial done |
| 0:55–1:14 | "The stampede! Tame new dinos!" run in Plains; wild labels with rarity/size + "Required ⚡10"; "Not enough stamina"; "IT'S YOURS!", "1/2 SECURED"; "GREAT RUN! You caught 2 dinos!" |
| 1:24–1:28 | Pen $9/s; "Common Dodo $1/s"; other plots: Epic $325/s, Legendary $4.8K/s, Rainbow Aura dino |
| 1:32–2:08 | 2nd run: zone strip Plains→Forest→Desert→Jungle→Snow→…→Volcano→Cosmic(?); distance 193→1,413 m; "Into the Forest" badge ≈1.1 km; harder animals (Required ⚡12, Rare Triceratops); lasso + green indicator; "Not enough stamina" + red pie timer; "+3 Meteor Shards" |
| 2:12–2:27 | Deposit ("GET CLOSER – walk up to your pen"); "Rare Aurochs $15/s"; buy machine ($300) → statue on pedestal; "Walk into your Dino Machine to jump on!"; sign "Upgrade Machine · +? Stamina/s · $15K" |
| 2:29–2:38 | **Stamina training**: riding the machine, floating "⚡ +0.4" stacks, stamina 22→36 in ~8 s; banner "More Stamina lets you stay on dinos longer. Keep training to catch better dinos!" |

## 2. Feature inventory
**C** = confirmed on screen · **I** = inferred (needs a testable design, not a claimed formula) · **X** = monetization, excluded until approved

| # | System | Evidence | C/I | Ours today |
|---|---|---|---|---|
| 1 | Shared world + individual plots/pens with owner sign & $/s | 0:32–0:36, 1:28 | C | Shared hub, no plots |
| 2 | Wild animals in runs ("stampede"), separate from base | 0:55, 1:32 | C | Savannah course + herds ✓ |
| 3 | Drop/mount onto wild animal, steer L/R | 0:12–0:28 | C | Leap + free steering ✓ |
| 4 | Stay mounted to tame; "almost tamed"; success banner | 0:20–0:28 | C | Temper (opposite meaning), tutorial befriending |
| 5 | Stamina stat (HUD ⚡) | whole video | C | — |
| 5a | Wild animal "Required ⚡N"; "Not enough stamina" fail | 0:55, 1:52 | C (exact rule I) | — |
| 5b | Stamina → longer stay-on | 2:37 banner | C (formula I) | — |
| 6 | Training machine: bought ($300), walk in to ride, at your base | 2:24–2:29 | C | — |
| 7 | Active training: floating "+0.4" gains, stat rises | 2:29–2:38 | C (tick rule I) | — |
| 8 | Machine upgrade ($15K, +stamina/s) / pen upgrade (level) | 0:41, 2:27 | C (effects I) | — |
| 9 | Carry captured animals (hotbar 7 slots) → deposit at pen (walk up / click) | 0:30–0:36, 2:16 | C | — |
| 10 | Persistent collection / inventory, "equipped in pen" vs not | 0:48 | C | `discovered` only |
| 11 | Passive $/s per animal, pen total, "+$N" pops | 0:36–0:44 | C | — |
| 12 | Rarities (Common→Mythic) & size tags (TINY/BIG/GIANT/HUGE), different $/s | throughout | C (multipliers I) | — |
| 13 | Sell unwanted animals (sort, select all, total) | 0:48 | C (UI) / prices I | — |
| 14 | Auras: stamina multipliers bought with $ | 0:31 | C (applies-to I) | — |
| 15 | Fuse Machine "0/3" | 0:43 | C exists / behaviour **I (never used)** | — |
| 16 | Stampede event timer ("3m left"), night timer | 0:30, 1:24 | C (behaviour I) | — |
| 17 | Goal panel tutorial chain with checklist & progress | throughout | C | Onboarding + tutorial ✓ (different chain) |
| 18 | Hotbar, $ & ⚡ displays, run "N SECURED" list, "GREAT RUN" summary | throughout | C | HUD ✓ (no currency/hotbar) |
| 19 | Zones by distance (Plains→…→Cosmic), harder/rarer further; zone badges | 1:32–2:01 | C (unlock rule I) | Fixed 950-stud course |
| 20 | Other players visible, own pen protected (only owner deposits) | 0:32, 1:28 | C / protection I | Remote mount view planned |
| 21 | Top Rankers leaderboard | 0:51 | C | — |
| 22 | Badges ("Ranch Hand", "Into the Forest") | 2:01, 2:35 | C | — |
| 23 | Meteor Shards, Robux packs, x2 Stamina pass, sale, Starter Pack | 2:08, 2:30 | **X** | — |

**Unclear:** whether stamina drains during a ride; exact Required-⚡ rule; aura card numbers (9/19/29); fuse rules; pen-upgrade effect; machine tick timing; zone unlock rule; 1:15–1:23.

## 3. Reuse map
- **Riding, free steering, leap, herds, HerdSchedule, server switch validation** → the run & mounting layer stays. "Press Drop" ≈ our leap.
- **Temper** → becomes **Grip** (how long you can stay on), now driven by stamina.
- **Tutorial befriending meter** → becomes the general **Tame progress** bar.
- **SafariService run state / seeded herds** → server validates tames like it validates switches.
- **PlayerDataService** → data v2 (coins, stamina, collection, plot items) with migration from v1.
- **Sanctuary hub + Safari Gate** → hub with plots around it; gate stays.
- **UiKit / HUD / Index / MenuController** → currency, stamina, hotbar, goals, sell, auras, collection.
- **D-019 sim clock** → machine training feedback; no change needed.

## 4. Proposed architecture (server-authoritative economy)
- **Server:** `PlotService` (assign/own plots, protect) · `PlayerDataService` v2 · `TameService` (validate tames vs seed, stamina, time) · `CollectionService` (inventory, pen equip, sell, fuse) · `IncomeService` (1 s tick → coins) · `TrainingService` (stamina ticks while on own machine, proximity-checked) · `ShopService` (machine, upgrades, auras; coins only) · `EventService` (stampede timer) · `GoalService` (tutorial chain).
- **Client:** run/ride (existing) + `TameController` (grip/tame UI) · `Hotbar` · `PlotView` (pens, machine, prompts) · `MachineRide` (local riding animation; server ticks) · goals panel & currency HUD.
- **Replication:** pen animals are server models (everyone sees); mounts stay client-side (D-016) + remote-mount view for other players.

### Proposed starting values (for playtest, NOT observed formulas)
- Mount gate: stamina ≥ species `requiredStamina` (Zebra 5, Giraffe 10, Elephant 15).
- Grip (stay-on seconds) = 4 + stamina × 0.3 (stamina 20 → 10 s).
- Tame time: Common 4 s, Uncommon 6, Rare 9, Epic 13, Legendary 18; size BIG ×1.2, GIANT ×1.4.
- Income: Common $1–2/s, Uncommon $5, Rare $15, Epic $60, Legendary $250; size ×1.5/×2.5.
- Training: +0.4 stamina per 0.5 s on the machine (level 1); each upgrade +50 %; auras multiply gains.
- Machine $300, machine upgrade $15K (matches reference anchors), pen capacity 4 → +2 per pen level.

## 5. Milestones (each ends with a playtest)
1. **P1 Plots & data v2** ✅ built `bbecf00`, awaiting playtest — plot per player around hub (pen + machine pad), coins & stamina saved, $/⚡ HUD; 2-player Studio test.
2. **P2 Taming** — stamina gate, grip, tame progress, server-validated captures, carried hotbar, run summary.
3. **P3 Deposit & income** — pen deposit, server pen models with labels, $/s tick, "+$" pops, capacity.
4. **P4 Training machine** — buy, walk-in ride, server stamina ticks with "+0.4" pops, machine & pen upgrades.
5. **P5 Goals tutorial** — new first-loop chain (catch → deposit → earn → buy machine → train); replaces befriending tutorial.
6. **P6 Collection & selling** — inventory UI, sell, Index integration.
7. **P7 Rarity/size + zones + stampede events** — distance zones, harder animals, timed stampedes.
8. **P8 Auras, Fuse, leaderboard, badges.**
**First playable target = P1–P4** (multiplayer, taming, deposits, income, training, upgrades).

## 6. Risks / investigate
Client-driven riding → tames validated by seed/time/stamina only · economy balance needs real playtests · DataStore v1→v2 migration · multiplayer testing via Studio local server (MCP support unverified) · scope creep (8 milestones) · fusion rules unknown · monetization items excluded until approved · reference IP: original names/art only.
