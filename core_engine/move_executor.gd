# File: res://core_engine/move_executor.gd
# Class: class_name MoveExecutor
# Role: 호스트 전용 이동 실행기. 한 칸 단위 프리미티브(begin/apply_step/finalize)로 설치물·결승 바운스·워프·잡기·업기를 판정하며, 동기 실행(execute)과 TurnManager의 비동기 한 칸씩 이동이 같은 규칙을 공유한다
class_name MoveExecutor
extends RefCounted

## 한 걸음을 밟은 결과.
enum StepOutcome {
	CONTINUE, # 계속 이동
	HALTED,   # 함정 등으로 이동이 중단됨 (현재 타일에서 도착 처리)
	TRAPPED,  # 함정이 말을 출발선으로 돌려보냄
	FINISHED, # 결승선 완주
}


## mover를 ctx.dice_value * ctx.direction 만큼 동기적으로 움직인다. 모든 중간 변화는 GameState 시그널로 방송된다.
## (비동기 연출이 필요한 이동은 TurnManager.execute_step_by_step_move가 같은 프리미티브를 await와 함께 호출한다.)
static func execute(state: GameState, mover: PlayerPawn, ctx: RuleContext) -> MoveReport:
	var report: MoveReport = begin(state, mover, ctx)
	if report.canceled:
		return report
	var path: Array[int] = state.board.calculate_path(mover, ctx.dice_value * ctx.direction, ctx)
	var outcome: StepOutcome = StepOutcome.CONTINUE
	for index: int in path.size():
		outcome = apply_step(state, mover, ctx, path[index], index == path.size() - 1, index == 0, report)
		if outcome != StepOutcome.CONTINUE:
			break
	finalize(state, mover, ctx, report, outcome)
	return report


## 이동 준비: ON_MOVE_CALC 법전 파이프라인을 통과시켜 지름길/업기/결승 바운스 플래그를 확정한다.
## 교칙이 이동을 취소하면 report.canceled가 true다. 돌진(charge_depth > 0) 이동은 플래그를 물려받으므로 건너뛴다.
static func begin(state: GameState, mover: PlayerPawn, ctx: RuleContext) -> MoveReport:
	var report := MoveReport.new()
	report.pawn_id = mover.entity_id
	ctx.pawn = mover
	mover.retreated_from_start = false
	if ctx.charge_depth == 0:
		ctx.trigger_timing = RuleContext.ON_MOVE_CALC
		var processed: RuleContext = state.rulebook.process_context(ctx)
		if processed.is_canceled:
			processed.is_canceled = false
			report.canceled = true
		elif mover.is_imprisoned:
			# 무인도(TRP_04): 짝수 눈금이 나와야 탈출하고, 홀수면 이번 이동은 헛수고가 된다.
			if absi(ctx.dice_value) % 2 == 0:
				mover.is_imprisoned = false
				report.released = true
			else:
				report.canceled = true
				report.jailed = true
	return report


## 기물을 destination 타일로 정확히 한 칸 옮기고 그 칸의 설치물·결승선을 판정한다.
## is_last: 경로의 마지막 걸음인가 / is_first: 이동의 첫 걸음인가.
static func apply_step(
		state: GameState,
		mover: PlayerPawn,
		ctx: RuleContext,
		destination: int,
		is_last: bool,
		is_first: bool,
		report: MoveReport) -> StepOutcome:
	var from_tile: int = mover.current_tile_idx
	var is_forward: bool = state.board.commit_step(mover, destination)
	mover.has_left_start = true
	if is_first and not is_forward and from_tile == GameEnums.GOAL_TILE:
		mover.retreated_from_start = true
	state.sync_stack_position(mover)
	report.path.append(destination)
	ctx.path_nodes.append(destination)
	state.pawn_stepped.emit(mover.entity_id, from_tile, destination)

	if _trigger_attachments(state, mover, ctx, destination, is_last, report):
		if not mover.has_left_start:
			# 함정이 말을 출발선으로 돌려보냈다 (send_to_start가 출발 상태를 초기화한다).
			report.trapped = true
			return StepOutcome.TRAPPED
		report.stopped_early = true
		return StepOutcome.HALTED

	if is_forward and destination == GameEnums.GOAL_TILE:
		_pay_salary(state, mover, report)
		if not is_last and ctx.exact_goal_required:
			report.bounced = true
			return StepOutcome.CONTINUE
		_finish(state, mover, report)
		return StepOutcome.FINISHED
	return StepOutcome.CONTINUE


## 이동 마무리: 정상 도착(CONTINUE/HALTED)이면 도착 처리(빵집·워프·잡기·업기·후속 효과)를 수행한다.
static func finalize(state: GameState, mover: PlayerPawn, ctx: RuleContext, report: MoveReport, outcome: StepOutcome) -> void:
	if outcome == StepOutcome.CONTINUE or outcome == StepOutcome.HALTED:
		_resolve_landing(state, mover, ctx, report)


## 모노폴리 2세트 [월급날]: 출발선(0번)을 지나거나 밟을 때마다 손패에 생떼 카드 2장을 보충한다.
static func _pay_salary(state: GameState, mover: PlayerPawn, report: MoveReport) -> void:
	if mover.kind != GameEnums.PawnKind.MONOPOLY or state.set_count(mover.owner_id, GameEnums.PawnKind.MONOPOLY) < GameEnums.SET_SYNERGY_2:
		return
	for i: int in 2:
		if state.draw_card(mover.owner_id) != &"":
			report.salary_cards += 1


## 모노폴리 카 [호텔 건설]: 이동이 끝난 타일에 2턴간 유지되는 통행료 호텔을 설치한다 (같은 타일의 내 호텔은 갱신).
static func _build_hotel(state: GameState, mover: PlayerPawn, report: MoveReport) -> void:
	var tile: TileNode = state.board.get_tile(mover.current_tile_idx)
	for attachment: TileAttachment in tile.attachments.duplicate():
		if attachment.attachment_id == "HOTEL" and attachment.owner_id == mover.owner_id:
			tile.remove_attachment(attachment)
	state.place_attachment(mover.current_tile_idx, Hotel.new(mover.owner_id))
	report.hotel_built = true


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


## 이 칸의 설치물을 차례로 발동시킨다. 함정이 이동을 중단시켜야 하면 true를 반환한다.
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
	if mover.kind == GameEnums.PawnKind.MONOPOLY and ctx.charge_depth == 0 and mover.current_tile_idx != GameEnums.GOAL_TILE:
		_build_hotel(state, mover, report)
	ctx.trigger_timing = RuleContext.ON_TURN_END
	ctx = state.rulebook.process_context(ctx)
	ctx.is_canceled = false
	for command: GameCommand in ctx.effects:
		command.bind_state(state)
		if command.can_execute(ctx):
			command.execute()
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
