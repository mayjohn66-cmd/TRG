# Split dartboard models

- `fixed_frame.scn`: solid housing, cream rim, extruded numbers, four rivets and rear feet.
- `rotating_target.scn`: scoring sectors and divider wires. The number ring never rotates.

Both parts retain the original origin, dimensions and transforms. Rotation is
applied only to the target in `DartBoardView`. Aim coordinates and authoritative
hit placement are unchanged.

Rebuild with `tools/art/split_dartboard_models.gd`. The original optimized v4
scene is preserved (SHA-256 and readback results in `split-report.json`). Both
new scenes reference the same optimized v4 mesh/material files; splitting adds
approximately 1.4 KB of compressed scene data and no duplicate geometry.
