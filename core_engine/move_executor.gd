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


## 이 말이 눈금 dice_value로 움직일 때의 예상 경로 (UI 미리보기·AI 평가용). 법전(ON_MOVE_CALC)을 Dry-Run으로 통과시키고
## 기물 능력까지 반영한다. 이동이 취소되면 빈 배열이다. 게임 상태는 바뀌지 않는다.
static func preview_path(state: GameState, pawn: PlayerPawn, dice_value: int) -> Array[int]:
	var ctx := RuleContext.new()
	ctx.state = state
	ctx.actor_id = pawn.owner_id
	ctx.dice_value = dice_value
	ctx.raw_roll = dice_value
	ctx.direction = state.movement_direction()
	ctx.pawn = pawn
	ctx.is_preview = true
	ctx.trigger_timing = RuleContext.ON_MOVE_CALC
	ctx = state.rulebook.process_context(ctx)
	if ctx.is_canceled:
		return [] as Array[int]
	return plan_path(state, pawn, ctx, MoveReport.new())


## 기물 능력을 반영한 이동 경로를 계산한다. 동기 실행(execute)과 TurnManager 비동기 이동이 공유한다.
## 세부 기물: 백돌 눈금 -1(최소 1칸), 퀸 +2칸, 비숍 코너 스침 +2칸, 포 +3칸(경로 중간에 말), 마 +2칸 / 상 +3칸(바로 앞 칸이 비면).
static func plan_path(state: GameState, mover: PlayerPawn, ctx: RuleContext, report: MoveReport) -> Array[int]:
	var steps: int = ctx.dice_value * ctx.direction
	var sign_dir: int = -1 if steps < 0 else 1
	if steps == 0:
		return state.board.calculate_path(mover, steps, ctx)
	var sub: GameEnums.PawnSubType = mover.sub_type()
	if sub == GameEnums.PawnSubType.BADUK_WHITE:
		steps = sign_dir * maxi(absi(steps) - 1, 1)
		report.ability_notes.append("백돌 눈금 -1")
	if sub == GameEnums.PawnSubType.CHESS_QUEEN:
		steps += 2 * sign_dir
		report.ability_notes.append("퀸 +2칸")
	if mover.kind == GameEnums.PawnKind.SHOGI:
		# 비차: 항상 +2칸 (나리 승급하면 용왕). 나리 승급한 쇼기 기물은 이동할 때마다 +1칸.
		if sub == GameEnums.PawnSubType.SHOGI_HISHA:
			steps += 2 * sign_dir
			report.ability_notes.append("용왕 +2칸" if mover.promoted else "비차 +2칸")
		if mover.promoted:
			steps += sign_dir
			report.ability_notes.append("나리 승급 +1칸")
	var path: Array[int] = state.board.calculate_path(mover, steps, ctx)
	# 비숍·각행: 코너(6·12·18번)를 스쳐 지나가거나 멈추면 이동 거리 +2칸.
	if mover.gets_corner_bonus() and _path_touches_bonus_corner(path):
		steps += 2 * sign_dir
		path = state.board.calculate_path(mover, steps, ctx)
		report.ability_notes.append("코너 보너스 +2칸")
	match sub:
		GameEnums.PawnSubType.JANGGI_PO:
			if _path_jumps_over_pawn(state, mover, path):
				path = state.board.calculate_path(mover, steps + 3 * sign_dir, ctx)
				report.cannon_bonus = true
				report.ability_notes.append("포 넘기 +3칸")
		GameEnums.PawnSubType.JANGGI_MA:
			if not path.is_empty() and not _tile_has_other_pawn(state, mover, path[0]):
				path = state.board.calculate_path(mover, steps + 2 * sign_dir, ctx)
				report.ability_notes.append("마 +2칸")
		GameEnums.PawnSubType.JANGGI_SANG:
			if not path.is_empty() and not _tile_has_other_pawn(state, mover, path[0]):
				path = state.board.calculate_path(mover, steps + 3 * sign_dir, ctx)
				report.ability_notes.append("상 도약 +3칸")
	return path


## 경로가 보너스 코너(6·12·18번)를 밟거나 스치는가.
static func _path_touches_bonus_corner(path: Array[int]) -> bool:
	for tile: int in path:
		if GameEnums.BONUS_CORNER_TILES.has(tile):
			return true
	return false


