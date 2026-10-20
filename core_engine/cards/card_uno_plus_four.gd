# File: res://core_engine/cards/card_uno_plus_four.gd
# Class: class_name CardUnoPlusFour
# Role: ACT_03 UDO +4 - 진행 방향의 다음 플레이어의 선두 말이 즉시 출발선으로 장외 사출되고, 내 선두 말 하나가 +4칸 전진한다 (떠넘기기·누적 없음)
class_name CardUnoPlusFour
extends BaseCard


func _init() -> void:
	card_id = &"ACT_03"
	display_name = "UDO +4"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func could_play(state: GameState, player_id: int) -> bool:
	var victim: int = PenaltyBombCommand.victim_of(state, player_id)
	return victim != -1 and state.front_pawn_of(victim) != null


func can_play(state: GameState, player_id: int, _params: Dictionary) -> bool:
	return could_play(state, player_id)


func create_command(_state: GameState, player_id: int, _params: Dictionary) -> GameCommand:
	return PenaltyBombCommand.new(player_id)
