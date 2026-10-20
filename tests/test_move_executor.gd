# File: res://tests/test_move_executor.gd
# Class: class_name TestMoveExecutor
# Role: 이동 실행기 검증 - 옷장 워프, 완주/바운스, 잡기, LAW_03/05/07, 업기와 LAW_02 우선순위, 윷 4업 특수 승리, 함정
class_name TestMoveExecutor
extends TestCase


func _yut_loadout() -> Array:
	return [Vector2i(GameEnums.PawnKind.YUT, 1), Vector2i(GameEnums.PawnKind.YUT, 2), Vector2i(GameEnums.PawnKind.YUT, 3), Vector2i(GameEnums.PawnKind.YUT, 4)]


func test_portal_warp_counts_as_stopping_on_16() -> void:
	var state := make_state()
	place(state, 11, 6, [5])
	var report: MoveReport = move(state, 11, 3)  # 7 -> 8 -> 9 (옷장)
	check(report.warped, "옷장에 멈추면 워프")
	check_eq(report.path, int_array([7, 8, 9, 16]), "워프 도착 칸까지 경로")
	var pawn: PlayerPawn = state.get_pawn(11)
	check_eq(pawn.current_tile_idx, 16, "보드를 가로질러 16번에 도착")
	var next: MoveReport = move(state, 11, 1)
	check_eq(next.path, int_array([17]), "워프 후 다음 이동은 16번에서 이어짐")
	check_eq(pawn.current_tile_idx, 17, "17번 정지")


func test_second_portal_warps_to_20_and_does_not_chain() -> void:
	var state := make_state()
	place(state, 11, 14, [13])
	var report: MoveReport = move(state, 11, 2)
	check_eq(report.path, int_array([15, 16, 20]), "16번 옷장은 20번으로")
	check_eq(state.get_pawn(11).current_tile_idx, 20, "20번 정지")
	check_eq(report.drawn_card != &"", true, "워프 도착한 20번이 빵집이라 카드를 받는다")


func test_portal_only_triggers_on_landing_not_passing() -> void:
	var state := make_state()
	place(state, 11, 7, [6])
	var report: MoveReport = move(state, 11, 3)  # 9를 지나 10에 정지 (10번 빵집)
	check(not report.warped, "통과만 하면 워프하지 않음")
	check_eq(state.get_pawn(11).current_tile_idx, 10, "10번 정지")


func test_corners_no_longer_have_jump_pads() -> void:
	var state := make_state()
	check(BoardSpec.jump_corner_targets.is_empty(), "코너 기본 점프대 삭제")
	place(state, 11, 3, [2])
	var report: MoveReport = move(state, 11, 3)
	check(not report.warped, "6번 코너에 정확히 멈춰도 점프하지 않는다")
	check_eq(report.path, int_array([4, 5, 6]), "6번에 그대로")


func test_law_01_disables_jump_corners_and_portals() -> void:
	var state := make_state()
	add_law(state, &"LAW_01")
	place(state, 11, 3, [2])
	var report: MoveReport = move(state, 11, 3)
	check(not report.warped, "LAW_01 중에는 점프 불가")
	check_eq(state.get_pawn(11).current_tile_idx, 6, "6번에 그대로")
	place(state, 12, 6, [5])
	move(state, 12, 3)
	check_eq(state.get_pawn(12).current_tile_idx, 9, "옷장도 워프하지 않는다")


func test_finish_without_law_discards_surplus() -> void:
	var state := make_state()
	place(state, 11, 22, [21])
	var report: MoveReport = move(state, 11, 5)
	check(report.finished, "완주")
	check(state.get_pawn(11).is_finished, "기물 완주 상태")
	check_eq(report.path, int_array([23, 0]), "경로")


func test_negative_roll_never_moves_a_pawn_backward() -> void:
	var state := make_state()
	place(state, 11, 0, [])
	var report: MoveReport = move(state, 11, -1)
	check(report.path.is_empty(), "음수 눈금은 0칸으로 본다")
	check_eq(state.get_pawn(11).current_tile_idx, 0, "출발선에 머문다")
	place(state, 12, 7, [6])
	move(state, 12, -3)
	check_eq(state.get_pawn(12).current_tile_idx, 7, "보드 위의 말도 뒤로 가지 않는다")


