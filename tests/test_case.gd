# File: res://tests/test_case.gd
# Class: class_name TestCase
# Role: 헤드리스 단위 테스트 베이스. check/check_eq로 실패를 수집하고 러너가 test_* 메서드를 실행한다
class_name TestCase
extends RefCounted

var failures: Array[String] = []
var assertions: int = 0
var current_test: String = ""
## 러너가 주입하는 씬 트리 (TurnManager 같은 Node 테스트용).
var tree: SceneTree = null
var _to_free: Array[Node] = []


func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append("%s: %s" % [current_test, message])


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: %s (기대=%s, 실제=%s)" % [current_test, message, str(expected), str(actual)])


## 테스트가 끝나면 러너가 해제할 Node를 등록한다.
func defer_free(node: Node) -> void:
	_to_free.append(node)


func cleanup() -> void:
	for node: Node in _to_free:
		if is_instance_valid(node):
			node.free()
	_to_free.clear()


# --- 공용 헬퍼 -------------------------------------------------------------

func make_state(player_count: int = 2, seed_value: int = 12345, kinds_by_player: Dictionary = {}) -> GameState:
	var ids: Array[int] = []
	for i: int in range(1, player_count + 1):
		ids.append(i)
	var state := GameState.new()
	state.setup(ids, seed_value, kinds_by_player)
	return state


func place(state: GameState, pawn_id: int, tile: int, history: Array[int] = [], started: bool = true) -> PlayerPawn:
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	pawn.current_tile_idx = tile
	var trail: Array[int] = history.duplicate()
	trail.append(tile)  # step_history 스택의 마지막 원소는 항상 현재 타일
	pawn.step_history = trail
	pawn.has_left_start = started
	state.sync_stack_position(pawn)
	return pawn


func make_ctx(state: GameState, steps: int, actor_id: int = 1) -> RuleContext:
	var ctx := RuleContext.new()
	ctx.state = state
	ctx.actor_id = actor_id
	ctx.raw_roll = steps
	ctx.dice_value = steps
	return ctx


func add_law(state: GameState, law_id: String) -> void:
	state.rulebook.enqueue_law(LawRegistry.create(law_id))


## 지정한 시점으로 ctx를 법전 파이프라인에 통과시킨다.
func run_timing(state: GameState, ctx: RuleContext, timing: String) -> RuleContext:
	ctx.trigger_timing = timing
	return state.rulebook.process_context(ctx)


func move(state: GameState, pawn_id: int, steps: int) -> MoveReport:
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	return MoveExecutor.execute(state, pawn, make_ctx(state, steps, pawn.owner_id))


## 커맨드 스택 노드를 만들어 테스트 종료 시 해제하도록 등록한다.
func new_stack() -> CommandStack:
	var stack := CommandStack.new()
	defer_free(stack)
	return stack


## 커맨드를 스택을 거쳐 즉시 실행한다 (바인딩 -> can_execute -> execute -> 이력).
func exec(state: GameState, command: GameCommand, stack: CommandStack = null) -> bool:
	var target: CommandStack = stack if stack != null else new_stack()
	return target.execute_command(command, make_ctx(state, 0, command.sender_id))


func int_array(values: Array) -> Array[int]:
	var result: Array[int] = []
	result.assign(values)
	return result
