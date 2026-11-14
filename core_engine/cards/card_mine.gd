# File: res://core_engine/cards/card_mine.gd
# Class: class_name CardMine
# Role: TRP_03 지뢰 - 선택한 타일에 은신 지뢰를 설치한다. 밟으면 반경 2칸 안의 모든 말이 출발선으로 날아간다
class_name CardMine
extends BaseCard


func _init() -> void:
	card_id = &"TRP_03"
	display_name = "지뢰찾기"
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
	return PlaceMineFieldCommand.new(player_id, int(params["tile"]))
