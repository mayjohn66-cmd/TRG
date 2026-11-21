# File: res://core_engine/commands/tower_command.gd
# Class: class_name TowerCommand
# Role: ACT_07 XVI. 무너지는 탑 - 고른 보드 한 변(코너 포함)의 모든 설치물(누구 것이든)을 무너뜨린다. 스냅샷으로 undo 가능
class_name TowerCommand
extends GameCommand

var side_index: int = 0
## 실행 뒤 UI가 읽는다: 무너진 칸들과 부서진 설치물 수.
var tiles: Array[int] = []
var destroyed: int = 0


func _init(acting_player: int = -1, side: int = 0) -> void:
	super()
	sender_id = acting_player
	side_index = side
	command_name = "Tower"


## 한 변의 칸들: side * 한 변 길이부터 다음 코너까지 (출발선 제외).
static func side_tiles(side: int) -> Array[int]:
	var result: Array[int] = []
	for offset: int in range(BoardSpec.side + 1):
		var tile: int = posmod(side * BoardSpec.side + offset, BoardSpec.tile_count)
		if tile != GameEnums.GOAL_TILE:
			result.append(tile)
	return result


## 이 변에 무너뜨릴 설치물이 있는가.
static func has_attachments(game: GameState, side: int) -> bool:
	for tile: int in side_tiles(side):
		if not game.board.get_tile(tile).attachments.is_empty():
			return true
	return false


func can_execute(_ctx: RuleContext) -> bool:
	return state != null and side_index >= 0 and side_index < 4


func _run() -> void:
	tiles = side_tiles(side_index)
	for tile_index: int in tiles:
		var tile: TileNode = state.board.get_tile(tile_index)
		destroyed += tile.attachments.size()
		tile.clear_attachments()
	state.side_collapsed.emit(side_index, tiles, destroyed)
