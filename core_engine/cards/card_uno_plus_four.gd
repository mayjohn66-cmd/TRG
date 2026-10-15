# File: res://core_engine/cards/card_uno_plus_four.gd
# Class: class_name CardUnoPlusFour
# Role: ACT_03 우노 +4 - 다음 턴 플레이어에게 pending_penalty -4를 건다. 상대는 즉발 카드로 -8을 떠넘기거나, 아니면 가장 앞선 말이 4칸 후퇴한다
class_name CardUnoPlusFour
extends BaseCard


func _init() -> void:
	card_id = &"ACT_03"
	display_name = "우노 +4"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func create_command(_state: GameState, player_id: int, _params: Dictionary) -> GameCommand:
	return PenaltyBombCommand.new(player_id)