func test_reverse_run_lets_retreated_pawn_finish() -> void:
	var state := make_state()
	place(state, 11, 23, [])
	state.get_pawn(11).retreated_run = true
	state.reverse_move_rounds_left = 2
	check(state.get_pawn(11).can_finish(state), "역주행 중에는 완주 가능")
	state.reverse_move_rounds_left = 0
	check(not state.get_pawn(11).can_finish(state), "역주행이 끝나면 다시 불가")
	check(state.pawn_progress_distance(state.get_pawn(11)) > BoardSpec.tile_count, "진행 거리는 한 바퀴 더")


func test_law_08_stops_short_of_the_goal_and_exact_finish_still_wins() -> void:
	var state := make_state()
	add_law(state, &"LAW_08")
	place(state, 11, 22, [21])
	var report: MoveReport = move(state, 11, 5)
	check(not report.finished, "남으면 완주하지 못함")
	check_eq(report.path, int_array([23]), "결승선 바로 앞까지만 간다")
	check_eq(state.get_pawn(11).current_tile_idx, 23, "23번에 정지")
	place(state, 12, 22, [21])
	var exact: MoveReport = move(state, 12, 2)
	check(exact.finished, "정확히 남은 칸이면 완주")


func test_law_03_swaps_with_last_place_after_big_roll() -> void:
	var state := make_state()
	add_law(state, &"LAW_03")
	place(state, 11, 0, [], false)
	place(state, 21, 14, [13])
	# 21번 말만 보드 위에 있고 나머지 상대 말은 출발선(미출발) -> 꼴찌는 출발선 말
	var report: MoveReport = move(state, 11, 6)  # 6번 코너 정지
	check_eq(report.effect_names, ["SwapWithLastPlace"] as Array[String], "교환 효과 실행")
	check_eq(state.get_pawn(11).current_tile_idx, 0, "이동한 말이 꼴찌 위치로")
	var swapped: PlayerPawn = null
	for pawn: PlayerPawn in state.pawns_of(2):
		if pawn.current_tile_idx == 6:
			swapped = pawn
	check(swapped != null, "꼴찌 말이 6번으로 이동")


func test_capture_sends_enemy_to_start_and_yut_pawn_grants_extra_turn() -> void:
	var state := make_state(2, 1, {1: _yut_loadout()})
	place(state, 11, 2, [1])
	place(state, 21, 4, [3])
	var report: MoveReport = move(state, 11, 2)
	check_eq(report.captured_pawn_ids, int_array([21]), "잡힌 말")
	check(report.extra_turn, "신명나는 사냥: 윷놀이 기물이 잡으면 추가 턴")
	var victim: PlayerPawn = state.get_pawn(21)
	check_eq(victim.current_tile_idx, 0, "출발선 복귀")
	check(not victim.has_left_start, "출발 상태 초기화")
	check(state.hurt_players.has(2), "피해자 기록(ACT_05 조건)")


func test_non_yut_pawns_capture_without_extra_turn() -> void:
	for kind: GameEnums.PawnKind in [GameEnums.PawnKind.BASIC, GameEnums.PawnKind.CHESS, GameEnums.PawnKind.JANGGI, GameEnums.PawnKind.MONOPOLY]:
		var loadout: Array = [0, 0, 0, 0] if kind == GameEnums.PawnKind.BASIC else [Vector2i(kind, 1), 0, 0, 0]
		var state := make_state(2, 1, {1: loadout})
		place(state, 11, 2, [1])
		place(state, 21, 4, [3])
		var report: MoveReport = move(state, 11, 2)
		check_eq(report.captured_pawn_ids, int_array([21]), "%d: 잡기는 그대로 수행" % kind)
		check(not report.extra_turn, "%d: 추가 굴림 기회 없음" % kind)
		check_eq(state.get_pawn(21).current_tile_idx, 0, "%d: 출발선으로" % kind)


