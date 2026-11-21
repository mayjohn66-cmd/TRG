# File: res://core_engine/cards/card_cover.gd
# Class: class_name CardCover
# Role: ACT_22 긴급 엄폐 - 내 턴 시작에 쓰는 일반 카드. 내 말 하나를 골라 택배 박스를 뒤집어씌우면 잡기·함정을 1회 막는 지정 보호막(ward)이 생긴다
class_name CardCover
extends BaseCard


func _init() -> void:
	card_id = &"ACT_22"
	display_name = "긴급 엄폐"
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func needs_pawn() -> bool:
	return true


func could_play(state: GameState, player_id: int) -> bool:
	return not CoverCommand.targets(state, player_id).is_empty()


## params: {"pawn_id": 내 말 ID}
func can_play(state: GameState, player_id: int, params: Dictionary) -> bool:
	var pawn: PlayerPawn = state.get_pawn(int(params.get("pawn_id", -1)))
	return pawn != null and CoverCommand.targets(state, player_id).has(pawn)


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return CoverCommand.new(player_id, int(params.get("pawn_id", -1)))
