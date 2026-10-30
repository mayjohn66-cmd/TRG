# Neutral NPC path warning art

NPC attack paths now use `assets/board/decals/NPC_WARNING.png` instead of a procedural skull. The generated transparent raster has a coral triangle, dark red inset edge, ivory outer keyline, and a large ivory exclamation mark. The keyline separates the icon from the pulsing red path floor at normal board scale.

The image uses the same board-plane projection and per-side orientation as terrain and trap decals. Regular tiles use 72% of their shorter footprint dimension; corners use 59%. A small ivory arrow follows the NPC's actual projected travel direction. Converting screen direction back to the board uses an affine inverse because the isometric basis is scaled and skewed.

At danger level 2, the warning replaces terrain, booster, and trap artwork to avoid stacked symbols. The underlying tile and trap state remain intact and their artwork returns when danger clears. Only the floor pulses; the warning remains readable throughout the pulse. NPC movement, range, targeting, and capture rules are unchanged.

The original native image is preserved without pixel editing. Godot imports a 256-pixel mipmapped texture, and an alpha-bounds atlas region removes transparent padding at runtime. The production arrow reuses the existing thick corner-arrow asset.

Authoring records: workspace `outputs/npc-warning-v01/prompt.json` and `manifest.json`; built-in `image_gen` generation, transparent output, zero corrective generations. Visual QA: native production board, all four board sides, and a tile gallery covering terrain, booster, corner, trap overlap, and restoration. The UI FX regression suite also checks visible warning artwork, projected travel heading, and clearing/restoration.
