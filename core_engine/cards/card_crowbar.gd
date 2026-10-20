# File: res://core_engine/cards/card_crowbar.gd
# Class: class_name CardCrowbar
# Role: ACT_10 빠루 - 내 선두 말 앞 3칸의 적 말 사출 + 설치물 파괴
class_name CardCrowbar
extends BaseCard


func _init() -> void:
	card_id = &"ACT_10"
	display_name = "빠루"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func could_play(state: GameState, player_id: int) -> bool:
	return not CrowbarCommand.reach_tiles(state, player_id).is_empty()


func can_play(state: GameState, player_id: int, _params: Dictionary) -> bool:
	return could_play(state, player_id)


func create_command(_state: GameState, player_id: int, _params: Dictionary) -> GameCommand:
	return CrowbarCommand.new(player_id)
