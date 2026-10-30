# Super augment symbols

Audit of all 12 super augments found eight flat procedural source PNGs (`SUPER_01` through `SUPER_08`). They have been replaced with native generated painted emblems matching the existing gold/ivory chunky cel-shaded art. `SUPER_09` through `SUPER_12` retain their existing illustrations. The same resource paths serve draft choices, the rulebook, augment history, and any other existing `AugmentArt` consumers; no rules, names, values, or renderer logic changed.

| ID | Effect | Replacement motif |
| --- | --- | --- |
| SUPER_01 | 판 뒤집기 (모 아니면 도) | Finish-flag coin, return arrow, pawn and tile |
| SUPER_02 | 공산주의 재분배 | Four player colors at equal height, cards and redistribution arrows |
| SUPER_03 | 악마의 계약 (영구 가속) | Horned wax-seal contract and winged speed boot |
| SUPER_04 | 광란의 지뢰밭 | Two toy mines on a tile, matching the default two placements |
| SUPER_05 | 도적단 대습격 | Hooded bandit and stolen card satchel |
| SUPER_06 | 주사위 도박사의 영혼 | Die, golden spirit, doubled chevrons and overheat spark |
| SUPER_07 | 강제 캐슬링 룰렛 | Rook and colored pawns with swap arrows |
| SUPER_08 | 에르핀의 빵집 털이 | Plump loaf, three reward cards and deployment chevrons |

Keep subsequent symbols as one compact readable group, with thick dark outlines and a plain dark background. Omit captions and numeric modifiers so table tuning does not leave stale values baked into art. No detailed scenery. Sources are unchanged 1254×1254 RGB PNGs generated with built-in `image_gen`; Godot imports 512-pixel lossy textures at quality 0.9 with mipmaps, preserving existing resource UIDs. There is no external pixel repainting or resizing.

Prompts, source paths, hashes, prior hashes, and QA records are in `super-symbols-v01.json` and the central illustration manifest. Workspace `outputs/super-symbols-v01` also preserves all old images, new images, import snapshots, and production-renderer previews. Acceptance includes the 12-symbol comparison, 40-pixel readability, circular clipping, all eight actual draft choices, and existing augment-art coverage tests.
