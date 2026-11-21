# A SINGULAR STRIKE! capture lettering

Enemy pawn captures now display the exact phrase **A SINGULAR STRIKE!** with both character illustrations. The phrase is a native-generated transparent artwork asset: condensed Gothic display lettering, rough black ink edges, gold-to-orange-red strokes and a restrained burgundy shadow.

The lettering snaps on at the 0.14-second contact beat, freezes with both actors through the 0.26-second impact hold, settles slightly during recoil and fades with the cutin before 0.96 seconds. Its visible alpha bounds fit the upper gap above the faces on standard, 4:3 and ultrawide viewports. Capture cancellation, duplicate suppression and subsequent queued opponents use the existing visual lifecycle.

Source: `assets/fx/capture/singular_strike.png`, original 2172×724 RGBA PNG preserved byte for byte. Godot imports a mipmapped 2048-pixel texture. Full generation prompt, native tool source/event identity, hash and transparency checks are in `capture-fx-v07.json`.

`capture-fx-v07.png` is the actual renderer's Shady/Daya contact frame. `capture-fx-v07.mp4` shows a real queued board capture at 60 fps. Preview audio is separately synchronized from the same existing curated effects, rather than recorded system loopback.

Validation: unit timing/hold/viewport bounds, actual capture UI lifecycle and RNG/state safety, native render review of all eight avatar pairings, Web export and packaged lettering/dependency checks. Existing character drawings and weapon-specific effects remain in use.
