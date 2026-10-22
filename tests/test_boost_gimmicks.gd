# File: res://tests/test_boost_gimmicks.gd
# Class: class_name TestBoostGimmicks
# Role: 후퇴 삭제 개편의 '폭풍 전진 3대 기믹'(🔥 리벤지 부스터 · ⚡ 부스터 발판 · 🏃 말 밟고 점프)과 장외 사출 규칙(음수 눈금 0칸, 짝수 니트로, 결승선 문턱)을 검사한다
class_name TestBoostGimmicks
extends TestCase


func _boost_state(players: int = 2) -> GameState:
	var state: GameState = make_state(players, 1)
	state.boost_gimmicks = true
	return state


# --- ⚡ 부스터 발판 -----------------------------------------------------------------

func test_dash_pads_are_4_11_and_19() -> void:
	check_eq(BoardSpec.dash_tiles, int_array([4, 11, 19]), "발판 위치 (24칸)")
	check_eq(GameEnums.DASH_STEPS, 3, "발판 가속 칸수")


func test_stopping_on_a_dash_pad_flies_three_more_tiles() -> void:
	for pad: int in BoardSpec.dash_tiles:
		var state: GameState = _boost_state()
		place(state, 11, pad - 2, [pad - 3])
		var signals: Array = []
		state.dash_pad_triggered.connect(func(pawn_id: int, tile: int) -> void: signals.append([pawn_id, tile]))
		var report: MoveReport = move(state, 11, 2)
		check_eq(state.get_pawn(11).current_tile_idx, pad + 3, "%d번 발판에 멈추면 +3칸 (%d번)" % [pad, pad + 3])
		check_eq(report.dash_tiles, int_array([pad]), "보고서에 발판 기록")
		check_eq(signals, [[11, pad]], "발판 신호")


func test_passing_over_a_dash_pad_does_nothing() -> void:
	var state: GameState = _boost_state()
	place(state, 11, 2, [1])
	move(state, 11, 3)
	check_eq(state.get_pawn(11).current_tile_idx, 5, "발판(4번)을 지나치기만 하면 가속 없음")


func test_dash_pad_landing_captures_before_flying_and_can_capture_again() -> void:
	var state: GameState = _boost_state()
	place(state, 11, 2, [1])
	place(state, 21, 4, [3])
	place(state, 22, 7, [6])
	var report: MoveReport = move(state, 11, 2)
	check_eq(state.get_pawn(11).current_tile_idx, 7, "발판 착지 후 +3칸")
	check(not state.get_pawn(21).has_left_start and not state.get_pawn(22).has_left_start, "발판 위의 말과 날아간 자리의 말을 모두 잡는다")
	check_eq(report.captured_pawn_ids.size(), 2, "처치 2명")


func test_dash_pads_are_off_without_the_gimmick_switch() -> void:
	var state: GameState = make_state(2, 1)
	place(state, 11, 2, [1])
	move(state, 11, 2)
	check_eq(state.get_pawn(11).current_tile_idx, 4, "기믹 스위치를 끄면 평범한 칸")


# --- 🏃 말 밟고 점프하기 -------------------------------------------------------------

func test_each_pawn_in_the_middle_of_the_path_adds_one_tile() -> void:
	var state: GameState = _boost_state()
	place(state, 11, 12, [11])
	place(state, 21, 13, [12])  # 적
	place(state, 12, 14, [13])  # 아군
	var report: MoveReport = move(state, 11, 3)  # 13, 14, 15 -> 중간 2칸에 말
	check_eq(report.leapfrog_bonus, 2, "밟고 지나간 말 2개 = +2칸")
	check_eq(state.get_pawn(11).current_tile_idx, 17, "원래 15번 -> 17번")
	check(state.get_pawn(21).has_left_start and state.get_pawn(12).has_left_start, "지나가기만 해서 아무도 잡히지 않는다")


