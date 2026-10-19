# File: res://tests/test_board_graph.gd
# Class: class_name TestBoardGraph
# Role: 24칸 사각 순환 트랙 검증 - 단일 고리 전진, 타일 배치(빵집·옷장·코너), 0번 후퇴(23번), 결승 바운스, 거리표와 BFS, 비숍 코너 보너스
class_name TestBoardGraph
extends TestCase


func _pawn_path(state: GameState, pawn_id: int, tile: int, history: Array[int], steps: int, started: bool = true) -> Array[int]:
	var pawn: PlayerPawn = place(state, pawn_id, tile, history, started)
	return state.board.calculate_path(pawn, steps, make_ctx(state, steps))


func test_graph_has_24_tiles_and_expected_types() -> void:
	var board := BoardGraph.new()
	check_eq(board.tiles.size(), 24, "타일 수")
	check(board.is_graph_valid(), "모든 간선이 0~23 범위")
	check_eq(board.get_tile(0).tile_type, TileNode.TileType.START_GOAL, "0번은 출발/결승")
	for index: int in [4, 10, 14, 20]:
		check_eq(board.get_tile(index).tile_type, TileNode.TileType.BAKERY, "빵집 %d" % index)
	for index: int in [9, 16]:
		check_eq(board.get_tile(index).tile_type, TileNode.TileType.PORTAL, "옷장 %d" % index)
	for index: int in [1, 2, 3, 5, 6, 7, 8, 11, 12, 13, 15, 17, 18, 19, 21, 22, 23]:
		check_eq(board.get_tile(index).tile_type, TileNode.TileType.NORMAL, "일반 %d" % index)
	check_eq(BoardSpec.corner_tiles, int_array([0, 6, 12, 18]), "코너 타일")
	board.free()


func test_single_loop_forward_and_goal() -> void:
	var state := make_state()
	check_eq(_pawn_path(state, 11, 0, [], 3, false), int_array([1, 2, 3]), "출발선에서 3칸")
	check_eq(_pawn_path(state, 11, 5, [4], 4), int_array([6, 7, 8, 9]), "6번을 지나도 분기 없음")
	check_eq(_pawn_path(state, 11, 22, [21], 5), int_array([23, 0]), "결승 도달 시 남은 칸은 버려짐")


func test_every_tile_edge_is_a_single_loop() -> void:
	var board := BoardGraph.new()
	defer_free(board)
	for index: int in 24:
		check_eq(board.get_tile(index).tile_id, index, "tile_id %d" % index)
		check_eq(board.get_tile(index).next_default, (index + 1) % 24, "next_default %d" % index)
		check_eq(board.get_tile(index).neighbors().size(), 1, "간선은 하나 %d" % index)


func test_retreat_from_start_goes_to_23() -> void:
	var state := make_state()
	check_eq(_pawn_path(state, 11, 0, [], -1, false), int_array([23]), "0번 후퇴는 23번")
	check_eq(_pawn_path(state, 11, 0, [23], -1), int_array([23]), "직전이 23번이면 23번")


func test_backward_retraces_history() -> void:
	var state := make_state()
	check_eq(_pawn_path(state, 11, 8, [5, 6, 7], -3), int_array([7, 6, 5]), "후진은 온 길을 되짚음")
	check_eq(_pawn_path(state, 11, 7, [], -1), int_array([6]), "history가 없으면 구조상 직전 타일")


func test_goal_threshold_stops_the_path_just_short_of_the_finish_line() -> void:
	var state := make_state()
	var pawn: PlayerPawn = place(state, 11, 22, [21])
	var ctx: RuleContext = make_ctx(state, 5)
	ctx.exact_goal_required = true
	check_eq(state.board.calculate_path(pawn, 5, ctx), int_array([23]), "눈금이 남으면 결승선 바로 앞(23번)에서 멈춘다 (뒤로 튕기지 않음)")
	check_eq(state.board.calculate_path(pawn, 2, ctx), int_array([23, 0]), "정확한 눈금이면 결승선까지 간다")


func test_distance_table_and_bfs() -> void:
	var board := BoardGraph.new()
	defer_free(board)
	check_eq(board.distance_to_goal(0, false), 24, "미출발 말은 한 바퀴")
	check_eq(board.distance_to_goal(23, true), 1, "23번")
	check_eq(board.distance_to_goal(12, true), 12, "반환점에서 12칸")
	check_eq(board.shortest_path(21, 0), int_array([22, 23, 0]), "BFS 21 -> 0")
	check_eq(board.shortest_path(3, 3), int_array([]), "같은 타일")


