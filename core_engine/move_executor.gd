# File: res://core_engine/move_executor.gd
# Class: class_name MoveExecutor
# Role: 호스트 전용 이동 실행기. 한 칸 단위 프리미티브(begin/apply_step/finalize)로 설치물·결승 바운스·워프·잡기·업기를 판정하며, 동기 실행(execute)과 TurnManager의 비동기 한 칸씩 이동이 같은 규칙을 공유한다
class_name MoveExecutor
extends RefCounted

## 코너에 정확히 도착했을 때 받는 다음 굴림 보너스 칸수.
const CORNER_BUFF_STEPS: int = 1

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
	announce_passives(state, mover, report)
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
	var report := MoveReport.new()
	var path: Array[int] = plan_path(state, pawn, ctx, report)
	if report.leapfrog_pending > 0 and not path.is_empty():
		# 실제로는 도착 칸에서 처치를 먼저 판정한 뒤 점프 부스트만큼 더 가지만, 미리보기는 최종 도착 칸까지 보여 준다.
		path = state.board.calculate_path(pawn, path.size() + report.leapfrog_pending, ctx)
	return path


## 기물 능력을 반영한 이동 경로를 계산한다. 동기 실행(execute)과 TurnManager 비동기 이동이 공유한다.
## 세부 기물: 퀸 +2칸, 룩·비차 직진 +2칸, 각행 코너 +2칸(용마 +3), 비숍 코너 진입 +1칸, 포 +3칸(경로 중간에 말), 마·상 +2칸(바로 앞 칸이 비면), 스타 카트 추가 이동 +2칸, 루도 복수자 리벤지 부스터 발동 시 +4칸.
static func plan_path(state: GameState, mover: PlayerPawn, ctx: RuleContext, report: MoveReport) -> Array[int]:
	# 후퇴는 없다: 눈금이 음수여도 0칸으로 본다.
	var steps: int = maxi(ctx.dice_value, 0)
	var sign_dir: int = 1
	if steps == 0:
		return [] as Array[int]
	# 점프 부스트로 이어 가는 추가 이동은 그 칸수만 그대로 간다 (기물 능력·부스트를 다시 붙이지 않는다).
	if is_leap_follow_up(ctx):
		return state.board.calculate_path(mover, steps, ctx)
	# 리벤지 부스터: 사출된 말이 출발선에서 다시 나갈 때 눈금에 +4칸 (루도 복수자는 발동 시 +4칸 더).
	if state.boost_gimmicks and mover.revenge_boost and not mover.has_left_start and revenge_bonus_of(mover, state) > 0:
		var revenge: int = revenge_bonus_of(mover, state)
		steps += revenge
		report.revenge_bonus = revenge
		report.ability_notes.append("복수 부스터 +%d칸" % revenge)
		if mover.sub_type() == GameEnums.PawnSubType.LUDO_AVENGER:
			report.passives.append(&"ludo_revenge")
	var sub: GameEnums.PawnSubType = mover.sub_type()
	# 스타 카트: 발판·돌진 같은 추가 이동은 모두 +2칸.
	if sub == GameEnums.PawnSubType.KART_STAR and ctx.charge_depth > 0:
		steps += KART_FOLLOW_UP_BONUS
		report.ability_notes.append("스타 카트 추가 이동 +%d칸" % KART_FOLLOW_UP_BONUS)
		report.passives.append(&"kart_follow")
	if sub == GameEnums.PawnSubType.CHESS_QUEEN:
		steps += 2 * sign_dir
		report.ability_notes.append("퀸 +2칸")
		report.passives.append(&"queen_bonus")
	# 흑돌: 홀수 눈금으로 전진하면 +1칸 (추가 이동에는 붙지 않는다).
	if sub == GameEnums.PawnSubType.BADUK_BLACK and ctx.charge_depth == 0 and posmod(ctx.dice_value, 2) == 1:
		steps += sign_dir
		report.ability_notes.append("흑돌 홀수 +1칸")
		report.passives.append(&"black_odd")
	# 나리 승급한 쇼기 기물은 이동할 때마다 +1칸.
	if mover.kind == GameEnums.PawnKind.SHOGI and mover.promoted:
		steps += sign_dir
		report.ability_notes.append("나리 승급 +1칸")
		report.passives.append(&"nari_bonus")
	var path: Array[int] = state.board.calculate_path(mover, steps, ctx)
	# 이동 1단계(리벤지 부스터 선행 전진) 칸은 판정하지 않는다: 경로를 보는 기물 능력·점프 부스트는 2단계(눈금 이동) 구간만 본다.
	var lead: int = report.revenge_bonus
	# 룩·비차: 코너를 꺾지 않는 직진(중간 칸에 코너가 없음)이면 +2칸.
	if mover.gets_straight_bonus() and is_straight(dice_segment(path, lead)):
		steps += 2 * sign_dir
		path = state.board.calculate_path(mover, steps, ctx)
		report.ability_notes.append(("용왕" if mover.promoted else "비차" if sub == GameEnums.PawnSubType.SHOGI_HISHA else "룩") + " 직진 +2칸")
		report.passives.append(&"straight_ryuo" if mover.promoted else &"straight_hisha" if sub == GameEnums.PawnSubType.SHOGI_HISHA else &"straight_rook")
	# 각행: 출발선 외 코너를 스쳐 지나가거나 멈추면 +2칸 (용마는 +3칸).
	if mover.gets_corner_bonus() and _path_touches_bonus_corner(dice_segment(path, lead)):
		var corner_bonus: int = 3 if mover.promoted else 2
		steps += corner_bonus * sign_dir
		path = state.board.calculate_path(mover, steps, ctx)
		report.ability_notes.append("코너 보너스 +%d칸" % corner_bonus)
		report.passives.append(&"corner_ryuma" if mover.promoted else &"corner_kaku")
	# 비숍: 코너 바로 앞 칸에 멈추게 되면 +1칸 더 가서 코너에 들어간다.
	if sub == GameEnums.PawnSubType.CHESS_BISHOP and not path.is_empty() and BoardSpec.bonus_corner_tiles.has(posmod(path.back() + 1, BoardSpec.tile_count)):
		steps += sign_dir
		path = state.board.calculate_path(mover, steps, ctx)
		report.ability_notes.append("비숍 코너 진입 +1칸")
		report.passives.append(&"bishop_corner")
	match sub:
		GameEnums.PawnSubType.JANGGI_PO:
			if _path_jumps_over_pawn(state, mover, dice_segment(path, lead)):
				path = state.board.calculate_path(mover, steps + 3 * sign_dir, ctx)
				report.cannon_bonus = true
				report.ability_notes.append("포 넘기 +3칸")
				report.passives.append(&"po_jump")
		GameEnums.PawnSubType.JANGGI_MA:
			var first: Array[int] = dice_segment(path, lead)
			if not first.is_empty() and not _tile_has_other_pawn(state, mover, first[0]):
				path = state.board.calculate_path(mover, steps + 2 * sign_dir, ctx)
				report.ability_notes.append("마 +2칸")
				report.passives.append(&"ma_leap")
		GameEnums.PawnSubType.JANGGI_SANG:
			var first: Array[int] = dice_segment(path, lead)
			if not first.is_empty() and not _tile_has_other_pawn(state, mover, first[0]):
				path = state.board.calculate_path(mover, steps + 2 * sign_dir, ctx)
				report.ability_notes.append("상 도약 +2칸")
				report.passives.append(&"sang_leap")
	# 말 밟고 점프하기: 경로 중간에 서 있는 말(아군·적군 무관)마다 +1칸 (최대 3칸). 경로를 무시하는 기물은 제외.
	# 경로에 합치지 않는다: 눈금 이동으로 도착한 칸에서 처치를 먼저 판정한 뒤, 그 자리에서 추가 이동으로 이어 간다 (finalize).
	if ctx.charge_depth == 0:
		var leap: int = leapfrog_bonus(state, mover, dice_segment(path, lead))
		if leap > 0:
			report.leapfrog_pending = leap
			report.ability_notes.append("점프 부스트! (+%d칸)" % leap)
	if report.revenge_bonus > 0:
		report.revenge_total = path.size()
	return path


