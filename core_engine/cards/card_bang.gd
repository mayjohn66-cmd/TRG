# File: res://core_engine/cards/card_bang.gd
# Class: class_name CardBang
# Role: ACT_02 뱅! - 내 턴 시작에 사정거리(앞뒤 3칸) 안의 가장 앞선 상대 말을 자동 조준. 손패 한 장을 버리면 회피, 손패가 없으면 출발선으로 추방
class_name CardBang
extends BaseCard


func _init() -> void:
	card_id = &"ACT_02"
	display_name = "뱅!"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func could_play(state: GameState, player_id: int) -> bool:
	return BangCommand.find_target(state, player_id) != null


func can_play(state: GameState, player_id: int, _params: Dictionary) -> bool:
	return BangCommand.find_target(state, player_id) != null


func create_command(_state: GameState, player_id: int, _params: Dictionary) -> GameCommand:
	return BangCommand.new(player_id)
