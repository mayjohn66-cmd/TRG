# File: res://tests/test_move_executor.gd
# Class: class_name TestMoveExecutor
# Role: 이동 실행기 검증 - 옷장 워프, 완주/바운스, 잡기, LAW_03/05/07, 업기와 LAW_02 우선순위, 윷 4업 특수 승리, 함정
class_name TestMoveExecutor
extends TestCase


func test_portal_warp_counts_as_stopping_on_22() -> void:
	var state := make_state()
	place(state, 11, 4, [3])
	var report: MoveReport = move(state, 11, 3)  # 5(통과) -> 6 -> 7 (옷장)
	check(report.warped, "옷장에 멈추면 워프")
	check_eq(report.path, int_array([5, 6, 7, 22]), "워프 도착 칸까지 경로")
	var pawn: PlayerPawn = state.get_pawn(11)
	check_eq(pawn.tile_index, 22, "22번에 도착")
	var next: MoveReport = move(state, 11, 2)
	check_eq(next.path, int_array([27, 28]), "워프 후 다음 이동은 27 -> 28 최단 루트")
	check_eq(pawn.tile_index, 28, "28번 정지")


func test_portal_only_triggers_on_landing_not_passing() -> void:
	var state := make_state()
	place(state, 11, 6, [5])
	var report: MoveReport = move(state, 11, 3)  # 7을 지나 9에 정지
	check(not report.warped, "통과만 하면 워프하지 않음")
	check_eq(state.get_pawn(11).tile_index, 9, "9번 정지")


func test_finish_without_law_discards_surplus() -> void:
	var state := make_state()
	place(state, 11, 18, [17])
	var report: MoveReport = move(state, 11, 5)
	check(report.finished, "완주")
	check(state.get_pawn(11).is_finished, "기물 완주 상태")
	check_eq(report.path, int_array([19, 0]), "경로")


func test_law_08_bounces_back_surplus_and_exact_finish_still_wins() -> void:
	var state := make_state()
	add_law(state, &"LAW_08")
	place(state, 11, 18, [17])
	var report: MoveReport = move(state, 11, 5)
	check(report.bounced and not report.finished, "남으면 튕겨 나옴")
	check_eq(report.path, int_array([19, 0, 19, 18, 17, 22]), "바운스 경로 (17번 옷장에 멈추면 22번으로 워프)")
	check_eq(state.get_pawn(11).tile_index, 22, "22번에 정지")
	place(state, 12, 18, [17])
	var exact: MoveReport = move(state, 12, 2)
	check(exact.finished, "정확히 남은 칸이면 완주")


func test_law_08_bounce_through_shortcut_exit_28() -> void:
	var state := make_state()
	add_law(state, &"LAW_08")
	place(state, 11, 27, [10, 25, 26, 22])
	var report: MoveReport = move(state, 11, 4)  # 28, 0, 28, 27
	check_eq(report.path, int_array([28, 0, 28, 27]), "지름길 출구에서 튕김")


func test_capture_sends_enemy_to_start_and_grants_extra_turn() -> void:
	var state := make_state()
	place(state, 11, 2, [1])
	place(state, 21, 4, [3])
	var report: MoveReport = move(state, 11, 2)
	check_eq(report.captured_pawn_ids, int_array([21]), "잡힌 말")
	check(report.extra_turn, "추가 턴")
	var victim: PlayerPawn = state.get_pawn(21)
	check_eq(victim.tile_index, 0, "출발선 복귀")
	check(not victim.has_left_start, "출발 상태 초기화")
	check(state.hurt_players.has(2), "피해자 기록(ACT_05 조건)")


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
	check_eq(state.get_pawn(11).tile_index, 5, "잡은 뒤 3칸 돌진")
	check_eq(state.get_pawn(21).tile_index, 0, "피해자 복귀")


func test_law_07_expels_capturers_other_advanced_pawn() -> void:
	var state := make_state()
	add_law(state, &"LAW_07")
	place(state, 11, 2, [1])
	place(state, 12, 9, [8])
	place(state, 13, 14, [13])
	place(state, 21, 4, [3])
	place(state, 22, 12, [11])
	move(state, 11, 2)
	check_eq(state.get_pawn(21).tile_index, 0, "잡힌 말")
	check_eq(state.get_pawn(13).tile_index, 0, "잡은 쪽의 가장 앞선 다른 말이 동반 추방")
	check_eq(state.get_pawn(12).tile_index, 9, "그 외 말은 영향 없음")
	check_eq(state.get_pawn(22).tile_index, 12, "잡힌 쪽의 다른 말도 영향 없음")
	check_eq(state.get_pawn(11).tile_index, 4, "잡은 말 자신은 그대로")