func test_unstacked_pieces_on_one_tile_are_captured_one_at_a_time() -> void:
	var state := make_state()
	place(state, 21, 4, [3])
	place(state, 22, 4, [3])
	place(state, 23, 4, [3])
	place(state, 11, 2, [1])
	var report: MoveReport = move(state, 11, 2)
	check_eq(report.captured_pawn_ids, int_array([21]), "ID가 가장 앞선 말 하나만 잡힌다")
	check_eq(state.get_pawn(21).current_tile_idx, 0, "잡힌 말은 출발선으로")
	check_eq(state.get_pawn(22).current_tile_idx, 4, "나머지는 그 타일에 생존")
	check_eq(state.get_pawn(23).current_tile_idx, 4, "나머지는 그 타일에 생존")
	check(state.get_pawn(22).has_left_start and state.get_pawn(23).has_left_start, "생존한 말은 출발 상태 유지")
	check_eq(state.get_pawn(11).current_tile_idx, 4, "이동한 말도 같은 타일에 공존")
	var second: MoveReport = move(state, 11, 0 + 1)  # 다른 말이 같은 타일에 다시 도착하면 다음 말이 잡힌다
	check(second.captured_pawn_ids.is_empty(), "이동해 떠난 뒤에는 잡기 없음")
	place(state, 12, 2, [1])
	check_eq(move(state, 12, 2).captured_pawn_ids, int_array([22]), "다음 도착은 남은 말 중 ID가 앞선 하나")


func test_stacked_pieces_are_captured_together_as_one_unit() -> void:
	var state := make_state(2, 1, {2: [Vector2i(GameEnums.PawnKind.YUT, 1), Vector2i(GameEnums.PawnKind.YUT, 2), Vector2i(GameEnums.PawnKind.YUT, 3), 0]})
	place(state, 21, 4, [3])
	place(state, 22, 4, [3])
	state.stack_pawns(state.get_pawn(21), state.get_pawn(22))
	place(state, 23, 4, [3])
	place(state, 11, 2, [1])
	var report: MoveReport = move(state, 11, 2)
	check_eq(report.captured_pawn_ids, int_array([21, 22]), "업힌 말은 전원 함께 추방")
	check_eq(state.get_pawn(22).current_tile_idx, 0, "업힌 말도 출발선으로")
	check(state.get_pawn(22).carrier == null, "업기 해제")
	check_eq(state.get_pawn(23).current_tile_idx, 4, "따로 서 있던 말은 생존")


func test_each_enemy_owner_loses_at_most_one_unit_per_capture() -> void:
	var state := make_state(3)
	place(state, 21, 4, [3])
	place(state, 22, 4, [3])
	place(state, 31, 4, [3])
	place(state, 32, 4, [3])
	place(state, 11, 2, [1])
	var report: MoveReport = move(state, 11, 2)
	check_eq(report.captured_pawn_ids, int_array([21, 31]), "상대 플레이어마다 1개씩")
	check_eq(state.get_pawn(22).current_tile_idx, 4, "P2의 나머지 말 생존")
	check_eq(state.get_pawn(32).current_tile_idx, 4, "P3의 나머지 말 생존")


func test_area_traps_still_hit_every_piece_on_the_tile() -> void:
	var state := make_state()
	place(state, 21, 6, [5])
	place(state, 22, 6, [5])
	place(state, 12, 7, [6])
	var mine := PlaceMineFieldCommand.new(1, 6)
	mine.bind_state(state)
	mine.execute()
	place(state, 11, 4, [3])
	move(state, 11, 2)  # 6번 지뢰를 밟아 폭발
	check_eq(state.get_pawn(21).current_tile_idx, 0, "지뢰는 그 칸의 모든 말을 날린다 (1)")
	check_eq(state.get_pawn(22).current_tile_idx, 0, "지뢰는 그 칸의 모든 말을 날린다 (2)")


func test_start_tile_is_safe() -> void:
	var state := make_state()
	place(state, 12, 19, [18])
	var report: MoveReport = move(state, 12, 1)  # 결승 도달은 완주 처리
	check(report.captured_pawn_ids.is_empty(), "0번에서는 잡지 않음")


