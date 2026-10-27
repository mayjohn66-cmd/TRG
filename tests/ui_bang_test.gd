## ACT_02 only: actual card command, target selection, queue timing and cancellation.
extends SceneTree

var _board: MainBoard
var _failures: Array[String] = []
var _checks := 0
var _captures: Dictionary = {}
var _seen: Array[StringName] = []
var _origin := Vector2.ZERO
var _rng := 0
var _observe := false
var _first_launch := -1.0

func _initialize() -> void: _run.call_deferred()

func _expect(ok: bool, note: String) -> void:
	_checks += 1
	if not ok and not _failures.has(note): _failures.append(note)

func _capture(tag: String) -> void:
	var folder := OS.get_environment("BANG_CAPTURE_DIR")
	if folder.is_empty() or _captures.has(tag): return
	_captures[tag] = true
	_save.call_deferred(folder, tag)

func _save(folder: String, tag: String) -> void:
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(folder.path_join(tag + ".png")) == OK, "Capture " + tag)

func _process(_delta: float) -> bool:
	if not _observe or _board == null: return false
	var stage: Node2D = _board.get_node_or_null("BangStage")
	if stage == null: return false
	if not _seen.has(stage.phase): _seen.append(stage.phase)
	_expect(_board.state.rng.state == _rng, "Presentation does not consume game RNG")
	_expect(stage.target_id == 22, "The chosen player's actual leading pawn is targeted")
	_expect(stage.gun.flag_root.visible == false, "BANG uses the revolver without a roulette flag")
	_expect(stage.gun.mouse_filter == Control.MOUSE_FILTER_IGNORE and stage._veil.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Effects do not intercept pointer input")
	_expect(stage._tracer.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The textured tracer passes pointer input through")
	_expect(stage.MUZZLE_FLASH.get_width() == 512 and stage.HIT_SPARK.get_width() == 512, "Painted effects use the bounded runtime texture size")
	if stage.elapsed > stage.HIT_AT + 0.045:
		_expect(not stage._tracer.visible, "The tracer fades after impact instead of remaining as a beam")
	var view: Node2D = _board._pawn_views[22]
	if not stage.released:
		_expect(view.position.distance_to(_origin) < 0.1, "The victim stays at its real tile until impact hold ends")
	if _board._fx_running(view) and _first_launch < 0:
		_first_launch = stage.elapsed
		_expect(stage.hit_started and stage.released, "Ejection starts only after the shot hits")
		_expect(stage.elapsed < stage.RELEASE_AT + 0.12, "Impact flows into ejection without a second queue delay")
	if stage.elapsed > 0.32 and stage.phase == &"aim": _capture("bang-aim")
	if stage.fired and stage.elapsed < stage.HIT_AT: _capture("bang-shot")
	if stage.hit_started and not stage.released: _capture("bang-impact")
	if stage.released and stage.elapsed > 0.86: _capture("bang-eject")
	return false

func _stage() -> void:
	_board._reset_presentation()
	_board._announcer.cancel()
	if is_instance_valid(_board._draft_overlay): _board._draft_overlay.hide()
	_board._draft_open = false
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)
	_board.manager.draft_enabled = false
	_board.manager._counter_offer.clear()
	_board._fx_until_msec = 0
	var places := {11: 4, 21: 7, 22: 17, 31: 12, 41: 19}
	for pawn: PlayerPawn in _board.state.pawns:
		pawn.reset_to_start()
		pawn.has_left_start = places.has(pawn.entity_id)
		pawn.current_tile_idx = int(places.get(pawn.entity_id, 0))
		var view: Node2D = _board._pawn_views[pawn.entity_id]
		_board._kill_fx(view)
		view.position = _board._pawn_position(pawn)
		view.scale = Vector2.ONE * _board._depth_scale(MainBoard.tile_norm(pawn.current_tile_idx).y)
		view.modulate = Color.WHITE
		view.visible = pawn.has_left_start
	for seat: int in _board.state.hands: (_board.state.hands[seat] as Array).clear()
	_origin = _board._pawn_views[22].position
	_rng = _board.state.rng.state

func _fire(shooter: int = 1, victim: int = 2, front: int = 22) -> void:
	var card: BaseCard = CardRegistry.get_card(&"ACT_02")
	_expect(card.can_play(_board.state, shooter, {"target_player": victim}), "The real BANG card accepts the opponent")
	var command: GameCommand = card.create_command(_board.state, shooter, {"target_player": victim})
	command.bind_state(_board.state)
	command.execute()
	_expect(not _board.state.get_pawn(front).has_left_start, "Engine ejection is authoritative before visuals")
	_expect(_board.state.get_pawn(21).current_tile_idx == 7, "Only the leading pawn is ejected")

func _wait_done() -> void:
	var until := Time.get_ticks_msec() + 12000
	await process_frame
	while _board._presentation_active() and Time.get_ticks_msec() < until:
		await process_frame
	_expect(not _board._presentation_active(), "BANG queue finishes within its budget")

func _wait_stage() -> Node2D:
	var until := Time.get_ticks_msec() + 4000
	while _board.get_node_or_null("BangStage") == null and Time.get_ticks_msec() < until:
		await process_frame
	return _board.get_node_or_null("BangStage")

func _run() -> void:
	root.size = Vector2i(1366, 768)
	root.content_scale_size = Vector2i(1366, 768)
	GameSession.mode = GameSession.MODE_AI
	GameSession.pace_scale = 1.0
	_board = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(_board)
	var deadline := Time.get_ticks_msec() + 20000
	while (not _board._draft_open or _board._intro_blocks()) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(_board._draft_open, "Board is ready for the focused card fixture")
	_stage()
	_observe = true
	_fire()
	await _wait_done()
	_observe = false
	_expect(_seen == [&"aim", &"shot", &"impact", &"release"], "Aim, muzzle flash, hit hold and release occur in order")
	_expect(_first_launch >= 0, "The real target visibly flies out")
	_expect(_board.get_node_or_null("BangStage") == null, "The revolver, viewport and smoke are released")
	var view: Node2D = _board._pawn_views[22]
	_expect(not view.visible and is_zero_approx(view.rotation) and view.modulate == Color.WHITE, "Ejected pawn is hidden with its normal pose restored")
	_expect(_board.state.get_pawn(22).revenge_boost, "Existing revenge rules are preserved")

	# Cover reversed gun orientation and the supported motion speeds on real targets.
	for shot: Array in [[2, 1, 11, 0.5], [3, 4, 41, 2.0]]:
		_stage()
		GameSession.pace_scale = shot[3]
		_fire(shot[0], shot[1], shot[2])
		var other := await _wait_stage()
		_expect(other != null, "Another player can fire the same presentation")
		if other != null:
			while other.elapsed < 0.38: await process_frame
			_expect(other._muzzle.is_finite() and other._muzzle.distance_to(other._origin) < 140, "Muzzle projection follows the rotated revolver")
			_expect(other._muzzle.direction_to(other._at).dot(other._direction) > 0.98, "The revolver points toward its actual target in both directions")
		await _wait_done()
		_expect(_board.get_node_or_null("BangStage") == null, "Repeated shots release their viewport at both speeds")
	GameSession.pace_scale = 1.0

	# The original defense gate is retained before the shot, so no false hit leaks.
	_stage()
	var before := TurnSnapshot.capture(_board.state)
	_fire()
	_board.manager._counter_offer = {"victim": 2}
	await create_timer(0.12).timeout
	_expect(_board.get_node_or_null("BangStage") == null, "No gun or bullet appears while defense is pending")
	_board.manager._counter_offer.clear()
	before.restore(_board.state, false)
	await process_frame
	_expect(_board.get_node_or_null("BangStage") == null and _board.state.get_pawn(22).has_left_start, "Defending/rewinding cancels the pending shot")

	# Reset during aim and during flight; no residual tint, viewports or tweens.
	for age: float in [0.30, 0.82]:
		_stage()
		_fire()
		var stage := await _wait_stage()
		_expect(stage != null, "Cancellation fixture starts")
		if stage == null: continue
		while is_instance_valid(stage) and stage.elapsed < age: await process_frame
		_board._reset_presentation()
		await process_frame
		await process_frame
		_expect(_board.get_node_or_null("BangStage") == null, "Reset removes the stage at %.2f" % age)
		_expect(not view.visible and not _board._fx_running(view) and view.modulate == Color.WHITE and is_zero_approx(view.rotation), "Reset preserves real state and restores pose at %.2f" % age)

	_stage()
	_board.instant_roll_for_test = true
	_fire()
	await process_frame
	_expect(_board.get_node_or_null("BangStage") == null, "Effects-off mode does not instantiate 3D or stall")
	_board.queue_free()
	await process_frame
	await process_frame
	# Let already scheduled profile reactions expire before shutting down rendering.
	await create_timer(0.8).timeout
	if _failures.is_empty():
		print("UI_BANG_OK: %d checks" % _checks)
		quit(0)
	else:
		for failure: String in _failures: printerr("UI_BANG_FAIL: " + failure)
		quit(1)
