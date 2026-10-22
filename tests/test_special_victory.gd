# File: res://tests/test_special_victory.gd
# Class: class_name TestSpecialVictory
# Role: 🏆 중앙 법전의 특수 승리 교칙 8종 - 기록 집계, 달성 판정, 달성 시 졸업과 교칙 삭제, 진행도 툴팁 데이터 검증
class_name TestSpecialVictory
extends TestCase


func _law(id: String) -> VictoryLaw:
	return LawRegistry.create(id) as VictoryLaw


func _new_manager(player_count: int = 4) -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	var ids: Array[int] = []
	for i: int in range(1, player_count + 1):
		ids.append(i)
	manager.start_game(ids, 4242)
	return manager


## 이번 라운드를 끝까지 넘긴다 (특수 승리는 라운드가 끝나기 직전에 판정한다).
func _finish_round(manager: TurnManager) -> void:
	var start_round: int = manager.state.round_number
	var guard: int = 0
	while manager.state.round_number == start_round and not manager.is_game_over and guard < 300:
		manager.force_timeout()
		guard += 1


func _dispose(manager: TurnManager) -> void:
	tree.root.remove_child(manager)
	manager.free()


func test_registry_makes_eight_victory_laws_with_table_goals() -> void:
	var goals: Array[int] = []
	for id: String in LawRegistry.ALL_IDS:
		var law: VictoryLaw = _law(id)
		check(law != null and law.trigger_timing == "", "%s는 판을 변조하지 않는 특수 승리 교칙" % id)
		goals.append(law.goal())
	check_eq(goals, int_array([6, 5, 5, 16, 4, 8, 4, 3]), "표의 목표 수치")
	check_eq(_law("LAW_01").law_name, "투기장의 지배자", "이름")
	check_eq(_law("LAW_05").condition_text(), "말 4개 모두 트랙 위에서 서로 3칸 이상 간격", "조건 문구")


func test_kills_and_ejections_are_counted_from_captures() -> void:
	var state := make_state()
	place(state, 11, 2, [1])
	place(state, 21, 4, [3])
	move(state, 11, 2)
	check_eq(state.stat(1, VictoryLaw.KILLS), 1, "적 처치 1회")
	check_eq(state.stat(2, VictoryLaw.EJECTED), 1, "사출 1회")
	state.send_to_start(state.get_pawn(11), 1)  # 자기 말을 스스로 보내면 처치가 아니다
	check_eq(state.stat(1, VictoryLaw.KILLS), 1, "자폭은 처치가 아니다")
	check_eq(state.stat(1, VictoryLaw.EJECTED), 1, "그래도 사출은 센다")
	state.send_to_start(state.get_pawn(12), 2)
	check_eq(state.stat(1, VictoryLaw.EJECTED), 1, "출발선에 있던 말은 사출로 세지 않는다")


func test_arena_master_graduates_the_killer_and_removes_the_law() -> void:
	var manager: TurnManager = _new_manager(3)
	var state: GameState = manager.state
	add_law(state, "LAW_01")
	add_law(state, "LAW_06")
	state.law_stats[1] = {VictoryLaw.KILLS: 5}
	place(state, 11, 2, [1])
	place(state, 21, 4, [3])
	manager.state.tools[1] = ScriptedTool.new([2])
	manager.act(&"proceed", {"player_id": 1})
	manager.act(&"roll", {"player_id": 1})
	manager.act(&"select_pawn", {"player_id": 1, "pawn_id": 11})
	check_eq(state.stat(1, VictoryLaw.KILLS), 6, "6번째 처치")
	check(state.rankings.is_empty(), "달성해도 바로 졸업하지 않는다 (라운드 끝에 판정)")
	_finish_round(manager)
	check_eq(state.rankings, int_array([1]), "라운드가 끝나기 직전에 6처치 확인 -> 1위 졸업")
	check_eq(state.rank_reasons[1], &"LAW_01", "사유는 교칙 ID")
	check(not state.rulebook.has_law("LAW_01"), "달성된 교칙은 법전에서 삭제")
	check(state.rulebook.has_law("LAW_06"), "다른 교칙은 남는다")
	check(not manager.is_game_over, "3인 판은 계속된다")
	check_eq(VictoryChecker.reason_text(&"LAW_01"), "특수 승리 (투기장의 지배자)", "결과 문구")
	_dispose(manager)


