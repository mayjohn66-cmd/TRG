# Curated game sound effects

All source recordings used here are **CC0 1.0**. They may be modified and
redistributed with the game. Attribution is retained voluntarily.

| Creator | Source pack |
| --- | --- |
| Kenney | [UI Audio](https://kenney.nl/assets/ui-audio) |
| Kenney | [Casino Audio](https://kenney.nl/assets/casino-audio) |
| Kenney | [Impact Sounds](https://kenney.nl/assets/impact-sounds) |
| Kenney | [Music Jingles](https://kenney.nl/assets/music-jingles) |
| Robin Lamb | [UI sound effects](https://opengameart.org/content/ui-sound-effects-button-clicks-user-feedback-notifications) |
| rubberduck | [100 CC0 metal and wood SFX](https://opengameart.org/content/100-cc0-metal-and-wood-sfx) |
| AntumDeluge | [Bicycle horn](https://opengameart.org/content/bicycle-horn) — child's plastic horn |

License: https://creativecommons.org/publicdomain/zero/1.0/

`manifest.json` records each original filename, source URL, author, source hash,
processing and output hash. Kenney license notices are in `licenses/`.

34 events use 39 mono Vorbis clips at 44.1 kHz, approximately 285 KiB total.
Original silence is trimmed, edges are faded, harsh extremes filtered and peaks
scaled by role. The two Mahjong impacts derive from casino chip recordings;
the Yut toss uses a short fan-of-cards rustle, with actual wooden hits on landing.
The toy gun uses a mechanical switch for empty chambers and a plastic horn for
the flag. No realistic firearm discharge recording is used.

The generated `catalog.gd` takes priority over legacy random candidates.
User files in `content_trickcal/audio/sfx/` still replace an event's whole set.
Rebuild with `tools/audio/curate_sfx.py` (NumPy and FFmpeg required).

Halli Galli adds `halli_bell_01.ogg`, a 0.72-second derivative of Kenney's
`impactBell_heavy_000.ogg` (Impact Sounds, CC0). It is pitched up, shortened,
faded and normalized for a small game bell. Rebuild this clip separately with
`tools/audio/add_halli_bell.py`; processing and hashes are in the manifest.

## Presentation effects (2026-10-26)

12 additional mono Vorbis clips (24 kHz, approximately 68 KiB) cover nine events:
rail placement, locomotive chug/whistle, chain pull/clasp, bakery door/commotion,
raid cut-in slash and pinball metal contact. These replace unrelated generic
sound cues at their existing animation/contact hooks.

| Creator | Source | Recordings |
| --- | --- | --- |
| rubberduck | [80 CC0 RPG SFX](https://opengameart.org/content/80-cc0-rpg-sfx) | chain_01/02, lock_03, blade_03, metal_01/03, wood_03 |
| Brian MacIntosh (BMacZero) | [Mechanical Sounds](https://opengameart.org/content/mechanical-sounds) | clank1, rattle1, squeakyclick1 |
| Joseph Sardin / Axeline T. | [Train whistle, foley #6](https://bigsoundbank.com/train-whistle-foley-6-s3320.html) | locomotive-style whistle, recording 3320 |

All three sources explicitly release these recordings under CC0. Notices are
retained in `licenses/Presentation-CC0.txt`. Rebuild only these additions with
`tools/audio/add_presentation_sfx.py`; the manifest records original and output
hashes, trims, pitch changes, filtering, fades and level targets. Uncompressed
downloads remain outside the game export.
