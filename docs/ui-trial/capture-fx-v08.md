# Painted accents for the player ejection cutscene

The live `CaptureCutin` overlay now uses dry-brush motion paint at the screen
edges, a fibrous luminous thrust trail for arrows/spears, and soft broken magic
wisps at contact. These replace the diagonal flat polygon field, 22 triangular
speed rays, three polygon thrust streaks, diamond magic particles and drawn
contact arcs. The existing impact painting already includes torn flecks, so its
extra nine triangular fragments were removed.

The eight characters retain their original attack/hit artwork, weapon-specific
accent types, colors, 0.96-second sequence, impact sound, lettering and queue
behavior. Painted trails share the actors' impact hold, then resume slowly.
The quiet center and subdued edge paint preserve face and weapon readability.
The flat dim and letterbox bars remain cinematic framing.

New PNG source art is copied byte-for-byte from the built-in image-generation
tool. Prompts, actual source paths, alpha QA, dimensions and matching SHA-256
hashes are in `capture-fx-v08.json`. Godot imports the edge overlay at 1024 pixels
and the two contact/trail textures at 512 pixels with mipmaps.

## Focused validation

- `TEST_ONLY=test_capture_cutin godot --headless --path . -s res://tests/run_tests.gd`
- `godot --headless --path . -s res://tests/ui_capture_fx_test.gd`
- `godot --headless --path . -s res://tests/ui_capture_test.gd`

`CAPTURE_FX_DIR` optionally captures the native renderer's blunt, pierce, slash
and magic frames. The overlay fixture covers all eight avatars, held trails,
one impact, cleanup, input pass-through and narrow/wide viewports. The existing
real-board capture check covers event order, ejection and snapshot reset.
CI marker `[check:capture-fx]` runs these capture checks without the full suite.
