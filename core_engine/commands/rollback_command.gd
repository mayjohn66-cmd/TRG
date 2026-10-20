# File: res://core_engine/commands/rollback_command.gd
# Class: class_name RollbackCommand
# Role: CNT_01 바이츠 더 더스트 실행 - CommandStack이 이번 턴 커맨드 이력을 역순 undo하도록 요청한다. 손패는 되돌리지 않으므로 소모된 카드는 복구되지 않는다
class_name RollbackCommand
extends GameCommand


## CNT_01 바이츠 더 더스트: 되감은 뒤 공격한 사람의 턴을 끝낸다.
var ends_turn: bool = false


func _init(acting_player: int = -1) -> void:
	super()
	sender_id = acting_player
	command_name = "Rollback"
	triggers_rollback = true


func _run() -> void:
	state.hurt_players.clear()
	state.rollback_requested = true
	state.rollback_ends_turn = ends_turn
