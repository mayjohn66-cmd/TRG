# File: res://core_engine/commands/penalty_bomb_command.gd
# Class: class_name PenaltyBombCommand
# Role: ACT_03 우노 +4 실행 - 다음 턴 플레이어에게 후퇴 페널티(pending_penalty -4)를 건다. 이미 걸린 페널티가 있으면 누적된다
class_name PenaltyBombCommand
extends GameCommand

const PENALTY: int = -4


func _init(acting_player: int = -1) -> void:
	super()
	sender_id = acting_player
	command_name = "PenaltyBomb"


func _run() -> void:
	var target_player: int = state.next_player_after(sender_id)
	if target_player == -1:
		return
	state.pending_penalty[target_player] = state.penalty_of(target_player) + PENALTY
