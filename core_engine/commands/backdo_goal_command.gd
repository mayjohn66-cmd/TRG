# File: res://core_engine/commands/backdo_goal_command.gd
# Class: class_name BackdoGoalCommand
# Role: ACT_04 실행 - 지정한 말(업힌 말 포함)을 즉시 결승선 완주(Goal) 처리
class_name BackdoGoalCommand
extends GameCommand

var pawn_id: int = -1


func _init(acting_player: int = -1, target_pawn_id: int = -1) -> void:
	player_id = acting_player
	pawn_id = target_pawn_id
	command_name = &"BackdoGoal"


func _run(state: GameState) -> void:
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	if pawn != null and not pawn.is_finished:
		state.finish_stack(pawn)