func test_hand_law_is_checked_when_my_turn_starts() -> void:
	var manager: TurnManager = _new_manager(3)
	var state: GameState = manager.state
	add_law(state, "LAW_02")
	for i: int in 5:
		state.give_card(2, &"ACT_04")
	check(not state.is_graduated(2), "남의 턴에 카드가 쌓여도 아직")
	manager.state.tools[1] = ScriptedTool.new([1])
	manager.act(&"proceed", {"player_id": 1})
	manager.act(&"roll", {"player_id": 1})
	manager.act(&"select_pawn", {"player_id": 1, "pawn_id": 11})
	check(state.rankings.is_empty() and state.current_player == 2, "P2 턴 시작에 손패 5장이 기록되지만 아직 졸업하지 않는다")
	_finish_round(manager)
	check_eq(state.rankings, int_array([2]), "라운드 끝 판정에서 P2 졸업")
	_dispose(manager)


func test_estate_counts_my_hotels_and_traps_on_the_board() -> void:
	var state := make_state()
	add_law(state, "LAW_03")
	for tile: int in [3, 5, 7, 9]:
		state.place_attachment(tile, TrapDomino.new(1))
	check_eq(_law("LAW_03").progress(state, 1), 4, "설치물 4개")
	check(SpecialVictory.achieved_by(state, 1) == &"", "아직 4/5")
	state.place_attachment(11, TrapDomino.new(1))
	check_eq(SpecialVictory.achieved_by(state, 1), &"LAW_03", "5개 -> 달성")
	check(SpecialVictory.achieved_by(state, 2) == &"", "상대는 0개")


func test_one_shot_move_and_roll_chain_count_only_while_the_law_is_on_the_board() -> void:
	var state := make_state()
	SpecialVictory.note_session(state, 1, VictoryLaw.BEST_MOVE, 20)
	check_eq(state.stat(1, VictoryLaw.BEST_MOVE), 0, "교칙이 없으면 세지 않는다")
	AugmentRegistry.get_def(&"AUG_LAW_04").apply(state, 1)
	SpecialVictory.note_session(state, 1, VictoryLaw.BEST_MOVE, 12)
	SpecialVictory.note_session(state, 1, VictoryLaw.BEST_MOVE, 9)
	check_eq(state.stat(1, VictoryLaw.BEST_MOVE), 12, "최고 기록")
	SpecialVictory.note_session(state, 2, VictoryLaw.BEST_MOVE, 16)
	check_eq(SpecialVictory.achieved_by(state, 2), &"LAW_04", "16칸 한 방")
	state.rulebook.remove_law_by_id("LAW_04")
	AugmentRegistry.get_def(&"AUG_LAW_04").apply(state, 1)
	check_eq(state.stat(1, VictoryLaw.BEST_MOVE), 0, "다시 제정되면 0부터")


func test_roll_chain_is_recorded_by_the_turn_manager() -> void:
	var manager: TurnManager = _new_manager(2)
	add_law(manager.state, "LAW_07")
	manager.state.tools[1] = ScriptedTool.new([ScriptedTool.reroll_of(4), ScriptedTool.reroll_of(4), ScriptedTool.reroll_of(4), 2])
	manager.act(&"proceed", {"player_id": 1})
	for i: int in 4:
		manager.act(&"roll", {"player_id": 1})
	check_eq(manager.state.stat(1, VictoryLaw.BEST_CHAIN), 4, "4연속 굴림 기록")
	manager.act(&"select_pawn", {"player_id": 1, "pawn_id": 11})
	check(manager.state.rankings.is_empty(), "라운드 중에는 아직 졸업하지 않는다")
	_finish_round(manager)
	check_eq(manager.state.rankings, int_array([1, 2]), "라운드 끝 판정: 초전도체 달성 -> 1위 졸업, 남은 P2는 2위")
	check(manager.is_game_over, "2인 판은 1위가 나오면 끝")
	_dispose(manager)


