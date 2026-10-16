# File: res://core_engine/commands/place_mine_field_command.gd
# Class: class_name PlaceMineFieldCommand
# Role: TRP_03 지뢰 설치 실행 - 선택한 타일에 은신 지뢰 1개를 설치한다 (숫자 표시 타일은 없다)
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
	state.place_attachment(tile, TrapMine.new(sender_id))
