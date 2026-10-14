# File: res://core_engine/commands/game_command.gd
# Class: class_name GameCommand
# Role: 모든 행동·생떼 카드·법전 후속 효과를 캡슐화하는 실행(execute)/취소(undo) 인터페이스
class_name GameCommand
extends RefCounted

var player_id: int = -1
var command_name: StringName = &"GameCommand"
var _before: TurnSnapshot = null


## 실행 직전 상태를 저장한 뒤 _run()을 호출한다. 서브클래스는 _run()만 구현한다.
func execute(state: GameState) -> void:
	_before = TurnSnapshot.capture(state)
	_run(state)


## 실행 이전 상태로 되돌린다. 커맨드 스택이 LIFO로만 호출하므로 중간 상태가 어긋나지 않는다.
func undo(state: GameState) -> void:
	if _before != null:
		_before.restore(state, true)


func _run(_state: GameState) -> void:
	push_error("GameCommand._run()은 서브클래스에서 구현해야 합니다: %s" % command_name)