## 이 타일에 (이동자 본인과 업은 말을 뺀) 출발한 말이 서 있는가. 출발선 대기 말은 보드 위에 없는 것으로 본다.
static func _tile_has_other_pawn(state: GameState, mover: PlayerPawn, tile: int) -> bool:
	if tile == GameEnums.GOAL_TILE:
		return false
	for other: PlayerPawn in state.leaders_at(tile):
		if other != mover and other.has_left_start:
			return true
	return false


## 경로의 '중간 칸'(도착 칸 제외)에 이동자 본인·업은 말이 아닌 말(아군·적군 모두)이 서 있는가.
static func _path_jumps_over_pawn(state: GameState, mover: PlayerPawn, path: Array[int]) -> bool:
	for index: int in range(path.size() - 1):
		if _tile_has_other_pawn(state, mover, path[index]):
			return true
	return false


## 이동 준비: ON_MOVE_CALC 법전 파이프라인을 통과시켜 지름길/업기/결승 바운스 플래그를 확정한다.
## 교칙이 이동을 취소하면 report.canceled가 true다. 돌진(charge_depth > 0) 이동은 플래그를 물려받으므로 건너뛴다.
static func begin(state: GameState, mover: PlayerPawn, ctx: RuleContext) -> MoveReport:
	var report := MoveReport.new()
	report.pawn_id = mover.entity_id
	ctx.pawn = mover
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
	if is_forward and from_tile == GameEnums.GOAL_TILE:
		mover.retreated_run = false
	mover.has_left_start = true
	state.sync_stack_position(mover)
	report.path.append(destination)
	ctx.path_nodes.append(destination)
	state.pawn_stepped.emit(mover.entity_id, from_tile, destination)
	# 출발선(0번)에서 뒤로 물러나는 말은 한 바퀴를 거꾸로 도는 대신 회수되어 출발 대기로 돌아간다 (역주행 중에는 예외).
	if is_first and not is_forward and from_tile == GameEnums.GOAL_TILE and state.movement_direction() > 0:
		for member: PlayerPawn in mover.stack_members():
			member.reset_to_start()
		for member: PlayerPawn in mover.stack_members():
			state.pawn_sent_to_start.emit(member.entity_id, mover.owner_id)
		report.trapped = true
		return StepOutcome.TRAPPED
	_promote_pawns(state, mover, report)
	if not is_last:
		# 강아지: 빵집을 멈추지 않고 지나가기만 해도 카드 1장 (도착한 빵집은 _resolve_landing이 처리한다)
		if mover.sub_type() == GameEnums.PawnSubType.MONO_DOG and state.board.get_tile(destination).tile_type == TileNode.TileType.BAKERY:
			var sniffed: StringName = state.draw_card(mover.owner_id)
			if sniffed != &"":
				report.dog_cards += 1
				if report.drawn_card == &"":
					report.drawn_card = sniffed

	# 증기선: 이동 중 처음 만나는 상대 설치물은 효과 없이 파괴한다 (이동 한 번에 한 칸)
	if mover.sub_type() == GameEnums.PawnSubType.MONO_SHIP and not bool(ctx.metadata.get("ship_used", false)):
		if _sink_hostile_attachments(state, mover, destination, report):
			ctx.metadata["ship_used"] = true

	# 나이트 점프: 중간 칸의 설치물은 무시하고 도착 칸의 설치물만 판정한다.
	var skip_attachments: bool = not is_last and mover.jumps_over_attachments()
	# 계마: 이동 경로의 첫 2칸에 있는 함정은 뛰어넘어 무시한다 (도착 칸이면 그대로 판정).
	if not is_last and mover.sub_type() == GameEnums.PawnSubType.SHOGI_KEIMA and report.path.size() <= 2:
		skip_attachments = true
	if not skip_attachments and _trigger_attachments(state, mover, ctx, destination, is_last, report):
		if not mover.has_left_start:
			# 함정이 말을 출발선으로 돌려보냈다 (send_to_start가 출발 상태를 초기화한다).
			report.trapped = true
			return StepOutcome.TRAPPED
		report.stopped_early = true
		return StepOutcome.HALTED

	if is_forward and destination == GameEnums.GOAL_TILE and mover.can_finish(state):
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


## 모노폴리 미니카: 출발선(0번)을 지나거나 밟을 때마다 손패에 생떼 카드 1장을 보충한다.
static func _pay_salary(state: GameState, mover: PlayerPawn, report: MoveReport) -> void:
	if mover.sub_type() != GameEnums.PawnSubType.MONO_CAR:
		return
	if state.draw_card(mover.owner_id) != &"":
		report.salary_cards += 1


