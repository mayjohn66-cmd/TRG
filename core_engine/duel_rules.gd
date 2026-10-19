# File: res://core_engine/duel_rules.gd
# Class: class_name DuelRules
# Role: ACT_09 가위바위보 결투의 순수 규칙 - 손 모양 승패, 결투 상대 지목, 패자가 사출될 말 목록, 승자 +3칸 전진과 패자 사출 실행. 입력 대기와 타이머는 TurnManager가 맡는다
class_name DuelRules
extends RefCounted

enum Hand { ROCK, SCISSORS, PAPER }

const HAND_NAMES: Array[String] = ["바위", "가위", "보"]
## 결투 승자의 말이 앞으로 날아가는 칸수 (패자의 말은 출발선으로 사출된다).
const WINNER_ADVANCE: int = 3
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


## 패자의 말 중 사출시킬 수 있는 대표 말 ID들 (보드 위에 나와 있고 업히지 않은 말).
static func strike_candidates(state: GameState, loser: int) -> Array[int]:
	var result: Array[int] = []
	for pawn: PlayerPawn in state.pawns_of(loser):
		if pawn.is_finished or pawn.carrier != null or not pawn.has_left_start or pawn.current_tile_idx == GameEnums.GOAL_TILE:
			continue
		result.append(pawn.entity_id)
	return result


## 승자의 보상: 패자가 고른(또는 자동으로 정해진) 말은 그 자리에서 즉시 출발선으로 사출되고, 승자의 선두 말(없으면 출발 대기 말 하나)은 앞으로 WINNER_ADVANCE칸 날아간다.
## 반환: {"from", "landing", "to", "sent_to_start", "trapped", "boost_pawn_id", "boost_from", "boost_to"}.
static func apply_strike(state: GameState, winner: int, pawn: PlayerPawn) -> Dictionary:
	var from_tile: int = pawn.current_tile_idx
	state.send_to_start(pawn, winner)
	var result: Dictionary = {"from": from_tile, "landing": GameEnums.GOAL_TILE, "to": pawn.current_tile_idx, "sent_to_start": true, "trapped": false, "boost_pawn_id": -1, "boost_from": -1, "boost_to": -1}
	var booster: PlayerPawn = state.front_pawn_of(winner)
	if booster == null:
		for candidate: PlayerPawn in state.pawns_of(winner):
			if candidate.is_selectable():
				booster = candidate
				break
	if booster != null:
		result["boost_pawn_id"] = booster.entity_id
		result["boost_from"] = booster.current_tile_idx
		MoveExecutor.forced_advance(state, booster, WINNER_ADVANCE)
		result["boost_to"] = booster.current_tile_idx
	return result
