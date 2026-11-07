# File: res://tests/test_augment_timeline.gd
# Class: class_name TestAugmentTimeline
# Role: 증강 타임라인(AugmentTimeline)의 계산 검증 - 어느 라운드가 증강인가(4·7·10…: 1~3라운드는 기본 규칙을 먼저 체험), 초증강·법전이 섞이는 라운드(7부터), 왼쪽 글의 종류, 라운드 시작 사전 예고
class_name TestAugmentTimeline
extends TestCase

## 실제 일정(첫 증강은 4라운드)으로 검증한다는 표시 (러너가 읽는다).
const REAL_DRAFT_SCHEDULE: bool = true


func test_draft_rounds_are_4_then_every_three() -> void:
	var drafts: Array[int] = []
	for round_number: int in range(1, 26):
		if AugmentTimeline.is_draft_round(round_number):
			drafts.append(round_number)
	check_eq(drafts, [4, 7, 10, 13, 16, 19, 22, 25] as Array[int], "증강 라운드는 4라운드와 그 뒤 3라운드마다 (1~3라운드는 증강 없이 기본 규칙 체험)")
	check(not AugmentTimeline.is_draft_round(1) and not AugmentTimeline.is_draft_round(2) and not AugmentTimeline.is_draft_round(3), "1~3라운드에는 증강이 없다")


func test_advanced_augments_mix_in_by_tempo_stage() -> void:
	check(not AugmentTimeline.is_super_round(1) and not AugmentTimeline.is_super_round(4), "1·4라운드는 초증강이 섞이지 않는다")
	check(not AugmentTimeline.is_super_round(7), "7라운드(템포 0)는 쉬운 증강만 섞인다")
	check(AugmentTimeline.is_super_round(10) and AugmentTimeline.is_super_round(16), "템포 1단계(8R)부터 고급 증강이 섞인 증강 라운드에 별 표시")
	check(not AugmentTimeline.is_super_round(8), "증강 라운드가 아니면 별 표시가 없다")


func test_entries_keep_the_current_round_centered_at_both_edges() -> void:
	var list: Array[Dictionary] = AugmentTimeline.entries(3, 25)
	check_eq(list.size(), 5, "칩은 현재 라운드 포함 다섯 개")
	check_eq(list.map(func(entry: Dictionary) -> int: return entry["round"]), [1, 2, 3, 4, 5], "현재 라운드 앞뒤로 두 칸씩 표시")
	check(bool(list[2]["current"]) and not bool(list[1]["current"]) and not bool(list[3]["current"]), "가운데 칸만 current")
	check(bool(list[3]["draft"]) and int(list[3]["round"]) == 4, "4라운드 칩은 증강")
	check(not bool(list[0]["draft"]) and not bool(list[1]["draft"]), "1·2라운드 칩은 증강이 아니다")
	var start: Array[Dictionary] = AugmentTimeline.entries(1, 25)
	check(not start[0]["available"] and not start[1]["available"] and start[2]["available"], "1라운드 왼쪽은 빈칸")
	var near_end: Array[Dictionary] = AugmentTimeline.entries(24, 25)
	check(near_end.size() == 5 and near_end[3]["available"] and not near_end[4]["available"], "상한 뒤 라운드는 번호 없는 칸")


func test_caption_counts_rounds_until_the_next_augment() -> void:
	var first: Dictionary = AugmentTimeline.caption_for(1, false, 25)
	check_eq(first["kind"], &"later", "1라운드에는 첫 증강(4라운드)이 아직 멀다")
	check_eq(int(first["rounds"]), 3, "1라운드 -> 4라운드는 3라운드 뒤")
	check_eq(AugmentTimeline.caption_for(3, false, 25)["kind"], &"soon", "다음 라운드가 증강이면 [다음 라운드 증강!]")
	check_eq(AugmentTimeline.caption_for(4, true, 25)["kind"], &"now", "4라운드 증강을 고르는 중이면 [이번 라운드 증강!]")
	var after_pick: Dictionary = AugmentTimeline.caption_for(4, false, 25)
	check_eq(after_pick["kind"], &"later", "4라운드 증강을 고른 뒤에는 다음 증강(7라운드)을 센다")
	check_eq(int(after_pick["rounds"]), 3, "4라운드 -> 7라운드는 3라운드 뒤")
	check_eq(AugmentTimeline.caption_for(5, false, 25)["kind"], &"later", "5라운드는 7라운드까지 2라운드 뒤")
	check_eq(AugmentTimeline.caption_for(25, false, 25)["kind"], &"none", "상한 라운드를 넘으면 남은 증강이 없다")


func test_warning_appears_only_the_round_before_an_augment() -> void:
	var warned: Array[int] = []
	for round_number: int in range(1, 26):
		if AugmentTimeline.warns_next_round(round_number, 25):
			warned.append(round_number)
	check_eq(warned, [3, 6, 9, 12, 15, 18, 21, 24] as Array[int], "증강 한 라운드 전(3·6·9…)에만 사전 예고")
	check(not AugmentTimeline.warns_next_round(25, 25), "상한 라운드 뒤에는 예고하지 않는다")


## 온보딩(2026-11): 1~3라운드는 증강 없이 바로 굴리고 움직일 수 있고, 첫 증강은 4라운드 시작에 열린다. 몇 번째 드래프트인지는 옛 일정 기준을 그대로 쓴다 (4라운드 = 2번째).
func test_first_draft_waits_until_round_four_and_numbers_stay() -> void:
	check_eq([AugmentRegistry.draft_number(1), AugmentRegistry.draft_number(3), AugmentRegistry.draft_number(4), AugmentRegistry.draft_number(7), AugmentRegistry.draft_number(10)], [0, 0, 2, 3, 4], "몇 번째 드래프트 (4라운드 = 2번째, 첫 드래프트 전은 0)")
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	tree.root.add_child(manager)
	manager.set_process(false)
	defer_free(manager)
	manager.start_game([1, 2, 3, 4] as Array[int], 2026)
	check_eq(manager.state.round_number, 1, "게임은 1라운드로 시작")
	check(manager.current_state != TurnManager.State.PHASE_ROUND_START and manager._draft_offers.is_empty(), "1라운드에는 증강 선택 없이 바로 턴이 시작된다")


## 이동 거리 계산식 말풍선 (2026-11): 눈금 + 보너스 내역을 한 줄로.
func test_move_breakdown_text_lists_every_bonus() -> void:
	check_eq(MainBoard.move_breakdown_text(5, ["복수 부스터 +4칸", "흑돌 홀수 +1칸"]), "총 10칸 이동 (기본 5 + 리벤지 부스터 4 + 흑돌 홀수 1)", "눈금 5 + 리벤지 4 + 흑돌 1")
	check_eq(MainBoard.move_breakdown_text(3, []), "총 3칸 이동", "보너스가 없으면 괄호 없이")
	check_eq(MainBoard.move_breakdown_text(4, ["점프 부스트! (+2칸)", "퀸 +2칸"]), "총 8칸 이동 (기본 4 + 점프 부스트 2 + 퀸 2)", "느낌표·괄호 표기도 읽는다")
	check_eq(MainBoard.move_breakdown_text(6, ["비숍 코너 진입 +1칸", "들이받힘"]), "총 7칸 이동 (기본 6 + 비숍 코너 진입 1)", "칸 수가 없는 능력 문구는 건너뛴다")
	check_eq(MainBoard.move_breakdown_text(5, ["복수 부스터 +4칸"], 7), "총 7칸 이동 (기본 5 + 리벤지 부스터 4)", "실제 경로가 짧으면(결승선 등) 총합을 그 칸수로")
