extends SceneTree

var board: MainBoard
var failures: Array[String] = []
var frames: int = 0

func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		GameSession.avatar_id = &"avatar_03"
		board = load("res://scenes/main_board.tscn").instantiate()
		board.instant_roll_for_test = true
		root.add_child(board)
	if frames == 3:
		_run()
	return false

func expect(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _run() -> void:
	board._bot.set_enabled(false)
	board.ai_mode = false
	board._close_draft_overlay()
	board._close_opening()
	board._intro_pending = false
	board._announcer.cancel()
	board._announced_round = board.state.round_number
	board.pacing_enabled = false
	board.instant_roll_for_test = false
	var state: GameState = board.state
	var mine: PlayerPawn = state.get_pawn(11)
	var enemy: PlayerPawn = state.get_pawn(21)
	mine.current_tile_idx = 1
	mine.has_left_start = true
	mine.step_history.assign([1])
	enemy.current_tile_idx = 2
	enemy.has_left_start = true
	enemy.step_history.assign([2])
	board._refresh_all()
	board._announcer.cancel()
	var ctx := RuleContext.new()
	ctx.state = state
	ctx.actor_id = 1
	ctx.raw_roll = 1
	ctx.dice_value = 1
	var report: MoveReport = MoveExecutor.execute(state, mine, ctx)
	expect(report.captured_pawn_ids.has(21), "real move captures the opposing pawn")
	expect(board._capture_cutin.active, "actual capture signal opens the overlay")
	expect(board._capture_cutin.attacker_avatar == &"avatar_03", "my selected avatar attacks")
	expect(board._capture_cutin.defender_avatar == board._avatar_for(2), "opponent's own avatar is hit")
	expect(board._ui_busy(), "input waits for the short presentation")
	var snapshot: Dictionary = TurnSnapshot.capture(state).to_dict()
	var rng_state: int = state.rng.state
	await create_timer(0.40).timeout
	expect(board._capture_cutin.busy(), "capture holds long enough to read the slow recoil")
	await create_timer(CaptureCutin.DURATION - 0.40 + 0.08).timeout
	expect(not board._capture_cutin.busy(), "presentation cleans up after its full slow-motion duration")
	expect(TurnSnapshot.capture(state).to_dict() == snapshot and state.rng.state == rng_state, "visual frames do not mutate authoritative state/RNG")
	state.send_to_start(state.get_pawn(12), 2)
	expect(not board._capture_cutin.active, "trap-like generic reset does not show the attack")
	board._on_pawn_captured(21, 11)
	expect(board._capture_cutin.attacker_avatar == board._avatar_for(2) and board._capture_cutin.defender_avatar == &"avatar_03", "roles reverse when the opponent captures me")
	state.snapshot_restored.emit()
	expect(not board._capture_cutin.busy() and board._capture_marks.is_empty(), "snapshot restoration clears current poses")
	board._stage_warps = 1
	board._on_pawn_captured(21, 11)
	state.snapshot_restored.emit()
	board._stage_warps = 0
	board._fx_after_announcer()
	expect(not board._capture_cutin.busy(), "restoration invalidates delayed capture callbacks")
	board._new_game()
	expect(not board._capture_cutin.busy() and board._capture_marks.is_empty(), "rematch removes old poses and queue")
	board.instant_roll_for_test = true
	if failures.is_empty(): print("UI_CAPTURE_OK: real capture, selected avatars, reverse roles, reset exclusion, no simulation mutation, cleanup")
	else:
		for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
