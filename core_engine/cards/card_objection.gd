# File: res://core_engine/cards/card_objection.gd
# Class: class_name CardObjection
# Role: ACT_06 이의 있음! - 법전의 특수 승리 교칙 하나를 골라 한 플레이어의 진행 기록을 0으로 되돌린다 (역전재판 패러디)
class_name CardObjection
extends BaseCard


func _init() -> void:
	card_id = &"ACT_06"
	display_name = "이의 있음!"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


## 지울 수 있는 [대상, 교칙] 조합들.
static func choices(state: GameState) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for law_id: String in state.rulebook.law_ids():
		for target: int in state.player_ids:
			if ResetStatCommand.resettable(state, target, law_id):
				result.append({"target_player": target, "law_id": law_id})
	return result


func could_play(state: GameState, _player_id: int) -> bool:
	return not choices(state).is_empty()


## params: {"target_player": int, "law_id": String}
func can_play(state: GameState, _player_id: int, params: Dictionary) -> bool:
	return ResetStatCommand.resettable(state, int(params.get("target_player", -1)), String(params.get("law_id", "")))


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return ResetStatCommand.new(player_id, int(params["target_player"]), String(params["law_id"]))