## 경로 계산에서 발동한 기물 능력을 보드 뱃지용으로 알린다 (실제 이동이 시작될 때 한 번).
static func announce_passives(state: GameState, mover: PlayerPawn, report: MoveReport) -> void:
	for passive: StringName in report.passives:
		state.passive_triggered.emit(mover.entity_id, passive)
	report.passives.clear()


## 이 칸에 상대가 설치한 함정이 있는가 (나이트·계마가 뛰어넘을 때 [함정 관통!]을 알린다).
static func _has_hostile_trap(state: GameState, mover: PlayerPawn, tile_index: int) -> bool:
	for attachment: TileAttachment in state.board.get_tile(tile_index).attachments:
		if attachment.attachment_id.begins_with("TRP") and attachment.owner_id != mover.owner_id:
			return true
	return false


## 이동 2단계(눈금 이동) 구간: 경로에서 리벤지 부스터 선행 전진 칸(lead)을 뺀 나머지.
static func dice_segment(path: Array[int], lead: int) -> Array[int]:
	if lead <= 0:
		return path
	return path.slice(mini(lead, path.size()))


## 경로 중간(도착 칸 제외)에 서 있는 말 수만큼의 추가 칸수 (최대 LEAPFROG_MAX). 나이트·퀸·포·마·상은 경로를 무시하므로 0.
static func leapfrog_bonus(state: GameState, mover: PlayerPawn, path: Array[int]) -> int:
	if not state.boost_gimmicks or not mover.has_left_start or mover.jumps_over_attachments():
		return 0
	var sub: GameEnums.PawnSubType = mover.sub_type()
	if sub == GameEnums.PawnSubType.JANGGI_PO or sub == GameEnums.PawnSubType.JANGGI_MA or sub == GameEnums.PawnSubType.JANGGI_SANG:
		return 0
	var count: int = 0
	for index: int in range(path.size() - 1):
		if _tile_has_other_pawn(state, mover, path[index]):
			count += 1
	return mini(count * GameData.leapfrog_per_pawn(), GameData.leapfrog_max())


