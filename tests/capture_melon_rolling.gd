## Real movement signals and presentation queue, at both normal and giant size.
extends "res://tests/capture_darts_integration.gd"

var motion_checks: int = 0

func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	_board._on_draft_auto_pressed()
	await settle(15)
	quiet()
	_board.instant_roll_for_test = true
	_board.state.boost_gimmicks = false
	var pawn: PlayerPawn = _board.state.pawns_of(_board._dock_owner())[0]
	pawn.evolve(GameEnums.PawnKind.ARCADE, 7)
	pawn.place_at(1)
	pawn.has_left_start = true
	_board.manager.current_turn_index = _board.manager.player_order.find(pawn.owner_id)
	_board.manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
	quiet()
	_board._refresh_all()
	_board._roll_button.hide()
	var tip := _board.get_node_or_null("FirstMatchTip") as CanvasLayer
	if tip != null: tip.hide()
	_board._skill_hint.hide()
	await settle(12)
	await snap("01-melon-ready")
	var token: PawnToken = _board._pawn_views[pawn.entity_id].get_node("Bounce/Token")
	_expect(token.artwork.texture.resource_path.ends_with("ODD_MELON_V01.png"), "native board uses new fruit")
	_board.instant_roll_for_test = false
	recording = true
	await settle(12)
	await roll_path(pawn, 4, "02-normal-rolled")
	await settle(18)
	# Reposition only between the two movement demonstrations.
	_board.instant_roll_for_test = true
	pawn.place_at(13)
	pawn.melon_size = 3
	_board._refresh_all()
	await settle(2)
	_board.instant_roll_for_test = false
	await settle(18)
	await roll_path(pawn, 4, "03-giant-rolled")
	await settle(18)
	recording = false
	# A canceled motion must stop spinning and settle to authoritative position.
	var view: Node2D = _board._pawn_views[pawn.entity_id]
	_board._play_hop(pawn.entity_id, view.position + Vector2(90, 0), view.scale.x, 18)
	await settle(2)
	_board._reset_presentation()
	_board._kill_fx(view)
	var stopped: float = token.melon_roll_angle
	_board.instant_roll_for_test = true
	_board._refresh_all()
	await settle(8)
	_expect(is_equal_approx(token.melon_roll_angle, stopped) and not _board._fx_running(view), "cancel stops body rotation")
	_expect(view.position.is_equal_approx(_board._pawn_position(pawn)), "cancel restores authoritative tile")
	for failure: String in _failures: printerr("MELON_FAIL ", failure)
	print("MELON_NATIVE ", _failures.size(), " failures; ", motion_checks, " grounded samples; ", recorded_frames, " frames")
	MatchTelemetry.test_sender = Callable()
	quit(0 if _failures.is_empty() else 1)

func roll_path(pawn: PlayerPawn, steps: int, snapshot: String) -> void:
	var view: Node2D = _board._pawn_views[pawn.entity_id]
	var token: PawnToken = view.get_node("Bounce/Token")
	var bounce: Node2D = view.get_node("Bounce")
	var ctx := RuleContext.new()
	ctx.state = _board.state
	ctx.actor_id = pawn.owner_id
	ctx.raw_roll = steps
	ctx.dice_value = steps
	var events: Array = []
	var on_step: Callable = func(_id: int, _from: int, tile: int) -> void:
		if _id == pawn.entity_id: events.append(tile)
	_board.state.pawn_stepped.connect(on_step)
	var rng_before: int = _board.state.rng.state
	MoveExecutor.execute(_board.state, pawn, ctx)
	_board.state.pawn_stepped.disconnect(on_step)
	var previous_angle: float = token.melon_roll_angle
	var spin: float = 0.0
	var moving: int = 0
	var samples: int = 0
	while samples < 180 and (_board._presentation_active() or _board._fx_running(view)):
		await process_frame
		samples += 1
		_expect(bounce.position == Vector2.ZERO and bounce.scale == Vector2.ONE and bounce.rotation == 0.0, "rolling has no jump/squash/base rotation")
		_expect(view.rotation == 0.0, "ground shadow and label remain upright")
		var delta: float = wrapf(token.melon_roll_angle - previous_angle, -PI, PI)
		spin += delta
		if absf(delta) > 0.001: moving += 1
		previous_angle = token.melon_roll_angle
		motion_checks += 1
	_expect(events.size() == steps, "real engine emits each expected step")
	_expect(moving > 5 and absf(spin) > 1.0, "body visibly rotates across multiple steps")
	_expect(view.position.distance_to(_board._pawn_position(pawn)) < 0.01, "roll stops at actual destination")
	_expect(_board.state.rng.state == rng_before, "cosmetic rolling never consumes gameplay RNG")
	await snap(snapshot)
