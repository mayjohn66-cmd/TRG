# Lightweight runtime models

Game-facing copies generated on 2026-11-27 with Godot 4.7.1. Original source models remain under their original asset paths; runtime scenes now reference this directory. Old source/prototype model folders and earlier optimization trials are excluded by `export_presets.cfg`.

| Metric | Source | Runtime |
| --- | ---: | ---: |
| Model resource files | 16,445,250 bytes | 2,635,463 bytes including shared resources, environment and map |
| Unique processed triangle count | 612,541 | 107,247 |
| Unique processed vertex count | 755,329 | 92,295 |

The source byte count covers the 41 mesh/scene inputs; a small environment is copied as the 42nd runtime entry. These are model resource file sizes, not the complete game download size.

Engine meshoptimizer LODs become the base meshes after indexing and compacting vertices. Candidate LODs must preserve local bounds within 3.5% of the original diagonal. Node paths, transforms, surface ordering, UVs and materials are preserved. Shared mesh/material/texture resources are externalized once. Texture dimensions are capped at 512px and stored as portable compressed textures with their compressed data retained for saving. Normal textures use lossless compression.

`model-map.json` maps source resources to their runtime replacements. `tests/lowpoly_models_test.gd` checks fresh disk readback, animation anchor paths/transforms, finite geometry/UVs, nonempty texture pixels and dependency closure. The final validation covered 42 resources and 1,402 nodes; the maximum bounds difference was 3.45%.

To regenerate, run `tools/art/build_lowpoly_models.gd` with an output report directory and a **new** `res://assets/models/optimized/<version>/` directory. The builder refuses to overwrite existing output folders. Inputs default to `tools/art/model_optimization_sources.json`. After authoring a new version, update runtime references/export exclusions and run the validation plus affected visual tests.
