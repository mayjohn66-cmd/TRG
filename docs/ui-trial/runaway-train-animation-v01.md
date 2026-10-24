# Runaway train on the board

## Camera and collision polish (2026-10-24)

Before the locomotive enters, the board camera eases into a restrained 12% zoom toward the entry side, then gently pans along its route. Board artwork, pawn sprites, 3D rails and train share the same transform; HUD panels stay at their normal scale. The camera returns smoothly after the train passes and restores immediately on cancellation or reset, including a window resize during the shot.

Victims remain on their original tiles until the accelerating front reaches them. Contact times are solved from the visible train's acceleration curve, so a skipped browser frame preserves individual collision times instead of launching every victim at the late frame. Pawns launch primarily along the train's travel direction with an outward deflection, upward impulse, gravity, tumble and a late fade.

Validation for this iteration is limited to `tests/ui_train_test.gd`: all four entry sides, same-frame world projection, pre-contact retention, forward flights, ordered contacts after a stalled frame and camera restoration after completion/interruption. Native desktop/mobile captures are in workspace `outputs/train-camera-20261024`. `[check:train]` selects only this focused test during deployment; broader suites remain available separately.

## Original implementation

The TRAIN sweep now uses the approved 3D toy locomotive, four freight wagons and modular track on the existing board. It lays short track segments in travel order with a low drop and dry wooden clacks, waits 0.40 seconds after construction, then accelerates the train through the selected side. All 22 wheels rotate and steam drifts behind the stack. Surviving tracks fade after the last wagon has exited.

An isolated transparent SubViewport renders real meshes. Its ground projection maps onto the same board plane as the tile artwork, so track position, gauge and train orientation remain aligned on all four sides and after window resizing. Static meshes are combined by material on presentation instances; source model assets remain intact, and wheel pivots stay separate for rotation. The render target stops updating while idle.

NpcSweep emits a presentation snapshot signal before resetting pawns or removing traps. MainBoard holds their original visuals, then releases each tile when the locomotive front reaches it. Actual pawn sprites tumble off the board, and trap icons shatter at that contact. These victims skip the generic delayed ejection queue, so they cannot get knocked away a second time after the train. Other sides and the goal safe zone remain unaffected. Core clearing still happens immediately and uses the existing path, captures and trap rules; the presentation consumes no authoritative RNG and changes no global time scale.

The sequence uses local time and follows the game's animation pace. It participates in the normal presentation queue and input lock, including draft reveal deferral. Reset/rewind hides the train and releases all held sprites and trap art. Other summoned NPC movement keeps its existing presentation; the old drawn TrainSprite has been removed.

Validation: `tests/ui_train_test.gd` exercises all four sides, allied/enemy/shielded victims, safe-zone and other-side exclusions, pre-contact trap retention, sequential construction, the pause, wheel/wagon retention, ordered front contacts, actual sprite displacement, queue completion and interruption during construction. `test_super_augments.gd` also checks the pre-clear snapshot ordering and identical route/RNG. Native desktop/mobile captures and a recorded demo are in workspace `outputs/runaway-train-animation-v01`. CI runs the focused train test before export.
