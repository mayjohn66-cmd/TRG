# Weapon-specific capture accents

Shady's scythe now uses a painted cyan crescent following the blade, revealed from top to bottom during the fast approach. The trail freezes with the actors for the 0.12-second impact hold, then fades during slow recoil. Its hollow interior and placement beside the blade keep both faces readable.

Butter's slingshot, Silla's bow and Daya's straight sword thrust use thin rightward trails. These four weapon attacks no longer receive the large circular punch burst. Punches and palms retain the radial shock; Belita retains her magic burst.

The sixteen approved character drawings, capture event rules and 0.96-second sequence duration are unchanged. VFX use deterministic visual samples and do not consume simulation RNG or change global time scale.

`capture-fx-v06.png` shows Shady attacking Daya in the actual game renderer. `capture-fx-v06.mp4` shows a real queued board capture at 60 fps; its audio uses the existing curated effects synchronized separately for the preview, rather than recorded system loopback. The prompt, native tool provenance, original source hash and alpha QA are in `capture-fx-v06.json`. Source PNG is preserved byte for byte; Godot imports a 1024-pixel mipmapped texture for runtime.

Validation: unit tests, real-capture UI lifecycle/input cleanup, presentation queue checks, native rendering of all eight avatar pairs, and Web export with packaged texture/dependency checks.
