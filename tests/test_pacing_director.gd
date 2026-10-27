# File: res://tests/test_pacing_director.gd
# Class: class_name TestPacingDirector
# Role: 🕵️ 히든 페이싱 디렉터: 난이도별 눈금 보정이 도구의 실제 굴림 결과만 돌려주는지, 끄면 그대로인지, 서든데스·20라운드 상한·
#       잡힌 말 추격 표시·컴퓨터 법전 브레이크가 동작하는지 검사한다.
class_name TestPacingDirector
extends TestCase


func _state(pacing_level: int, round_number: int = 1) -> GameState:
	var state := GameState.new()
	state.match_rules = MatchRules.for_difficulty(pacing_level) if pacing_level > 0 else MatchRules.defaults()
	state.setup([1, 2, 3, 4] as Array[int], 77)
	state.round_number = round_number
	return state


## n번 굴려 눈금별 횟수를 센다.
func _histogram(state: GameState, tool: BaseJudgmentTool, n: int = 3000) -> Dictionary:
	var counts: Dictionary = {}
	for i: int in n:
		var result: RollResult = PacingDirector.adjust(state, 1, tool, tool.roll(state.rng))
		var steps: int = 0 if result.ends_turn else result.steps
		counts[steps] = int(counts.get(steps, 0)) + 1
	return counts


func _share(counts: Dictionary, predicate: Callable) -> float:
	var hit: int = 0
	var total: int = 0
	for steps: int in counts:
		total += int(counts[steps])
		if predicate.call(steps):
			hit += int(counts[steps])
	return float(hit) / float(maxi(total, 1))


func test_rules_turn_pacing_on_only_for_single_difficulty() -> void:
	check_eq(MatchRules.defaults()["pacing"], 0, "친선전·기본 규칙은 히든 보정 없음")
	for level: int in [1, 2, 3, 4, 5]:
		check_eq(MatchRules.for_difficulty(level)["pacing"], level, "Lv.%d 싱글은 같은 단계의 히든 보정" % level)
	check_eq(MatchRules.sanitize({"pacing": 9})["pacing"], 5, "밖에서 온 값은 0~5로 고친다")


func test_off_leaves_the_roll_alone_and_results_stay_real_tool_rolls() -> void:
	var off: GameState = _state(0, 16)
	var low: float = _share(_histogram(off, ToolDiceD6.new()), func(s: int) -> bool: return s <= 2)
	check(low > 0.28 and low < 0.39, "끄면 1~2가 1/3 그대로 (%.2f)" % low)
	var cream: GameState = _state(1)
	var counts: Dictionary = _histogram(cream, ToolDiceD6.new())
	for steps: int in counts:
		check(steps >= 1 and steps <= 6, "보정해도 주사위가 실제로 굴린 1~6만 나온다 (%d)" % steps)


func test_cream_helps_only_the_human_and_more_with_finished_pawns() -> void:
	var state: GameState = _state(1)
	var bot_high: float = _share(_histogram(state, ToolDiceD6.new()), func(s: int) -> bool: return s >= 4)
	check(bot_high > 0.43 and bot_high < 0.57, "크림: 컴퓨터는 보정 없음 (%.2f)" % bot_high)
	state.pacing_humans = [1] as Array[int]
	var base_high: float = _share(_histogram(state, ToolDiceD6.new()), func(s: int) -> bool: return s >= 5)
	var expected: float = 1.0 / 3.0 + 2.0 / 3.0 * PacingDirector.CREAM_HIGH_BASE
	check(base_high > expected - 0.05 and base_high < expected + 0.05, "크림: 사람은 5칸 이상이 더 자주 (%.2f)" % base_high)
	var before: float = PacingDirector.cream_high_chance(state, 1)
	var pawns: Array = state.pawns_of(1)
	(pawns[0] as PlayerPawn).is_finished = true
	(pawns[1] as PlayerPawn).is_finished = true
	check(PacingDirector.cream_high_chance(state, 1) > before and PacingDirector.cream_high_chance(state, 1) <= PacingDirector.CREAM_HIGH_MAX, "완주 2개 + 컴퓨터보다 먼저 완주: 확률이 더 오른다 (상한까지)")
	var later_high: float = _share(_histogram(state, ToolDiceD6.new()), func(s: int) -> bool: return s >= 5)
	check(later_high > base_high + 0.015, "완주할수록 고눈금이 더 자주 (%.2f → %.2f)" % [base_high, later_high])

