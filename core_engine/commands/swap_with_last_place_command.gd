# File: res://core_engine/commands/swap_with_last_place_command.gd
# Class: class_name SwapWithLastPlaceCommand
# Role: LAW_03 후속 효과 - 이동을 마친 말과 (자기 말을 제외한) 꼴찌 말의 위치를 강제 교환
class_name SwapWithLastPlaceCommand
extends GameCommand

var pawn_id: int = -1


func _init(acting_player: int = -1, mover_pawn_id: int = -1) -> void:
	player_id = acting_player
	pawn_id = mover_pawn_id
	command_name = &"SwapWithLastPlace"


func _run(state: GameState) -> void:
	var mover: PlayerPawn = state.get_pawn(pawn_id)
	if mover == null or mover.is_finished:
		return
	var last: PlayerPawn = state.last_place_pawn(mover.owner_id)
	if last == null or last == mover:
		return
	state.swap_stacks(mover, last)
