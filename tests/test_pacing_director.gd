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


func test_cream_rerolls_low_rolls() -> void:
	var low: float = _share(_histogram(_state(1), ToolDiceD6.new()), func(s: int) -> bool: return s <= 2)
	check(low < 0.15, "Lv.1: 1~2칸은 75%%가 다시 굴려져 드물다 (%.2f)" % low)


func test_mid_levels_ramp_up_after_round_eleven() -> void:
	var early: float = _share(_histogram(_state(2, 10), ToolDiceD6.new()), func(s: int) -> bool: return s >= 4)
	var late: float = _share(_histogram(_state(2, 14), ToolDiceD6.new()), func(s: int) -> bool: return s >= 4)
	check(early > 0.43 and early < 0.57, "Lv.2 10라운드까지는 기본 확률 (%.2f)" % early)
	check(late > 0.75, "Lv.2 14라운드: 고눈금이 점점 늘어난다 (%.2f)" % late)


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
