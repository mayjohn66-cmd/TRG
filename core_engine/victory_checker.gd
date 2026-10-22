# File: res://core_engine/victory_checker.gd
# Class: class_name VictoryChecker
# Role: 서바이벌 순위 판정. 승리 조건(말 4개 완주 또는 중앙 법전의 특수 승리)을 먼저 달성한 순서대로 1·2·3위가 확정되고, 마지막 한 명이 4위가 된다
class_name VictoryChecker
extends RefCounted

const ALL_HOME: StringName = &"all_home"
## 마지막까지 남아 자동으로 꼴찌가 된 플레이어.
const LAST_PLACE: StringName = &"last_place"


static func reason_text(reason: StringName) -> String:
	match reason:
		ALL_HOME: return "승리 (말 4개 모두 완주)"
		LAST_PLACE: return "마지막까지 남음"
	var law: LawResource = LawRegistry.create(String(reason)) if LawRegistry.ALL_IDS.has(String(reason)) else null
	if law != null:
		return "특수 승리 (%s)" % law.law_name
	return String(reason)


## 결과 화면용 짧은 사유: "말 4개 모두 완주" / "특수 승리: 교칙 이름" / "마지막까지 남음".
static func short_reason(reason: StringName) -> String:
	match reason:
		ALL_HOME: return "말 4개 모두 완주"
		LAST_PLACE: return "마지막까지 남음"
	var law: LawResource = LawRegistry.create(String(reason)) if LawRegistry.ALL_IDS.has(String(reason)) else null
	if law != null:
		return "특수 승리: %s" % law.law_name
	return String(reason)


## 플레이어의 레이스 진행: {"finished": 완주한 말 수, "remaining": 결승까지 남은 칸 합, "progress": 0~100}.
static func progress_of(state: GameState, player_id: int) -> Dictionary:
	var full: int = maxi(BoardSpec.tile_count * GameEnums.PAWNS_PER_PLAYER, 1)
	var finished: int = 0
	var remaining: int = 0
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if pawn.is_finished:
			finished += 1
		else:
			remaining += state.pawn_progress_distance(pawn)
	return {"finished": finished, "remaining": remaining, "progress": clampi(roundi(100.0 * (1.0 - float(remaining) / float(full))), 0, 100)}


## 아직 순위가 없는 플레이어 중 지금 승리 조건을 달성한 사람들 (현재 턴 플레이어가 먼저). [{player, reason}]
## include_special이 false면 말 4개 완주만 본다 (특수 승리는 차례가 끝날 때 판정한다).
static func newly_qualified(state: GameState, player_order: Array[int], current_player: int, include_special: bool = true) -> Array[Dictionary]:
	var order: Array[int] = [current_player]
	for player_id: int in player_order:
		if player_id != current_player:
			order.append(player_id)
	var result: Array[Dictionary] = []
	for player_id: int in order:
		if state.is_graduated(player_id):
			continue
		var reason: StringName = player_reason(state, player_id, include_special)
		if reason != &"":
			result.append({"player": player_id, "reason": reason})
	return result


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


static func player_reason(state: GameState, player_id: int, include_special: bool = true) -> StringName:
	if _all_home(state, player_id):
		return ALL_HOME
	return SpecialVictory.achieved_by(state, player_id) if include_special else &""


static func _all_home(state: GameState, player_id: int) -> bool:
	for pawn: PlayerPawn in state.pawns_of(player_id):
		if not pawn.is_finished:
			return false
	return true


## 1~N등. 이미 확정된 순위(state.rankings)가 먼저이고, 아직 순위가 없는 사람은 완주한 말 수가 많은 순 → 결승까지 남은 거리 합이 작은 순 →
## 그래도 같으면 승자 다음 차례부터의 턴 순서. [{player, rank, finished, remaining, progress(0~100)}] (모든 참가자가 같은 결과를 계산한다)
static func standings(state: GameState, player_order: Array[int], winner: int) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var ranked: Array[int] = state.rankings.duplicate()
	if ranked.is_empty() and winner != -1:
		ranked.append(winner)
	var start: int = maxi(player_order.find(winner), 0)
	for index: int in player_order.size():
		var player_id: int = player_order[index]
		# 순위가 확정된 사람은 졸업한 순간의 진행(말을 철수하기 전)을 쓴다: 특수 승리로 졸업했으면 완주 수가 그대로 남는다.
		var progress: Dictionary = state.rank_stats.get(player_id, progress_of(state, player_id))
		entries.append({"player": player_id, "finished": int(progress["finished"]), "remaining": int(progress["remaining"]),
			"progress": int(progress["progress"]),
			"turn_rank": (index - start + player_order.size()) % player_order.size(),
			"reason": state.rank_reasons.get(player_id, &"")})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var rank_a: int = ranked.find(int(a["player"]))
		var rank_b: int = ranked.find(int(b["player"]))
		if rank_a != rank_b and (rank_a == -1 or rank_b == -1):
			return rank_b == -1
		if rank_a != -1 and rank_b != -1:
			return rank_a < rank_b
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
