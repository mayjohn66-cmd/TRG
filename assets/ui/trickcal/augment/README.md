# Shared augment card background

`card_base.png` is the unmodified 1024×1536 RGBA image generated with built-in imagegen. Rounded corners retain source transparency. It contains only the painted neutral frame and blank reading surfaces.

`AugmentCardSkin` places this one texture behind every augment card. `augment_card_tint.gdshader` derives luminance and applies the current category color; separate recolored PNGs are unnecessary. Icons, names, rules, rarity borders, hover glow and selection remain live UI elements.

Runtime texture: maximum 768px, lossy quality 0.9, mipmaps. The 260×390 card keeps its original emblem and description placement. The former small debug category label above the emblem is omitted; the title begins at y=170 to match the painted title band. Utility supply uses blue (#4dabf7) for the shared background, emblem ring and category border, clearly distinct from pawn evolution's mint.

The exact generation prompt, source path and source SHA-256 are recorded in `card_base.source.json` and `docs/ui-trial/augment-background-v01.json`. Native renderer captures in the task outputs show the neutral base, six categories and real draft screens.

Frame alignment uses the live StyleBoxFlat border thickness and radius, including 3px normal, 4px gold and 5px rare frames. The shader samples the visible source rectangle (11, 8, 1003, 1498), omitting its asymmetric transparent margin. Only 128px source corner patches are warped to the matching inner radius; straight edges, material thickness and corner leaf details remain intact. A rounded inner-frame mask keeps the artwork inside the border. The source PNG is unchanged.
