# Live six-bug hotfix

Production base: `b1fe101c7c3486436a15ced30d2181d63d369c20` (`claude/tender-gauss-i4mq1o`). This patch was built in an isolated checkout; unfinished `local/v1.01` cutscenes and assets are excluded.

1. **Pinball / blocked targets:** the turn-start stage used the ordinary roll-phase visibility flag, so it covered the board before card use. Pinball now needs an explicit preparation action. Readiness survives asynchronous host acknowledgement and is consumed when rolling. All card targets, pawn choices and counter prompts use CanvasLayer 10000 (Godot caps CanvasItem z_index at 4096); tools also hide while a choice is open.
2. **Spaces in editors:** board, duel and rulebook shortcut handlers processed input before TextEdit/LineEdit. A shared guard returns for focused native text editors and browser input/textarea/contenteditable elements.
3. **Blocked kills / deaths:** reversible damage updated authoritative stats before counters finished. Counterable hits now keep pending deltas; declining/timeout commits once, successful defence restores the pawn without applying the deltas. Central ejection also checks wards and shields before recording damage. Existing counter-retaliation exclusions remain.
4. **Normal finisher:** completion previously used the survival/spectated-seat graduation rule. A real four-pawn completion now ends immediately, ranks remaining active seats from current race progress and stops the match timer.
5. **Mobile cards:** touch drags no longer bypass confirmation. First tap opens a large, scrollable description with a separate enabled/disabled Use button; only that button activates the card. Hand and augment description typography is enlarged. Korean, English and Japanese details are checked at two narrow landscape sizes.
6. **Final diagnostics:** retiring players sets their pawns to synthetic finished positions and removes won laws. Serializable board/law facts are now captured before retirement, preserved by network/rewind snapshots and used by final diagnostic reports. Earlier special graduates retain their own departure facts.

Focused, silent validation:

```sh
godot --headless --audio-driver Dummy --path . -s res://tests/run_live_hotfix.gd
godot --headless --audio-driver Dummy --path . -s res://tests/ui_live_hotfix_test.gd
```

`[check:live-hotfix]` selects these checks in deployment CI. No whole-game suite is requested for this hotfix. Temporary browser fixtures and audio muting are local QA only and are not exported to production.

Local result: 132 core assertions and 46 UI assertions passed. The UI checks send real pointer/key events for trap placement, UNO target selection, feedback spaces, the first card tap and the Use button. Native rendering was also checked. In the muted ego-browser session, an actual UNO target click consumed the card, `hello` + Space + `world` remained `hello world`, and a touch on Use consumed the previewed card and closed the preview without script errors. Browser surface screenshots were unavailable in this environment; visual layout was checked with the native renderer and layout bounds.