## 효과(카드·초증강·결투)로 말을 앞으로 steps칸 날려 보낸다. 평소 이동처럼 설치물·잡기·발판을 모두 판정한다.
static func forced_advance(state: GameState, pawn: PlayerPawn, steps: int) -> MoveReport:
	var ctx := RuleContext.new()
	ctx.state = state
	ctx.actor_id = pawn.owner_id
	ctx.pawn = pawn
	ctx.dice_value = steps
	ctx.raw_roll = steps
	ctx.direction = 1
	return execute(state, pawn, ctx)


## 설치물·잡기 판정 없이 말을 앞으로 steps칸 날린다 (스프링 대포 함정). 지난 타일들을 반환한다. 도착 판정은 호출한 이동이 이어서 한다.
static func fling(state: GameState, pawn: PlayerPawn, steps: int) -> Array[int]:
	var path: Array[int] = state.board.calculate_path(pawn, steps, RuleContext.new())
	for destination: int in path:
		var from_tile: int = pawn.current_tile_idx
		state.board.commit_step(pawn, destination)
		state.sync_stack_position(pawn)
		state.pawn_stepped.emit(pawn.entity_id, from_tile, destination)
	return path


const KART_FOLLOW_UP_BONUS: int = 2
## 8번 공: 적을 처치하면 그 자리에서 +3칸 더 굴러간다.
const EIGHT_BALL_CHARGE: int = 3


## 이 말의 리벤지 부스터 칸 수. 루도 복수자는 발동할 때 augments_table.csv EVO_7_2 param_1(기본 4)칸을 더 간다.
## 템포 업이 오르면 리벤지 부스터가 커진다 (8R 6칸, 15R 8칸). 규칙이 꺼져 있으면 그대로 0.
static func revenge_bonus_of(mover: PlayerPawn, state: GameState = null) -> int:
	var tempo: int = TempoUp.revenge_bonus(state.round_number) if state != null else 0
	var base: int = GameData.revenge_bonus()
	var bonus: int = maxi(base, tempo) if base > 0 else 0
	if bonus > 0 and state != null and MatchRules.is_speed(state):
		bonus += MatchRules.SPEED_REVENGE_EXTRA  # 스피드전: 초반부터 리벤지 부스터가 크다
	if bonus > 0 and mover.sub_type() == GameEnums.PawnSubType.LUDO_AVENGER:
		bonus += GameData.param("augments", "EVO_7_2", 1, 4)
	return bonus


