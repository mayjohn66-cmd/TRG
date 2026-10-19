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
	board.instant_roll_for_test = true
	board._reset_presentation()
	board._fx_until_msec = 0
	var state: GameState = board.state
	# A bot's first step can run between phase refreshes. Its slot must already
	# reflect deployment while that same movement phase is still in progress.
	var bot_pawn: PlayerPawn = state.get_pawn(31)
	var bot_ctx := RuleContext.new()
	bot_ctx.state = state
	bot_ctx.actor_id = 3
	bot_ctx.dice_value = 1
	var bot_report: MoveReport = MoveExecutor.begin(state, bot_pawn, bot_ctx)
	MoveExecutor.apply_step(state, bot_pawn, bot_ctx, 1, true, true, bot_report)
	expect((board._profiles[3]["slots"][0]["status"] as Label).text == "출전", "bot deployment updates its profile slot before the next phase refresh")
	state.send_to_start(bot_pawn, 3)
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
	board.instant_roll_for_test = false
	var report: MoveReport = MoveExecutor.execute(state, mine, ctx)
	await _wait_for_pose()
	expect(report.captured_pawn_ids.has(21), "real move captures the opposing pawn")
	expect(board._capture_cutin.active, "actual capture signal opens the overlay")
	expect(board._capture_cutin._strike != null, "the actual capture overlay loads the painted A SINGULAR STRIKE lettering")
	expect(board._capture_cutin.attacker_avatar == &"avatar_03", "my selected avatar attacks")
	expect(board._capture_cutin.defender_avatar == board._avatar_for(2), "opponent's own avatar is hit")
	expect(board._ui_busy(), "input waits for the short presentation")
	var victim_start: Vector2 = (board._pawn_views[21] as Node2D).position
	var snapshot: Dictionary = TurnSnapshot.capture(state).to_dict()
	var rng_state: int = state.rng.state
	await create_timer(0.40).timeout
	expect(board._capture_cutin.busy(), "capture holds long enough to read the slow recoil")
	expect(float(CaptureCutin.caption_at(board._capture_cutin.elapsed)["alpha"]) > 0.0, "strike lettering stays visible alongside the character illustrations")
	await create_timer(CaptureCutin.DURATION - 0.40 + 0.08).timeout
	expect(not board._capture_cutin.busy(), "presentation cleans up after its full slow-motion duration")
	expect(TurnSnapshot.capture(state).to_dict() == snapshot and state.rng.state == rng_state, "visual frames do not mutate authoritative state/RNG")
	expect((board._pawn_views[21] as Node2D).position.distance_to(victim_start) > 3.0, "ejection starts promptly after the pose without a second cutin delay")
	await _wait_for_queue()
	state.send_to_start(state.get_pawn(12), 2)
	expect(not board._capture_cutin.active, "trap-like generic reset does not show the attack")
	await _wait_for_queue()
	board._on_pawn_captured(21, 11)
	await _wait_for_pose()
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


func _wait_for_pose() -> void:
	var until: int = Time.get_ticks_msec() + 4000
	while not board._capture_cutin.active and Time.get_ticks_msec() < until:
		await create_timer(0.01).timeout


func _wait_for_queue() -> void:
	var until: int = Time.get_ticks_msec() + 4000
	while board._presentation_active() and Time.get_ticks_msec() < until:
		await create_timer(0.01).timeout
	expect(not board._presentation_active(), "the presentation queue finishes")
