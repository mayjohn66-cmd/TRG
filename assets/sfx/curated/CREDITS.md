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
