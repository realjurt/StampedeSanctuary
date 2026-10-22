# UI Design

Back to [[00 - Project Dashboard]]

> **Current direction (2026-10-21): [[11 - Decisions#D-022 UI direction: classic polished simulator style ("Outlined Radiance") — supersedes D-010's UI clause]].**
> Visual north star: `Assets & References/Outlined Radiance - Plate I.png` + [[Assets & References/Outlined Radiance - Design Philosophy|design philosophy]].
> Tokens: ground #16171C · panel #22232A · track #101014 · ink #0B0B0E · green #56EC68→#169634 · cyan #40DEFA→#0A80B2 · blue #548CFF→#1C3ECE · purple #A86EFF→#5822C8 · pink #FF70D2→#C4188C · yellow #FFDE5C→#EE9600 · red #FF6262→#C4141C. Contours 6–9 px ink; radius 6–14; gloss stripes at 30°; font FredokaOne with black outline.
> Stud texture (user reference, 2026-10-22): L-bevel stud tile `rbxassetid://115925519940442` on every colored surface and bar fill, faint on dark panels; darker bottom lip on raised surfaces.
> The workflow and screen list below predate this direction; ChatGPT now supplies icons/art only.

## Workflow (confirmed)
1. Define the UI's function
2. Design references in **ChatGPT**
3. Review & approve layout
4. Give Claude Code the images + specs
5. Build with native Roblox ScreenGui
6. Test responsiveness and function
7. Compare to approved reference
8. Refine

Claude Code does **not** invent a full UI style on its own. Mockup images are references, not functional UI. Dynamic content uses native text/elements.

## ChatGPT brief template
```
Screen: <name>          Platform: Roblox, desktop + mobile (16:9 and phone)
Purpose: <what the player needs to do/know>
Must show: <data elements>
Interactions: <buttons, taps>
Style: clean, minimal, playful, modern, highly readable; matches cute voxel animals;
       no glowing borders, heavy gradients, or clutter
Deliver: full-screen mockup + separate exportable icons/assets (PNG, transparent)
```
Approved images go in [[Assets & References/README|Assets & References]] and get listed in the table below.

## Style
Clean · minimal · playful · modern · highly readable · matches voxel art. No glowing borders, heavy gradients, or clutter.

## Needed screens
| UI | Phase | Status |
|---|---|---|
| Riding HUD | 1 | Placeholder only in Phase 1 |
| Temper meter | 1 | Placeholder bar in Phase 1 |
| Animal-switch indicator | 2 | — |
| Safari results | 3 | — |
| Discovery notification | 3 | — |
| Animal Book | 3 | — |
| Coin display | 4 | — |
| Habitat interaction | 4 | — |
| Progression indicators | 4 | — |

Phase 1–2 placeholders are deliberately plain and get replaced by approved designs in Phase 5.
