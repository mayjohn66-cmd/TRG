# File: res://core_engine/duel_rules.gd
# Class: class_name DuelRules
# Role: ACT_09 가위바위보 결투의 순수 규칙 - 손 모양 승패, 결투 상대 지목, 승자가 밀어낼 수 있는 말 목록, 후퇴 실행(출발선까지만, 도착 칸 함정 연쇄). 입력 대기와 타이머는 TurnManager가 맡는다
class_name DuelRules
extends RefCounted

enum Hand { ROCK, SCISSORS, PAPER }

const HAND_NAMES: Array[String] = ["바위", "가위", "보"]
## 결투 승자가 진 사람의 말을 뒤로 밀어내는 칸 수.
const RETREAT_STEPS: int = 2
## 비기면 다시 겨루는 최대 횟수: 이 횟수만큼 연달아 비기면 신청자의 판정승이다.
const MAX_DRAWS: int = 2
## 손 선택(초)과 말 고르기(초) 제한 시간 (TurnManager.timer_scale이 곱해진다).
const TIME_PICK: float = 5.0
const TIME_STRIKE: float = 8.0


## a가 b를 이기면 1, 지면 -1, 비기면 0.
static func compare(a: int, b: int) -> int:
	if a == b:
		return 0
	return 1 if (a - b + 3) % 3 == 2 else -1


## 결투를 걸 수 있는 상대: 보드 위에 나와 있는 말이 있는 상대 플레이어들.
static func targets(state: GameState, challenger: int) -> Array[int]:
	return BangCommand.target_players(state, challenger)


## 대상을 안 골랐을 때(그냥 보드에 던짐) 자동 지목: 선두 말이 결승에 가장 가까운 상대. 없으면 -1.
static func default_target(state: GameState, challenger: int) -> int:
	var best_player: int = -1
	var best_distance: int = 1 << 30
	for player_id: int in targets(state, challenger):
		var distance: int = state.pawn_progress_distance(state.front_pawn_of(player_id))
		if distance < best_distance:
			best_distance = distance
			best_player = player_id
	return best_player


## 패자의 말 중 밀어낼 수 있는 대표 말 ID들 (보드 위에 나와 있고 업히지 않은 말).
static func strike_candidates(state: GameState, loser: int) -> Array[int]:
	var result: Array[int] = []
	for pawn: PlayerPawn in state.pawns_of(loser):
		if pawn.is_finished or pawn.carrier != null or not pawn.has_left_start or pawn.current_tile_idx == GameEnums.GOAL_TILE:
			continue
		result.append(pawn.entity_id)
	return result


## 승자가 고른 말을 RETREAT_STEPS칸 뒤로 보낸다 (업힌 말은 함께). 출발선에 닿으면 거기서 멈추고 출발 전 상태로 돌아간다.
## 도착 칸의 함정·호텔 같은 설치물은 평소 이동처럼 발동한다. 반환: {"from", "to", "sent_to_start", "trapped"}.
static func apply_strike(state: GameState, winner: int, pawn: PlayerPawn) -> Dictionary:
	var from_tile: int = pawn.current_tile_idx
	var path: Array[int] = state.board.calculate_path(pawn, -RETREAT_STEPS, RuleContext.new())
	var sent_to_start: bool = false
	for destination: int in path:
		var step_from: int = pawn.current_tile_idx
		state.board.commit_step(pawn, destination)
		state.sync_stack_position(pawn)
		state.pawn_stepped.emit(pawn.entity_id, step_from, destination)
		if destination == GameEnums.GOAL_TILE:
			sent_to_start = true
			break
	var landing: int = pawn.current_tile_idx
	var trapped: bool = false
	if sent_to_start:
		state.send_to_start(pawn, winner)
	else:
		var report: MoveReport = MoveExecutor.resolve_forced_arrival(state, pawn)
		trapped = report.trapped or report.stopped_early or not report.attachment_events.is_empty()
	return {"from": from_tile, "landing": landing, "to": pawn.current_tile_idx, "sent_to_start": sent_to_start or not pawn.has_left_start, "trapped": trapped}