func test_same_law_achievers_at_round_end_only_the_leader_graduates() -> void:
	var manager: TurnManager = _new_manager(3)
	var state: GameState = manager.state
	add_law(state, "LAW_01")
	state.law_stats[1] = {VictoryLaw.KILLS: 6}
	state.law_stats[3] = {VictoryLaw.KILLS: 6}
	place(state, 31, 20, [19])
	place(state, 11, 4, [3])
	_finish_round(manager)
	check_eq(state.rankings, int_array([3]), "같은 교칙을 둘이 달성: 레이스에서 앞선 P3만 졸업 (교칙은 한 명을 졸업시키고 사라진다)")
	check(not state.is_graduated(1) and not state.rulebook.has_law("LAW_01"), "P1은 레이스에 남고 교칙은 법전에서 사라졌다")
	var standings: Array[Dictionary] = VictoryChecker.standings(state, manager.player_order, state.rankings[0])
	var winner_row: Dictionary = standings[0]
	check(int(winner_row["progress"]) < 100 and int(winner_row["finished"]) == 0, "결과표는 졸업 순간의 진행을 보여 준다 (철수한 말을 완주로 세지 않는다)")
	check_eq(VictoryChecker.short_reason(winner_row["reason"]), "특수 승리: 투기장의 지배자", "결과표 사유")
	_dispose(manager)


func test_siege_needs_four_separate_pawns_three_tiles_apart() -> void:
	var state := make_state()
	for entry: Array in [[11, 2], [12, 5], [13, 8], [14, 10]]:
		place(state, entry[0], entry[1], [entry[1] - 1])
	check_eq(VictoryLaw.spread_count(state, 1), 3, "10번은 8번과 2칸 차이")
	place(state, 14, 11, [10])
	check_eq(VictoryLaw.spread_count(state, 1), 4, "모두 3칸 이상")
	add_law(state, "LAW_05")
	check_eq(SpecialVictory.achieved_by(state, 1), &"LAW_05", "사도 포위망 달성")


func test_underdog_counts_kills_on_the_leader_only_with_no_finished_pawns() -> void:
	var state := make_state(3)
	place(state, 21, 20, [19])  # P2가 선두
	place(state, 31, 6, [5])
	place(state, 11, 4, [3])
	check_eq(state.race_leader(1), 2, "P1을 뺀 선두는 P2")
	state.send_to_start(state.get_pawn(31), 1)
	check_eq(state.stat(1, VictoryLaw.UNDERDOG), 0, "선두가 아닌 사람을 잡으면 세지 않는다")
	state.send_to_start(state.get_pawn(21), 1)
	check_eq(state.stat(1, VictoryLaw.UNDERDOG), 1, "선두의 말 처치")
	state.finish_stack(state.get_pawn(12))
	place(state, 22, 20, [19])
	state.send_to_start(state.get_pawn(22), 1)
	check_eq(state.stat(1, VictoryLaw.UNDERDOG), 1, "완주한 말이 있으면 다크호스가 아니다")


func test_progress_rows_flag_danger_and_survive_snapshots() -> void:
	var state := make_state(2)
	add_law(state, "LAW_06")
	state.law_stats[2] = {VictoryLaw.EJECTED: 7}
	var rows: Array[Dictionary] = SpecialVictory.progress_rows(state, state.rulebook.active_laws_queue[0] as VictoryLaw)
	check_eq(rows.size(), 2, "플레이어마다 한 줄")
	check_eq([int(rows[1]["value"]), int(rows[1]["goal"]), bool(rows[1]["danger"])], [7, 8, true], "7/8 위험!")
	check(not bool(rows[0]["danger"]), "0/8은 안전")
	var snapshot: TurnSnapshot = TurnSnapshot.capture(state)
	state.law_stats.clear()
	snapshot.restore(state)
	check_eq(state.stat(2, VictoryLaw.EJECTED), 7, "되감기·동기화로 기록 복원")


