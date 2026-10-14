# File: res://core_engine/cards/card_objection.gd
# Class: class_name CardObjection
# Role: ACT_06 이의 있음! 법전 파기 - 중앙 법전에서 지정한 교칙 1개(law_id)를 즉시 영구 삭제
class_name CardObjection
extends BaseCard


func _init() -> void:
	card_id = &"ACT_06"
	display_name = "이의 있음! 법전 파기"
	playable_phases = [GameEnums.Phase.TURN_BEGIN, GameEnums.Phase.INTERRUPT_ROLL, GameEnums.Phase.RESOLUTION]


## params: {"law_id": String}
func can_play(state: GameState, _player_id: int, params: Dictionary) -> bool:
	return state.rulebook.has_law(String(params.get("law_id", "")))


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return RepealLawCommand.new(player_id, String(params["law_id"]))