## 모노폴리 카 [호텔 건설]: 이동이 끝난 타일에 내 턴 5번간 유지되는 통행료 호텔을 설치한다 (같은 타일의 내 호텔은 갱신).
static func _build_hotel(state: GameState, mover: PlayerPawn, report: MoveReport) -> void:
	var tile: TileNode = state.board.get_tile(mover.current_tile_idx)
	for attachment: TileAttachment in tile.attachments.duplicate():
		if attachment.attachment_id == "HOTEL" and attachment.owner_id == mover.owner_id:
			tile.remove_attachment(attachment)
	state.place_attachment(mover.current_tile_idx, Hotel.new(mover.owner_id))
	report.hotel_built = true


static func _finish(state: GameState, mover: PlayerPawn, report: MoveReport) -> void:
	state.finish_stack(mover)
	report.finished = true


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


## 끌려가거나 밀려나 이미 자리 잡은 말이 그 칸의 설치물(함정·지뢰·도미노·호텔)에 걸리게 한다 (ACT_09 결투 후퇴 등).
## 함정이 말을 출발선으로 돌려보내면 report.trapped가 true다.
static func resolve_forced_arrival(state: GameState, mover: PlayerPawn) -> MoveReport:
	var ctx := RuleContext.new()
	ctx.state = state
	ctx.actor_id = mover.owner_id
	ctx.pawn = mover
	var report := MoveReport.new()
	report.pawn_id = mover.entity_id
	if _trigger_attachments(state, mover, ctx, mover.current_tile_idx, true, report):
		report.stopped_early = true
		if not mover.has_left_start:
			report.trapped = true
	return report


## 도착(마지막 칸) 처리: 빵집 → 옷장 워프 → 잡기 → 업기 → 이동 완료 훅.
static func _resolve_landing(state: GameState, mover: PlayerPawn, ctx: RuleContext, report: MoveReport) -> void:
	var tile: TileNode = state.board.get_tile(mover.current_tile_idx)
	# 점프 코너(6->10, 18->21)와 옷장 포탈(9->16, 16->20)은 정확히 멈췄을 때만 작동하고 LAW_01 중에는 멈춘다. 워프 뒤 도착 칸은 다시 워프하지 않는다.
	if ctx.allow_shortcut and not mover.is_imprisoned and not bool(ctx.metadata.get("no_warp_chain", false)):
		var warp_target: int = -1
		if GameEnums.JUMP_CORNER_TARGETS.has(mover.current_tile_idx):
			warp_target = GameEnums.JUMP_CORNER_TARGETS[mover.current_tile_idx]
		elif tile.tile_type == TileNode.TileType.PORTAL:
			# 비행기는 옷장에서 더 앞선 곳으로 워프한다 (9번 -> 18번 코너, 16번 -> 22번)
			warp_target = GameEnums.PORTAL_WARP_TARGETS[mover.current_tile_idx]
			if mover.sub_type() == GameEnums.PawnSubType.MONO_PLANE:
				warp_target = GameEnums.PLANE_WARP_TARGETS[mover.current_tile_idx]
		if warp_target != -1:
			if not _warp_to(state, mover, ctx, report, warp_target):
				return
			tile = state.board.get_tile(mover.current_tile_idx)
	if tile.tile_type == TileNode.TileType.BAKERY and ctx.charge_depth == 0:
		var card_id: StringName = state.draw_card(mover.owner_id)
		if card_id != &"":
			report.drawn_card = card_id
	_resolve_captures(state, mover, ctx, report)
	if mover.is_finished:
		return
	_kaku_strike(state, mover, ctx, report)
	_resolve_stacking(state, mover, ctx, report)
	if can_build_hotel(state, mover) and ctx.charge_depth == 0 and mover.current_tile_idx != GameEnums.GOAL_TILE:
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


## 필살기 순간이동(비행기 워프·알까기로 날아간 흑돌의 안착): 기물을 destination에 놓고 도착 칸의 설치물·빵집·잡기·업기를 평소 도착처럼 판정한다.
## 도착 칸의 함정에 걸려 출발선으로 돌아가면 report.trapped가 true가 된다.
static func teleport_to(state: GameState, mover: PlayerPawn, ctx: RuleContext, report: MoveReport, destination: int) -> void:
	if mover.current_tile_idx != destination:
		if not _warp_to(state, mover, ctx, report, destination):
			return
	# 필살기 도착은 점프 코너·옷장을 다시 타지 않는다.
	ctx.metadata["no_warp_chain"] = true
	_resolve_landing(state, mover, ctx, report)
	ctx.metadata.erase("no_warp_chain")