## 라운드 마지막 차례에 처치로 조건을 채워도 턴 도중에는 졸업하지 않고, 라운드가 끝나는 순간 딱 한 번만 판정한다.
func test_capture_during_the_round_never_graduates_before_the_round_ends() -> void:
	var manager: TurnManager = _new_manager(4)
	var state: GameState = manager.state
	add_law(state, "LAW_01")
	state.law_stats[1] = {VictoryLaw.KILLS: 5}
	var judgements: Array[int] = []
	manager.event_received.connect(func(kind: StringName, _data: Dictionary) -> void:
		if kind == &"round_end_judgement":
			judgements.append(state.round_number))
	place(state, 11, 2, [1])
	place(state, 21, 4, [3])
	manager.state.tools[1] = ScriptedTool.new([2])
	manager.act(&"proceed", {"player_id": 1})
	manager.act(&"roll", {"player_id": 1})
	manager.act(&"select_pawn", {"player_id": 1, "pawn_id": 11})
	check_eq(state.stat(1, VictoryLaw.KILLS), 6, "처치로 진행도만 오른다")
	check(state.rankings.is_empty() and judgements.is_empty(), "라운드 도중(내 턴 직후)에는 판정이 일어나지 않는다")
	manager.force_timeout()  # 다음 사람들의 차례를 넘긴다
	check(state.rankings.is_empty() and judgements.is_empty(), "다른 사람 차례가 끝나기 전에도 판정이 없다")
	_finish_round(manager)
	check_eq(judgements, [1], "라운드 끝에 정확히 한 번만 판정한다")
	check_eq(state.rankings, int_array([1]), "그때 졸업")
	_dispose(manager)


## 졸업한 사람은 이후 라운드의 특수 승리 판정에서 빠지고, 달성된 교칙은 법전에서 사라져 다시 판정되지 않는다.
func test_graduate_and_destroyed_law_are_never_checked_again_in_later_rounds() -> void:
	var manager: TurnManager = _new_manager(4)
	var state: GameState = manager.state
	add_law(state, "LAW_01")
	state.law_stats[1] = {VictoryLaw.KILLS: 6}
	var ranked: Array[int] = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"player_ranked":
			ranked.append(int(data["player_id"])))
	_finish_round(manager)
	check_eq(state.rankings, int_array([1]), "1라운드 끝에 P1이 졸업")
	check(not state.rulebook.has_law("LAW_01"), "달성된 교칙은 법전에서 완전히 사라진다")
	# 남은 사람이 같은 교칙을 다시 제정해도 졸업한 P1의 옛 기록 때문에 P1이 다시 걸리지 않는다.
	state.law_stats[1] = {VictoryLaw.KILLS: 99}
	add_law(state, "LAW_01")
	state.law_stats[3] = {VictoryLaw.KILLS: 6}
	_finish_round(manager)
	check_eq(ranked.count(1), 1, "P1은 한 번만 순위를 받는다")
	check_eq(state.rankings, int_array([1, 3]), "다음 라운드에는 새로 달성한 P3만 졸업한다")
	check(not state.rulebook.has_law("LAW_01"), "다시 달성된 교칙도 법전에서 사라진다")
	var third_round: int = state.round_number
	_finish_round(manager)
	_finish_round(manager)
	check_eq(state.rankings, int_array([1, 3]), "교칙이 없는 라운드들에는 아무도 졸업하지 않는다 (옛 기록이 남아 있어도)")
	check(state.round_number > third_round or manager.is_game_over, "라운드는 계속 진행된다")
	_dispose(manager)