## 룩·비차 직진 판정: 경로의 중간 칸(도착 칸 제외)에 코너가 없다.
static func is_straight(path: Array[int]) -> bool:
	if path.is_empty():
		return false
	for index: int in range(path.size() - 1):
		if BoardSpec.corner_tiles.has(path[index]):
			return false
	return true


## 경로가 보너스 코너(BoardSpec.bonus_corner_tiles)를 밟거나 스치는가.
static func _path_touches_bonus_corner(path: Array[int]) -> bool:
	for tile: int in path:
		if BoardSpec.bonus_corner_tiles.has(tile):
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
			# 무인도(TRP_C01): 짝수 눈금이 나오거나 손패 1장을 내면 탈출하고, 둘 다 안 되면 이번 이동은 헛수고가 된다.
			if absi(ctx.dice_value) % 2 == 0:
				mover.is_imprisoned = false
				report.released = true
			elif not ctx.is_preview and state.discard_random_card(mover.owner_id, state.rng) != &"":
				mover.is_imprisoned = false
				report.released = true
				report.paid_bail = true
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
	if not mover.has_left_start:
		mover.revenge_boost = false  # 복수 부스터는 출발할 때 한 번 쓰이고 사라진다
		if is_first and report.revenge_bonus > 0:
			state.revenge_boost_fired.emit(mover.entity_id, maxi(ctx.dice_value, 0), report.revenge_bonus, report.revenge_total)
	mover.has_left_start = true
	state.sync_stack_position(mover)
	report.path.append(destination)
	ctx.path_nodes.append(destination)
	state.pawn_stepped.emit(mover.entity_id, from_tile, destination)
	_promote_pawns(state, mover, report)
	if not is_last and mover.sub_type() == GameEnums.PawnSubType.CHECKERS_KING:
		_checkers_jump(state, mover, destination, report)
	if not is_last:
		# 강아지: 빵집을 멈추지 않고 지나가기만 해도 카드 1장 (도착한 빵집은 _resolve_landing이 처리한다)
		if mover.sub_type() == GameEnums.PawnSubType.MONO_DOG and state.board.get_tile(destination).tile_type == TileNode.TileType.BAKERY:
			var sniffed: StringName = state.draw_card(mover.owner_id)
			if sniffed != &"":
				report.dog_cards += 1
				state.passive_triggered.emit(mover.entity_id, &"dog_bakery")
				if report.drawn_card == &"":
					report.drawn_card = sniffed

	# 증기선: 이동 중 처음 만나는 상대 설치물은 효과 없이 파괴한다 (이동 한 번에 한 칸)
	if mover.sub_type() == GameEnums.PawnSubType.MONO_SHIP and not bool(ctx.metadata.get("ship_used", false)):
		if _sink_hostile_attachments(state, mover, destination, report):
			ctx.metadata["ship_used"] = true
			state.passive_triggered.emit(mover.entity_id, &"ship_sink")

	# 나이트 점프: 중간 칸의 설치물은 무시하고 도착 칸의 설치물만 판정한다.
	var skip_attachments: bool = not is_last and mover.jumps_over_attachments()
	# 계마: 이동 경로의 첫 2칸에 있는 함정은 뛰어넘어 무시한다 (도착 칸이면 그대로 판정).
	if not is_last and mover.sub_type() == GameEnums.PawnSubType.SHOGI_KEIMA and report.path.size() <= 2:
		skip_attachments = true
	if skip_attachments and _has_hostile_trap(state, mover, destination):
		state.passive_triggered.emit(mover.entity_id, &"keima_pass" if mover.sub_type() == GameEnums.PawnSubType.SHOGI_KEIMA else &"queen_pass" if mover.sub_type() == GameEnums.PawnSubType.CHESS_QUEEN else &"knight_pass")
	if not skip_attachments and _trigger_attachments(state, mover, ctx, destination, is_last, report):
		if not mover.has_left_start:
			# 함정이 말을 출발선으로 돌려보냈다 (send_to_start가 출발 상태를 초기화한다).
			report.trapped = true
			return StepOutcome.TRAPPED
		report.stopped_early = true
		# 스프링 대포에 실려 결승선까지 날아갔다.
		if destination != GameEnums.GOAL_TILE and mover.current_tile_idx == GameEnums.GOAL_TILE and mover.can_finish(state):
			_finish(state, mover, report)
			return StepOutcome.FINISHED
		return StepOutcome.HALTED

	if is_forward and (destination == GameEnums.GOAL_TILE or TempoUp.in_zone_for(state, destination)) and mover.can_finish(state):
		if not is_last and ctx.exact_goal_required:
			report.bounced = true
			return StepOutcome.CONTINUE
		_finish(state, mover, report)
		return StepOutcome.FINISHED
	return StepOutcome.CONTINUE


