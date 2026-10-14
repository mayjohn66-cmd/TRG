# File: res://core_engine/commands/rollback_command.gd
# Class: class_name RollbackCommand
# Role: ACT_05 실행 - TurnSnapshot을 즉시 복원한다. 손패는 스냅샷 대상이 아니므로 소모된 카드는 복구되지 않는다
class_name RollbackCommand
extends GameCommand


func _init(acting_player: int = -1) -> void:
	player_id = acting_player
	command_name = &"Rollback"


func _run(state: GameState) -> void:
	if state.turn_snapshot == null:
		return
	state.turn_snapshot.restore(state, false)
	state.hurt_players.clear()
	state.rollback_requested = true
