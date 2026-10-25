# Profile status stamps

Generated with built-in `image_gen`, with genuine transparent backgrounds. Source PNGs are kept unchanged; Godot imports the skip mark at 256px and the ban stamp at 512px for the 60–120px portrait overlays and web loading budget. Source regions are normalized so placement survives import resizing.

- `skip_painted.png`: red prohibition mark with dry-brush paint, warm ivory edge and transparent gaps.
- `ban_painted.png`: distressed red BANNED rubber stamp with transparent interior.
- When both statuses are active, the skip mark occupies the upper portrait and BANNED sits below it. Expiring either status restores the remaining stamp's solo layout without replaying its slam.

Only presentation changed. Status durations, card restrictions and the original stamp slam/sound remain controlled by the existing state and refresh path.

## Final prompts

Skip (built-in image_gen; transparent_background=true):

Use case: illustration-story. Asset type: one transparent painted status stamp overlay placed on top of a small chibi character portrait in a cozy cartoon board game. Primary request: a bold red SKIP / turn skipped prohibition mark, one rough hand-painted red circular ring crossed by one broad diagonal red brushstroke from upper left to lower right. The ring and diagonal must remain immediately readable as the familiar prohibition symbol at 60 pixels. Give the red paint tangible dry-brush ink texture, subtly uneven organic contours, tiny worn gaps and restrained darker red shading, with a very thin warm ivory edge for contrast over colorful portraits. The center spaces and every area outside the red mark are genuinely transparent so the character's face remains visible through it. Compact front-facing flat decal composition centered in a square with generous empty transparent padding; no perspective, no background or backing disc. Friendly cartoon game finish with simple bold shapes but clearly painted rather than mathematically perfect vector primitives. No letters, no text, no extra symbols, no character, no sparkles, no large splatters outside the main silhouette, no watermark. One mark only.

Ban (built-in image_gen; transparent_background=true):

Use case: illustration-story. Asset type: one transparent painted status stamp overlay for a chibi character portrait in a cozy cartoon board game. Primary request: a short wide red rubber-ink BAN stamp reading exactly "BANNED" in large chunky condensed block capitals, within a slightly uneven double rectangular red ink border. True worn rubber-stamp texture: tiny missing ink patches, organically rough edges, subtle dark crimson variation, hand-stamped illustrated quality rather than a clean geometric vector button. A very thin warm ivory contour immediately around the red letters and border keeps it legible over a colorful portrait. The rectangle interior between the letters and the border must be transparent, with no solid red or white plate behind the typography, so the character's face remains visible. Straight-on horizontal front-facing stamp, about 3:1 width to height, fully visible with ample transparent padding on every side; the game will tilt it later. Bold simple readable lettering at 75 pixels wide. Only this stamp, no hand or handle, no paper, no badge, no ribbons, no decorative objects, no character, no background, no large splatters or glow, no watermark. Text verbatim: BANNED.
