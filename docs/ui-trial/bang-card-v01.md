# BANG! card presentation

ACT_02 uses the existing assembled silver revolver. The gun rises beside the
shooter's profile, cocks its hammer and points at the actual leading enemy pawn.
Four quiet aim corners converge around that pawn. One shot produces a short
muzzle flash, a fast gold tracer, soft drifting smoke, and a brief impact pose.
After the hit hold, the existing ejection animation launches the real pawn off
the board. Smoke and the gun fade during that flight.

- Shot 0.58 s, hit 0.65 s, ejection release 0.74 s; gun/smoke end at 1.12 s.
- Existing presentation speed applies; a slow first model upload cannot skip beats.
- Coordinates include the pawn layer transform. The tracer starts at the 3D
  muzzle projected through the gun viewport, including mirroring and rotation.
- The pending ejection step is replaced in place. The existing defense gate,
  announcements, carried pawns and bond consequences retain their queue order.
- A successful defense/rewind produces no false shot or ejection. Reset removes
  the gun, smoke, dimming and restores the pawn to its authoritative state.
- Uses the existing shot sound at -3 dB and toy click at -8 dB. No new downloads.
- No gameplay rule/RNG changes. UDO +4 retains its separate existing feedback.
- Corrected the old “pushed back 2 spaces” log in Korean, English and Japanese;
  the actual BANG rule already ejects the target to the start.

## Scoped validation

`godot --headless --path . -s res://tests/ui_bang_test.gd`

Exercises the real card/command against a staged board: leading target, shot/hit/
ejection order, defense gate, snapshot restoration, reset during aim and flight,
opposite directions, presentation speeds, repeated viewport cleanup, effects-off
mode and unchanged game RNG. `BANG_CAPTURE_DIR` optionally saves native frames.
CI commit marker `[check:bang]` selects this check instead of the full game suite.