func test_law_03_swaps_with_last_place_after_big_roll() -> void:
	var state := make_state()
	add_law(state, &"LAW_03")
	place(state, 11, 0, [], false)
	place(state, 21, 14, [13])
	# 21번 말만 보드 위에 있고 나머지 상대 말은 출발선(미출발) -> 꼴찌는 출발선 말
	var report: MoveReport = move(state, 11, 6)
	check_eq(report.effect_names, [&"SwapWithLastPlace"] as Array[StringName], "교환 효과 실행")
	check_eq(state.get_pawn(11).tile_index, 0, "이동한 말이 꼴찌 위치로")
	var swapped: PlayerPawn = null
	for pawn: PlayerPawn in state.pawns_of(2):
		if pawn.tile_index == 6:
			swapped = pawn
	check(swapped != null, "꼴찌 말이 6번으로 이동")


func test_law_03_ignores_small_rolls() -> void:
	var state := make_state()
	add_law(state, &"LAW_03")
	place(state, 11, 0, [], false)
	var report: MoveReport = move(state, 11, 5)
	check(report.effect_names.is_empty(), "5 이하는 발동 안 함")


func test_stacking_is_automatic_for_yut_and_enforced_by_law_02() -> void:
	var state := make_state()
	place(state, 11, 4, [3])
	place(state, 12, 2, [1])
	var report: MoveReport = move(state, 12, 2)
	check_eq(state.get_pawn(11).carrier, state.get_pawn(12), "같은 칸 아군은 업힘")
	check(report.stacked_pawn_ids.has(11), "보고서에 업기 기록")
	var leader: PlayerPawn = state.get_pawn(12)
	move(state, 12, 3)
	check_eq(state.get_pawn(11).tile_index, leader.tile_index, "업힌 말은 같이 이동")


func test_law_02_blocks_new_stacks_but_keeps_existing_ones() -> void:
	var state := make_state()
	place(state, 11, 4, [3])
	place(state, 12, 6, [5])
	state.stack_pawns(state.get_pawn(12), state.get_pawn(11))  # 이미 업혀 있던 상태 (11을 12가 업음)
	add_law(state, &"LAW_02")
	place(state, 13, 3, [2])
	place(state, 12, 8, [7])
	move(state, 13, 0 + 2)  # 13이 5번에 도착해도 아무것도 업지 않음
	var third: MoveReport = move(state, 13, 3)  # 8번: 12(+11)와 같은 칸
	check(third.stacked_pawn_ids.is_empty(), "LAW_02 중에는 새 업기 불가")
	check_eq(state.get_pawn(11).carrier, state.get_pawn(12), "기존 업기는 분리되지 않음")
	move(state, 12, 2)
	check_eq(state.get_pawn(11).tile_index, state.get_pawn(12).tile_index, "기존 업힌 말은 계속 동행")


func test_non_yut_pawns_only_stack_with_same_kind_or_yut() -> void:
	var state := make_state(2, 1, {1: [GameEnums.PawnKind.CHESS_KNIGHT, GameEnums.PawnKind.GO_STONE, GameEnums.PawnKind.YUT, GameEnums.PawnKind.CHESS_KNIGHT]})
	check(not state.get_pawn(11).can_stack_with(state.get_pawn(12)), "나이트 + 바둑돌 불가")
	check(state.get_pawn(11).can_stack_with(state.get_pawn(13)), "윷말은 다른 종류와도 업기 가능")
	check(state.get_pawn(11).can_stack_with(state.get_pawn(14)), "같은 종류는 가능")


func test_yut_four_stack_reaching_goal_is_special_victory() -> void:
	var state := make_state()
	place(state, 11, 18, [17])
	for slot: int in [2, 3, 4]:
		place(state, 10 + slot, 18, [17])
		state.stack_pawns(state.get_pawn(11), state.get_pawn(10 + slot))
	var report: MoveReport = move(state, 11, 2)
	check(report.finished, "4업 완주")
	check_eq(report.special_victory, &"yut_four_stack", "천하제일 4업")
	for pawn: PlayerPawn in state.pawns_of(1):
		check(pawn.is_finished, "업힌 말 전원 완주")


func test_three_stack_is_not_special_victory() -> void:
	var state := make_state()
	place(state, 11, 18, [17])
	for slot: int in [2, 3]:
		place(state, 10 + slot, 18, [17])
		state.stack_pawns(state.get_pawn(11), state.get_pawn(10 + slot))
	var report: MoveReport = move(state, 11, 2)
	check_eq(report.special_victory, &"", "3업은 특수 승리 아님")


func test_law_02_seals_four_stack_until_repealed() -> void:
	var state := make_state()
	add_law(state, &"LAW_02")
	for slot: int in [1, 2, 3, 4]:
		place(state, 10 + slot, 16, [15])
	for slot: int in [2, 3, 4]:
		move(state, 10 + slot, 0)
	var report: MoveReport = move(state, 11, 1)
	check(report.stacked_pawn_ids.is_empty(), "법전이 윷 업기 능력보다 우선")
	# FIFO로 밀어내면 다시 가능
	for law_id: StringName in [&"LAW_01", &"LAW_03", &"LAW_04", &"LAW_05"]:
		add_law(state, law_id)
	check(not state.rulebook.has_law(&"LAW_02"), "5번째 교칙이 LAW_02를 밀어냄")


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
	check_eq(state.get_pawn(11).tile_index, 0, "출발선으로 복귀")
	check_eq(state.board.get_tile(3).attachments.size(), 0, "발동 후 소모")