func test_cream_dodges_turn_ends_more_after_each_hit() -> void:
	var state: GameState = _state(1)
	state.pacing_humans = [1] as Array[int]
	var yut := ToolYut.new()
	var ends: int = 0
	var first_hits: int = -1
	for i: int in 4000:
		var result: RollResult = PacingDirector.adjust(state, 1, yut, yut.roll(state.rng))
		if result.ends_turn:
			ends += 1
	var off: GameState = _state(0)
	var off_ends: int = 0
	for i: int in 4000:
		if yut.roll(off.rng).ends_turn:
			off_ends += 1
	check(off_ends > 0 and ends * 2 < off_ends, "크림: 턴 종료(낙)가 크게 줄어든다 (%d → %d)" % [off_ends, ends])
	check(int(state.pacing_turn_ends.get(1, 0)) == ends, "당한 턴 종료를 센다")
	var fresh: GameState = _state(1)
	fresh.pacing_humans = [1] as Array[int]
	fresh.pacing_turn_ends[1] = 3
	first_hits = 0
	for i: int in 4000:
		if PacingDirector.adjust(fresh, 1, yut, yut.roll(fresh.rng)).ends_turn:
			first_hits += 1
	check(first_hits < ends, "턴 종료를 당할수록 다음 턴 종료는 더 잘 피한다 (%d < %d)" % [first_hits, ends])


func test_cream_boosts_a_law_that_would_win_right_away() -> void:
	var state: GameState = _state(1, 7)
	state.pacing_humans = [1] as Array[int]
	var arena: AugmentDef = AugmentRegistry.get_def(&"AUG_LAW_01")
	check_eq(AugmentRegistry.effective_weight(arena, state, 1), 0.0, "크림 기본: 법전은 나오지 않는다")
	# 커스텀으로 쉬운 법전 2종을 켰을 때만 이 보정이 작동한다
	state.match_rules["laws"] = true
	state.match_rules["law_pool"] = MatchRules.EASY_LAWS.duplicate()
	var before: float = AugmentRegistry.effective_weight(arena, state, 1)
	check(before > 0.0, "법전을 켠 크림: 투기장의 지배자는 나온다")
	check(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"AUG_LAW_03"), state, 1) == 0.0, "크림: 다른 법전은 안 나온다")
	state.law_stats[1] = {VictoryLaw.KILLS: (LawRegistry.create("LAW_01") as VictoryLaw).goal()}
	check_eq(AugmentRegistry.effective_weight(arena, state, 1), before * PacingDirector.CREAM_WINNING_LAW_FACTOR, "고르면 바로 이기는 법전은 가중치 대폭 상승")
	check_eq(AugmentRegistry.effective_weight(arena, state, 2), before, "컴퓨터 자리는 그대로")


func test_mid_levels_ramp_up_after_round_eleven() -> void:
	var early_state: GameState = _state(2, 10)
	early_state.pacing_humans = [1] as Array[int]
	var late_state: GameState = _state(2, 14)
	late_state.pacing_humans = [1] as Array[int]
	var early: float = _share(_histogram(early_state, ToolDiceD6.new()), func(s: int) -> bool: return s >= 4)
	var late: float = _share(_histogram(late_state, ToolDiceD6.new()), func(s: int) -> bool: return s >= 4)
	check(early > 0.43 and early < 0.57, "Lv.2 10라운드까지는 기본 확률 (%.2f)" % early)
	check(late > 0.75, "Lv.2 14라운드: 고눈금이 점점 늘어난다 (%.2f)" % late)
	var bot: float = _share(_histogram(_state(2, 16), ToolDiceD6.new()), func(s: int) -> bool: return s >= 4)
	check(bot > 0.43 and bot < 0.57, "Lv.2: 컴퓨터 자리는 서든데스까지 보정 없음 (%.2f)" % bot)
	var lv3_bot: float = _share(_histogram(_state(3, 14), ToolDiceD6.new()), func(s: int) -> bool: return s >= 4)
	check(lv3_bot > 0.75, "Lv.3부터는 컴퓨터도 같은 보정 (%.2f)" % lv3_bot)


