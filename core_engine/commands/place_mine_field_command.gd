# File: res://core_engine/commands/place_mine_field_command.gd
# Class: class_name PlaceMineFieldCommand
# Role: TRP_03 실행 - 선택한 타일에 은신 지뢰를, 앞뒤 타일에 [1] 숫자 표시를 설치해 연속된 3칸을 만든다
class_name PlaceMineFieldCommand
extends GameCommand

var tile: int = -1


func _init(acting_player: int = -1, target_tile: int = -1) -> void:
	super()
	sender_id = acting_player
	tile = target_tile
	command_name = "PlaceMineField"


func can_execute(_ctx: RuleContext) -> bool:
	return state != null and state.board.is_valid_tile(tile) and tile != GameEnums.GOAL_TILE


func _run() -> void:
	var mine := TrapMine.new(sender_id)
	var behind: int = state.board.default_previous(tile)
	var ahead: int = state.board.get_tile(tile).next_default
	for neighbor: int in [behind, ahead]:
		if neighbor != tile and not mine.number_tiles.has(neighbor):
			mine.number_tiles.append(neighbor)
			state.place_attachment(neighbor, MineNumber.new(sender_id))
	state.place_attachment(tile, mine)