## 발동하지 않은 함정의 피해 기록을 지운다.
static func _forget_attack(state: GameState, serial: int, victim: int) -> void:
	for index: int in range(state.attack_log.size() - 1, -1, -1):
		var entry: Dictionary = state.attack_log[index]
		if int(entry["serial"]) == serial and int(entry["victim"]) == victim and (entry["stats"] as Dictionary).is_empty():
			state.attack_log.remove_at(index)


## 체커 킹: 지나가는 칸의 적 대표 말을 모두 뛰어넘으며 잡는다 (백돌 방어막은 막는다).
static func _checkers_jump(state: GameState, mover: PlayerPawn, tile: int, report: MoveReport) -> void:
	if tile == GameEnums.GOAL_TILE:
		return
	state.begin_attack({"kind": &"capture", "attacker": mover.owner_id, "attacker_pawn": mover.entity_id, "tile": tile})
	_checkers_jump_at(state, mover, tile, report)
	state.end_attack()


static func _checkers_jump_at(state: GameState, mover: PlayerPawn, tile: int, report: MoveReport) -> void:
	for enemy: PlayerPawn in state.leaders_at(tile):
		if enemy.owner_id == mover.owner_id or not enemy.has_left_start:
			continue
		if state.break_shield(enemy):
			continue
		for member: PlayerPawn in enemy.stack_members():
			report.captured_pawn_ids.append(member.entity_id)
		state.passive_triggered.emit(mover.entity_id, &"checker_slide")
		state.pawn_captured.emit(mover.entity_id, enemy.entity_id)
		state.send_to_start(enemy, mover.owner_id)


## 이동 마무리: 정상 도착(CONTINUE/HALTED)이면 도착 처리(빵집·워프·잡기·업기·후속 효과)를 수행한다.
static func finalize(state: GameState, mover: PlayerPawn, ctx: RuleContext, report: MoveReport, outcome: StepOutcome) -> void:
	if outcome == StepOutcome.CONTINUE and report.leapfrog_pending > 0 and ctx.charge_depth == 0 and _leap_onward(state, mover, ctx, report):
		return
	if outcome == StepOutcome.CONTINUE or outcome == StepOutcome.HALTED:
		_resolve_landing(state, mover, ctx, report)
		_grant_corner_buff(state, mover, report)


## 점프 부스트(Step 4): 눈금 이동이 끝난 칸은 경유지다. 그 칸의 적만 먼저 처치 판정하고(Step 3), 그 자리에서 점프 부스트 칸수만큼 더 간다.
## 발판·빵집·코너 버프 같은 도착 정산은 최종 도착 칸에서만 한다. 처치 판정으로 말이 다른 곳으로 옮겨졌으면(8번 공 돌진 등) 이어 가지 않는다. 이어 갔으면 true.
static func _leap_onward(state: GameState, mover: PlayerPawn, ctx: RuleContext, report: MoveReport) -> bool:
	var waypoint: int = mover.current_tile_idx
	var leap: int = report.leapfrog_pending
	report.leapfrog_pending = 0
	_resolve_captures(state, mover, ctx, report)
	if mover.is_finished or mover.is_imprisoned or not mover.has_left_start:
		return true
	if mover.current_tile_idx != waypoint:
		return true  # 처치 효과로 이미 더 움직였다
	report.leapfrog_bonus += leap
	state.leapfrog_boosted.emit(mover.entity_id, waypoint, leap)
	var follow: RuleContext = ctx.make_follow_up(leap)
	follow.metadata["leap_follow_up"] = true
	report.merge(execute(state, mover, follow))
	return true


