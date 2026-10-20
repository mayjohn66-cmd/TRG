# File: res://core_engine/special_victory.gd
# Class: class_name SpecialVictory
# Role: 🏆 중앙 법전의 특수 승리 교칙 판정과 기록 갱신. 조건을 달성한 사람은 다음 순위로 졸업하고, 달성된 교칙은 법전에서 사라진다
class_name SpecialVictory
extends RefCounted


## 이 플레이어가 지금 법전의 특수 승리 조건 하나를 달성했다면 그 교칙 ID(법전 순서로 첫 번째), 아니면 빈 값.
static func achieved_by(state: GameState, player_id: int) -> StringName:
	for law: LawResource in state.rulebook.active_laws_queue:
		if law is VictoryLaw and (law as VictoryLaw).achieved(state, player_id):
			return StringName(law.law_id)
	return &""


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
