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


func test_every_pawn_kind_can_stack_with_its_own_team() -> void:
	for kind: GameEnums.PawnKind in [GameEnums.PawnKind.BASIC, GameEnums.PawnKind.CHESS, GameEnums.PawnKind.JANGGI, GameEnums.PawnKind.MONOPOLY, GameEnums.PawnKind.GO]:
		var loadout: Array = [0, 0, 0, 0] if kind == GameEnums.PawnKind.BASIC else [Vector2i(kind, 1), Vector2i(kind, 2), 0, 0]
		if kind == GameEnums.PawnKind.JANGGI:
			loadout = [Vector2i(kind, 2), Vector2i(kind, 1), 0, 0]  # 움직이는 쪽은 포 (차는 직진 +2칸이라 지나친다)
		var state := make_state(2, 1, {1: loadout})
		place(state, 11, 4, [3])
		place(state, 12, 2, [1])
		var report: MoveReport = move(state, 12, 2)
		check(state.get_pawn(11).carrier == state.get_pawn(12) and report.stacked_pawn_ids.has(11), "%d: 아군 말 위에 도착하면 합류" % kind)
		check_eq(state.leaders_at(4).size(), 1, "%d: 하나로 합쳐 움직인다" % kind)
	var enemies := make_state(2, 1)
	place(enemies, 21, 4, [3])
	place(enemies, 11, 2, [1])
	check(not enemies.get_pawn(11).can_stack_with(enemies.get_pawn(21)), "적 말과는 업을 수 없다")

func test_defer_stack_choice_reports_an_offer_instead_of_stacking() -> void:
	var state := make_state(2, 1, {1: _yut_loadout()})
	place(state, 11, 4, [3])
	place(state, 12, 2, [1])
	var ctx: RuleContext = make_ctx(state, 2)
	ctx.defer_stack_choice = true
	var report: MoveReport = MoveExecutor.execute(state, state.get_pawn(12), ctx)
	check_eq(report.stack_offer, {"mover": 12, "others": [11]}, "업기 제안")
	check(state.get_pawn(11).carrier == null, "선택 전에는 합치지 않음")


func test_any_two_own_pawns_can_stack_regardless_of_kind() -> void:
	var state := make_state(2, 1, {1: [Vector2i(GameEnums.PawnKind.CHESS, 2), Vector2i(GameEnums.PawnKind.GO, 1), Vector2i(GameEnums.PawnKind.YUT, 1), Vector2i(GameEnums.PawnKind.CHESS, 1)]})
	check(state.get_pawn(11).can_stack_with(state.get_pawn(12)), "나이트 + 바둑돌 가능")
	check(state.get_pawn(11).can_stack_with(state.get_pawn(13)), "윷말과도 가능")
	check(state.get_pawn(11).can_stack_with(state.get_pawn(14)), "같은 종류도 가능")


func test_stack_magnet_pulls_onto_an_ally_one_tile_ahead_or_behind() -> void:
	var state := make_state(2, 1)
	place(state, 11, 8, [7])
	place(state, 12, 5, [4])
	var report: MoveReport = move(state, 12, 2)  # 7번에 멈추면 바로 앞(8번)의 아군에게 합류
	check(state.get_pawn(11).carrier == state.get_pawn(12) and state.get_pawn(12).current_tile_idx == 8, "앞 1칸 아군에게 당겨 붙어 업힌다")
	check(report.stacked_pawn_ids.has(11) and report.path.back() == 8, "보고서에 합류 칸과 업기 기록")
	var behind := make_state(2, 1)
	place(behind, 11, 6, [5])
	place(behind, 12, 3, [2])
	move(behind, 12, 4)  # 7번에 멈추면 바로 뒤(6번)의 아군에게 합류
	check(behind.get_pawn(11).carrier == behind.get_pawn(12) and behind.get_pawn(12).current_tile_idx == 6, "뒤 1칸 아군에게도 합류")
	var far := make_state(2, 1)
	place(far, 11, 9, [8])
	place(far, 12, 5, [4])
	move(far, 12, 2)
	check(far.get_pawn(11).carrier == null and far.get_pawn(12).current_tile_idx == 7, "2칸 떨어진 아군은 당기지 않는다")


