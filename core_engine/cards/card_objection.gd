# File: res://core_engine/cards/card_objection.gd
# Class: class_name CardObjection
# Role: ACT_06 이의 있음! 법전 파기 - 중앙 법전 4슬롯 중 원하는 교칙 1개를 즉시 영구 삭제
class_name CardObjection
extends BaseCard


func _init() -> void:
	card_id = &"ACT_06"
	display_name = "이의 있음! 법전 파기"
	playable_phases = [GameEnums.Phase.TURN_BEGIN, GameEnums.Phase.INTERRUPT_ROLL, GameEnums.Phase.RESOLUTION]


## params: {"slot_index": int}
func can_play(state: GameState, _player_id: int, params: Dictionary) -> bool:
	var slot_index: int = int(params.get("slot_index", -1))
	return slot_index >= 0 and slot_index < state.rulebook.laws.size()


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return RepealLawCommand.new(player_id, int(params["slot_index"]))
