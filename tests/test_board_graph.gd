# File: res://tests/test_board_graph.gd
# Class: class_name TestBoardGraph
# Role: 확정 명세 2·3·4 검증 - 22번 통과/정지 분기, 옷장 후 진행, 코너 정지 진입, 비숍 예외, 0번 후퇴 규칙
class_name TestBoardGraph
extends TestCase


func _pawn_path(state: GameState, pawn_id: int, tile: int, history: Array[int], steps: int, started: bool = true) -> Array[int]:
	var pawn: PlayerPawn = place(state, pawn_id, tile, history, started)
	return state.board.calculate_path(pawn, steps, make_ctx(state, steps))


func test_graph_has_29_tiles_and_expected_types() -> void:
	var board := BoardGraph.new()
	check_eq(board.tiles.size(), 29, "타일 수")
	check_eq(board.get_tile(0).tile_type, GameEnums.TileType.START_GOAL, "0번은 출발/결승")
	check_eq(board.get_tile(3).tile_type, GameEnums.TileType.BAKERY, "3번 빵집")
	check_eq(board.get_tile(17).tile_type, GameEnums.TileType.PORTAL, "17번 옷장")
	check_eq(board.get_tile(22).tile_type, GameEnums.TileType.CENTER, "22번 중앙")


func test_outer_track_forward_and_goal() -> void:
	var state := make_state()
	check_eq(_pawn_path(state, 11, 0, [], 3, false), int_array([1, 2, 3]), "출발선에서 3칸")
	check_eq(_pawn_path(state, 11, 18, [17], 5), int_array([19, 0]), "결승 도달 시 남은 칸은 버려짐")


func test_passing_22_via_shortcut_1_exits_to_23_24_15() -> void:
	var state := make_state()
	# 5번에 멈췄다가 출발 -> 20 -> 21 -> 22(통과) -> 23 -> 24 -> 15 -> 16
	check_eq(_pawn_path(state, 11, 5, [4], 7), int_array([20, 21, 22, 23, 24, 15, 16]), "지름길 1 통과 경로")
	# 중간(21번) 출발: 직전 타일이 20이어도 21 -> 22 -> 23
	check_eq(_pawn_path(state, 11, 21, [5, 20], 2), int_array([22, 23]), "21번에서 출발해 22 통과")


func test_passing_22_via_shortcut_2_exits_to_27_28_goal() -> void:
	var state := make_state()
	check_eq(_pawn_path(state, 11, 10, [9], 6), int_array([25, 26, 22, 27, 28, 0]), "지름길 2 통과 후 결승")
	check_eq(_pawn_path(state, 11, 26, [10, 25], 2), int_array([22, 27]), "26번 다음 22 통과는 27로")


func test_stopping_exactly_on_22_then_leaving_always_takes_shortest_route() -> void:
	var state := make_state()
	# 지름길 1로 들어와 22번에 정확히 멈춘 말(직전 타일 21)이 다음 턴 출발: 23이 아니라 27.
	check_eq(_pawn_path(state, 11, 22, [5, 20, 21], 3), int_array([27, 28, 0]), "22번 정지 후 출발은 최단 결승 루트(21에서 왔어도)")
	check_eq(_pawn_path(state, 11, 22, [10, 25, 26], 2), int_array([27, 28]), "지름길 2에서 와서 정지해도 동일")


func test_corner_entry_requires_stopping() -> void:
	var state := make_state()
	check_eq(_pawn_path(state, 11, 3, [2], 4), int_array([4, 5, 6, 7]), "5번을 밟고 지나가면 외곽 직진")
	check_eq(_pawn_path(state, 11, 8, [7], 4), int_array([9, 10, 11, 12]), "10번을 밟고 지나가면 외곽 직진")
	check_eq(_pawn_path(state, 11, 5, [4], 2), int_array([20, 21]), "5번에 멈췄다 출발하면 20번 진입")
	check_eq(_pawn_path(state, 11, 10, [9], 2), int_array([25, 26]), "10번에 멈췄다 출발하면 25번 진입")
	check_eq(_pawn_path(state, 11, 15, [14], 2), int_array([16, 17]), "15번은 합류점이라 지름길 없음")


func test_law_01_blocks_corner_shortcuts() -> void:
	var state := make_state()
	var pawn: PlayerPawn = place(state, 11, 5, [4])
	var ctx: RuleContext = make_ctx(state, 2)
	ctx.allow_shortcut = false
	check_eq(state.board.calculate_path(pawn, 2, ctx), int_array([6, 7]), "LAW_01이면 정지해도 외곽")


func test_bishop_turns_into_shortcut_even_when_only_passing() -> void:
	var state := make_state(2, 1, {1: [GameEnums.PawnKind.CHESS_BISHOP, GameEnums.PawnKind.YUT, GameEnums.PawnKind.YUT, GameEnums.PawnKind.YUT]})
	check_eq(_pawn_path(state, 11, 3, [2], 4), int_array([4, 5, 20, 21]), "비숍은 5번을 스치면 20번으로 꺾음")
	check_eq(_pawn_path(state, 11, 8, [7], 4), int_array([9, 10, 25, 26]), "비숍은 10번을 스치면 25번으로 꺾음")
	var pawn: PlayerPawn = place(state, 11, 3, [2])
	var ctx: RuleContext = make_ctx(state, 4)
	ctx.allow_shortcut = false
	check_eq(state.board.calculate_path(pawn, 4, ctx), int_array([4, 5, 6, 7]), "LAW_01 중에는 비숍도 외곽으로만")


func test_retreat_from_start_defaults_to_19() -> void:
	var state := make_state()
	check_eq(_pawn_path(state, 11, 0, [], -1, false), int_array([19]), "0번 후퇴 기본은 19번")


func test_retreat_from_start_uses_28_when_history_says_so() -> void:
	var state := make_state()
	check_eq(_pawn_path(state, 11, 0, [27, 28], -1), int_array([28]), "step_history 직전이 28번이면 28번으로")
	check_eq(_pawn_path(state, 11, 0, [19], -1), int_array([19]), "직전이 19번이면 19번")


func test_backward_retraces_history() -> void:
	var state := make_state()
	check_eq(_pawn_path(state, 11, 22, [5, 20, 21], -3), int_array([21, 20, 5]), "후진은 온 길을 되짚음")
	check_eq(_pawn_path(state, 11, 6, [], -1), int_array([5]), "history가 없으면 구조상 직전 타일")


func test_goal_bounce_path_with_law_08_flag() -> void:
	var state := make_state()
	var pawn: PlayerPawn = place(state, 11, 18, [17])
	var ctx: RuleContext = make_ctx(state, 5)
	ctx.exact_goal_required = true
	check_eq(state.board.calculate_path(pawn, 5, ctx), int_array([19, 0, 19, 18, 17]), "남은 칸만큼 뒤로 튕김")


func test_distance_table_and_bfs() -> void:
	var board := BoardGraph.new()
	check_eq(board.distance_to_goal(0, false), 20, "미출발 말은 한 바퀴")
	check_eq(board.distance_to_goal(19, true), 1, "19번")
	check_eq(board.distance_to_goal(5, true), 6, "5번에서 지름길로 6칸")
	check_eq(board.distance_to_goal(22, true), 3, "중앙에서 3칸")
	check_eq(board.shortest_path(5, 0), int_array([20, 21, 22, 27, 28, 0]), "BFS 5 -> 0")
	check_eq(board.shortest_path(3, 3), int_array([]), "같은 타일")
