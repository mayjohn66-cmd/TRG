# File: res://core_engine/commands/reverse_turn_command.gd
# Class: class_name ReverseTurnCommand
# Role: ACT_01 실행 - 턴 진행 순서 반전을 요청(시그널). 말의 이동 방향은 바꾸지 않는다(후퇴 없음). 턴 순서는 TurnManager 소유라 undo 대상이 아니다
class_name ReverseTurnCommand
extends GameCommand


func _init(acting_player: int = -1) -> void:
	super()
	sender_id = acting_player
	command_name = "ReverseTurn"


func _run() -> void:
	state.turn_order_reverse_requested.emit()
