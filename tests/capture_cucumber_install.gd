## Real skill button -> planted prop -> pawn leaves -> enemy consumes it.
extends "res://tests/capture_darts_integration.gd"

func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	_board._on_draft_auto_pressed()
	await settle(15)
	quiet()
	_board.instant_roll_for_test = true
	var owner: int = _board._dock_owner()
	var pawn: PlayerPawn = _board.state.pawns_of(owner)[0]
	pawn.evolve(GameEnums.PawnKind.ARCADE, 6)
	pawn.place_at(3)
	pawn.has_left_start = true
	pawn.skill_used = false
	_board.manager.current_turn_index = _board.manager.player_order.find(owner)
	_board.manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
	quiet()
	_board._fx_busy = false
	_board._refresh_all()
	_board._roll_button.hide()
	var tip := _board.get_node_or_null("FirstMatchTip") as CanvasLayer
	if tip != null: tip.hide()
	await settle(16)
	_board._skill_hint.hide()
	await snap("01-before-planting")
	var button: Button = _board._skill_buttons[0] if _board.ai_mode else _board._dock_skill_buttons[0]
	_expect(button.is_visible_in_tree() and not button.disabled, "real skill button is available")
	recording = true
	await click(button)
	await settle(55)
	quiet()
	_board._refresh_all()
	await settle(18)
	_board._skill_hint.hide()
	await snap("02-cucumber-planted")
	_expect(pawn.skill_used, "real button spends the skill")
	var tile: TileNode = _board.state.board.get_tile(3)
	_expect(tile.attachments.size() == 1 and tile.attachments[0] is TrapCucumber, "skill installs one authoritative cucumber")
	_expect(_board._structure_views.has(3), "installation is visible on the board")
	if not _board._structure_views.has(3):
		printerr("CUCUMBER_FAIL missing installation after click")
		quit(1)
		return
	var model: MainBoard.BoardStructure = _board._structure_views[3].node
	_expect(model.kind == &"cucumber" and model.artwork.texture.resource_path.ends_with("CUCUMBER_V01.png"), "actual view uses cucumber prop")
	_expect(model.position.x > _board._tile_center(3).x + 8, "prop is offset from Cuee's body")
	var tooltip: String = _board._tile_views[3].tooltip_text
	_expect(tooltip.contains("오이") and not tooltip.contains("지뢰") and not tooltip.contains("폭발"), "tooltip describes cucumber, not mine")
	_expect(not _board._trap_tiles.has(3), "prop replaces the generic trap marker")
	var rng_state: int = _board.state.rng.state
	_board._refresh_tiles()
	_expect(_board._structure_views[3].node == model and _board.state.rng.state == rng_state, "refresh reuses the view without consuming RNG")
	pawn.place_at(5)
	_board._refresh_all()
	await settle(24)
	_board._skill_hint.hide()
	await snap("03-pawn-left-cucumber")
	_expect(_board._structure_views[3].node == model, "cucumber stays on the planted tile after Cuee leaves")
	recording = false
	# Use the real movement/landing pipeline, rather than deleting the view.
	var enemy: int = 2 if owner == 1 else 1
	var victim: PlayerPawn = _board.state.pawns_of(enemy)[0]
	victim.place_at(2)
	victim.has_left_start = true
	_board.state.hands[enemy] = []
	var ctx := RuleContext.new()
	ctx.state = _board.state
	ctx.actor_id = enemy
	ctx.raw_roll = 1
	ctx.dice_value = 1
	MoveExecutor.execute(_board.state, victim, ctx)
	quiet()
	_board._refresh_all()
	await settle(35)
	_expect((_board.state.hands[enemy] as Array).has(&"JNK_CUKE"), "enemy receives the existing cucumber card")
	_expect(not tile.has_attachment("TRP_CUKE") and not _board._structure_views.has(3) and not is_instance_valid(model), "consumed cucumber removes its prop")
	await snap("04-consumed")
	for failure: String in _failures: printerr("CUCUMBER_FAIL ", failure)
	print("CUCUMBER_NATIVE ", _failures.size(), " failures; ", recorded_frames, " frames")
	MatchTelemetry.test_sender = Callable()
	quit(0 if _failures.is_empty() else 1)
