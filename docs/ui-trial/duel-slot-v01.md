# Duel game selection slot

ACT_09 now opens with one wide casino reel containing all six minigames. Each ticket carries its game name and symbol; lamps chase, the lever pulls, and the drum decelerates into the authoritative game. A short locked-ticket beat is followed by a separate large instruction screen, then the existing game inputs open. There is no bottom explanation beneath the reel.

- Reel: 2.6 seconds, followed by a 0.55 second locked-ticket beat. The 700px wide instruction screen uses a large objective, controls and caution for each game. Start/view button continues immediately; a 6.05 second real-time fallback keeps unattended and spectator games moving. Game-speed settings do not shorten reading time.
- No new draw or gameplay RNG; the engine still chooses the game. Initial logs no longer spoil it before the visible stop.
- Bots and local inputs wait through the introduction. Already received network results stay queued. Input deadlines include the introduction allowance for all six games.
- Reuses existing bell, revolver and card art alongside simple scissors, bottle-cap and barrel symbols. No additional raster asset budget.
- Closing during a spin cancels the reel and releases input holds. The modal fits the available logical viewport.

Validation: 516 unit tests, 596466 assertions, zero failures; existing full UI FX test including six complete duels; focused six-game selection/queue/cancellation test; desktop and short-mobile render captures.

Large introduction follow-up: existing full UI FX and focused six-game selection tests pass, including start-button continuation, automatic continuation, input clock gating and desktop/mobile render captures. Capture artifacts: outputs/duel-intro-v02 in the task workspace.

During play, static instructions below the stage are also removed. Hotseat turns use the upper participant line; live feedback and results remain available.

Deferred card previews are now immediately owned by a hidden pending-announcement node. Cancelling the presentation frees its pending children. The focused test verifies ownership and cancellation; the existing six-duel orphan-count regression is retained.
