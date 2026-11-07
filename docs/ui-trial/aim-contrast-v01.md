# Sniper and BANG aim contrast — 2026-10-28

Both aiming presentations now use saturated crimson (`#ff365c`) over a dark plum (`#35152b`) outline. This separates the marks from pale tiles, grass and coloured pawns. The sniper no longer washes its red ring toward gold while locking; its inner ticks and lock progress use a bright cream highlight. Main aiming strokes increase from 2–2.2 to 3 logical pixels, with a 6px backing stroke so the result retains a narrow outline at phone scale.

Original reticle shapes, open centres, motion, target coordinates, camera, shot timing, hit effects and game rules remain. No new raster assets or screen effects were added.

Native production renders were compared at 844×390, 740×360 and 1366×768 with touch layout enabled. All six aim centres remained attached to their actual targets. Existing focused `ui_sniper_test.gd` and `ui_bang_test.gd` passed acquisition, firing, actual ejection and reset checks. CI `bang` scope now checks just these two requested presentations. Following the user's audio preference, local test launchers use `--audio-driver Dummy` and future test instructions default to silent execution.