func test_tile_node_defaults_and_neighbors() -> void:
	var node := TileNode.new(4)
	check_eq(node.tile_type, TileNode.TileType.NORMAL, "기본 타입")
	check_eq(node.attachments.size(), 0, "설치물 없음")
	node.next_default = 5
	check_eq(node.neighbors(), int_array([5]), "간선 하나")


func test_board_entity_defaults_and_place_at() -> void:
	var state := make_state()
	var pawn: PlayerPawn = state.get_pawn(11)
	check_eq(pawn.entity_id, 11, "entity_id")
	check_eq(pawn.current_tile_idx, 0, "시작 타일")
	check_eq(pawn.step_history, int_array([0]), "step_history 기본값은 [0]")
	check(pawn is Node2D, "BoardEntity는 Node2D")
	pawn.place_at(9)
	check_eq(pawn.step_history, int_array([9]), "place_at은 이력을 새로 시작")


func test_step_history_stack_backtracks_exact_route() -> void:
	var state := make_state()
	var pawn: PlayerPawn = place(state, 11, 0, [], false)
	var out: Array[int] = state.board.calculate_path(pawn, 5, make_ctx(state, 5))
	check_eq(out, int_array([1, 2, 3, 4, 5]), "전진 5칸")
	var report: MoveReport = move(state, 11, 5)
	check_eq(pawn.current_tile_idx, 5, "실제 이동")
	check_eq(pawn.step_history, int_array([0, 1, 2, 3, 4, 5]), "이동한 모든 타일이 스택에 쌓임")
	var back: Array[int] = state.board.calculate_path(pawn, -4, make_ctx(state, -4))
	check_eq(back, int_array([4, 3, 2, 1]), "빽도는 스택을 역추적")
	check(report.path.size() == 5, "보고서 경로")


func test_bishop_gets_plus_2_when_passing_or_stopping_on_a_corner() -> void:
	var state := make_state(2, 1, {1: [Vector2i(GameEnums.PawnKind.CHESS, 3), Vector2i(GameEnums.PawnKind.YUT, 1), Vector2i(GameEnums.PawnKind.YUT, 2), Vector2i(GameEnums.PawnKind.YUT, 3)]})
	place(state, 11, 3, [2])
	var ctx: RuleContext = make_ctx(state, 4)
	var report := MoveReport.new()
	check_eq(MoveExecutor.plan_path(state, state.get_pawn(11), ctx, report), int_array([4, 5, 6, 7, 8, 9]), "6번을 스치면 4칸 -> 6칸")
	place(state, 11, 1, [0])
	check_eq(MoveExecutor.plan_path(state, state.get_pawn(11), make_ctx(state, 5), MoveReport.new()), int_array([2, 3, 4, 5, 6, 7, 8]), "정확히 6번에 멈추는 눈금도 +2")
	place(state, 11, 7, [6])
	check_eq(MoveExecutor.plan_path(state, state.get_pawn(11), make_ctx(state, 3), MoveReport.new()), int_array([8, 9, 10]), "코너를 안 건드리면 보너스 없음")


func test_find_nearest_entity_bfs_picks_closest_by_edges() -> void:
	var state := make_state()
	var near: PlayerPawn = place(state, 21, 8, [7])
	var far: PlayerPawn = place(state, 22, 14, [13])
	var targets: Array[BoardEntity] = [far, near]
	check_eq(state.board.find_nearest_entity_bfs(5, targets), int_array([6, 7, 8]), "더 가까운 말까지의 경로")
	check_eq(state.board.find_nearest_entity_bfs(8, targets), int_array([]), "같은 타일에 있으면 빈 경로")
	var none: Array[BoardEntity] = []
	check_eq(state.board.find_nearest_entity_bfs(5, none), int_array([]), "대상이 없으면 빈 경로")


func test_find_nearest_handles_wraparound_through_goal() -> void:
	var state := make_state()
	var target: PlayerPawn = place(state, 21, 2, [1])
	var targets: Array[BoardEntity] = [target]
	check_eq(state.board.find_nearest_entity_bfs(22, targets), int_array([23, 0, 1, 2]), "결승을 지나 출발선 쪽으로 이어짐")
