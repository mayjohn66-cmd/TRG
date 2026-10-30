# Priority presentation art — 2026-10-27

The four highest-priority presentation groups now use transparent painted accents:

- **Autobahn Nitro:** blue layered flame plumes, textured floor wake/grid, airy contact and rotating small chips replace flame polygons, triangular slipstreams, the filled star and diamond fragments. The existing close camera, impact hold and simultaneous victim release use their original clocks.
- **Revenge booster:** the profile/bench flame uses the same painted plume in orange. Moving exhaust follows the opposite direction of travel and returns to a bounded sprite pool; there are no expanding circular puffs.
- **Board flip:** success uses hollow painted pressure waves, pawn-shaped shared afterimages and golden flame exhaust. Failure uses a real branched lightning sprite with measured core endpoints and a small textured contact instead of a regular zigzag and filled circle. Coin toss, outcome and launch timing remain unchanged.
- **Sniper's target:** the intentional reticle remains. The bullet uses the existing tapered BANG tracer shader; the impact uses a small painted spark. The stage follows the pawn layer transform, and the focus veil continues covering the viewport when that layer is translated or scaled.

Three new sources (flame, lightning, contact) are copied byte-for-byte from native image generation, with alpha preserved and import UIDs recorded. Runtime limits are 256px for flame/contact and 512px for lightning. Existing common ripple/fleck and capture wake textures are reused. [Prompts, paths, alpha checks and source/final hashes](../../assets/fx/priority/source.json).

Validation is scoped to `ui_priority_paint_test.gd`, `ui_nitro_test.gd`, `ui_sniper_test.gd` and `ui_flip_test.gd`. Native OpenGL runs passed and captured actual in-game ignition, dash, impact, simultaneous flight, booster profile/exhaust, sniper impact and both coin outcomes. Checks cover authoritative movement/outcomes, phase ordering, unchanged game RNG/time scale, endpoint alignment, camera restoration, cancellation, bounded import sizes and exhaust pool reuse. The `priority-fx` CI scope runs only these four checks before the normal web export and publish steps.
