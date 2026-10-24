# Updated augment artwork: Autobahn and Sniper

Two existing augment images now match the current rules:

- **LAW_06 — 아우토반 무제한 과속:** replaces the retired speed-camera image with an accelerating red-and-gold toy car on a gold/ivory freeway with three forward boost chevrons. The current rule grants +3 movement on rolls of at least 5.
- **SUPER_09 — 저격수의 표적:** replaces the flat reticle and obsolete `-5` label with a targeted red meeple launching from a spring cannon, plus a small forward chevron. The current effect ejects a leading enemy to start, advances the player's pawn by 4 and places a spring cannon at the targeted location.

The two assets use the existing chunky gold/ivory cel-shaded style with dark backgrounds and circular-medallion composition. Numerical rules stay in the live card description. The gameplay rules and image lookup IDs are unchanged.

Native-generated 1254×1254 PNG sources are preserved byte for byte at the existing resource paths. Both now import at 512 pixels with mipmaps and 90% lossy compression. Individual runtime settings are recorded in `content_trickcal/illustrations/manifest.json`; the full prompts, source events, old/new hashes and visual QA are also in `augment-art-v04.json`.

`augment-art-v04.png` shows the actual game draft UI with both updated medallions. Validation covers all 50 draft image lookups, visual inspection at actual 110-pixel circular size, unit tests and Web export/package checks.
