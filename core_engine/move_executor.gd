# File: res://core_engine/move_executor.gd
# Class: class_name MoveExecutor
# Role: 호스트 전용 이동 실행기. 한 칸씩 이동하며 설치물·결승 바운스·워프·잡기·업기를 판정하고, 법전 훅을 통과시킨 뒤 MoveReport를 만든다.
class_name MoveExecutor
extends RefCounted


## mover를 ctx.dice_value(법전 통과 후 확정 칸수)만큼 움직인다. 모든 중간 변화는 GameState 시그널로 방송된다.
static func execute(state: GameState, mover: PlayerPawn, ctx: RuleContext) -> MoveReport:
	var report := MoveReport.new()
	report.pawn_id = mover.entity_id
	ctx.pawn = mover
	if ctx.charge_depth == 0:
		ctx.trigger_timing = RuleContext.ON_MOVE_CALC
		ctx = state.rulebook.process_context(ctx)
		if ctx.is_canceled:
			ctx.is_canceled = false
			report.canceled = true
			return report

	var board: BoardGraph = state.board
	var signed_steps: int = ctx.dice_value * ctx.direction
	var forward: bool = signed_steps > 0
	var remaining: int = absi(signed_steps)
	var start_tile: int = mover.current_tile_idx
	var cursor: PathCursor = PathCursor.from_entity(mover, mover.has_left_start)
	var first_step: bool = true
	var resolved_normally: bool = true
	mover.retreated_from_start = false

	while remaining > 0:
		var from_tile: int = cursor.tile
		var stepped_forward: bool = forward
		if forward:
			board.advance_forward(cursor, first_step, ctx.allow_shortcut, mover.turns_at_corner_when_passing())
		else:
			board.advance_backward(cursor)
			if first_step and start_tile == GameEnums.GOAL_TILE:
				mover.retreated_from_start = true
		first_step = false
		remaining -= 1
		_commit_cursor(state, mover, cursor)
		report.path.append(cursor.tile)
		ctx.path_nodes.append(cursor.tile)
		state.pawn_stepped.emit(mover.entity_id, from_tile, cursor.tile)

		if _trigger_attachments(state, mover, ctx, cursor.tile, remaining == 0, report):
			if not mover.has_left_start:
				# 함정이 말을 출발선으로 돌려보냈다 (send_to_start가 출발 상태를 초기화한다).
				report.trapped = true
				resolved_normally = false
				break
			remaining = 0
			report.stopped_early = true

		if stepped_forward and cursor.tile == GameEnums.GOAL_TILE and mover.has_left_start:
			if remaining > 0 and ctx.exact_goal_required:
				forward = false
				report.bounced = true
			else:
				_finish(state, mover, report)
				resolved_normally = false
				break

	if resolved_normally:
		_resolve_landing(state, mover, ctx, report)
	return report


static func _commit_cursor(state: GameState, mover: PlayerPawn, cursor: PathCursor) -> void:
	mover.current_tile_idx = cursor.tile
	mover.step_history.assign(cursor.history)
	mover.has_left_start = cursor.started
	state.sync_stack_position(mover)


static func _finish(state: GameState, mover: PlayerPawn, report: MoveReport) -> void:
	var members: Array[PlayerPawn] = mover.stack_members()
	var all_yut: bool = members.size() == GameEnums.PAWNS_PER_PLAYER
	for member: PlayerPawn in members:
		if member.kind != GameEnums.PawnKind.YUT:
			all_yut = false
	state.finish_stack(mover)
	report.finished = true
	if all_yut:
		report.special_victory = &"yut_four_stack"


static func _trigger_attachments(
		state: GameState,
		mover: PlayerPawn,
		ctx: RuleContext,
		tile_index: int,
		is_landing: bool,
		report: MoveReport) -> bool:
	var tile: TileNode = state.board.get_tile(tile_index)
	ctx.metadata["is_landing"] = is_landing
	for attachment: TileAttachment in tile.attachments.duplicate():
		ctx.metadata.erase("cutscene_id")
		var halted: bool = attachment.on_step_trigger(mover, ctx)
		if halted:
			var cutscene_id: StringName = ctx.metadata.get("cutscene_id", &"")
			state.attachment_triggered.emit(tile_index, attachment.attachment_id, mover.entity_id, cutscene_id)
			report.attachment_events.append({
				"tile": tile_index,
				"attachment_id": attachment.attachment_id,
				"pawn_id": mover.entity_id,
				"cutscene_id": cutscene_id,
			})
		if attachment.is_expired():
			tile.remove_attachment(attachment)
		if halted:
			return true
	return false


