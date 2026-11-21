# File: res://tests/test_fortune_cookie.gd
# Class: class_name TestFortuneCookie
# Role: 포츈쿠키(DICE_COOKIE) - 종이표 확률·칸수·글 구성, 도구 목록·교체 증강 등록, 결과가 판정 엔진 규칙(한 번 더·턴 종료 없음)에 맞는지 검증
class_name TestFortuneCookie
extends TestCase


func test_paper_table_adds_up_and_has_a_text_for_every_result() -> void:
	var total: int = 0
	var average: float = 0.0
	for entry: Array in ToolFortuneCookie.PAPERS:
		total += int(entry[1])
		average += float(entry[0]) * float(entry[1]) / 100.0
		check(str(entry[2]).strip_edges() != "", "%d칸 종이에는 글이 있다" % int(entry[0]))
	check_eq(total, 100, "가중치 합 100")
	check(average > 3.3 and average < 4.1, "평균 이동 칸수가 다른 도구와 비슷하다 (%.2f)" % average)


func test_every_roll_matches_its_paper_and_has_no_side_effects() -> void:
	var tool := ToolFortuneCookie.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var seen: Dictionary = {}
	for i: int in 2000:
		var result: RollResult = tool.roll(rng)
		check(result.steps >= 1 and result.steps <= 8 and result.steps != 7, "1~6칸 또는 8칸 (%d)" % result.steps)
		check(not result.reroll and not result.ends_turn, "한 번 더·턴 종료가 없다")
		check_eq(str(result.details["message"]).is_empty(), false, "종이에 글이 있다")
		check_eq(bool(result.details["jackpot"]), result.steps == ToolFortuneCookie.JACKPOT_STEPS, "8칸만 대박")
		seen[result.steps] = true
	check_eq(seen.size(), ToolFortuneCookie.PAPERS.size(), "2000번 중 모든 칸수가 나온다")


func test_registered_as_a_swappable_tool_with_art_and_table_rows() -> void:
	check(ToolRegistry.ALL_IDS.has(&"DICE_COOKIE"), "도구 목록에 있다")
	check(ToolRegistry.create(&"DICE_COOKIE") is ToolFortuneCookie, "생성된다")
	check(AugmentRegistry.SWAPPABLE_TOOLS.has(&"DICE_COOKIE"), "교체 증강으로 고를 수 있다")
	check(AugmentRegistry.get_def(&"TOOL_DICE_COOKIE") != null, "교체 증강 카드가 있다")
	check_eq(ToolRegistry.create(&"DICE_COOKIE").display_name, "포츈쿠키", "표의 이름")
	check(ResourceLoader.exists("res://content_trickcal/illustrations/dice/DICE_COOKIE.png"), "아이콘 그림이 있다")
	check(RollPresenter.supports(&"DICE_COOKIE"), "굴림 연출이 있다")
