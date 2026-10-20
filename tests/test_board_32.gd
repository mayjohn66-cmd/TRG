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
	# 부스터 발판도 다른 특수 칸(빵집·옷장·코너)과 한 칸에 겹치지 않는다 (아이콘·효과가 한 칸에 겹치지 않게)
	for tile: int in BoardSpec.bakery_tiles + BoardSpec.portal_tiles + BoardSpec.corner_tiles + BoardSpec.dash_tiles:
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


func test_corner_stop_and_finish_run_on_the_bigger_board() -> void:
	_use_32()
	var state: GameState = make_state()
	place(state, 11, 6, [5])
	move(state, 11, 2)  # 7, 8: 코너 8 정지 (점프대 없음)
	check_eq(state.get_pawn(11).current_tile_idx, 8, "8번 코너에 멈춘다")
	var finisher: PlayerPawn = place(state, 12, 30, [29])
	check(move(state, 12, 2).finished and finisher.is_finished, "30번에서 눈금 2면 정확히 완주")
	place(state, 13, 28, [27])
	var far: MoveReport = move(state, 13, 6)
	check(far.finished, "넘치는 눈금은 결승선에서 끝난다")


func test_boost_pads_and_promotion_follow_the_32_tile_layout() -> void:
	_use_32()
	var state: GameState = make_state()
	state.boost_gimmicks = true
	place(state, 11, 2, [1])
	move(state, 11, 2)  # 4번 부스터 발판 -> +3
	check_eq(state.get_pawn(11).current_tile_idx, 7, "4번 발판에 멈추면 +3칸 날아가 7번에 선다")
	check(BoardSpec.promotion_tiles.has(16) and not BoardSpec.promotion_tiles.has(15), "승급은 16번(반환점)부터")


func test_board_skin_tiles_do_not_overlap_on_a_longer_side() -> void:
	_use_32()
	var length: float = 1.0 - 2.0 * BoardSkin.TRACK_INSET
	var rects: Array[Rect2] = []
	for index: int in BoardSpec.tile_count:
		var footprint: Vector2 = BoardSkin.definition(index)["footprint"]
		var center: Vector2 = BoardLayout.tile_norm(index) * length
		rects.append(Rect2(center - footprint / 2.0, footprint))
	var overlaps: int = 0
	for a: int in BoardSpec.tile_count:
		for b: int in range(a + 1, BoardSpec.tile_count):
			if rects[a].intersects(rects[b]):
				overlaps += 1
	check(overlaps == 0, "모든 타일의 발자국이 서로 겹치지 않는다 (겹침 %d쌍)" % overlaps)
	var along: float = BoardSkin.definition(3)["footprint"].y
	var normal_gap: float = (BoardLayout.tile_norm(4) - BoardLayout.tile_norm(3)).length() * length
	check(along > normal_gap * 0.85, "일반 타일은 이웃과 거의 맞닿을 만큼 넓다 (폭 %.3f / 간격 %.3f)" % [along, normal_gap])
	var corner: float = BoardSkin.definition(8)["footprint"].x
	var depth: float = BoardSkin.definition(3)["footprint"].x
	check(corner > depth * 1.15, "코너 타일은 일반 타일보다 확실히 크다 (%.3f vs %.3f)" % [corner, depth])


func test_floor_decals_follow_board_plane_and_next_tile_on_both_layouts() -> void:
	# A diamond board has skewed axes: a screen rotation alone cannot reproduce its plane.
	var plane := Transform2D(Vector2(370,233),Vector2(-370,233),Vector2(640,360))
	for count: int in [24,32]:
		BoardSpec.apply(count)
		for index: int in BoardSpec.corner_tiles + BoardSpec.dash_tiles:
			var next: Vector2 = BoardLayout.tile_norm((index+1)%count)-BoardLayout.tile_norm(index)
			var frame := BoardSkin.decal_frame(plane,0.1,BoardSkin.forward_world(index))
			check(frame.x.normalized().dot(plane.basis_xform(next).normalized()) > 0.9999,"%d칸 보드 %d번 화살표는 다음 칸을 가리킨다" % [count,index])
			check(absf(frame.x.normalized().dot(frame.y.normalized())) > 0.1,"아이콘은 화면 직각이 아니라 보드 기울기를 공유한다")
		for index: int in BoardSpec.bakery_tiles + BoardSpec.portal_tiles:
			var axis: Vector2 = BoardSkin.symbol_axis(index)
			var top := Vector2(axis.y,-axis.x)
			var inward: Vector2 = [Vector2.LEFT,Vector2.DOWN,Vector2.RIGHT,Vector2.UP][mini(index/BoardSpec.side,3)]
			check(top.dot(inward)>0.9999,"빵·옷장 윗부분은 네 변 모두 판 중심을 향한다: %d" % index)
			check(absf(axis.dot(BoardSkin.forward_world(index)))>0.9999,"빵·옷장 가로축은 타일 짧은 변과 나란하다")
	for kind: String in BoardSkin.DECALS:
		var texture: Texture2D = BoardSkin.DECALS[kind]
		check(texture != null and texture.get_width() <= 256,"보드 심볼은 256px 이하로 임포트된다: " + kind)
