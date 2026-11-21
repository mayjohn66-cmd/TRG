# File: res://core_engine/cards/card_domino.gd
# Class: class_name CardDomino
# Role: TRP_05 도미노 연쇄 - 타일에 숨겨 두는 은신 함정(타일 설치형). 밟은 말은 멈추고 반경 2칸 안의 다른 함정이 전부 연쇄 발동한다
class_name CardDomino
extends BaseCard


func _init() -> void:
	card_id = &"TRP_05"
	display_name = "도미노 연쇄"
	category = GameEnums.CardCategory.TRAP
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func needs_tile() -> bool:
	return true


func can_play(state: GameState, _player_id: int, params: Dictionary) -> bool:
	var tile: int = int(params.get("tile", -1))
	if not state.board.is_valid_tile(tile) or tile == GameEnums.GOAL_TILE:
		return false
	return not state.board.get_tile(tile).has_trap()  # 한 칸에 함정은 하나만


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return PlaceAttachmentCommand.new(player_id, int(params["tile"]), "TRP_05")
