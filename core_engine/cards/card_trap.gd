# File: res://core_engine/cards/card_trap.gd
# Class: class_name CardTrap
# Role: 타일에 설치하는 함정 카드 (TRP_06 바나나·TRP_07 스파이크·TRP_08 강제 환승 포탈 / 코너 전용 TRP_C02 피아식별 점프대·TRP_C03 톨게이트·TRP_C04 타르). 한 칸에는 종류와 상관없이 함정 하나만
class_name CardTrap
extends BaseCard

const NAMES: Dictionary = {
	&"TRP_06": "바나나 껍질",
	&"TRP_07": "스파이크",
	&"TRP_08": "강제 환승 포탈",
	&"TRP_C02": "피아식별 점프대",
	&"TRP_C03": "톨게이트",
	&"TRP_C04": "타르",
}


func _init(id: StringName = &"TRP_06") -> void:
	card_id = id
	display_name = NAMES[id]
	category = GameEnums.CardCategory.TRAP
	corner_only = String(id).begins_with("TRP_C")
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func needs_tile() -> bool:
	return true


## params: {"tile": int}
func can_play(state: GameState, _player_id: int, params: Dictionary) -> bool:
	var tile: int = int(params.get("tile", -1))
	if not state.board.is_valid_tile(tile) or tile == GameEnums.GOAL_TILE:
		return false
	return not state.board.get_tile(tile).has_trap()  # 한 칸에 함정은 하나만


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return PlaceAttachmentCommand.new(player_id, int(params["tile"]), String(card_id))
