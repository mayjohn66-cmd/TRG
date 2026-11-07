# File: res://core_engine/commands/command_stack.gd
# Class: class_name CommandStack
# Role: 개입 타이밍 동안 들어온 생떼 카드를 스택에 쌓아 LIFO(후입선출)로 실행하고, 이번 턴 실행 이력을 보관해 ACT_05 발동 시 역순으로 undo하는 매니저
class_name CommandStack
extends Node

signal interrupt_queued(command: GameCommand)
signal command_executed(command: GameCommand)
signal command_undone(command: GameCommand)
signal turn_rolled_back(undone_count: int)

## 개입 대기열. 가장 마지막에 쌓인 커맨드가 가장 먼저 실행된다.
var interrupt_stack: Array[GameCommand] = []
## 이번 턴에 실행된(또는 실행 중인 이동으로 등록된) 커맨드 이력. 오래된 것이 앞에 있다.
var turn_history: Array[GameCommand] = []


## 새 턴이 시작되면 이전 턴의 이력과 대기열을 비운다.
func begin_turn() -> void:
	interrupt_stack.clear()
	turn_history.clear()


## 즉시 실행한다. can_execute()가 false면 실행하지 않고 false를 반환한다.
## triggers_rollback 커맨드(ACT_05)는 이력에 남기지 않고 이번 턴 이력을 역순 undo한다.
func execute_command(command: GameCommand, ctx: RuleContext) -> bool:
	command.bind_state(ctx.state)
	if not command.can_execute(ctx):
		return false
	command.execute()
	command_executed.emit(command)
	if command.triggers_rollback:
		rollback_turn()
	else:
		turn_history.append(command)
	return true


## 개입 대기열에 쌓는다. 쌓는 시점에 한 번 검사하고, 실제 실행 직전에 resolve_interrupts()가 다시 검사한다.
func push_interrupt(command: GameCommand, ctx: RuleContext) -> bool:
	command.bind_state(ctx.state)
	if not command.can_execute(ctx):
		return false
	interrupt_stack.append(command)
	interrupt_queued.emit(command)
	return true


## 대기 중인 개입 커맨드를 가장 나중에 낸 것부터(LIFO) 실행한다. 실행 직전 can_execute()가 false가 된
## 커맨드(예: 이미 파기된 교칙을 다시 파기)는 건너뛴다. 실제 실행된 커맨드를 실행 순서대로 반환한다.
func resolve_interrupts(ctx: RuleContext) -> Array[GameCommand]:
	var resolved: Array[GameCommand] = []
	while not interrupt_stack.is_empty():
		var command: GameCommand = interrupt_stack.pop_back()
		if execute_command(command, ctx):
			resolved.append(command)
	return resolved


## 이미 다른 곳에서 수행 중인 동작(비동기 이동 루프)을 이력에 등록한다. 실행 전 상태는 호출 측이 capture_before()로 저장해 둔다.
func record(command: GameCommand) -> void:
	turn_history.append(command)


## 가장 최근 이력 하나를 취소한다.
func undo_last() -> bool:
	if turn_history.is_empty():
		return false
	var command: GameCommand = turn_history.pop_back()
	command.undo()
	command_undone.emit(command)
	return true


## 이번 턴 이력을 최근 것부터 역순으로 모두 undo한다. 취소한 개수를 반환한다.
func undo_turn_history() -> int:
	var count: int = 0
	while undo_last():
		count += 1
	return count


## ACT_05 바이츠 더 더스트: 이번 턴의 모든 행동을 시간 역순으로 되감는다.
func rollback_turn() -> int:
	var count: int = undo_turn_history()
	turn_rolled_back.emit(count)
	return count


func interrupt_count() -> int:
	return interrupt_stack.size()


func history_count() -> int:
	return turn_history.size()


func clear_interrupts() -> void:
	interrupt_stack.clear()
