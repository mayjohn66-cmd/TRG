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
	var path: Array[int] = plan_path(state, mover, ctx, report)
	var outcome: StepOutcome = StepOutcome.CONTINUE
	for index: int in path.size():
		outcome = apply_step(state, mover, ctx, path[index], index == path.size() - 1, index == 0, report)
		if outcome != StepOutcome.CONTINUE:
			break
	finalize(state, mover, ctx, report, outcome)
	return report


## 기물 능력을 반영한 이동 경로를 계산한다. 동기 실행(execute)과 TurnManager 비동기 이동이 공유한다.
## - 바둑 2세트 [포석]: 눈금 -1 (최소 1칸). - 장기 [포 넘기]: 중간 칸에 다른 말이 하나라도 있으면 +2칸.
static func plan_path(state: GameState, mover: PlayerPawn, ctx: RuleContext, report: MoveReport) -> Array[int]:
	var steps: int = ctx.dice_value * ctx.direction
	var sign_dir: int = -1 if steps < 0 else 1
	if steps != 0 and mover.kind == GameEnums.PawnKind.GO and state.set_count(mover.owner_id, GameEnums.PawnKind.GO) >= GameEnums.SET_SYNERGY_2:
		steps = sign_dir * maxi(absi(steps) - 1, 1)
	var path: Array[int] = state.board.calculate_path(mover, steps, ctx)
	if mover.kind == GameEnums.PawnKind.JANGGI and _path_jumps_over_pawn(state, mover, path):
		path = state.board.calculate_path(mover, steps + 2 * sign_dir, ctx)
		report.cannon_bonus = true
	return path


## 경로의 '중간 칸'(도착 칸 제외)에 이동자 본인·업은 말이 아닌 말(아군·적군 모두)이 서 있는가.
static func _path_jumps_over_pawn(state: GameState, mover: PlayerPawn, path: Array[int]) -> bool:
	for index: int in range(path.size() - 1):
		var tile: int = path[index]
		if tile == GameEnums.GOAL_TILE:
			continue
		for other: PlayerPawn in state.leaders_at(tile):
			if other != mover and other.has_left_start:
				return true
	return false


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

	# 나이트 점프: 중간 칸의 설치물은 무시하고 도착 칸의 설치물만 판정한다.
	var skip_attachments: bool = not is_last and mover.jumps_over_attachments()
	if not skip_attachments and _trigger_attachments(state, mover, ctx, destination, is_last, report):
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


## 모노폴리 카 [호텔 건설]: 이동이 끝난 타일에 내 턴 5번간(4세트면 영구) 유지되는 통행료 호텔을 설치한다 (같은 타일의 내 호텔은 갱신).
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
	# 바둑 2세트 [포석]: 내 바둑돌은 잡히지 않는다. 멈춘 침입자는 잡지 못하고 한 칸 밀려난다.
	for victim: PlayerPawn in victims:
		if is_capture_immune(state, victim):
			state.step_back_one(mover)
			report.pushed_back = true
			report.path.append(mover.current_tile_idx)
			return
	# 바둑 [알까기]: 잡는 대신 상대를 2칸 앞으로 튕겨 내고 내 돌이 그 칸을 차지한다.
	if mover.kind == GameEnums.PawnKind.GO:
		for victim: PlayerPawn in victims:
			_knock_forward(state, victim, 2, report)
		return
	ctx.capturer = mover
	ctx.captured_pawns = victims
	# 윷놀이 기물의 고유 능력 [신명나는 사냥]: 잡기 추가 턴은 윷놀이 기물로 잡았을 때만 얻는다.
	ctx.capture_extra_turn = mover.kind == GameEnums.PawnKind.YUT
	ctx.capture_charge_steps = 0
	ctx.trigger_timing = RuleContext.ON_CAPTURE
	ctx = state.rulebook.process_context(ctx)
	if ctx.is_canceled:
		ctx.is_canceled = false
		return
	var restrain_instead: bool = mover.kind == GameEnums.PawnKind.JANGGI \
			and state.set_count(mover.owner_id, GameEnums.PawnKind.JANGGI) >= GameEnums.SET_SYNERGY_2
	for victim: PlayerPawn in victims:
		for member: PlayerPawn in victim.stack_members():
			report.captured_pawn_ids.append(member.entity_id)
		if restrain_instead:
			# 장기 2세트 [초나라 포진]: 출발선으로 보내지 않고 그 자리에서 1턴 구속한다.
			for member: PlayerPawn in victim.stack_members():
				member.restrained_turns = maxi(member.restrained_turns, 1)
				report.restrained_pawn_ids.append(member.entity_id)
			if not state.hurt_players.has(victim.owner_id):
				state.hurt_players.append(victim.owner_id)
		else:
			state.send_to_start(victim, mover.owner_id)
	if ctx.capture_extra_turn:
		report.extra_turn = true
	if ctx.capture_charge_steps > 0 and ctx.charge_depth == 0:
		var charge_ctx: RuleContext = ctx.make_follow_up(ctx.capture_charge_steps)
		var charge_report: MoveReport = execute(state, mover, charge_ctx)
		report.merge(charge_report)


