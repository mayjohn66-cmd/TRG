# File: res://core_engine/commands/game_command.gd
# Class: class_name GameCommand
# Role: 모든 행동·생떼 카드·법전 후속 효과를 캡슐화하는 실행(execute)/취소(undo) 인터페이스. 실행 전 보드 상태를 TurnSnapshot으로 보관해 undo한다
class_name GameCommand
extends RefCounted

## 이 커맨드를 낸 플레이어 ID.
var sender_id: int = -1
## 생성 시각(ms, Time.get_ticks_msec). 호스트가 개입 순서를 기록·검증하는 데 쓴다.
var timestamp: int = 0
var command_name: String = "GameCommand"
## true면 CommandStack이 이 커맨드를 실행한 뒤 이번 턴 히스토리를 역순으로 undo한다 (ACT_05).
var triggers_rollback: bool = false
## execute()/undo()는 인자를 받지 않으므로 CommandStack이 실행 직전에 bind_state()로 주입한다.
var state: GameState = null
var _before: TurnSnapshot = null


func _init() -> void:
	timestamp = Time.get_ticks_msec()


func bind_state(game_state: GameState) -> void:
	state = game_state


## 지금 실행해도 되는가. 개입 카드는 LIFO로 뒤늦게 실행되므로 실행 직전에 다시 검사한다.
## 기본은 상태가 주입되어 있으면 true다. 서브클래스가 대상 유효성 검사를 덧붙인다.
func can_execute(_ctx: RuleContext) -> bool:
	return state != null


## 실행 직전 상태를 저장한 뒤 _run()을 호출한다. 서브클래스는 보통 _run()만 구현한다.
func execute() -> void:
	if state == null:
		push_error("GameCommand.execute(): 상태가 주입되지 않았습니다: %s" % command_name)
		return
	capture_before()
	_run()


## 실행 이전 상태로 되돌린다. 기물·타일 설치물·법전·NPC가 복원되며, 턴 순서·라운드 같은 턴 메타와
## 이미 소모된 손패는 TurnSnapshot의 범위 밖이므로 되돌리지 않는다(확정 명세 5).
## CommandStack이 LIFO로만 호출하므로 중간 상태가 어긋나지 않는다.
func undo() -> void:
	if state != null and _before != null:
		_before.restore(state, false)


## 실행 직전 상태를 저장한다. 실행을 다른 곳(비동기 이동 루프)이 대신 수행하는 커맨드가 이력에 등록될 때 쓴다.
func capture_before() -> void:
	_before = TurnSnapshot.capture(state)


func _run() -> void:
	push_error("GameCommand._run()은 서브클래스에서 구현해야 합니다: %s" % command_name)
