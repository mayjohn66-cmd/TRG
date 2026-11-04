## Bounty-only native verification: marker lifetime, movement, growth and stacking.
extends "res://tests/capture_darts_integration.gd"

func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	_board._on_draft_auto_pressed()
	await settle(15)
	quiet()
	_board.instant_roll_for_test = true
	_board.state.boost_gimmicks = false
	var hunter: int = _board._dock_owner()
	var enemy: int = 2 if hunter == 1 else 1
	var target: PlayerPawn = _board.state.pawns_of(enemy)[1]
	target.place_at(10)
	target.has_left_start = true
	var result: Dictionary = UtilityAugments.apply(UtilityAugments.BOUNTY, _board.state, hunter)
	_expect(bool(result.ok) and int(_board.state.bounties[hunter]) == target.entity_id, "real augment chooses target")
	_board._refresh_all()
	_board._roll_button.hide()
	var tip := _board.get_node_or_null("FirstMatchTip") as CanvasLayer
	if tip != null: tip.hide()
	_board._skill_hint.hide()
	await settle(14)
	var view: Node2D = _board._pawn_views[target.entity_id]
	var mark: TextureRect = view.get_node_or_null("WantedMark")
	_expect(mark != null and mark.texture.resource_path.ends_with("target.svg"), "target icon replaces WANTED label")
	if mark == null:
		printerr("BOUNTY_FAIL missing icon")
		quit(1)
		return
	_expect(mark.size == Vector2(26, 26) and mark.mouse_filter == Control.MOUSE_FILTER_IGNORE, "compact non-interactive marker")
	_expect(is_equal_approx(mark.material.get_shader_parameter("outline_px"), 1.8), "white silhouette outline")
	var initial_top: float = mark.position.y
	await snap("01-bounty-target")
	_board.state.bounties[4] = target.entity_id
	_board._refresh_bounty_marks()
	_expect(view.get_node("WantedMark") == mark, "multiple hunters reuse one marker")
	target.evolve(GameEnums.PawnKind.ARCADE, 7)
	target.melon_size = 3
	_board._refresh_all()
	_expect(mark.position.y < initial_top - 10.0, "large melon has clearance above its body")
	_board.instant_roll_for_test = false
	var ctx := RuleContext.new()
	ctx.state = _board.state
	ctx.actor_id = enemy
	ctx.raw_roll = 4
	ctx.dice_value = 4
	MoveExecutor.execute(_board.state, target, ctx)
	for i: int in 65:
		await process_frame
		_expect(mark.get_parent() == view and mark.rotation == 0.0, "target follows moving body without rolling")
	await snap("02-grown-moving-target")
	_board.instant_roll_for_test = true
	quiet()
	var carrier: PlayerPawn = _board.state.pawns_of(enemy)[0]
	carrier.place_at(target.current_tile_idx)
	carrier.has_left_start = true
	carrier.carried.append(target)
	target.carrier = carrier
	_board._refresh_all()
	_expect(_board._pawn_views[carrier.entity_id].get_node_or_null("WantedMark") != null and view.get_node_or_null("WantedMark") == null, "carried target marks visible carrier")
	carrier.carried.clear()
	target.carrier = null
	_board._refresh_all()
	target.reset_to_start()
	_board._refresh_all()
	_expect(view.get_node_or_null("WantedMark") == null, "waiting target has no board marker")
	ctx.dice_value = 1
	ctx.raw_roll = 1
	MoveExecutor.execute(_board.state, target, ctx)
	_expect(view.get_node_or_null("WantedMark") != null, "first redeployment step immediately restores target")
	_board.state.bounties.clear()
	_board._refresh_bounty_marks()
	_expect(view.get_node_or_null("WantedMark") == null, "cleared bounty removes marker immediately")
	_board.state.bounties[hunter] = target.entity_id
	_board._refresh_bounty_marks()
	_expect(view.get_node_or_null("WantedMark") != null and not view.get_node("WantedMark").is_queued_for_deletion(), "same-frame reapply creates a live marker")
	_board.manager.is_game_over = true
	_board._refresh_bounty_marks()
	_expect(view.get_node_or_null("WantedMark") == null, "game over clears targets")
	_board.manager.is_game_over = false
	for failure: String in _failures: printerr("BOUNTY_FAIL ", failure)
	print("BOUNTY_NATIVE ", _failures.size(), " failures; movement 65 samples")
	MatchTelemetry.test_sender = Callable()
	quit(0 if _failures.is_empty() else 1)
