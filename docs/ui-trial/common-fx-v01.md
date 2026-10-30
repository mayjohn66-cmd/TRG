# Shared painted impact effects — 2026-10-27

Common landing, impact, card and profile bursts now use two transparent painted sprites instead of an outlined circle and textureless square particles. The hollow shockwave expands over the board below pawns; the small irregular chips rotate, fall and fade. Existing callers keep their colors, impact radius, duration and count cap.

The shared moving-pawn trail samples the actual PawnToken artwork and nested transform. It preserves the sampled jump/rotation and fades as a colored silhouette behind the pawn. Stationary sources do not repeatedly stamp the same position. Hidden/deleted sources, effects-off and presentation reset stop emission; pooled sprites and one-shot cleanup also handle interrupted tweens.

Source images are preserved byte-for-byte with real transparency. Imports limit the shockwave to 512px and the particle to 128px with mipmaps. Prompts, source paths, hashes and alpha QA are in [the asset manifest](../../assets/fx/common/source.json).

Validation is limited to `tests/ui_common_fx_test.gd`: real production helpers, native rendering, bounded texture/particle sizes, transparent center, tint and fade, transformed silhouette position and layering, normal expiry, pool reuse, reset, freed source, effects-off, unchanged gameplay RNG and simulation clock. The `common-fx` workflow scope runs only this focused test before the normal web export/deployment steps.
