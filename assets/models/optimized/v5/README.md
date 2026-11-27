# Current presentation models — 1.3.1 lightweight pass

The existing v4 optimized models remain in use. This pass adds the new yacht
case and reduces recently edited procedural models without changing outcomes.

| Runtime object | Before | After |
| --- | ---: | ---: |
| Yacht case + hollow cup triangles | 4,184 | 1,816 |
| Yacht case runtime file | 191,140-byte GLB | 53,493-byte bundled compressed SCN |
| Yacht dice, rendered triangles (five dice including outline) | 8,940 | 3,180 |
| Slot machine, rendered triangles | 4,874 | 2,138 |
| Pinball, rendered triangles | 6,882 | 6,450 |
| Combined active target pixels for these views | 1,827,042 | 1,298,450 |

The case uses one bevel segment for small trim, two for its outer silhouette,
and a 16-sided hollow cup. Dice keep their flat painted faces and exact result
axes; the smaller grid is concentrated on bevel boundaries. The slot drums
retain six exact atlas cells with 48 rather than 72 circumferential segments.

Cup mouth: (724,174) in stage pixels; its mesh clears the case edge by more
than 16 pixels. The dice viewport includes the cup, so the throw starts there.
Dice/input centers on the felt and hold row remain unchanged.

Editable source: `art_source/models/yacht_case/v2/yacht-case-v2.blend`.
Interchange source: `assets/models/yacht_case/v2/yacht-case-v2.glb`.
Rebuild with `tools/art/build_yacht_case_v2.py`, then
`tools/art/pack_yacht_case_v2.gd`. Native readback has no GLB dependencies.
Source GLBs (both v1 and v2) are excluded from web exports. Hidden yacht/pinball
targets park at 32x32 and restore their active dimensions when shown again.
