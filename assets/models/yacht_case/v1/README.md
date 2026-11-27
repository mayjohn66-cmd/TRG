# Yacht case v1 — 1.3.1 presentation

Original low-poly Blender model: charcoal case, five recessed hold wells, green
felt playing surface, brass fittings and a genuinely hollow tapered dice cup.
No copied commercial model, no text baked into the asset.

- Source: `art_source/models/yacht_case/v1/yacht-case-v1.blend`
- Rebuild: Blender background CLI with `tools/art/build_yacht_case_v1.py`.
- Validation: source readback and SHA-256 in the adjacent source `report.json`.
- Geometry: 4,184 triangles / 2,168 vertices; GLB approximately 191 KB.
- Runtime: `YachtCase3D`, behind the existing `YachtRoll3D` and input controls.
- A static viewport draws once; the case is instantiated only when shown.
- Felt reuses the shared mat texture; dice outcomes and hit areas stay in code.

Pixel-space layout uses 42 pixels per Blender unit. Wells align with the
existing hold row at (100 + 110 * index, 90); cup mouth is at (668, 232).