## 도착(마지막 칸) 처리: 빵집 → 옷장 워프 → 잡기 → 업기 → 이동 완료 훅.
static func _resolve_landing(state: GameState, mover: PlayerPawn, ctx: RuleContext, report: MoveReport) -> void:
	var tile: TileNode = state.board.get_tile(mover.current_tile_idx)
	if tile.tile_type == TileNode.TileType.BAKERY and ctx.charge_depth == 0:
		var card_id: StringName = state.draw_card(mover.owner_id)
		if card_id != &"":
			report.drawn_card = card_id
	if tile.tile_type == TileNode.TileType.PORTAL:
		if not _warp_to_center(state, mover, ctx, report):
			return
	_resolve_captures(state, mover, ctx, report)
	if mover.is_finished:
		return
	_resolve_stacking(state, mover, ctx, report)
	ctx.trigger_timing = RuleContext.ON_TURN_END
	ctx = state.rulebook.process_context(ctx)
	ctx.is_canceled = false
	for command: GameCommand in ctx.effects:
		command.execute(state)
		report.effect_names.append(command.command_name)
	ctx.effects.clear()


## 옷장(PORTAL)에 멈추면 22번에 도착해 멈춘 것으로 판정한다 (다음 이동은 27 -> 28 -> 0 최단 루트).
## 워프 도착 칸의 함정에 걸려 출발선으로 돌아가면 false를 반환한다.
static func _warp_to_center(state: GameState, mover: PlayerPawn, ctx: RuleContext, report: MoveReport) -> bool:
	var from_tile: int = mover.current_tile_idx
	mover.current_tile_idx = GameEnums.CENTER_TILE
	mover.step_history.append(GameEnums.CENTER_TILE)
	state.sync_stack_position(mover)
	report.warped = true
	report.path.append(GameEnums.CENTER_TILE)
	ctx.path_nodes.append(GameEnums.CENTER_TILE)
	state.pawn_warped.emit(mover.entity_id, from_tile, GameEnums.CENTER_TILE)
	if _trigger_attachments(state, mover, ctx, GameEnums.CENTER_TILE, true, report) and not mover.has_left_start:
		report.trapped = true
		return false
	return true


static func _resolve_captures(state: GameState, mover: PlayerPawn, ctx: RuleContext, report: MoveReport) -> void:
	if mover.current_tile_idx == GameEnums.GOAL_TILE:
		return
	var victims: Array[PlayerPawn] = []
	for leader: PlayerPawn in state.leaders_at(mover.current_tile_idx):
		if leader.owner_id != mover.owner_id:
			victims.append(leader)
	if victims.is_empty():
		return
	ctx.capturer = mover
	ctx.captured_pawns = victims
	ctx.capture_extra_turn = true
	ctx.capture_charge_steps = 0
	ctx.trigger_timing = RuleContext.ON_CAPTURE
	ctx = state.rulebook.process_context(ctx)
	if ctx.is_canceled:
		ctx.is_canceled = false
		return
	for victim: PlayerPawn in victims:
		for member: PlayerPawn in victim.stack_members():
			report.captured_pawn_ids.append(member.entity_id)
		state.send_to_start(victim, mover.owner_id)
	if ctx.capture_extra_turn:
		report.extra_turn = true
	if ctx.capture_charge_steps > 0 and ctx.charge_depth == 0:
		var charge_ctx: RuleContext = ctx.make_follow_up(ctx.capture_charge_steps)
		var charge_report: MoveReport = execute(state, mover, charge_ctx)
		report.merge(charge_report)


## 업기: 법전(allow_stacking)이 기물 고유 능력(can_stack_with)보다 우선한다. 출발선(0번)에서는 업지 않는다.
static func _resolve_stacking(state: GameState, mover: PlayerPawn, ctx: RuleContext, report: MoveReport) -> void:
	if not ctx.allow_stacking or mover.current_tile_idx == GameEnums.GOAL_TILE:
		return
	for other: PlayerPawn in state.leaders_at(mover.current_tile_idx):
		if other != mover and mover.can_stack_with(other):
			state.stack_pawns(mover, other)
			for member: PlayerPawn in mover.stack_members():
				if not report.stacked_pawn_ids.has(member.entity_id):
					report.stacked_pawn_ids.append(member.entity_id)
