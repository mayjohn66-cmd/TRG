# File: res://core_engine/cards/card_domino.gd
# Class: class_name CardDomino
# Role: TRP_05 스프링 인간 대포(옛 도미노 연쇄 붕괴) - 타일에 대포를 숨겨 두는 은신 함정(타일 설치형). 밟은 말이 앞으로 +5칸 사출되고 착지 지점의 말은 들이받혀 출발선으로 날아간다
class_name CardDomino
extends BaseCard


func _init() -> void:
	card_id = &"TRP_05"
	display_name = "스프링 인간 대포"
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