func test_law_05_charges_forward_instead_of_extra_turn() -> void:
	var state := make_state()
	add_law(state, &"LAW_05")
	place(state, 11, 0, [], false)
	place(state, 21, 2, [1])
	var report: MoveReport = move(state, 11, 2)
	check(not report.extra_turn, "추가 턴 없음")
	check_eq(state.get_pawn(11).current_tile_idx, 5, "잡은 뒤 3칸 돌진")
	check_eq(state.get_pawn(21).current_tile_idx, 0, "피해자 복귀")


func test_law_07_expels_capturers_other_advanced_pawn() -> void:
	var state := make_state()
	add_law(state, &"LAW_07")
	place(state, 11, 2, [1])
	place(state, 12, 9, [8])
	place(state, 13, 14, [13])
	place(state, 21, 4, [3])
	place(state, 22, 12, [11])
	move(state, 11, 2)
	check_eq(state.get_pawn(21).current_tile_idx, 0, "잡힌 말")
	check_eq(state.get_pawn(13).current_tile_idx, 0, "잡은 쪽의 가장 앞선 다른 말이 동반 추방")
	check_eq(state.get_pawn(12).current_tile_idx, 9, "그 외 말은 영향 없음")
	check_eq(state.get_pawn(22).current_tile_idx, 12, "잡힌 쪽의 다른 말도 영향 없음")
	check_eq(state.get_pawn(11).current_tile_idx, 4, "잡은 말 자신은 그대로")


func test_law_03_ignores_small_rolls() -> void:
	var state := make_state()
	add_law(state, &"LAW_03")
	place(state, 11, 0, [], false)
	var report: MoveReport = move(state, 11, 5)
	check(report.effect_names.is_empty(), "5 이하는 발동 안 함")


func test_yut_pawn_stacks_with_allies_of_any_kind_and_carried_pawns_move_together() -> void:
	var state := make_state(2, 1, {1: [Vector2i(GameEnums.PawnKind.YUT, 1), Vector2i(GameEnums.PawnKind.CHESS, 1), 0, 0]})
	place(state, 12, 4, [3])  # 체스 폰이 먼저 와 있고
	place(state, 11, 2, [1])
	var report: MoveReport = move(state, 11, 2)  # 윷놀이 기물이 도착
	check_eq(state.get_pawn(12).carrier, state.get_pawn(11), "윷놀이 기물은 다른 종류의 아군도 업는다")
	check(report.stacked_pawn_ids.has(12), "보고서에 업기 기록")
	move(state, 11, 3)
	check_eq(state.get_pawn(12).current_tile_idx, state.get_pawn(11).current_tile_idx, "업힌 말은 같이 이동")


func test_allies_arriving_on_a_yut_pawn_also_stack() -> void:
	var state := make_state(2, 1, {1: [Vector2i(GameEnums.PawnKind.YUT, 1), Vector2i(GameEnums.PawnKind.GO, 1), 0, 0]})
	place(state, 11, 4, [3])
	place(state, 12, 2, [1])
	move(state, 12, 2)  # 바둑돌이 내 윷놀이 기물이 있는 칸에 도착
	check_eq(state.get_pawn(11).carrier, state.get_pawn(12), "아군이 윷놀이 기물이 있는 칸에 도착해도 업힘")


func test_non_yut_pawns_never_stack_and_coexist_on_one_tile() -> void:
	for kind: GameEnums.PawnKind in [GameEnums.PawnKind.BASIC, GameEnums.PawnKind.CHESS, GameEnums.PawnKind.JANGGI, GameEnums.PawnKind.MONOPOLY, GameEnums.PawnKind.GO]:
		var loadout: Array = [0, 0, 0, 0] if kind == GameEnums.PawnKind.BASIC else [Vector2i(kind, 1), Vector2i(kind, 2), 0, 0]
		var state := make_state(2, 1, {1: loadout})
		place(state, 11, 4, [3])
		place(state, 12, 2, [1])
		var report: MoveReport = move(state, 12, 3 if kind == GameEnums.PawnKind.GO else 2)  # 바둑 2세트 포석은 눈금 -1
		check(report.stacked_pawn_ids.is_empty() and report.stack_offer.is_empty(), "%d: 업기 없음" % kind)
		check(state.get_pawn(11).carrier == null and state.get_pawn(12).carrier == null, "%d: 각각 별개 기물" % kind)
		check_eq(state.get_pawn(11).current_tile_idx, state.get_pawn(12).current_tile_idx, "%d: 같은 타일에 나란히 공존" % kind)
		check_eq(state.leaders_at(4).size(), 2, "%d: 대표 말이 둘" % kind)


