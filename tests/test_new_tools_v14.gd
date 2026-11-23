# File: res://tests/test_new_tools_v14.gd
# Class: class_name TestNewToolsV14
# Role: 새 판정 도구 2종 - 해적 룰렛(DICE_PIRATE: 칼마다 +2 누적, 8구멍 중 1개 해적 → 0칸·턴 종료, 7개 무사면 14칸 자동 확정)과
#       스크래치 복권(DICE_SCRATCH: 당첨 문양 3/2/1/0개 일치 12+한번더/5/1/0, 일치 칸이 황금이면 2배). 확률·결정성·봇·등록 검증.
class_name TestNewToolsV14
extends TestCase


func test_pirate_stacks_two_per_sword_and_pops() -> void:
	var tool := ToolPirateRoulette.new()
	var order: Array[int] = [3, 0, 5, 1, 7, 2, 6, 4]
	tool.arm(3, order)
	var rng := RandomNumberGenerator.new()
	for sword: int in 3:
		var result: RollResult = tool.roll(rng)
		check(result.can_continue and not result.ends_turn, "%d번째 칼은 무사하다" % (sword + 1))
		check_eq(result.steps, (sword + 1) * ToolPirateRoulette.STEPS_PER_SWORD, "칼마다 +2칸 누적")
		check_eq(result.details["holes"].size(), sword + 1, "꽂은 구멍 기록")
	check(tool.has_pending_state(), "누적이 있으면 멈출 수 있다")
	var popped: RollResult = tool.roll(rng)
	check(popped.ends_turn and popped.steps == 0 and bool(popped.details["popped"]), "4번째(해적 구멍)는 0칸 + 턴 종료")
	check_eq(int(popped.details["lost"]), 6, "누적 6칸이 사라진다")
	check(not tool.has_pending_state(), "터지면 통이 비워진다")


func test_pirate_cash_out_and_full_barrel() -> void:
	var tool := ToolPirateRoulette.new()
	var rng := RandomNumberGenerator.new()
	tool.arm(5)
	tool.roll(rng)
	tool.roll(rng)
	var stop: RollResult = tool.cash_out()
	check(stop != null and stop.steps == 4 and bool(stop.details["voluntary"]) and not stop.can_continue, "멈추면 누적 4칸 확정")
	check(tool.cash_out() == null, "확정 뒤에는 멈출 것이 없다")
	tool.arm(ToolPirateRoulette.HOLES - 1)
	var last: RollResult = null
	for _sword: int in ToolPirateRoulette.HOLES - 1:
		last = tool.roll(rng)
	check(last != null and not last.can_continue and last.steps == ToolPirateRoulette.MAX_STEPS and bool(last.details["full"]), "7개 모두 무사하면 14칸 자동 확정")


