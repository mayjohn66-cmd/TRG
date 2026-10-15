# File: res://core_engine/victory_checker.gd
# Class: class_name VictoryChecker
# Role: PHASE_RESOLUTION의 승리 판정. 승리 조건은 하나뿐이다: 내 말 4개를 모두 완주시킨다 (빽도 완주 같은 생떼 카드 효과도 결국 완주로 센다)
class_name VictoryChecker
extends RefCounted

const ALL_HOME: StringName = &"all_home"


static func reason_text(reason: StringName) -> String:
	match reason:
		ALL_HOME: return "승리 (말 4개 모두 완주)"
	return String(reason)


## 모든 플레이어를 검사한다 (현재 턴 플레이어가 먼저). 승자가 있으면 {"winner": int, "reason": StringName}, 없으면 {}.
static func evaluate(state: GameState, player_order: Array[int], current_player: int) -> Dictionary:
	var order: Array[int] = [current_player]
	for player_id: int in player_order:
		if player_id != current_player:
			order.append(player_id)
	for player_id: int in order:
		if _all_home(state, player_id):
			return {"winner": player_id, "reason": ALL_HOME}
	return {}


static func player_reason(state: GameState, player_id: int) -> StringName:
	return ALL_HOME if _all_home(state, player_id) else &""


static func _all_home(state: GameState, player_id: int) -> bool:
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if not pawn.is_finished:
			return false
	return true


## 결승까지 남은 거리의 합이 가장 작은(= 가장 앞선) 상대 플레이어. 완주한 말은 0으로 센다.
static func leader_player(state: GameState, player_order: Array[int], excluding: int) -> int:
	var best: int = -1
	var best_total: int = 1 << 30
	for player_id: int in player_order:
		if player_id == excluding:
			continue
		var total: int = 0
		for pawn: PlayerPawn in state.pawns_of(player_id):
			total += 0 if pawn.is_finished else state.pawn_progress_distance(pawn)
		if total < best_total:
			best_total = total
			best = player_id
	return best
