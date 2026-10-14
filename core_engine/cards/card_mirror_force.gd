# File: res://core_engine/cards/card_mirror_force.gd
# Class: class_name CardMirrorForce
# Role: TRP_01 성스러운 방어막 거울의 힘 - 타일 하나에 뒷면 은신 함정을 설치 (타일 설치형 카드의 대표 구현)
class_name CardMirrorForce
extends BaseCard


func _init() -> void:
	card_id = &"TRP_01"
	display_name = "성스러운 방어막 거울의 힘"
	category = GameEnums.CardCategory.TRAP
	playable_phases = [GameEnums.Phase.TURN_BEGIN]


## params: {"tile": int}  출발/결승선(0번)과 중앙(22번)에는 설치할 수 없고, 한 타일에 같은 설치물은 하나만 둔다.
func can_play(state: GameState, _player_id: int, params: Dictionary) -> bool:
	var tile: int = int(params.get("tile", -1))
	if not state.board.is_valid_tile(tile) or tile == GameEnums.GOAL_TILE or tile == GameEnums.CENTER_TILE:
		return false
	return not state.board.get_tile(tile).has_attachment(&"TRP_01")


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return PlaceAttachmentCommand.new(player_id, int(params["tile"]), &"TRP_01")
