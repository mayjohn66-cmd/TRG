# File: res://core_engine/commands/backdo_goal_command.gd
# Class: class_name BackdoGoalCommand
# Role: ACT_04 실행 - 지정한 말(업힌 말 포함)을 즉시 결승선 완주(Goal) 처리
class_name BackdoGoalCommand
extends GameCommand

var pawn_id: int = -1


func _init(acting_player: int = -1, target_pawn_id: int = -1) -> void:
	super()
	sender_id = acting_player
	pawn_id = target_pawn_id
	command_name = "BackdoGoal"


func can_execute(_ctx: RuleContext) -> bool:
	if state == null:
		return false
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	return pawn != null and not pawn.is_finished


func _run() -> void:
	state.finish_stack(state.get_pawn(pawn_id))
