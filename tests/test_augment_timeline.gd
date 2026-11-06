# File: res://tests/test_augment_timeline.gd
# Class: class_name TestAugmentTimeline
# Role: 증강 타임라인(AugmentTimeline)의 계산 검증 - 어느 라운드가 증강인가(1·4·7·10…), 초증강·법전이 섞이는 라운드(7부터), 왼쪽 글의 종류, 라운드 시작 사전 예고
class_name TestAugmentTimeline
extends TestCase


func test_draft_rounds_are_1_then_every_three() -> void:
	var drafts: Array[int] = []
	for round_number: int in range(1, 26):
		if AugmentTimeline.is_draft_round(round_number):
			drafts.append(round_number)
	check_eq(drafts, [1, 4, 7, 10, 13, 16, 19, 22, 25] as Array[int], "증강 라운드는 1라운드와 그 뒤 3라운드마다")


func test_super_augments_mix_in_from_round_seven() -> void:
	check(not AugmentTimeline.is_super_round(1) and not AugmentTimeline.is_super_round(4), "1·4라운드는 초증강이 섞이지 않는다")
	check(AugmentTimeline.is_super_round(7) and AugmentTimeline.is_super_round(10), "7라운드부터는 초증강·법전까지 섞인다")
	check(not AugmentTimeline.is_super_round(8), "증강 라운드가 아니면 별 표시가 없다")


func test_entries_keep_the_current_round_centered_at_both_edges() -> void:
	var list: Array[Dictionary] = AugmentTimeline.entries(3, 25)
	check_eq(list.size(), 5, "칩은 현재 라운드 포함 다섯 개")
	check_eq(list.map(func(entry: Dictionary) -> int: return entry["round"]), [1, 2, 3, 4, 5], "현재 라운드 앞뒤로 두 칸씩 표시")
	check(bool(list[2]["current"]) and not bool(list[1]["current"]) and not bool(list[3]["current"]), "가운데 칸만 current")
	check(bool(list[3]["draft"]) and int(list[3]["round"]) == 4, "4라운드 칩은 증강")
	var start: Array[Dictionary] = AugmentTimeline.entries(1, 25)
	check(not start[0]["available"] and not start[1]["available"] and start[2]["available"], "1라운드 왼쪽은 빈칸")
	var near_end: Array[Dictionary] = AugmentTimeline.entries(24, 25)
	check(near_end.size() == 5 and near_end[3]["available"] and not near_end[4]["available"], "상한 뒤 라운드는 번호 없는 칸")


func test_caption_counts_rounds_until_the_next_augment() -> void:
	check_eq(AugmentTimeline.caption_for(1, true, 25)["kind"], &"now", "1라운드 증강을 고르는 중이면 [이번 라운드 증강!]")
	var after_pick: Dictionary = AugmentTimeline.caption_for(1, false, 25)
	check_eq(after_pick["kind"], &"later", "1라운드 증강을 고른 뒤에는 다음 증강(4라운드)을 센다")
	check_eq(int(after_pick["rounds"]), 3, "1라운드 -> 4라운드는 3라운드 뒤")
	check_eq(AugmentTimeline.caption_for(3, false, 25)["kind"], &"soon", "다음 라운드가 증강이면 [다음 라운드 증강!]")
	check_eq(AugmentTimeline.caption_for(5, false, 25)["kind"], &"later", "5라운드는 7라운드까지 2라운드 뒤")
	check_eq(AugmentTimeline.caption_for(25, false, 25)["kind"], &"none", "상한 라운드를 넘으면 남은 증강이 없다")


func test_warning_appears_only_the_round_before_an_augment() -> void:
	var warned: Array[int] = []
	for round_number: int in range(1, 26):
		if AugmentTimeline.warns_next_round(round_number, 25):
			warned.append(round_number)
	check_eq(warned, [3, 6, 9, 12, 15, 18, 21, 24] as Array[int], "증강 한 라운드 전(3·6·9…)에만 사전 예고")
	check(not AugmentTimeline.warns_next_round(25, 25), "상한 라운드 뒤에는 예고하지 않는다")
