# Duel game selection slot

ACT_09 now opens with one wide casino reel containing all six minigames. Each ticket carries its game name and symbol; lamps chase, the lever pulls, and the drum decelerates into the authoritative game. A short locked-ticket beat is followed by the selected game rules, then the existing game inputs open.

- Reel: 2.6 seconds; locked ticket and rules: 1.6 seconds total. Follows the game-speed button without extending for the old presentation-pace setting.
- No new draw or gameplay RNG; the engine still chooses the game. Initial logs no longer spoil it before the visible stop.
- Bots and local inputs wait through the introduction. Already received network results stay queued. Input deadlines include the introduction allowance for all six games.
- Reuses existing bell, revolver and card art alongside simple scissors, bottle-cap and barrel symbols. No additional raster asset budget.
- Closing during a spin cancels the reel and releases input holds. The modal fits the available logical viewport.

Validation: 516 unit tests, 596466 assertions, zero failures; existing full UI FX test including six complete duels; focused six-game selection/queue/cancellation test; desktop and short-mobile render captures.
