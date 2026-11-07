# Shared augment card background

`card_base.png` is the unmodified 1024×1536 RGBA image generated with built-in imagegen. Rounded corners retain source transparency. It contains only the painted neutral frame and blank reading surfaces.

`AugmentCardSkin` places this one texture behind every augment card. `augment_card_tint.gdshader` derives luminance and applies the current category color; separate recolored PNGs are unnecessary. Icons, names, rules, rarity borders, hover glow and selection remain live UI elements.

Runtime texture: maximum 768px, lossy quality 0.9, mipmaps. The 260×390 card keeps its original emblem and description placement. The former small debug category label above the emblem is omitted; the title begins at y=170 to match the painted title band. Utility supply uses blue (#4dabf7) for the shared background, emblem ring and category border, clearly distinct from pawn evolution's mint.

The exact generation prompt, source path and source SHA-256 are recorded in `card_base.source.json` and `docs/ui-trial/augment-background-v01.json`. Native renderer captures in the task outputs show the neutral base, six categories and real draft screens.

Frame alignment uses the live StyleBoxFlat border thickness and radius, including 3px normal, 4px gold and 5px rare frames. Two concentric rounded rectangles draw a constant 4.5px inner rim, parallel to that outline on all four sides. Only the corners curve. The painted rim and its inward-sloping corner joins are excluded; the original leaf details are sampled separately. The source PNG is unchanged.

Reading surfaces retain the neutral paper texture; horizontal separators repeat the center profile. Explicit mip LOD follows the screen-space footprint during hover/scale. The earlier center-profile-only correction left concave painted corner joins and was insufficient. The replacement rim is defined by geometry across the full perimeter. Native before/after 2x purple and red card captures, six-category gallery and actual draft screens are in task outputs/augment-flat-v02.