## 점프 부스트로 이어 가는 추가 이동인가 (도착 정산은 첫 이동처럼 한다).
static func is_leap_follow_up(ctx: RuleContext) -> bool:
	return bool(ctx.metadata.get("leap_follow_up", false))


## 이 이동이 굴림에서 나온 본 이동(또는 그 점프 부스트 연장)인가: 빵집·부스터 발판·8번 공 돌진은 본 이동의 도착에서만 일어난다.
static func _primary_move(ctx: RuleContext) -> bool:
	return ctx.charge_depth == 0 or is_leap_follow_up(ctx)


## 코너에 정확히 멈추면 다음 굴림 결과에 +1 (함정이 있던 칸이면 버프 대신 함정이 발동한 것으로 끝난다). 워프·잡기로 자리를 옮겼으면 받지 못한다.
static func _grant_corner_buff(state: GameState, mover: PlayerPawn, report: MoveReport) -> void:
	if mover.is_finished or mover.is_imprisoned or report.trap_at_landing or report.warped:
		return
	if not BoardSpec.bonus_corner_tiles.has(mover.current_tile_idx) or report.path.is_empty() or int(report.path.back()) != mover.current_tile_idx:
		return
	state.corner_buff[mover.owner_id] = CORNER_BUFF_STEPS  # 겹쳐 쌓이지 않는다
	report.corner_buff = CORNER_BUFF_STEPS


## 모노폴리 미니카: 반환점(BoardSpec.halfway_tile)을 지나거나 밟을 때마다 손패에 생떼 카드 1장을 보충한다.
static func _pay_salary(state: GameState, mover: PlayerPawn, report: MoveReport) -> void:
	if mover.sub_type() != GameEnums.PawnSubType.MONO_CAR or mover.current_tile_idx != BoardSpec.halfway_tile:
		return
	if state.draw_card(mover.owner_id) != &"":
		report.salary_cards += 1
		state.passive_triggered.emit(mover.entity_id, &"car_salary")


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
		var is_trap: bool = attachment.attachment_id.begins_with("TRP")
		if is_trap and is_landing:
			report.trap_at_landing = true
		if is_trap and mover.is_trap_immune():
			# 지뢰찾기 공병: 적 함정은 해체하고 카드 1장. 스타 카트·공병은 어떤 함정에도 걸리지 않는다.
			if mover.sub_type() == GameEnums.PawnSubType.MINESWEEPER_FLAG and attachment.owner_id != mover.owner_id:
				tile.remove_attachment(attachment)
				state.trap_defused.emit(tile_index, attachment.attachment_id, mover.entity_id)
				if state.draw_card(mover.owner_id) != &"":
					report.defused_cards += 1
			elif attachment.owner_id != mover.owner_id:
				state.passive_triggered.emit(mover.entity_id, &"kart_immune")
			continue
		if is_trap and attachment.owner_id != mover.owner_id and state.break_shield(mover):
			tile.remove_attachment(attachment)  # 백돌 방어막이 함정을 막고 함께 부서진다
			continue
		# 남의 함정은 방어 카드(싸이크론·포고령·도굴꾼)의 대상이 되도록 피해 직전 상태를 기록한다.
		var hostile: bool = is_trap and attachment.owner_id != mover.owner_id
		var hand_before: int = (state.hands.get(mover.owner_id, []) as Array).size()
		if hostile:
			state.begin_attack({"kind": &"trap", "attacker": attachment.owner_id, "trap_id": attachment.attachment_id, "trap_tile": tile_index, "trap_data": attachment.serialize()})
			state.record_hit(mover)
		var before: Dictionary = state.pawn_state(mover)
		var halted: bool = attachment.on_step_trigger(mover, ctx)
		if hostile:
			var hurt: bool = halted or state.pawn_state(mover) != before or (state.hands.get(mover.owner_id, []) as Array).size() != hand_before
			if not hurt:
				_forget_attack(state, int(state.attack_source["serial"]), mover.owner_id)
			state.end_attack()
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
			_chain_forced_arrival(state, mover, ctx, tile_index, report)
			return true
	return false