func test_high_levels_help_captured_pawns_until_halfway() -> void:
	var state: GameState = _state(4, 5)
	var plain: float = _share(_histogram(state, ToolDiceD6.new()), func(s: int) -> bool: return s >= 5)
	check(plain < 0.4, "잡힌 말이 없으면 기본 확률 (%.2f)" % plain)
	var pawn: PlayerPawn = state.get_pawn(11)
	place(state, 11, 5)
	state.send_to_start(pawn, 2)
	check(pawn.comeback_run, "잡혀서 출발선으로 간 말은 추격 표시")
	var boosted: float = _share(_histogram(state, ToolDiceD6.new()), func(s: int) -> bool: return s >= 5)
	check(boosted > 0.6, "Lv.4: 다시 출발한 말이 있으면 5~6칸이 크게 늘어난다 (%.2f)" % boosted)
	place(state, 11, BoardSpec.halfway_tile)
	check(not PacingDirector.has_comeback(state, 1) and not pawn.comeback_run, "반환점에 닿으면 추격 표시가 지워진다")


func test_sudden_death_from_round_fifteen() -> void:
	var low: float = _share(_histogram(_state(3, 15), ToolDiceD6.new()), func(s: int) -> bool: return s < 4)
	check(low < 0.01, "15라운드부터 모두 4칸 이상 수준 (%.3f)" % low)


func test_stateful_tools_are_never_rerolled() -> void:
	var state: GameState = _state(1, 16)
	var yacht := ToolYacht.new()
	var first: RollResult = yacht.roll(state.rng)
	check(PacingDirector.adjust(state, 1, yacht, first) == first, "야추처럼 이어 굴리는 도구는 그대로")


func test_round_cap_ends_the_game_by_race_order() -> void:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	manager.match_rules = MatchRules.for_difficulty(3)
	manager.start_game([1, 2, 3, 4] as Array[int], 99)
	manager.state.round_number = PacingDirector.HARD_CAP_ROUND + 1
	manager._enter_round_start()
	check(manager.is_game_over, "20라운드가 끝나면 판이 끝난다")
	check_eq(manager.state.rankings.size(), 4, "남은 사람 모두 진행 순위로 확정")
	check_eq(manager.state.rank_reasons[manager.state.rankings[3]], VictoryChecker.LAST_PLACE, "맨 뒤 한 명은 꼴찌")
	tree.root.remove_child(manager)
	manager.free()


func test_bot_law_brake_before_round_eleven() -> void:
	var state: GameState = _state(3, 8)
	state.rulebook.enqueue_law(LawRegistry.create("LAW_01"))
	var law: VictoryLaw = state.rulebook.active_laws_queue[0]
	state.law_stats[1] = {VictoryLaw.KILLS: law.goal() - 1}
	check(PacingDirector.capture_would_win_law(state, 1, 2), "10라운드까지는 마지막 처치를 피한다")
	state.round_number = PacingDirector.LAW_BRAKE_BEFORE_ROUND
	check(not PacingDirector.capture_would_win_law(state, 1, 2), "11라운드부터는 브레이크가 풀린다")
	var off: GameState = _state(0, 8)
	off.rulebook.enqueue_law(LawRegistry.create("LAW_01"))
	off.law_stats[1] = {VictoryLaw.KILLS: law.goal() - 1}
	check(not PacingDirector.capture_would_win_law(off, 1, 2), "히든 보정이 꺼진 판(친선전)은 브레이크 없음")


func test_chain_rolls_get_rarer_after_each_extra_roll() -> void:
	var state: GameState = _state(0)
	var yut := ToolYut.new()
	var shares: Array[float] = []
	for chain: int in [0, 1, 2]:
		var extra: int = 0
		for i: int in 4000:
			if PacingDirector.damp_chain(state, yut, yut.roll(state.rng), chain).reroll:
				extra += 1
		shares.append(float(extra) / 4000.0)
	check(shares[0] > 0.25, "첫 굴림의 윷·모(추가 굴림)는 그대로 (%.2f)" % shares[0])
	check(shares[1] < shares[0] * 0.75 and shares[2] < shares[1] * 0.75, "추가 굴림을 얻을수록 또 얻을 확률이 줄어든다 (%s)" % str(shares))

