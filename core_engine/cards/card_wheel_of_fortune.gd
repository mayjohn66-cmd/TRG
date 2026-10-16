# File: res://core_engine/cards/card_wheel_of_fortune.gd
# Class: class_name CardWheelOfFortune
# Role: ACT_08 X. 운명의 수레바퀴 (Wheel of Fortune) - 내 가장 뒤처진 보드 위 말과 가장 앞선 적 말의 위치를 강제로 맞바꾼다 (내 턴 굴리기 전)
class_name CardWheelOfFortune
extends BaseCard


func _init() -> void:
	card_id = &"ACT_08"
	display_name = "X. 운명의 수레바퀴"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func could_play(state: GameState, player_id: int) -> bool:
	return TarotEffects.leading_enemy(state, player_id) != null


func can_play(state: GameState, player_id: int, _params: Dictionary) -> bool:
	return TarotEffects.leading_enemy(state, player_id) != null


func create_command(_state: GameState, player_id: int, _params: Dictionary) -> GameCommand:
	return WheelOfFortuneCommand.new(player_id)
