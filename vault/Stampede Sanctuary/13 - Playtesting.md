# Playtesting

Back to [[00 - Project Dashboard]]

Rules: test with fresh player data · record real observations only · never fabricate metrics · "the code works" ≠ "it's fun".

## Metrics to record
Time to first ride · first switch · first discovery · first habitat · confusing controls · failure points · enjoyment · mobile usability · technical errors

## Session template
```
### YYYY-MM-DD — Phase X build
Tester(s):
Device(s):
What felt good:
What felt bad / confusing:
Metrics:
Bugs found: (→ [[15 - Bug Tracker]])
Changes to try:
```

## Sessions

### 2026-10-22 — R1: species handling (commit `bebccfb`)
Tester: realjurt · Device: desktop (Studio) · **Verdict: not approved — handling adjustment first**
What needs work: giraffe and elephant feel noticeably delayed when steering, which makes them frustrating to control. Zebra is close to what's wanted.
Direction (confirmed): every animal must react noticeably and promptly to a direction press. Keep species personality through acceleration, turning radius, top speed, jump height, body movement and momentum — **not** through input lag. Giraffe = smooth and graceful, not delayed; elephant = heavy and powerful, not hard to control. Responsive, satisfying controls over realism.
Changes made: tuning pass `d12f148` (see [[12 - Development Log]]).
Re-test (same day): **handling approved for these animals.** New issue: camera felt shaky → fixed in `8030a42` ([[15 - Bug Tracker#BUG-004 Free-ride camera shake|BUG-004]]); **camera confirmed steady.**

### 2026-10-21 — R0: directional riding prototype (commit `0216979`)
Tester: realjurt · Device: desktop (Studio) · **Verdict: approved → R1**
What felt good: directional riding is a much better foundation than the straight safari; free exploration and jumping work; camera reasonably stable.
What needs work: the zebra still looks visually stiff. Test field is fine as placeholder — don't decorate it.
Changes to try (R1): make zebra / giraffe / elephant ride clearly differently; subtle body lean, gallop timing, landing reactions (placeholder level, no polished animation).
Not covered by this playtest: mobile touch, gamepad.

### 2026-10-21 — Milestone 5: animal switching (commit `3d1bb37`)
Tester: realjurt · Device: desktop (Studio)
What felt good: switching feels promising.
What needs work:
- Players need a first-time teaching moment for leaping (slow-motion, clear prompt, highlighted target).
- Space doing both jump and leap causes accidental switches when trying to jump obstacles → separate controls (Space = jump, F = leap, separate mobile/gamepad buttons).
Status: both changes built in `0688d5c` (D-019 to D-021) — awaiting playtest. Your Studio save has `leapTutorialDone = false` so you'll see the lesson.

### 2026-10-21 — Milestone 4: herds & targeting (commits `d13f01d`, `869bf6c`)
Tester: realjurt · Verdict: good foundation; approved moving to switching.

### 2026-10-20 — Milestone 3: tutorial safari (commit `c7ccf15`)
Tester: realjurt · Device: desktop (Studio)
What felt good: the tutorial experience feels good overall.
What needs work: the walk from spawn to the Safari Gate is unnecessarily long.
Change made: gate moved closer (100 → 60 studs, ~4 s straight walk) and entrance arch lowered so the gate sign is visible from spawn — see [[12 - Development Log]].

### 2026-10-20 — Milestone 2: sanctuary & Safari Gate (commit `d591747`)
Tester: realjurt · Device: desktop (Studio)
What felt good: sanctuary spawn and Safari Gate are improvements; choosing when to start a run.
What needs work:
- The game's purpose isn't communicated clearly enough.
- The empty Zebra Habitat should motivate discovering the first animal.
Direction: keep models/UI placeholder; don't decorate the sanctuary yet.

### 2026-10-20 — Phase 1 zebra prototype (commit `711dfa5`)
Tester: realjurt · Device: desktop (Studio)
**Verdict:** Not satisfying. Feels like a basic obstacle course, not an animal-riding adventure.
What felt bad:
- Forward movement isn't exciting; camera doesn't communicate speed
- 3 fixed lanes feel restrictive
- Course too straight and repetitive
- Zebra looks like it slides rather than runs
- Crashes have no satisfying feedback
- No animal switching
- New players are dropped onto a zebra with no idea what the game is about
Outcome: gameplay and onboarding redesign planned (pending approval).

### 2026-10-22 — P1 plots + coins/stamina (`bbecf00`)
Tester(s): user (solo Studio play)
What felt good / worked: existing onboarding and riding tutorial still function; currency/stamina HUD appears correctly.
**Outstanding:** multiplayer plot ownership NOT yet verified with two real Studio clients (Test → Clients and Servers → 2). Multiplayer is not complete until this passes.

### 2026-10-22 — P2 taming (`ba31a5a`) — ✅ approved
Tester(s): user (solo Studio play)
Worked: elephant stamina block, normal-gameplay tames, "IT'S YOURS!" confirmation, carried count rises, full run ending with 2 captured animals. User approved P2.

### 2026-10-23 — P3 deposits & income (`89bc9e6`) — ✅ approved
Tester(s): user (solo Studio play)
Worked: tamed an animal, carried it home, deposited it in the pen, passive income started. User approved P3.
Improvement requested: make depositing more obvious — visible **DEPOSIT ANIMALS** sign + clear prompt (small placeholder change, not a redesign). Planned as step 0 of P4 ([[11 - Decisions#D-026 P4 Training machine & upgrades plan|D-026]]).

### 2026-10-21 — P4 training machine & upgrades (`dfbd48d`) — ✅ core gameplay approved
Tester(s): user (solo Studio play)
Worked: training machine, stamina progression, elephant unlock, BOOST, leaving the machine. User approved P4 core gameplay; asked for the real two-client test before P5.

### Outstanding multiplayer test
**Status: NOT done — needs two real Studio clients (user-run).** Claude's Studio tools only start single-player Play; simulated players don't count. Multiplayer is not complete until this passes. Fill in Pass / Fail + notes, then share with Claude.

**Setup**
1. Rojo connected; Game Settings → Security → *Enable Studio Access to API Services* on (otherwise nothing saves → step 7 can't pass).
2. **Test** tab → *Clients and Servers* → Players **2** → **Start**. Three windows open: Server, Player1, Player2. Arrange Player1 and Player2 side by side.
3. Test players are brand new: in each client walk to the Safari Gate and **hold F (Skip Tutorial)**, or play the tutorial.

**Steps** (A = Player1, B = Player2)

| # | Do | Expect | Result |
|---|---|---|---|
| 1 | Look at the plot signs in both windows | A and B own **different** plots, each sign shows its owner's name; "YOUR PLOT" marker points to your own | |
| 2a | Both stand in the hub near each other | Each sees the other's character move | |
| 2b | A tames 1+ animals on safari, returns, deposits at **own** DEPOSIT sign (E) | A gets "+$300 STARTER BONUS" once; B sees A's animals appear in **A's** pen | |
| 3a | B walks to A's DEPOSIT sign, A's machine kiosk and A's pen plaque | B sees **no** prompts on A's plot | |
| 3b | A buys the machine (hold F at kiosk, $300). B walks onto A's machine | B gets no Train prompt and can't sit; A's stamina doesn't change | |
| 4 | Compare HUD pills in both windows after 3b | A: coins −300, machine Lv 1; B: own coins/stamina/carried unchanged; B's plot still has no machine | |
| 5 | B deposits (gets own $300), buys own machine. **Both** train at once (E on own machine) | Each stamina rises only in its own HUD; each sees the other's zebra gallop; BOOST only affects its owner | |
| 6 | Watch both signs for 10 s | Each sign shows its own owner's $/s; coins rise only for the owner (+$N pops over own pen only) | |
| 7a | Close **B's** window (player leaves) | In A's window: B's pen animals + machine disappear, B's sign → "Empty Plot" | |
| 7b | Stop the test, start a new 2-player test | Both get plots again; coins, stamina, machine level, pen animals return; bonus **not** granted again | |
| 8 | Both start a safari at the same time; A switches animals (leap) | ⚠️ **Expected FAIL** (known gap, D-016): B sees A's character but **no mount** under it and no herd. Note what B actually sees | |

Also note: console errors/warnings in any window (Server window: View → Output).

**Known gap before testing:** other players' mounts are not drawn yet — planned in [[11 - Decisions#D-016 Riding architecture: client-predicted mounts, replicated rider, server-tracked run state|D-016]] ("remote-mount view"), never built. If step 8 confirms it, fix = each client renders other riders' mounts from their replicated character + `MountSpecies` attribute.
