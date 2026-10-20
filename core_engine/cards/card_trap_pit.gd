# File: res://core_engine/cards/card_trap_pit.gd
# Class: class_name CardTrapPit
# Role: TRP_02 함정 속으로(나락) - 눈금 4 이상으로 지나가는 상대 말을 출발선으로 떨어뜨리는 은신 함정을 타일에 설치
class_name CardTrapPit
extends BaseCard


func _init() -> void:
	card_id = &"TRP_02"
	display_name = "함정 속으로 (나락)"
	category = GameEnums.CardCategory.TRAP
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func needs_tile() -> bool:
	return true


func can_play(state: GameState, _player_id: int, params: Dictionary) -> bool:
	var tile: int = int(params.get("tile", -1))
	if not state.board.is_valid_tile(tile) or tile == GameEnums.GOAL_TILE:
		return false
	return not state.board.get_tile(tile).has_attachment("TRP_02")


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return PlaceAttachmentCommand.new(player_id, int(params["tile"]), "TRP_02")
