# Mobile effect coordinates — 2026-10-27

Focused presentation audit at landscape 844×390 and 740×360, including a width change while each effect remains active. Uses the shipping 1366×768 canvas-items/expand stretch; 844×390 produces a 1662×768 logical viewport and a 148px horizontal board offset. No simulation, input, outcome, RNG or global time-scale changes.

| Corrected presentation | Original error in physical screen pixels | Correction |
| --- | --- | --- |
| Castling source marks and orbit | 75.16 | Stage and pawn poses share the pawn-layer transform; orbit centre is converted into that frame. |
| Bakery tile marker and storefront | 75.16 / 19.70 | Transform tile centres and refresh storefront/door anchors as the board layout changes. |
| Responsibility chains | 19.70 | Preserve pawn-local endpoints and resolve their current board positions every frame. |
| BANG aim, tracer and dimmer | 19.70 | Resolve live profile/target anchors, retain muzzle offset in the shot frame and resize the dimmer. |
| Gambler target effect | 39.39 | Keep the anchor relative to its target control instead of caching an old screen point. |
| Card draw/reveal/profile delivery | 19.70 / 39.39 | Resolve current deck/reveal/destination positions; theft and bakery draws also supply a live source provider. |

`tests/ui_mobile_fx_test.gd` passed 72 coordinate measurements in both native OpenGL and headless runs. Maximum observed error after correction was 0.000109 screen pixels (floating-point noise); the test threshold is 1.1 screen pixels. It checks RNG state and global time scale are unchanged. Additional aligned presentations covered mine tiles, sniper focus, shared pressure rings, profile auras, spotlight, train rail projection, Nitro pawn/flame/glow and all six duel containers. Remote card delivery retains the card back.

Native mobile renders were inspected for pawn attachment, scene framing, spotlight coverage, rails, Nitro and the resized post-shot BANG stage. The six existing focused cases (`castling`, `bakery`, `bond`, `bang`, `gambler`, `raid`) also passed their original activation/completion checks. CI scope `mobile-fx` runs only the mobile coordinate audit and those six affected presentation cases before exporting/publishing; the full game suite is intentionally outside this request.

The deployed web canvas was checked using ego-browser at 844×390, DPR 2: CSS bounds 0,0,844,390 and backing buffer 1688×780. Browser screenshot capture timed out, so visual effect QA used native production rendering at the same mobile viewport sizes. This is viewport testing, not a physical-device gameplay test. No new artwork was introduced.
