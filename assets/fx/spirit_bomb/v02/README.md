# Spirit Bomb explosion carry

The eruption PNG is the live explosion and the final victory illustration.
`spirit_bomb_stage.gd` creates one `CarriedExplosionPrint` and retains it through
the finale. After the eruption settles, its rectangle freezes; only ink, palette
and halftone shading transition with `spirit_bomb_print.gdshader`. The shared
victory caption mask keeps the lower text area clear.

The previously generated `victory_poster.png` is retained as source history but
is no longer loaded by the victory presentation. Do not reconnect that separate
mountain scene: the user's approved direction is a continuous explosion frame.

Gather/drop/impact timings, sound cues and game rules are unchanged.
