# File: res://core_engine/cards/card_uno_reverse.gd
# Class: class_name CardUnoReverse
# Role: ACT_01 우노 리버스 - 턴 진행 순서를 뒤집고 1라운드 동안 모든 말의 이동 방향을 역주행으로 변경
class_name CardUnoReverse
extends BaseCard


func _init() -> void:
	card_id = &"ACT_01"
	display_name = "우노 리버스"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func create_command(_state: GameState, player_id: int, _params: Dictionary) -> GameCommand:
	return ReverseTurnCommand.new(player_id)