## 한 이동에서 함정이 말을 다른 칸으로 옮긴 뒤(바나나 미끄러짐·소원빌기 점프·환승 포탈) 도착 칸의 함정을 이어서 판정하는 최대 횟수.
const MAX_TRAP_CHAIN: int = 3


## 함정이 말을 다른 칸으로 옮겼다면 그 도착 칸의 설치물도 발동시킨다 (연쇄는 MAX_TRAP_CHAIN번까지: 무한 루프 방지).
static func _chain_forced_arrival(state: GameState, mover: PlayerPawn, ctx: RuleContext, from_tile: int, report: MoveReport) -> void:
	var landed: int = mover.current_tile_idx
	if landed == from_tile or landed == GameEnums.GOAL_TILE or not mover.has_left_start or mover.is_finished:
		return
	var depth: int = int(ctx.metadata.get("trap_chain", 0))
	if depth >= MAX_TRAP_CHAIN:
		return
	ctx.metadata["trap_chain"] = depth + 1
	_trigger_attachments(state, mover, ctx, landed, true, report)


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
	# 점프 코너(BoardSpec.jump_corner_targets)와 옷장 포탈(BoardSpec.portal_warp_targets)은 정확히 멈췄을 때만 작동하고 LAW_01 중에는 멈춘다. 워프 뒤 도착 칸은 다시 워프하지 않는다.
	if ctx.allow_shortcut and not mover.is_imprisoned and not bool(ctx.metadata.get("no_warp_chain", false)):
		var warp_target: int = -1
		if BoardSpec.jump_corner_targets.has(mover.current_tile_idx):
			warp_target = BoardSpec.jump_corner_targets[mover.current_tile_idx]
		elif tile.tile_type == TileNode.TileType.PORTAL:
			# 비행기는 옷장에서 더 앞선 곳으로 워프한다 (BoardSpec.plane_warp_targets)
			warp_target = BoardSpec.portal_warp_targets[mover.current_tile_idx]
			if mover.sub_type() == GameEnums.PawnSubType.MONO_PLANE:
				warp_target = BoardSpec.plane_warp_targets[mover.current_tile_idx]
				state.passive_triggered.emit(mover.entity_id, &"plane_warp")
		if warp_target != -1:
			if not _warp_to(state, mover, ctx, report, warp_target):
				return
			tile = state.board.get_tile(mover.current_tile_idx)
	if tile.tile_type == TileNode.TileType.BAKERY and _primary_move(ctx):
		state.add_stat(mover.owner_id, VictoryLaw.BAKERY)  # 봉인된 에르핀의 식권: 빵집 방문 횟수
		var card_id: StringName = state.draw_card(mover.owner_id)
		if card_id != &"":
			report.drawn_card = card_id
	_resolve_captures(state, mover, ctx, report)
	if mover.is_finished:
		return
	_kaku_strike(state, mover, ctx, report)
	_resolve_stacking(state, mover, ctx, report)
	# 부스터 발판: 멈춘 자리가 발판이면 곧바로 앞으로 3칸 더 날아간다 (뒤따르는 이동이 도착 정산을 이어서 한다).
	if state.boost_gimmicks and GameData.dash_steps() > 0 and BoardSpec.dash_tiles.has(mover.current_tile_idx) and _primary_move(ctx) and not mover.is_finished and not mover.is_imprisoned:
		report.dash_tiles.append(mover.current_tile_idx)
		state.dash_pad_triggered.emit(mover.entity_id, mover.current_tile_idx)
		report.merge(execute(state, mover, ctx.make_follow_up(GameData.dash_steps())))
		return
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
	mover.push_step(destination)
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


