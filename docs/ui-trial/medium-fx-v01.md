# Medium-priority presentation art — 2026-10-27

Remaining geometric accents in the medium-priority groups now use transparent painted textures:

- **Devil contract:** the original sigil and scroll remain, with wispy ground haze, painted embers, a flowing curved comet trail and a broken arrival ripple in place of filled circles, bead trails and straight rays.
- **Gambler:** boost/activation ripples and embers use painted accents; overheat produces irregular smoke. Profile aura tongues and tool-frame flames reuse the painted plume, keeping the existing palette and clear card contents.
- **Runaway train:** chimney smoke uses small unshaded camera-facing Sprite3D billboards instead of sphere meshes. Steam rises, drifts, expands and fades on the existing presentation clock; cancellation clears it with the other train visuals.
- **Minefield:** landings produce a shallow outward dust sweep and small textured flecks, with a soft ground shadow. Tile-aligned warnings and the authoritative mine handoff retain their original behavior.
- **Alkkagi / bottle-cap curling:** tapered textured wakes and small organic contact accents replace thick solid trails and evenly spaced spokes. Aiming guides, gestures and physics are unchanged.
- **Pumpkin roulette:** the flash and cloud use painted accents; original pumpkin artwork breaks into uneven jagged chunks rotating around their own centers. The original Angry1_1 frame sequence and delayed grow/fade-in remain unchanged.

Two new native image-generation PNGs are copied byte-for-byte with real alpha. Runtime limits are 256px for steam and 512px for ground dust, with mipmaps and import UIDs. [Prompts, source paths, hashes, alpha QA and reused assets](../../assets/fx/atmosphere/source.json).

Native OpenGL validation passed for `ui_devil`, `ui_gambler`, `ui_profile_aura`, `ui_train`, `ui_minefield`, `ui_alkkagi`, `ui_curling` and `ui_pumpkin`. The final pumpkin revision was also replayed and inspected. These focused cases cover phase timing, real outcomes, simultaneous visual/state handoff, input, physics replay, unchanged simulation RNG/time scale, cancellation and cleanup. The `medium-fx` CI scope runs only those eight cases before normal web export and publication.