func test_law_02_blocks_new_stacks_but_keeps_existing_ones() -> void:
	var state := make_state(2, 1, {1: _yut_loadout()})
	place(state, 11, 4, [3])
	place(state, 12, 6, [5])
	state.stack_pawns(state.get_pawn(12), state.get_pawn(11))  # 이미 업혀 있던 상태 (11을 12가 업음)
	add_law(state, &"LAW_02")
	place(state, 13, 3, [2])
	place(state, 12, 8, [7])
	move(state, 13, 0 + 2)  # 13이 5번에 도착해도 아무것도 업지 않음
	var third: MoveReport = move(state, 13, 3)  # 8번: 12(+11)와 같은 칸
	check(third.stacked_pawn_ids.is_empty() and third.stack_offer.is_empty(), "LAW_02 중에는 새 업기 불가")
	check_eq(state.get_pawn(11).carrier, state.get_pawn(12), "기존 업기는 분리되지 않음")
	move(state, 12, 2)
	check_eq(state.get_pawn(11).current_tile_idx, state.get_pawn(12).current_tile_idx, "기존 업힌 말은 계속 동행")


func test_defer_stack_choice_reports_an_offer_instead_of_stacking() -> void:
	var state := make_state(2, 1, {1: _yut_loadout()})
	place(state, 11, 4, [3])
	place(state, 12, 2, [1])
	var ctx: RuleContext = make_ctx(state, 2)
	ctx.defer_stack_choice = true
	var report: MoveReport = MoveExecutor.execute(state, state.get_pawn(12), ctx)
	check_eq(report.stack_offer, {"mover": 12, "others": [11]}, "업기 제안")
	check(state.get_pawn(11).carrier == null, "선택 전에는 합치지 않음")


func test_non_yut_pawns_only_stack_when_a_yut_pawn_is_involved() -> void:
	var state := make_state(2, 1, {1: [Vector2i(GameEnums.PawnKind.CHESS, 2), Vector2i(GameEnums.PawnKind.GO, 1), Vector2i(GameEnums.PawnKind.YUT, 1), Vector2i(GameEnums.PawnKind.CHESS, 1)]})
	check(not state.get_pawn(11).can_stack_with(state.get_pawn(12)), "나이트 + 바둑돌 불가")
	check(state.get_pawn(11).can_stack_with(state.get_pawn(13)), "윷말은 다른 종류와도 업기 가능")
	check(not state.get_pawn(11).can_stack_with(state.get_pawn(14)), "같은 종류여도 윷이 아니면 불가")
	check(state.get_pawn(13).can_stack_with(state.get_pawn(11)), "방향과 무관하게 윷이 끼면 가능")


func test_mirror_force_trap_stops_and_expels_enemy_but_not_owner() -> void:
	var state := make_state()
	var trap := TrapMirrorForce.new(2)
	state.place_attachment(3, trap)
	place(state, 21, 0, [], false)
	var safe: MoveReport = move(state, 21, 5)
	check(not safe.trapped, "설치자 본인은 통과")
	check_eq(state.board.get_tile(3).attachments.size(), 1, "설치자가 지나가도 함정은 유지")
	place(state, 11, 0, [], false)
	var report: MoveReport = move(state, 11, 5)
	check(report.trapped, "상대 말은 통과 중에도 발동")
	check_eq(report.path, int_array([1, 2, 3]), "함정 칸에서 즉시 중단")
	check_eq(state.get_pawn(11).current_tile_idx, 0, "출발선으로 복귀")
	check_eq(state.board.get_tile(3).attachments.size(), 0, "발동 후 소모")
