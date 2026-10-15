# File: res://core_engine/cards/card_mine.gd
# Class: class_name CardMine
# Role: TRP_03 지뢰찾기 숫자 타일 - 선택한 타일에 은신 지뢰, 양옆에 [1] 숫자 표시를 설치한다
class_name CardMine
extends BaseCard


func _init() -> void:
	card_id = &"TRP_03"
	display_name = "지뢰찾기 숫자 타일"
	category = GameEnums.CardCategory.TRAP
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func needs_tile() -> bool:
	return true


func can_play(state: GameState, _player_id: int, params: Dictionary) -> bool:
	var tile: int = int(params.get("tile", -1))
	if not state.board.is_valid_tile(tile) or tile == GameEnums.GOAL_TILE:
		return false
	return not state.board.get_tile(tile).has_attachment("TRP_03")


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return PlaceMineFieldCommand.new(player_id, int(params["tile"]))
