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


## 게임이 끝났을 때의 1~N등. 1등은 승자(말 4개 완주), 나머지는 완주한 말 수가 많은 순 → 결승까지 남은 거리 합이 작은 순 →
## 그래도 같으면 승자 다음 차례부터의 턴 순서. [{player, rank, finished, remaining, progress(0~100)}] (모든 참가자가 같은 결과를 계산한다)
static func standings(state: GameState, player_order: Array[int], winner: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var full: int = maxi(BoardSpec.tile_count * GameEnums.PAWNS_PER_PLAYER, 1)
	var start: int = maxi(player_order.find(winner), 0)
	for index: int in player_order.size():
		var player_id: int = player_order[index]
		var finished: int = 0
		var remaining: int = 0
		for pawn: PlayerPawn in state.pawns_of(player_id):
			if pawn.is_finished:
				finished += 1
			else:
				remaining += state.pawn_progress_distance(pawn)
		entries.append({"player": player_id, "finished": finished, "remaining": remaining,
			"progress": clampi(roundi(100.0 * (1.0 - float(remaining) / float(full))), 0, 100),
			"turn_rank": (index - start + player_order.size()) % player_order.size()})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if (int(a["player"]) == winner) != (int(b["player"]) == winner):
			return int(a["player"]) == winner
		if int(a["finished"]) != int(b["finished"]):
			return int(a["finished"]) > int(b["finished"])
		if int(a["remaining"]) != int(b["remaining"]):
			return int(a["remaining"]) < int(b["remaining"])
		return int(a["turn_rank"]) < int(b["turn_rank"]))
	for index: int in entries.size():
		entries[index]["rank"] = index + 1
		entries[index].erase("turn_rank")
	return entries


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
