# File: res://core_engine/commands/reverse_turn_command.gd
# Class: class_name ReverseTurnCommand
# Role: ACT_01 실행 - 턴 진행 순서 반전을 요청(시그널)하고 이동 방향 역주행 라운드를 1로 설정. 턴 순서는 TurnManager 소유라 undo 대상이 아니다
class_name ReverseTurnCommand
extends GameCommand


func _init(acting_player: int = -1) -> void:
	super()
	sender_id = acting_player
	command_name = "ReverseTurn"


func _run() -> void:
	state.reverse_move_rounds_left = 1
	state.turn_order_reverse_requested.emit()