func test_leapfrog_is_capped_at_three_tiles() -> void:
	var state: GameState = _boost_state(4)
	place(state, 11, 7, [6])
	place(state, 21, 8, [7])
	place(state, 31, 9, [8])
	place(state, 41, 10, [9])
	place(state, 12, 11, [10])
	var report: MoveReport = move(state, 11, 5)  # 8,9,10,11,12 -> 중간에 4개
	check_eq(report.leapfrog_bonus, GameEnums.LEAPFROG_MAX, "최대 +3칸")
	check(not report.ability_notes.is_empty() and str(report.ability_notes).contains("점프 부스트"), "점프 부스트 안내")


func test_the_destination_tile_does_not_count_as_stepped_over() -> void:
	var state: GameState = _boost_state()
	place(state, 11, 12, [11])
	place(state, 21, 15, [14])
	var report: MoveReport = move(state, 11, 3)
	check_eq(report.leapfrog_bonus, 0, "도착 칸의 말은 밟고 지나가는 게 아니다")
	check(not state.get_pawn(21).has_left_start, "도착 칸의 적은 평소처럼 잡는다")


func test_leapfrog_kills_at_the_dice_landing_first_then_jumps_on() -> void:
	# 이동 4단계: 눈금 이동(14~16) -> 도착 칸(16)의 적 처치 판정 -> 그 자리에서 점프 부스트 +1칸 (17)
	# 16번은 옷장이지만 경유지라 워프하지 않는다 (도착 정산은 최종 도착 칸에서만)
	var state: GameState = _boost_state()
	place(state, 11, 13, [12])
	place(state, 12, 14, [13])  # 밟고 지나갈 아군
	place(state, 21, 16, [15])  # 눈금 도착 칸의 적
	var order: Array = []
	state.pawn_sent_to_start.connect(func(pawn_id: int, _by: int) -> void: order.append(["kill", pawn_id]))
	state.leapfrog_boosted.connect(func(pawn_id: int, waypoint: int, bonus: int) -> void: order.append(["leap", pawn_id, waypoint, bonus]))
	state.pawn_stepped.connect(func(_pawn_id: int, _from: int, to: int) -> void: order.append(["step", to]))
	var report: MoveReport = move(state, 11, 3)
	check(not state.get_pawn(21).has_left_start, "눈금 도착 칸의 적을 먼저 잡는다")
	check_eq(state.get_pawn(11).current_tile_idx, 17, "그 뒤 +1칸 더 간다 (경유지 옷장은 타지 않는다)")
	check_eq(report.leapfrog_bonus, 1, "점프 부스트 기록")
	check_eq(order, [["step", 14], ["step", 15], ["step", 16], ["kill", 21], ["leap", 11, 16, 1], ["step", 17]], "눈금 이동 -> 처치 -> 점프 부스트 -> 추가 이동 순서 (%s)" % str(order))


func test_leapfrog_landing_can_capture_again() -> void:
	var state: GameState = _boost_state()
	place(state, 11, 13, [12])
	place(state, 12, 14, [13])
	place(state, 21, 17, [16])  # 점프 부스트로 도착할 칸의 적
	move(state, 11, 3)
	check_eq(state.get_pawn(11).current_tile_idx, 17, "점프 부스트 도착")
	check(not state.get_pawn(21).has_left_start, "추가 이동 도착 칸에서도 처치 판정")


func test_leapfrog_is_included_in_the_move_preview() -> void:
	var state: GameState = _boost_state()
	place(state, 11, 12, [11])
	place(state, 21, 13, [12])
	check_eq(MoveExecutor.preview_path(state, state.get_pawn(11), 3).size(), 4, "미리보기도 +1칸")


# --- 🔥 리벤지 부스터 ---------------------------------------------------------------

func test_a_captured_pawn_gets_a_revenge_boost_and_adds_four_on_its_next_start() -> void:
	var state: GameState = _boost_state()
	place(state, 11, 8, [7])
	place(state, 21, 10, [9])
	move(state, 11, 2)  # 10번에서 21 처치
	var victim: PlayerPawn = state.get_pawn(21)
	check(not victim.has_left_start and victim.revenge_boost, "잡힌 말은 복수 부스터를 얻는다")
	check_eq(MoveExecutor.preview_path(state, victim, 3).size(), 7, "미리보기에 +4칸이 보인다")
	var report: MoveReport = move(state, 21, 3)
	check_eq(victim.current_tile_idx, 7, "출발 눈금 3 + 복수 부스터 4 = 7칸")
	check(not victim.revenge_boost and victim.has_left_start, "한 번 쓰면 사라진다")
	check(str(report.ability_notes).contains("복수 부스터"), "안내 문구")
	place(state, 22, 0, [], false)
	check_eq(move(state, 22, 3).path.size(), 3, "복수 부스터가 없는 말은 평범하게 출발")