func test_pirate_pop_position_is_uniform_and_deterministic() -> void:
	var counts: Array[int] = []
	counts.resize(ToolPirateRoulette.HOLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for _game: int in 4000:
		var tool := ToolPirateRoulette.new()
		var swords: int = 0
		while true:
			var result: RollResult = tool.roll(rng)
			if result.ends_turn:
				break
			swords += 1
			if not result.can_continue:
				break  # 7개 모두 무사 (해적은 마지막 8번째 구멍)
		counts[swords] += 1
	for index: int in counts.size():
		check(counts[index] > 350 and counts[index] < 650, "해적이 튀어나오는 순서는 고르다 (%d번째: %d)" % [index + 1, counts[index]])
	var a := RandomNumberGenerator.new()
	a.seed = 77
	var b := RandomNumberGenerator.new()
	b.seed = 77
	check_eq(ToolPirateRoulette.new().roll(a).to_dict(), ToolPirateRoulette.new().roll(b).to_dict(), "같은 시드면 같은 결과 (온라인 동기화)")


func test_bot_stops_pirate_after_three_or_four_swords() -> void:
	var tool := ToolPirateRoulette.new()
	tool.arm(7)
	var rng := RandomNumberGenerator.new()
	tool.roll(rng)
	tool.roll(rng)
	check(not BotBrain.should_stop_roulette(tool, 2), "칼 2개면 더 꽂는다")
	tool.roll(rng)
	check(BotBrain.should_stop_roulette(tool, 2), "목표 2면 칼 3개에서 멈춘다")
	check(not BotBrain.should_stop_roulette(tool, 3), "목표 3이면 칼 4개까지 꽂는다")


func test_scratch_payouts_and_golden_double() -> void:
	var none: Array[bool] = [false, false, false]
	check_eq(ToolScratchLottery.of_cells(0, [0, 0, 0] as Array[int], none).steps, 12, "3개 일치 12칸")
	check(ToolScratchLottery.of_cells(0, [0, 0, 0] as Array[int], none).reroll, "3개 일치는 한 번 더")
	check_eq(ToolScratchLottery.of_cells(1, [1, 2, 1] as Array[int], none).steps, 5, "2개 일치 5칸")
	check_eq(ToolScratchLottery.of_cells(2, [3, 2, 0] as Array[int], none).steps, 1, "1개 일치 1칸")
	check_eq(ToolScratchLottery.of_cells(3, [0, 1, 2] as Array[int], none).steps, 0, "꽝 0칸")
	check(not ToolScratchLottery.of_cells(1, [1, 2, 1] as Array[int], none).reroll, "2개 일치는 한 번 더 없음")
	var gold: RollResult = ToolScratchLottery.of_cells(0, [0, 0, 0] as Array[int], [false, true, false] as Array[bool])
	check(gold.steps == 24 and gold.reroll and bool(gold.details["golden"]), "황금 문양이 섞인 3개 일치는 24칸 + 한 번 더")
	check_eq(ToolScratchLottery.of_cells(2, [2, 1, 3] as Array[int], [true, false, false] as Array[bool]).steps, 2, "황금 1개 일치는 2칸")
	check_eq(ToolScratchLottery.of_cells(2, [2, 1, 3] as Array[int], [false, true, false] as Array[bool]).steps, 1, "황금이 당첨 문양 칸이 아니면 2배가 아니다")
	check(not ToolScratchLottery.of_cells(1, [0, 2, 3] as Array[int], [true, true, true] as Array[bool]).details["golden"], "꽝은 황금이 붙어도 0칸")


func test_scratch_odds_land_near_a_normal_die() -> void:
	var tool := ToolScratchLottery.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var counts: Array[int] = [0, 0, 0, 0]
	var golden: int = 0
	var total: int = 0
	var runs: int = 20000
	for _i: int in runs:
		var result: RollResult = tool.roll(rng)
		var matches: int = int(result.details["matches"])
		counts[matches] += 1
		total += result.steps
		golden += 1 if bool(result.details["golden"]) else 0
		check(not result.ends_turn, "턴 종료는 없다")
		for index: int in 3:
			var gold_cell: bool = (result.details["gold"] as Array)[index]
			check(not gold_cell or int((result.details["cells"] as Array)[index]) == int(result.details["winning"]), "황금은 당첨 문양 칸에만")
	var average: float = float(total) / float(runs)
	check(average > 3.0 and average < 4.2, "평균 칸수가 기본 주사위와 비슷하다 (%.2f)" % average)
	check(absf(counts[3] / float(runs) - 0.08) < 0.015, "3개 일치 약 8%% (%.3f)" % (counts[3] / float(runs)))
	check(absf(counts[0] / float(runs) - 0.19) < 0.02, "꽝 약 19%% (%.3f)" % (counts[0] / float(runs)))
	check(golden > runs / 20 and golden < runs / 6, "황금 2배는 가끔 (%d회)" % golden)


func test_registered_with_tables_art_and_presenter() -> void:
	for entry: Array in [[&"DICE_PIRATE", "해적 룰렛", ToolPirateRoulette], [&"DICE_SCRATCH", "스크래치 복권", ToolScratchLottery]]:
		var id: StringName = entry[0]
		check(ToolRegistry.ALL_IDS.has(id), "%s 도구 목록에 있다" % id)
		check(is_instance_of(ToolRegistry.create(id), entry[2]), "%s 생성된다" % id)
		check_eq(ToolRegistry.create(id).display_name, str(entry[1]), "표의 이름")
		check(AugmentRegistry.SWAPPABLE_TOOLS.has(id), "%s 교체 증강으로 고를 수 있다" % id)
		check(AugmentRegistry.get_def(StringName("TOOL_" + String(id))) != null, "%s 교체 증강 카드가 있다" % id)
		check(ResourceLoader.exists("res://content_trickcal/illustrations/dice/%s.png" % id), "%s 아이콘 그림이 있다" % id)
		check(RollPresenter.supports(id), "%s 굴림 연출이 있다" % id)
		check_eq(AugmentDef.tool_step_range(id).size(), 2, "%s 칸 범위 표" % id)