## 바둑 2세트를 가진 주인의 바둑돌은 잡히지 않는다 (포석).
static func is_capture_immune(state: GameState, pawn: PlayerPawn) -> bool:
	return pawn.kind == GameEnums.PawnKind.GO \
			and state.set_count(pawn.owner_id, GameEnums.PawnKind.GO) >= GameEnums.SET_SYNERGY_2


## 대표 말(업은 말 포함)을 앞으로 steps칸 튕겨 낸다. 결승선은 넘지 않고 직전 칸에서 멈추며, 설치물·잡기는 판정하지 않는다.
static func _knock_forward(state: GameState, victim: PlayerPawn, steps: int, report: MoveReport) -> void:
	var from_tile: int = victim.current_tile_idx
	var path: Array[int] = state.board.calculate_path(victim, steps, RuleContext.new())
	for destination: int in path:
		if destination == GameEnums.GOAL_TILE:
			break
		state.board.commit_step(victim, destination)
	if victim.current_tile_idx == from_tile:
		return
	state.sync_stack_position(victim)
	for member: PlayerPawn in victim.stack_members():
		report.knocked_pawn_ids.append(member.entity_id)
	state.pawn_knocked.emit(victim.entity_id, from_tile, victim.current_tile_idx)


## 대표 말을 steps칸 후퇴시킨다 (ACT_03 우노 +4 페널티). 설치물·잡기는 판정하지 않는다. 실제로 지난 타일들을 반환한다.
static func retreat(state: GameState, pawn: PlayerPawn, steps: int) -> Array[int]:
	var path: Array[int] = state.board.calculate_path(pawn, -absi(steps), RuleContext.new())
	for destination: int in path:
		var from_tile: int = pawn.current_tile_idx
		state.board.commit_step(pawn, destination)
		state.sync_stack_position(pawn)
		state.pawn_stepped.emit(pawn.entity_id, from_tile, destination)
	return path


## 업기: 윷놀이 기물의 고유 능력이다 (법전 allow_stacking이 우선). 출발선(0번)에서는 업지 않는다.
## ctx.defer_stack_choice가 켜져 있으면 즉시 합치지 않고 report.stack_offer로 플레이어의 선택을 요청한다.
static func _resolve_stacking(state: GameState, mover: PlayerPawn, ctx: RuleContext, report: MoveReport) -> void:
	if not ctx.allow_stacking or mover.current_tile_idx == GameEnums.GOAL_TILE:
		return
	var partners: Array[PlayerPawn] = []
	for other: PlayerPawn in state.leaders_at(mover.current_tile_idx):
		if other != mover and mover.can_stack_with(other):
			partners.append(other)
	if partners.is_empty():
		return
	if ctx.defer_stack_choice:
		var ids: Array[int] = []
		for partner: PlayerPawn in partners:
			ids.append(partner.entity_id)
		report.stack_offer = {"mover": mover.entity_id, "others": ids}
		return
	for other: PlayerPawn in partners:
		state.stack_pawns(mover, other)
	for member: PlayerPawn in mover.stack_members():
		if not report.stacked_pawn_ids.has(member.entity_id):
			report.stacked_pawn_ids.append(member.entity_id)