## 체스 폰: 반환점(BoardSpec.halfway_tile) 이상 타일을 밟거나 지나가는 순간 영구히 퀸으로 승진한다 (업고 있는 폰도 함께).
static func _promote_pawns(state: GameState, mover: PlayerPawn, report: MoveReport) -> void:
	_pay_salary(state, mover, report)
	_promote_shogi(state, mover, report)
	if not BoardSpec.promotion_tiles.has(mover.current_tile_idx):
		return
	for member: PlayerPawn in mover.stack_members():
		if member.sub_type() == GameEnums.PawnSubType.CHESS_PAWN:
			member.unit_no = GameEnums.CHESS_QUEEN_UNIT
			report.promoted_pawn_ids.append(member.entity_id)
			state.pawn_promoted.emit(member.entity_id)


## 쇼기 나리 승급: 반환점(BoardSpec.halfway_tile) 이상 타일을 밟는 순간 영구히 승급한다 (업고 있는 말도 함께). 경로를 스치기만 해도 밟은 것으로 본다.
static func _promote_shogi(state: GameState, mover: PlayerPawn, report: MoveReport) -> void:
	if not BoardSpec.promotion_tiles.has(mover.current_tile_idx):
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
		if state.break_shield(enemy):
			continue  # 백돌 방어막이 이번 잡기를 막았다
		if not is_capture_immune(state, enemy):
			vulnerable.append(enemy)
	if vulnerable.is_empty():
		return  # 잡을 수 없는 말과는 한 칸에 함께 선다 (뒤로 밀려나지 않는다)
	# 개별 피격: 업히지 않고 따로 서 있는 말들은 주인마다 1개(ID가 앞선 말)만 잡힌다. 업힌 말은 하나의 대표 말이라 전원이 함께 잡힌다.
	var victims: Array[PlayerPawn] = pick_capture_victims(vulnerable)
	ctx.capturer = mover
	ctx.captured_pawns = victims
	# 잡기 추가 턴: 윷놀이 기물의 고유 능력 [신명나는 사냥].
	ctx.capture_extra_turn = grants_capture_extra_turn(state, mover)
	ctx.capture_charge_steps = EIGHT_BALL_CHARGE if mover.sub_type() == GameEnums.PawnSubType.POOL_8BALL else 0
	ctx.trigger_timing = RuleContext.ON_CAPTURE
	ctx = state.rulebook.process_context(ctx)
	if ctx.is_canceled:
		ctx.is_canceled = false
		return
	state.begin_attack({"kind": &"capture", "attacker": mover.owner_id, "attacker_pawn": mover.entity_id, "tile": mover.current_tile_idx})
	_apply_capture_effects(state, mover, victims, report)
	state.end_attack()
	if ctx.capture_extra_turn:
		report.extra_turn = true
		if mover.kind == GameEnums.PawnKind.YUT:
			state.passive_triggered.emit(mover.entity_id, &"yut_reroll")
	if ctx.capture_charge_steps > 0 and _primary_move(ctx):
		state.capture_charge_started.emit(mover.entity_id, ctx.capture_charge_steps)
		var charge_ctx: RuleContext = ctx.make_follow_up(ctx.capture_charge_steps)
		var charge_report: MoveReport = execute(state, mover, charge_ctx)
		report.merge(charge_report)


## 잡힌 대표 말(과 업힌 말)을 기록하고 출발선으로 보낸다.
static func _apply_capture_effects(state: GameState, mover: PlayerPawn, victims: Array[PlayerPawn], report: MoveReport) -> void:
	for victim: PlayerPawn in victims:
		for member: PlayerPawn in victim.stack_members():
			report.captured_pawn_ids.append(member.entity_id)
		state.pawn_captured.emit(mover.entity_id, victim.entity_id)
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


## 잡기 면역(미리보기·AI용): 방어막이 남아 있는 바둑 백돌 또는 관심사도 지정 보호막. 실제 잡기에서는 방어막이 깨지며 한 번 막는다 (GameState.break_shield).
static func is_capture_immune(_state: GameState, pawn: PlayerPawn) -> bool:
	return pawn.ward or (pawn.shield and pawn.sub_type() == GameEnums.PawnSubType.BADUK_WHITE)


## 업기: 모든 아군 말끼리 합칠 수 있다 (법전 allow_stacking이 우선). 출발선(0번)에서는 업지 않는다.
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
