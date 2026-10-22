# Progression & Economy

Back to [[00 - Project Dashboard]]

## Currency (MVP)
One currency: **Coins** (working name). All calculations server-authoritative.

| Earn | Spend |
|---|---|
| Completing safari runs | Habitat unlocks |
| Discovering animals | Basic sanctuary upgrades |
| Growing sanctuary (visitor income) | New expedition access |
| | Decorations (later) |

No required purchases for enjoyable progression. Minimal waiting/grinding. Costs tuned by real playtesting — see [[13 - Playtesting]].

## Progression path
Starter Savannah → Discover Animals → Build Habitats → Improve Sanctuary → Unlock Expeditions → More Species.
MVP stops before multiple biomes. Every upgrade has a clear purpose.

## Saved data (Phase 6)
Coins · discovered species · befriended species · unlocked habitats · upgrades · milestones.
Structured + versioned · server-validated · handle load failures · safe on shutdown/disconnect · no unnecessary personal data.

## P4 values (confirmed 2026-10-21, [[11 - Decisions#D-026 P4 Training machine & upgrades plan|D-026]])
- **Training machine:** L1 $300 +0.2⚡ · L2 $1,500 +0.3 · L3 $5,000 +0.4 · L4 $15,000 +0.5, per 0.5 s seated. Optional BOOST: window 1.2 s every 6 s, ×2 for 3 s. (`TrainingConfig`)
- **Pen:** L1 8 slots · L2 $1,000 10 · L3 $4,000 12. (`EconomyConfig.penLevels`)
- **Starter reward:** $300 once, on the first deposit. (`EconomyConfig.starterDepositReward`)
- **Grip:** stamina 20 ×1.0 · 40 ×1.5 · 60 ×1.7 · 80 ×1.85 · 100 ×2.0 (cap); stamina uncapped (sanity cap 1e6). (`TamingConfig.gripCurve`)
