# File: res://core_engine/cards/card_bang.gd
# Class: class_name CardBang
# Role: ACT_02 뱅! 저격 - 내 턴 시작에 저격할 상대 플레이어를 고르면 그 플레이어의 선두 말 하나가 즉시 출발선으로 장외 사출된다
class_name CardBang
extends BaseCard


func _init() -> void:
	card_id = &"ACT_02"
	display_name = "뱅! 저격"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func could_play(state: GameState, player_id: int) -> bool:
	return not BangCommand.target_players(state, player_id).is_empty()


## params: {"target_player": int}
func can_play(state: GameState, player_id: int, params: Dictionary) -> bool:
	return BangCommand.target_players(state, player_id).has(int(params.get("target_player", -1)))


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return BangCommand.new(player_id, int(params["target_player"]))
