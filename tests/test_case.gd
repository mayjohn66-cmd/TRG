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


func check(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append("%s: %s" % [current_test, message])


func check_eq(actual: Variant, expected: Variant, message: String) -> void:
	assertions += 1
	if typeof(actual) != typeof(expected) or actual != expected:
		failures.append("%s: %s (기대=%s, 실제=%s)" % [current_test, message, str(expected), str(actual)])


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
	pawn.tile_index = tile
	pawn.step_history.assign(history)
	pawn.has_left_start = started
	state.sync_stack_position(pawn)
	return pawn


func make_ctx(state: GameState, steps: int, player_id: int = 1) -> RuleContext:
	var ctx := RuleContext.new()
	ctx.state = state
	ctx.player_id = player_id
	ctx.raw_roll = steps
	ctx.steps = steps
	return ctx


func add_law(state: GameState, law_id: StringName) -> void:
	state.rulebook.add_law(LawRegistry.create(law_id))


func move(state: GameState, pawn_id: int, steps: int) -> MoveReport:
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	return MoveExecutor.execute(state, pawn, make_ctx(state, steps, pawn.owner_id))


func int_array(values: Array) -> Array[int]:
	var result: Array[int] = []
	result.assign(values)
	return result
