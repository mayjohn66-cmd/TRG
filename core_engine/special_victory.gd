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


## 아직 방어 여부가 정해지지 않은 공격(방어 대기 중이거나 아직 묻지 않은 공격)이 올린 이 사람의 기록. 화면은 이만큼 빼고 보여 준다:
## 방어하면 되돌아갈 처치를 미리 '달성'으로 보이지 않게 (판정은 방어 대기가 끝난 뒤 차례 끝에만 한다).
static func undecided_stat(state: GameState, player_id: int, key: StringName, pending_attack: int = -1) -> int:
	var total: int = 0
	for entry: Dictionary in state.attack_log:
		if bool(entry["countered"]) or (bool(entry["offered"]) and int(entry["id"]) != pending_attack):
			continue
		var owner: int = int(entry["victim"]) if key == VictoryLaw.EJECTED else int(entry.get("attacker", -1))
		if owner == player_id:
			total += int((entry["stats"] as Dictionary).get(key, 0))
	return total


## 화면에 보여 줄 진행도: 방어 여부가 정해지지 않은 공격의 기록은 뺀다.
static func shown_progress(state: GameState, law: VictoryLaw, player_id: int, pending_attack: int = -1) -> int:
	return law.progress(state, player_id) - undecided_stat(state, player_id, law.stat_key, pending_attack)


## 툴팁용 진행도: [{player, value, goal, danger, done}]
static func progress_rows(state: GameState, law: VictoryLaw) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for player_id: int in state.player_ids:
		rows.append({"player": player_id, "value": law.progress(state, player_id), "goal": law.goal(),
			"danger": law.is_danger(state, player_id), "done": state.is_graduated(player_id)})
	return rows
