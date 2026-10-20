# File: res://core_engine/cards/card_island.gd
# Class: class_name CardIsland
# Role: TRP_C01 무인도 감옥 (코너 전용) - 출발선을 뺀 코너 타일(BoardSpec.bonus_corner_tiles) 한 곳을 무인도로 바꾼다. 보드에는 무인도가 하나만 존재할 수 있다
class_name CardIsland
extends BaseCard

func _init() -> void:
	card_id = &"TRP_C01"
	display_name = "무인도 감옥"
	category = GameEnums.CardCategory.TRAP
	corner_only = true
	playable_phases = [TurnManager.State.PHASE_TURN_BEGIN]


func needs_tile() -> bool:
	return true


func can_play(state: GameState, _player_id: int, params: Dictionary) -> bool:
	if not BoardSpec.bonus_corner_tiles.has(int(params.get("tile", -1))):
		return false
	if state.board.get_tile(int(params["tile"])).has_trap():
		return false  # 한 칸에 함정은 하나만
	for tile: TileNode in state.board.tiles:
		if tile.has_attachment("TRP_C01"):
			return false
	return true


func create_command(_state: GameState, player_id: int, params: Dictionary) -> GameCommand:
	return PlaceAttachmentCommand.new(player_id, int(params["tile"]), "TRP_C01")