## 점프 코너·옷장(PORTAL)에 멈추면 destination에 도착해 멈춘 것으로 판정한다.
## 워프 도착 칸의 함정에 걸려 출발선으로 돌아가면 false를 반환한다.
static func _warp_to(state: GameState, mover: PlayerPawn, ctx: RuleContext, report: MoveReport, destination: int) -> bool:
	var from_tile: int = mover.current_tile_idx
	mover.current_tile_idx = destination
	mover.step_history.append(destination)
	state.sync_stack_position(mover)
	report.warped = true
	report.path.append(destination)
	ctx.path_nodes.append(destination)
	state.pawn_warped.emit(mover.entity_id, from_tile, destination)
	_promote_pawns(state, mover, report)
	if _trigger_attachments(state, mover, ctx, destination, true, report) and not mover.has_left_start:
		report.trapped = true
		return false
	return true


## 체스 폰: 반환점(12번) 이상 타일을 밟거나 지나가는 순간 영구히 퀸으로 승진한다 (업고 있는 폰도 함께).
static func _promote_pawns(state: GameState, mover: PlayerPawn, report: MoveReport) -> void:
	_promote_shogi(state, mover, report)
	if not GameEnums.PROMOTION_TILES.has(mover.current_tile_idx):
		return
	for member: PlayerPawn in mover.stack_members():
		if member.sub_type() == GameEnums.PawnSubType.CHESS_PAWN:
			member.unit_no = GameEnums.CHESS_QUEEN_UNIT
			report.promoted_pawn_ids.append(member.entity_id)
			state.pawn_promoted.emit(member.entity_id)


## 쇼기 나리 승급: 반환점(12번) 이상 타일을 밟는 순간 영구히 승급한다 (업고 있는 말도 함께). 경로를 스치기만 해도 밟은 것으로 본다.
static func _promote_shogi(state: GameState, mover: PlayerPawn, report: MoveReport) -> void:
	if not GameEnums.SHOGI_PROMOTION_TILES.has(mover.current_tile_idx):
		return
	for member: PlayerPawn in mover.stack_members():
		if member.kind == GameEnums.PawnKind.SHOGI and not member.promoted:
			member.promoted = true
			report.promoted_pawn_ids.append(member.entity_id)
			report.ability_notes.append("%s 나리 승급!" % PawnCatalog.unit_label(member.kind, member.unit_no))
			state.pawn_promoted.emit(member.entity_id)


## 용마(나리 승급한 각행): 이동이 끝난 뒤 바로 앞 1칸에 서 있는 잡을 수 있는 적 말도 함께 처치한다 (이동하지 않는다).
static func _kaku_strike(state: GameState, mover: PlayerPawn, ctx: RuleContext, report: MoveReport) -> void:
	if not mover.promoted or mover.sub_type() != GameEnums.PawnSubType.SHOGI_KAKU or mover.current_tile_idx == GameEnums.GOAL_TILE:
		return
	var ahead: Array[int] = state.board.calculate_path(mover, 1, ctx)
	if ahead.is_empty() or ahead[0] == GameEnums.GOAL_TILE:
		return
	var enemies: Array[PlayerPawn] = []
	for leader: PlayerPawn in state.leaders_at(ahead[0]):
		if leader.owner_id != mover.owner_id and leader.has_left_start and not is_capture_immune(state, leader):
			enemies.append(leader)
	if enemies.is_empty():
		return
	_apply_capture_effects(state, mover, pick_capture_victims(enemies), report)
	report.ability_notes.append("용마 앞 1칸 추가 처치")


## 모노폴리 호텔 건설: 미니카만 이동이 끝난 타일에 호텔을 짓는다.
static func can_build_hotel(_state: GameState, mover: PlayerPawn) -> bool:
	return mover.sub_type() == GameEnums.PawnSubType.MONO_CAR


## 증기선: 이 타일의 상대 설치물을 효과 없이 파괴한다. 파괴했으면 true.
static func _sink_hostile_attachments(state: GameState, mover: PlayerPawn, tile_index: int, report: MoveReport) -> bool:
	var tile: TileNode = state.board.get_tile(tile_index)
	var destroyed: bool = false
	for attachment: TileAttachment in tile.attachments.duplicate():
		if attachment.owner_id == mover.owner_id:
			continue
		report.destroyed_attachments.append({"tile": tile_index, "attachment_id": attachment.attachment_id})
		tile.remove_attachment(attachment)
		destroyed = true
	return destroyed


