# File: res://core_engine/commands/command_stack.gd
# Class: class_name CommandStack
# Role: 개입(Interrupt) 및 롤백 처리용 스택. 개입 대기 중 쌓인 생떼 카드를 LIFO(후입선출)로 실행하고, 실행 이력은 undo 가능하게 보관한다.
class_name CommandStack
extends RefCounted

signal command_executed(command: GameCommand)
signal command_undone(command: GameCommand)

var _history: Array[GameCommand] = []
var _interrupts: Array[GameCommand] = []


func execute(command: GameCommand, state: GameState) -> void:
	command.execute(state)
	_history.append(command)
	command_executed.emit(command)


func undo_last(state: GameState) -> bool:
	if _history.is_empty():
		return false
	var command: GameCommand = _history.pop_back()
	command.undo(state)
	command_undone.emit(command)
	return true


## 개입 타이밍 동안 들어온 커맨드를 대기열에 쌓는다.
func queue_interrupt(command: GameCommand) -> void:
	_interrupts.append(command)


func interrupt_count() -> int:
	return _interrupts.size()


func history_count() -> int:
	return _history.size()


## 대기 중인 개입 커맨드를 가장 나중에 낸 것부터(LIFO) 실행한다. 실행된 커맨드를 실행 순서대로 반환한다.
func resolve_interrupts(state: GameState) -> Array[GameCommand]:
	var resolved: Array[GameCommand] = []
	while not _interrupts.is_empty():
		var command: GameCommand = _interrupts.pop_back()
		execute(command, state)
		resolved.append(command)
	return resolved


func clear_interrupts() -> void:
	_interrupts.clear()


func clear_history() -> void:
	_history.clear()
