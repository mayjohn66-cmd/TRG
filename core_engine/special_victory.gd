# File: res://core_engine/special_victory.gd
# Class: class_name SpecialVictory
# Role: 🏆 중앙 법전의 특수 승리 교칙 판정과 기록 갱신. 조건을 달성한 사람은 다음 순위로 졸업하고, 달성된 교칙은 법전에서 사라진다
class_name SpecialVictory
extends RefCounted

## 사도 포위망: 경보 뒤 한 바퀴를 버텨야 하는 교칙 (update_siege).
const SIEGE_LAW: String = "LAW_05"


## 이 플레이어가 지금 법전의 특수 승리 조건 하나를 달성했다면 그 교칙 ID(법전 순서로 첫 번째), 아니면 빈 값.
static func achieved_by(state: GameState, player_id: int) -> StringName:
	for law: LawResource in state.rulebook.active_laws_queue:
		if law is VictoryLaw and (law as VictoryLaw).achieved(state, player_id):
			if law.law_id == SIEGE_LAW and not state.siege_ready.has(player_id):
				continue  # 사도 포위망은 경보 뒤 한 바퀴를 버텨야 졸업한다
			return StringName(law.law_id)
	return &""


## 법전에 걸린 이 교칙의 목표 수치 (없으면 교칙 기본값).
static func goal_of(state: GameState, law_id: String) -> int:
	for law: LawResource in state.rulebook.active_laws_queue:
		if law is VictoryLaw and law.law_id == law_id:
			return (law as VictoryLaw).goal()
	var fresh: LawResource = LawRegistry.create(law_id)
	return (fresh as VictoryLaw).goal() if fresh is VictoryLaw else 0


## 달성까지 딱 한 걸음 남았나 (1.01 리치 사이렌): 세는 기록은 1 남음. 카이지(한 번의 이동 최고 기록)는 쌓이는 기록이 아니라 제외.
static func is_reach(state: GameState, law: VictoryLaw, player_id: int) -> bool:
	if law.stat_key == VictoryLaw.BEST_MOVE or state.is_graduated(player_id):
		return false
	return law.goal() - law.progress(state, player_id) == 1


## 사도 포위망 경보를 갱신한다 (특수 승리 판정 직전). 기습 승리를 막기 위해 포위망은 두 번에 걸쳐 판정한다:
## 1) 자기 차례 끝에 처음 완성하면 경보(armed)만 울린다. 2) 다음 자기 차례가 끝날 때도 유지하고 있으면 졸업 자격(ready).
## 그 사이 누구의 판정에서든 포위망이 깨지면(처치·사출·업기 등) 경보가 풀린다. turn_player가 -1이면(라운드 끝 판정) 깨짐만 본다.
## {"armed": [새로 경보가 울린 사람], "broken": [경보가 풀린 사람]}
static func update_siege(state: GameState, turn_player: int) -> Dictionary:
	var result: Dictionary = {"armed": [], "broken": []}
	state.siege_ready.clear()
	var law: VictoryLaw = null
	for entry: LawResource in state.rulebook.active_laws_queue:
		if entry is VictoryLaw and entry.law_id == SIEGE_LAW:
			law = entry
	if law == null:
		state.siege_armed.clear()
		return result
	for player_id: int in state.player_ids:
		if state.is_graduated(player_id):
			state.siege_armed.erase(player_id)
			continue
		if not law.achieved(state, player_id):
			if state.siege_armed.has(player_id):
				state.siege_armed.erase(player_id)
				(result["broken"] as Array).append(player_id)
			continue
		if player_id != turn_player:
			continue
		if state.siege_armed.has(player_id):
			state.siege_ready[player_id] = true
		else:
			state.siege_armed[player_id] = state.round_number
			(result["armed"] as Array).append(player_id)
	return result


## 사도 포위망 경보가 울린 상태인가 (화면 표시·봇 견제용).
static func siege_armed(state: GameState, player_id: int) -> bool:
	return state.siege_armed.has(player_id)


## 누군가 졸업했다: 특수 승리로 졸업했으면 그 교칙을 법전에서 지운다.
static func on_graduated(state: GameState, _player_id: int, reason: StringName) -> void:
	if VictoryLaw.is_victory_id(String(reason)):
		state.rulebook.remove_law_by_id(String(reason))


## 순간 기록을 갱신한다: 그 교칙이 법전에 있을 때만 센다.
static func note_session(state: GameState, player_id: int, key: StringName, value: int) -> void:
	for law: LawResource in state.rulebook.active_laws_queue:
		if law is VictoryLaw and (law as VictoryLaw).stat_key == key:
			state.max_stat(player_id, key, value)
			return


## 교칙이 새로 제정되면 그 교칙의 순간 기록은 모두 0부터 다시 센다.
static func on_law_enacted(state: GameState, law: LawResource) -> void:
	if law is VictoryLaw and VictoryLaw.SESSION_KEYS.has((law as VictoryLaw).stat_key):
		for player_id: int in state.player_ids:
			state.reset_stat(player_id, (law as VictoryLaw).stat_key)


## 툴팁용 진행도: [{player, value, goal, danger, done}]
static func progress_rows(state: GameState, law: VictoryLaw) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for player_id: int in state.player_ids:
		rows.append({"player": player_id, "value": law.progress(state, player_id), "goal": law.goal(),
			"danger": law.is_danger(state, player_id), "done": state.is_graduated(player_id)})
	return rows
