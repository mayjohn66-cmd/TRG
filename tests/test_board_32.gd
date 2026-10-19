# File: res://tests/test_board_32.gd
# Class: class_name TestBoard32
# Role: 기본 32칸(한 변 8칸) 보드의 칸 수·코너·특수 타일·점프·완주 경로를 검사한다. 각 테스트가 32칸 배치를 켜고 끝나면 24칸으로 되돌린다
class_name TestBoard32
extends TestCase


func _use_32() -> void:
	BoardSpec.apply(32)


func cleanup() -> void:
	BoardSpec.apply(24)
	super()


func test_board_spec_defaults_to_32_tiles() -> void:
	_use_32()
	check_eq(BoardSpec.tile_count, 32, "총 32칸")
	check_eq(BoardSpec.side, 8, "한 변 8칸")
	check_eq(BoardSpec.corner_tiles, int_array([0, 8, 16, 24]), "코너")
	check_eq(BoardSpec.halfway_tile, 16, "반환점")
	check_eq(BoardSpec.promotion_tiles.size(), 16, "승급 타일은 반환점부터 끝까지")
	var state: GameState = make_state()
	check_eq(state.board.tiles.size(), 32, "보드 그래프도 32칸")
	check_eq(state.board.next_tile_forward(31), 0, "31번 다음은 출발선")


func test_special_tiles_are_valid_and_distinct() -> void:
	_use_32()
	var seen: Dictionary = {}
	for tile: int in BoardSpec.bakery_tiles + BoardSpec.portal_tiles + BoardSpec.corner_tiles:
		check(tile >= 0 and tile < 32, "%d번은 보드 안" % tile)
		check(not seen.has(tile), "%d번 타일이 겹치지 않는다" % tile)
		seen[tile] = true
	for from_tile: int in BoardSpec.jump_corner_targets.keys():
		check(BoardSpec.corner_tiles.has(from_tile), "점프는 코너에서 시작")
		check(int(BoardSpec.jump_corner_targets[from_tile]) > from_tile, "점프는 앞으로만")
	for from_tile: int in BoardSpec.portal_warp_targets.keys():
		check(BoardSpec.portal_tiles.has(from_tile) and int(BoardSpec.portal_warp_targets[from_tile]) > from_tile, "옷장 워프는 앞으로만")
	for from_tile: int in BoardSpec.plane_warp_targets.keys():
		check(int(BoardSpec.plane_warp_targets[from_tile]) < 32, "비행기 워프 목적지는 보드 안")


func test_layout_places_32_tiles_around_the_square() -> void:
	_use_32()
	check_eq(BoardLayout.tile_norm(0), Vector2(1.0, 1.0), "0번 우하단")
	check_eq(BoardLayout.tile_norm(8), Vector2(1.0, 0.0), "8번 우상단")
	check_eq(BoardLayout.tile_norm(16), Vector2(0.0, 0.0), "16번 좌상단")
	check_eq(BoardLayout.tile_norm(24), Vector2(0.0, 1.0), "24번 좌하단")
	var distinct: Dictionary = {}
	for index: int in 32:
		distinct[BoardLayout.tile_norm(index)] = true
	check_eq(distinct.size(), 32, "모든 타일 좌표가 서로 다르다")
	check_eq(BoardLayout.nearest_tile(BoardLayout.tile_norm(11)), 11, "가장 가까운 타일 찾기")


func test_jump_corner_and_finish_run_on_the_bigger_board() -> void:
	_use_32()
	var state: GameState = make_state()
	place(state, 11, 6, [5])
	move(state, 11, 2)  # 7, 8: 점프 코너 8 -> 13
	check_eq(state.get_pawn(11).current_tile_idx, 13, "8번 점프 코너에 멈추면 13번으로")
	var finisher: PlayerPawn = place(state, 12, 30, [29])
	check(move(state, 12, 2).finished and finisher.is_finished, "30번에서 눈금 2면 정확히 완주")
	place(state, 13, 28, [27])
	var far: MoveReport = move(state, 13, 6)
	check(far.finished, "넘치는 눈금은 결승선에서 끝난다")


func test_boost_pads_and_promotion_follow_the_32_tile_layout() -> void:
	_use_32()
	var state: GameState = make_state()
	state.boost_gimmicks = true
	place(state, 11, 3, [2])
	move(state, 11, 2)  # 5번 발판(빵집과 겹침) -> +3
	check_eq(state.get_pawn(11).current_tile_idx, 13, "5번 발판에 멈추면 +3칸 날아가 8번 점프 코너에 서고 13번으로 이어진다")
	check(BoardSpec.promotion_tiles.has(16) and not BoardSpec.promotion_tiles.has(15), "승급은 16번(반환점)부터")


func test_board_skin_tiles_do_not_overlap_on_a_longer_side() -> void:
	_use_32()
	var spacing: float = (1.0 - 2.0 * BoardSkin.TRACK_INSET) / float(BoardSpec.side)
	var along: float = BoardSkin.definition(3)["footprint"].y
	var depth: float = BoardSkin.definition(3)["footprint"].x
	var corner: float = BoardSkin.definition(8)["footprint"].x
	check(along < spacing, "한 변 8칸에서도 타일 폭(%.3f)이 칸 간격(%.3f)보다 작다" % [along, spacing])
	check(BoardSkin.definition(11)["footprint"].x < spacing, "가로 변도 마찬가지")
	check(corner / 2.0 + along / 2.0 < spacing, "코너 둘레 타일과 겹치지 않는다")
	check(depth / 2.0 + along / 2.0 < spacing, "코너 양쪽 이웃 타일끼리도 겹치지 않는다")
