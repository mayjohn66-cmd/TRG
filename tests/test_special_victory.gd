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
	check_eq(state.rankings, int_array([1]), "6번째 처치로 1위 졸업")
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
	check_eq(state.rankings, int_array([2]), "P2 턴 시작 시 손패 5장 -> 졸업")
	check_eq(state.current_player, 3, "졸업한 P2의 턴은 넘어간다")
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
	if not manager.state.is_graduated(1):  # 이동 선택 단계라면 이동을 마치면 판정된다
		manager.act(&"select_pawn", {"player_id": 1, "pawn_id": 11})
	check_eq(manager.state.rankings, int_array([1, 2]), "초전도체 달성 -> 1위 졸업, 남은 P2는 2위")
	check(manager.is_game_over, "2인 판은 1위가 나오면 끝")
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
