# 다야 high-resolution lobby idle

Source: https://viewer.dclnslde.com/ → 사도 → 다야, default Normal skin, Idle_1. Native viewer full-frame PNG ZIP at 16 fps with a 1536px camera; interaction disabled and fit-to-spine disabled. No screenshot, AI redraw or upscaled old frames.

All 43 transparent 1536×1536 PNG files are preserved byte-for-byte from the native archive. `manifest.json` records exact file hashes, timing and shared crop. Every frame uses the same AtlasTexture region, preventing frame-to-frame crop jitter. Godot imports at 1024×1024 lossless with mipmaps, matching Erpin's established quality setting; this is not a claim of unscaled 1536px runtime display.

`../idle_hq.tres` is automatically preferred by HubKit.avatar_full. Avatar-specific PCK export keeps this animation out of the main first-load package and retains the existing fallback while downloading. Original skeleton/atlas/texture files are retained in the task's outputs/avatars-hq-20261025/source/Daya/ folder.