func test_stack_magnet_skips_enemy_traps_and_is_automatic_even_with_choice() -> void:
	var state := make_state(2, 1)
	place(state, 11, 8, [7])
	place(state, 12, 5, [4])
	var trap: TileAttachment = AttachmentRegistry.create("TRP_02")
	trap.owner_id = 2
	state.board.get_tile(8).add_attachment(trap)
	move(state, 12, 2)
	check(state.get_pawn(11).carrier == null and state.get_pawn(12).current_tile_idx == 7, "상대 설치물이 있는 칸으로는 당기지 않는다")
	var choice := make_state(2, 1)
	place(choice, 11, 8, [7])
	place(choice, 12, 5, [4])
	var ctx: RuleContext = make_ctx(choice, 2)
	ctx.defer_stack_choice = true
	var report: MoveReport = MoveExecutor.execute(choice, choice.get_pawn(12), ctx)
	check(report.stack_offer.is_empty() and choice.get_pawn(11).carrier == choice.get_pawn(12), "업기 자석은 선택 없이 자동 합류")


func test_bot_puts_stacking_first() -> void:
	var state := make_state(2, 1)
	place(state, 11, 22, [21])  # 눈금 2: 결승 완주
	place(state, 12, 5, [4])    # 눈금 2: 7번 -> 앞 8번의 아군에게 합류
	place(state, 13, 8, [7])
	check(BotBrain.would_stack(state, state.get_pawn(12), 7), "합류 수를 알아본다")
	check_eq(BotBrain.choose_pawn(state, 1, 2), 12, "합류할 수 있는 말을 무엇보다 먼저 고른다")

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


## 함정이 말을 다른 칸으로 옮기면(바나나 미끄러짐) 그 도착 칸의 함정도 발동한다.
func test_trap_that_moves_the_pawn_triggers_the_trap_where_it_lands() -> void:
	var state := make_state()
	var slide: int = CardRegistry.param(&"TRP_06", TrapBanana.SLIDE_STEPS)
	place(state, 11, 1)
	state.place_attachment(2, TrapBanana.new(2))
	state.place_attachment(2 + slide, TrapMirrorForce.new(2))
	move(state, 11, 1)  # 2번 바나나 -> 미끄러져 도착한 칸의 함정
	var pawn: PlayerPawn = state.get_pawn(11)
	check(not pawn.has_left_start, "미끄러져 도착한 칸의 함정에 걸려 출발선으로 (%d번)" % pawn.current_tile_idx)
	check_eq(state.board.get_tile(2 + slide).attachments.size(), 0, "도착 칸 함정도 소모됨")


## 연쇄는 MAX_TRAP_CHAIN번까지만: 바나나가 줄줄이 깔려 있어도 무한히 미끄러지지 않는다.
func test_forced_arrival_trap_chain_is_capped() -> void:
	var state := make_state()
	var slide: int = CardRegistry.param(&"TRP_06", TrapBanana.SLIDE_STEPS)
	place(state, 11, 1)
	var tiles: Array[int] = []
	for i: int in MoveExecutor.MAX_TRAP_CHAIN + 2:
		tiles.append(2 + slide * i)
		state.place_attachment(tiles.back(), TrapBanana.new(2))
	move(state, 11, 1)
	var last: int = tiles[MoveExecutor.MAX_TRAP_CHAIN + 1]
	check_eq(state.get_pawn(11).current_tile_idx, last, "처음 1번 + 연쇄 %d번 미끄러진 뒤 멈춘다" % MoveExecutor.MAX_TRAP_CHAIN)
	check_eq(state.board.get_tile(last).attachments.size(), 1, "상한을 넘은 칸의 바나나는 발동하지 않고 남는다")
