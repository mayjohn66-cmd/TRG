# Shared short-pile felt

`felt-neutral.webp`: 512×512 opaque neutral fabric tile, 13,650 bytes. All three CardMat styles share this texture; no new 3D geometry or shader is used. Godot import uses lossy compression, mipmaps, and linear sampling. Mirrored repetition avoids a hard tile seam. Fixed board-space UVs retain fiber scale while the mat unrolls.

Created with the built-in OpenAI image generation tool on 2026-11-27, guided by the user's small dark teal felt closeup. The neutral source and complete prompt are preserved under `art_source/card_mats/v1/`, excluded from game exports. The runtime WebP is a size/format derivative, not a new painting.

The palette, borders, star embroidery and stitching remain code-driven in `scenes/card_mat.gd`. The previous 520 square flecks and large capsule-shaped center highlight are no longer drawn. Card hitboxes and the unroll/roll-up clock are unchanged.

The heavy flat leather/gold frame has been replaced with an 8–10px cloth binding using the same fiber tile, a shallow seam crease and low-contrast stitch pairs. Stitches are submitted as two batched multiline draws. The blanket's large stripes and long diagonal edge marks have been removed. No extra texture, shader, or 3D resource is required for the binding.
