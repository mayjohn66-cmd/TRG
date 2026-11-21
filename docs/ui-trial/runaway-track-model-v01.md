# Modular straight rail segment

One straight track module for the existing pastel toy locomotive, authored and rendered in Godot 4.7.1 Compatibility. Native asset: `assets/models/runaway_train/straight_track_v01.tscn`. Portable asset: `straight_track_v01.glb` in the same folder. Editable generator: `scenes/runaway_track_3d.gd`.

The segment is 3.2 units long along X, 2.75 units wide along Z, and 0.40 units high. Rail centers are at Z +/-0.96, matching the train's wheel centers. Place the existing train 0.365 units above the track origin to put its wheel treads on the rail heads. Train travel is local -X.

`Sleepers/Sleeper01` through `Sleeper05` are separately addressable groups. Each includes a rounded timber, two seat plates and four fasteners. `RailLeft` and `RailRight` each contain a wide foot, recessed web and rounded running head. These groups can later be revealed or moved independently for the sequential track-laying effect; the asset contains no animation or gameplay triggers yet.

`Start` at (+1.6, 0.4, 0) and `End` at (-1.6, 0.4, 0) are snap markers. Copies repeat at exactly 3.2 units along X. Rail end cuts are flush and the 0.64-unit sleeper pitch continues through every joint. There are no protruding end buffers, gravel beds, duplicate boundary sleepers or decorative caps across the rail running surfaces.

Validation reopens the saved native scene and GLB, checks finite transforms/normals and zero degenerate triangles, verifies all six rail parts end at +/-1.6, confirms sleeper spacing across a module joint, and compares gauge to the actual locomotive wheel pivot. All versions retain 41 mesh instances and 7,516 triangles. Studio views show one segment, three joined segments, top view and the complete train standing on seven copies. Reports and previews are in workspace `outputs/runaway-track-v01/final`.