func test_a_pawn_still_on_the_start_line_gets_no_revenge_boost() -> void:
	var state: GameState = _boost_state()
	var waiting: PlayerPawn = state.get_pawn(21)
	state.send_to_start(waiting, 1)
	check(not waiting.revenge_boost, "보드에 나온 적 없는 말은 해당 없음")


func test_revenge_boost_does_nothing_when_gimmicks_are_off() -> void:
	var state: GameState = make_state(2, 1)
	place(state, 21, 9, [8])
	state.send_to_start(state.get_pawn(21), 1)
	check_eq(move(state, 21, 3).path.size(), 3, "스위치를 끄면 +4칸이 붙지 않는다")


# --- 효과로 전진시키기 / 후퇴 삭제 -------------------------------------------------------

func test_forced_advance_runs_the_normal_move_rules() -> void:
	var state: GameState = _boost_state()
	place(state, 11, 1, [0])
	place(state, 21, 5, [4])
	var report: MoveReport = MoveExecutor.forced_advance(state, state.get_pawn(11), 4)
	check_eq(state.get_pawn(11).current_tile_idx, 5, "4칸 전진 (1 -> 5)")
	check(report.captured_pawn_ids.has(21), "착지 지점의 적을 잡는다")


func test_negative_dice_values_are_clamped_to_zero() -> void:
	var state: GameState = _boost_state()
	place(state, 11, 8, [7])
	var report: MoveReport = move(state, 11, -4)
	check(report.path.is_empty() and state.get_pawn(11).current_tile_idx == 8, "후퇴 눈금은 0칸")

func test_tower_scatters_only_forward() -> void:
	var state: GameState = make_state()
	check_eq(TarotEffects.tower_scatter_tiles(state, 8), int_array([9, 10]), "탑은 앞쪽 1~2칸으로만 흩는다")
	check_eq(TarotEffects.tower_scatter_tiles(state, 22), int_array([23]), "결승선 앞에서는 23번뿐")


func test_a_waiting_pawn_keeps_its_revenge_boost_when_sent_to_start_again() -> void:
	var state: GameState = _boost_state()
	place(state, 21, 9, [8])
	state.send_to_start(state.get_pawn(21), 1)
	state.send_to_start(state.get_pawn(21), 1)
	check(state.get_pawn(21).revenge_boost, "이미 켜진 복수 부스터는 유지")


func test_revenge_boost_announces_base_bonus_and_total_once_on_the_first_step() -> void:
	var state: GameState = _boost_state()
	var pawn: PlayerPawn = state.get_pawn(11)
	pawn.revenge_boost = true
	var fired: Array = []
	state.revenge_boost_fired.connect(func(pawn_id: int, base: int, bonus: int, total: int) -> void: fired.append([pawn_id, base, bonus, total]))
	var first_step: Array = []
	state.pawn_stepped.connect(func(pawn_id: int, _from: int, to: int) -> void:
		if first_step.is_empty():
			first_step.append([fired.size(), to]))
	var report: MoveReport = MoveExecutor.forced_advance(state, pawn, 3)
	check_eq(fired.size(), 1, "발동 신호는 한 번")
	check_eq(fired[0], [11, 3, GameEnums.REVENGE_BONUS, 3 + GameEnums.REVENGE_BONUS], "기본 눈금·부스터·총 칸수")
	check_eq(first_step[0][0], 1, "신호는 첫 걸음보다 먼저 온다")
	check_eq(report.revenge_bonus, GameEnums.REVENGE_BONUS, "보고서에 부스터 기록")
	check(not pawn.revenge_boost, "부스터는 출발과 함께 사라진다")
	MoveExecutor.forced_advance(state, pawn, 2)
	check_eq(fired.size(), 1, "이미 출발한 말의 다음 이동에서는 발동하지 않는다")
