# Remaining presentation accents — 2026-10-27

This pass finishes the secondary accents left after the common, high- and medium-priority work:

- Castling source/destination marks use broken painted ripples; individual landings release small shallow dust sweeps. The main roulette rim, pockets and fixed pointer remain readable.
- Raid's short curved extraction swipe uses tapered overlapping painted wakes and a small leading glint, following the existing victim-to-card cue.
- Bakery destination emphasis uses a painted floor ripple. The storefront, Erpin, flour, three-bread haul, dimming and reward sequence are retained.
- D6 and Yut ground contacts use painted ripples, shallow dust and textured flecks. The D6 shadow is a soft irregular footprint. The existing floor contact clock and fixed contact positions, release timing and cancellation still own the accents; Chinchiro keeps its 3D bowl.
- Halli's bell sends out two staggered broken sound ripples, with a shallow soft shadow. Its keyboard focus ring remains a clear UI outline.
- RPS has soft hand shadows, sparse painted light and six uneven winner glints which decay after the reveal. Choice/result outlines remain for seat readability.
- E-card winners receive a restrained painted halo behind their actual revealed card; hidden choices, citizen discards and authoritative outcomes retain the same timing.
- Difficulty ramen emits three expanding steam wisps from the noodle surface, drifting upwards and fading. The level-three face's two breath puffs retain the face's full bob/scale/rotation transform. Icon faces and the existing bowl model are retained.

All assets are reused from `assets/fx/common`, `assets/fx/priority` and `assets/fx/atmosphere`; no new source image, image-generation call or texture import is added. Original image provenance remains in those folders' `source.json` manifests.

Native OpenGL runs passed for `ui_castling`, `ui_raid`, `ui_bakery`, `ui_remaining_fx`, `ui_rps`, `ui_halli`, `ui_ecard` and `ui_ramen_bowl`. Screenshots of the actual phases were inspected. `ui_remaining_fx` invokes only the existing D6 landing/result/cancel and Yut landing/nak/result/cancel checks from the larger UI fixture. The `remaining-fx` CI scope runs exactly these eight cases before web export/publication; it does not select the full-game suite.
