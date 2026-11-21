# Rounded rulebook skin

Generated with built-in image_gen. The source PNG is copied unchanged; manifest.json records the original path, dimensions, hash and complete edit prompt.

Replaces only the previous almost-square panel base. The generated source has generous corner arcs, measured at about 24% of its cropped width. `rulebook_visuals.gd` derives texture size from the requested visible radius and protects the complete curve with matching nine-slice margins. This restores round book edges, pills, entry tiles and circular icon pedestals while keeping straight side segments parallel.

Existing icon pictures, colors, text and control layout remain unchanged. Native inspection is scoped to the rulebook; CI uses the existing rulebook-art scope.

The circular icon pedestals and bullet dots use a second dedicated round source image without nine-slicing, preventing seams where corner slices would otherwise meet. Both original source PNGs remain unchanged.
