# File: res://core_engine/commands/expel_pawn_command.gd
# Class: class_name ExpelPawnCommand
# Role: LAW_07 후속 효과 - 지정한 말(업힌 말 포함)을 출발선으로 동반 추방
class_name ExpelPawnCommand
extends GameCommand

var pawn_id: int = -1


func _init(acting_player: int = -1, target_pawn_id: int = -1) -> void:
	player_id = acting_player
	pawn_id = target_pawn_id
	command_name = &"ExpelPawn"


func _run(state: GameState) -> void:
	var target: PlayerPawn = state.get_pawn(pawn_id)
	if target != null and not target.is_finished:
		state.send_to_start(target, player_id)