static func _resolve_captures(state: GameState, mover: PlayerPawn, ctx: RuleContext, report: MoveReport) -> void:
	if mover.current_tile_idx == GameEnums.GOAL_TILE:
		return
	var enemies: Array[PlayerPawn] = []
	for leader: PlayerPawn in state.leaders_at(mover.current_tile_idx):
		if leader.owner_id != mover.owner_id:
			enemies.append(leader)
	if enemies.is_empty():
		return
	# 잡기 면역(바둑 백돌 본인, 백돌과 같은 칸의 아군)인 말은 잡을 수 없다. 잡을 수 있는 말이 하나도 없으면 이동한 말이 한 칸 밀려난다.
	var vulnerable: Array[PlayerPawn] = []
	for enemy: PlayerPawn in enemies:
		if not is_capture_immune(state, enemy):
			vulnerable.append(enemy)
	if vulnerable.is_empty():
		state.step_back_one(mover)
		report.pushed_back = true
		report.path.append(mover.current_tile_idx)
		return
	# 개별 피격: 업히지 않고 따로 서 있는 말들은 주인마다 1개(ID가 앞선 말)만 잡힌다. 업힌 말은 하나의 대표 말이라 전원이 함께 잡힌다.
	var victims: Array[PlayerPawn] = pick_capture_victims(vulnerable)
	ctx.capturer = mover
	ctx.captured_pawns = victims
	# 잡기 추가 턴: 윷놀이 기물의 고유 능력 [신명나는 사냥].
	ctx.capture_extra_turn = grants_capture_extra_turn(state, mover)
	ctx.capture_charge_steps = 0
	ctx.trigger_timing = RuleContext.ON_CAPTURE
	ctx = state.rulebook.process_context(ctx)
	if ctx.is_canceled:
		ctx.is_canceled = false
		return
	_apply_capture_effects(state, mover, victims, report)
	if ctx.capture_extra_turn:
		report.extra_turn = true
	if ctx.capture_charge_steps > 0 and ctx.charge_depth == 0:
		var charge_ctx: RuleContext = ctx.make_follow_up(ctx.capture_charge_steps)
		var charge_report: MoveReport = execute(state, mover, charge_ctx)
		report.merge(charge_report)


## 잡힌 대표 말(과 업힌 말)을 기록하고 출발선으로 보낸다.
static func _apply_capture_effects(state: GameState, mover: PlayerPawn, victims: Array[PlayerPawn], report: MoveReport) -> void:
	for victim: PlayerPawn in victims:
		for member: PlayerPawn in victim.stack_members():
			report.captured_pawn_ids.append(member.entity_id)
		state.send_to_start(victim, mover.owner_id)


## 이 말이 상대를 잡았을 때 추가 굴림 기회를 얻는가: 윷놀이 기물만 얻는다.
static func grants_capture_extra_turn(_state: GameState, mover: PlayerPawn) -> bool:
	return mover.kind == GameEnums.PawnKind.YUT


## 같은 타일의 적 대표 말들 중 실제로 잡히는 말: 주인마다 ID가 가장 앞선 대표 말 1개 (업힌 말은 대표 말과 함께).
static func pick_capture_victims(enemies: Array[PlayerPawn]) -> Array[PlayerPawn]:
	var picked: Dictionary = {}
	for enemy: PlayerPawn in enemies:
		var current: PlayerPawn = picked.get(enemy.owner_id)
		if current == null or enemy.entity_id < current.entity_id:
			picked[enemy.owner_id] = enemy
	var result: Array[PlayerPawn] = []
	for enemy: PlayerPawn in enemies:
		if picked[enemy.owner_id] == enemy:
			result.append(enemy)
	return result


## 잡기 면역: 바둑 백돌 본인, 또는 같은 타일에 아군 백돌이 있는 기물(백돌 방어막).
static func is_capture_immune(state: GameState, pawn: PlayerPawn) -> bool:
	if pawn.sub_type() == GameEnums.PawnSubType.BADUK_WHITE:
		return true
	for ally: PlayerPawn in state.pawns_of(pawn.owner_id):
		if ally != pawn and not ally.is_finished and ally.current_tile_idx == pawn.current_tile_idx \
				and ally.sub_type() == GameEnums.PawnSubType.BADUK_WHITE:
			return true
	return false


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
