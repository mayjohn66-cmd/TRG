# File: res://tests/test_turn_manager.gd
# Class: class_name TestTurnManager
# Role: 8단계 턴 상태 머신·타이머·재굴림·러시안 룰렛 흐름·개입 LIFO·ACT_05·드래프트·호스트 권위(명세 1·4·5·7) 통합 검증
class_name TestTurnManager
extends TestCase

const Phase := TurnManager.State


func _new_manager(player_count: int = 2, hotseat: bool = true, loadouts: Dictionary = {}) -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = hotseat
	manager.draft_enabled = false
	tree.root.add_child(manager)
	var ids: Array[int] = []
	for i: int in range(1, player_count + 1):
		ids.append(i)
	manager.start_game(ids, 4242, loadouts)
	return manager


func _dispose(manager: TurnManager) -> void:
	tree.root.remove_child(manager)
	manager.free()


func _collect_events(manager: TurnManager) -> Array:
	var events: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void: events.append({"kind": kind, "data": data}))
	return events


func _rejections(manager: TurnManager) -> Array:
	var rejected: Array = []
	manager.action_rejected.connect(func(player_id: int, action: StringName, reason: StringName) -> void: rejected.append([player_id, action, reason]))
	return rejected


func _set_tool(manager: TurnManager, player_id: int, tool: BaseJudgmentTool) -> void:
	manager.state.tools[player_id] = tool


func _do(manager: TurnManager, player_id: int, action: StringName, params: Dictionary = {}) -> void:
	var payload: Dictionary = params.duplicate()
	payload["player_id"] = player_id
	manager.act(action, payload)


func test_game_starts_at_turn_begin_with_snapshot() -> void:
	var manager: TurnManager = _new_manager()
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "첫 페이즈")
	check_eq(manager.state.current_player, 1, "1번 플레이어부터")
	check(manager.state.turn_snapshot != null, "TURN_BEGIN 진입 시 TurnSnapshot 저장")
	check_eq(manager.phase_time_left, GameEnums.PHASE_TIME_TURN_BEGIN, "제한 시간")
	_dispose(manager)


func test_full_turn_flow_with_manual_actions() -> void:
	var manager: TurnManager = _new_manager()
	_set_tool(manager, 1, ScriptedTool.new([2]))
	_do(manager, 1, &"proceed")
	check_eq(manager.current_state, Phase.PHASE_ROLL_WAIT, "굴림 대기")
	_do(manager, 1, &"roll")
	check_eq(manager.current_state, Phase.PHASE_SELECT_PAWN, "손패가 없으면 개입 창은 즉시 닫힘")
	check_eq(manager.move_queue, int_array([2]), "이동 대기열")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(manager.state.get_pawn(11).current_tile_idx, 2, "말 이동")
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "다음 플레이어 턴 시작")
	check_eq(manager.state.current_player, 2, "2번 플레이어 차례")
	_dispose(manager)


func test_timeouts_drive_every_phase() -> void:
	var manager: TurnManager = _new_manager()
	_set_tool(manager, 1, ScriptedTool.new([2]))
	manager.tick(GameEnums.PHASE_TIME_TURN_BEGIN + 0.1)
	check_eq(manager.current_state, Phase.PHASE_ROLL_WAIT, "TURN_BEGIN 시간 초과 -> 굴림 대기")
	manager.tick(GameEnums.PHASE_TIME_ROLL + 0.1)
	check_eq(manager.current_state, Phase.PHASE_SELECT_PAWN, "굴림 시간 초과 -> 자동 굴림")
	manager.tick(GameEnums.PHASE_TIME_SELECT + 0.1)
	check_eq(manager.state.current_player, 2, "기물 선택 시간 초과 -> 자동 이동 후 다음 턴")
	var moved: int = 0
	for pawn: PlayerPawn in manager.state.pawns_of(1):
		if pawn.current_tile_idx == 2:
			moved += 1
	check_eq(moved, 1, "자동 선택된 말이 이동")
	_dispose(manager)


func test_bonus_roll_moves_first_then_rolls_again_keeping_one_card_per_turn() -> void:
	var manager: TurnManager = _new_manager()
	_set_tool(manager, 1, ScriptedTool.new([ScriptedTool.reroll_of(4), 2]))
	manager.state.give_card(1, &"ACT_04")
	manager.state.give_card(1, &"ACT_04")
	_do(manager, 1, &"play_card", {"card_id": &"ACT_04"})
	check(manager.card_played_this_turn(), "굴리기 전에 카드 1장")
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	check_eq(manager.current_state, Phase.PHASE_SELECT_PAWN, "추가 굴림이 나와도 이번 눈금으로 먼저 움직인다")
	check_eq(manager.move_queue, int_array([8]), "눈금 4 + 로켓 부스터 4")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(manager.state.get_pawn(11).current_tile_idx, 8, "첫 이동")
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "이동이 끝나면 같은 사람이 다시 굴린다 (카드 단계부터)")
	check_eq(manager.state.current_player, 1, "아직 내 차례")
	check(manager.card_played_this_turn(), "카드는 턴당 1장 그대로: 추가 굴림이라고 다시 열리지 않는다")
	var rejected: Array = _rejections(manager)
	_do(manager, 1, &"play_card", {"card_id": &"ACT_04"})
	check_eq(rejected.size(), 1, "두 번째 카드는 거절")
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"select_pawn", {"pawn_id": 12})
	check_eq(manager.state.get_pawn(12).current_tile_idx, 2, "추가 굴림 눈금으로 두 번째 이동")
	check_eq(manager.state.current_player, 2, "추가 굴림이 끝나면 턴 종료")
	_dispose(manager)


func test_law_pipeline_modifies_roll_before_move() -> void:
	var manager: TurnManager = _new_manager()
	manager.state.rulebook.add_personal("SUPER_10", 1)
	_set_tool(manager, 1, ScriptedTool.new([6]))
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	check_eq(manager.move_queue, int_array([9]), "아우토반 니트로(개인 패시브)가 눈금 6에 +3칸 = 9")
	_dispose(manager)


func test_russian_roulette_push_your_luck_flow() -> void:
	var manager: TurnManager = _new_manager()
	var revolver := ToolRussianRoulette.new()
	revolver.load_chamber(4)
	_set_tool(manager, 1, revolver)
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	check_eq(manager.current_state, Phase.PHASE_ROLL_WAIT, "빈 총이면 계속 당길 수 있음")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"stop")
	check_eq(manager.current_state, Phase.PHASE_SELECT_PAWN, "멈추면 이동 선택")
	check_eq(manager.move_queue, int_array([6]), "누적 6칸")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(manager.state.get_pawn(11).current_tile_idx, 6, "6칸 전진하면 6번 코너에 멈춘다 (코너 점프대 없음)")
	_dispose(manager)


func test_russian_roulette_bullet_ends_turn_without_moving() -> void:
	var manager: TurnManager = _new_manager()
	var revolver := ToolRussianRoulette.new()
	revolver.load_chamber(1)
	_set_tool(manager, 1, revolver)
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"roll")
	check_eq(manager.state.current_player, 2, "실탄 발사 즉시 턴 종료")
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "다음 턴")
	for pawn: PlayerPawn in manager.state.pawns_of(1):
		check_eq(pawn.current_tile_idx, 0, "이동 없음")
	_dispose(manager)


func test_stop_without_accumulation_is_rejected() -> void:
	var manager: TurnManager = _new_manager()
	var rejected: Array = _rejections(manager)
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"stop")
	check_eq(rejected.size(), 1, "거부됨")
	check_eq(rejected[0][2], &"nothing_to_cash_out", "사유")
	_dispose(manager)


func test_actions_from_wrong_player_or_phase_are_rejected() -> void:
	var manager: TurnManager = _new_manager()
	var rejected: Array = _rejections(manager)
	_do(manager, 2, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	_do(manager, 1, &"bogus")
	check_eq(rejected.size(), 4, "모두 거부")
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "상태 불변")
	_dispose(manager)


func test_host_authority_ignores_claimed_player_when_not_hotseat() -> void:
	var manager: TurnManager = _new_manager(2, false)
	var events: Array = _collect_events(manager)
	_set_tool(manager, 1, ScriptedTool.new([3]))
	_do(manager, 2, &"proceed")  # 방장(피어 1 = 1번 플레이어)이 2번을 사칭해도 1번으로 처리
	check_eq(manager.current_state, Phase.PHASE_ROLL_WAIT, "사칭 요청도 1번 플레이어 권한으로만 처리")
	_do(manager, 2, &"roll")
	var rolled: Array = events.filter(func(e: Dictionary) -> bool: return e["kind"] == &"roll_resolved")
	check_eq(rolled.size(), 1, "굴림 이벤트")
	check_eq(rolled[0]["data"]["player_id"], 1, "행동자는 발신 피어에 매핑된 플레이어")
	_dispose(manager)


func test_unknown_peer_is_rejected_when_not_hotseat() -> void:
	var manager: TurnManager = _new_manager(2, false)
	manager.peer_to_player = {}
	var rejected: Array = _rejections(manager)
	manager.act(&"proceed", {})
	check_eq(rejected.size(), 1, "매핑되지 않은 피어는 거부")
	check_eq(rejected[0][2], &"unknown_player", "사유")
	_dispose(manager)


func test_round_end_runs_npc_phase_and_advances_round() -> void:
	var manager: TurnManager = _new_manager()
	var events: Array = _collect_events(manager)
	manager.state.spawn_npc(10, GameEnums.NpcBehavior.CHASE_NEAREST, 1, &"SUM_01")
	for player_id: int in [1, 2]:
		_set_tool(manager, player_id, ScriptedTool.new([player_id]))  # 서로 다른 칸에 서도록 1, 2칸
		_do(manager, player_id, &"proceed")
		_do(manager, player_id, &"roll")
		_do(manager, player_id, &"select_pawn", {"pawn_id": player_id * 10 + 1})
	check_eq(manager.state.round_number, 2, "라운드 증가")
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "새 라운드 첫 턴")
	check_eq(manager.state.current_player, 1, "다시 1번")
	var npc_events: Array = events.filter(func(e: Dictionary) -> bool: return e["kind"] == &"npc_phase_resolved")
	check_eq(npc_events.size(), 1, "NPC 페이즈 실행")
	_dispose(manager)


func test_yut_capture_grants_extra_turn_to_same_player() -> void:
	var manager: TurnManager = _new_manager(2, true, {1: [Vector2i(GameEnums.PawnKind.YUT, 1), 0, 0, 0]})
	place(manager.state, 21, 2, [1])
	_set_tool(manager, 1, ScriptedTool.new([2]))
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(manager.state.current_player, 1, "잡기 후 같은 플레이어가 한 번 더")
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "새 턴으로 시작")
	_dispose(manager)


func test_non_yut_capture_does_not_grant_an_extra_turn() -> void:
	var manager: TurnManager = _new_manager()
	place(manager.state, 21, 2, [1])
	_set_tool(manager, 1, ScriptedTool.new([2]))
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(manager.state.get_pawn(21).current_tile_idx, 0, "잡기는 수행")
	check_eq(manager.current_player_id(), 2, "일반 기물은 추가 굴림 없이 턴 종료")
	_dispose(manager)


func _stack_offer_manager() -> TurnManager:
	var manager: TurnManager = _new_manager(2, true, {1: [Vector2i(GameEnums.PawnKind.YUT, 1), Vector2i(GameEnums.PawnKind.CHESS, 1), 0, 0]})
	manager.stack_choice_enabled = true
	place(manager.state, 12, 4, [3])
	place(manager.state, 11, 2, [1])
	_set_tool(manager, 1, ScriptedTool.new([2]))
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	return manager


func test_yut_stack_choice_waits_for_the_player_and_stacks_on_request() -> void:
	var manager: TurnManager = _stack_offer_manager()
	check_eq(manager.current_state, Phase.PHASE_RESOLUTION, "정산 단계에서 선택을 기다림")
	check(manager.stack_offer_pending(), "업기 선택 대기")
	check(manager.state.get_pawn(12).carrier == null, "선택 전에는 합치지 않음")
	var events: Array = _collect_events(manager)
	_do(manager, 1, &"stack_choice", {"stack": true})
	check(not manager.stack_offer_pending(), "선택 완료")
	check_eq(manager.state.get_pawn(12).carrier, manager.state.get_pawn(11), "업기를 선택하면 합체")
	var resolved: Array = events.filter(func(e: Dictionary) -> bool: return e["kind"] == &"stack_resolved")
	check_eq(resolved.size(), 1, "stack_resolved 이벤트")
	check_eq(manager.current_player_id(), 2, "선택 뒤 턴이 이어짐")
	_dispose(manager)


func test_yut_stack_choice_can_keep_pawns_separate() -> void:
	var manager: TurnManager = _stack_offer_manager()
	_do(manager, 1, &"stack_choice", {"stack": false})
	check(manager.state.get_pawn(12).carrier == null, "그냥 두기를 선택하면 개별 유지")
	check_eq(manager.state.get_pawn(11).current_tile_idx, manager.state.get_pawn(12).current_tile_idx, "같은 타일에 공존")
	_dispose(manager)


func test_yut_stack_choice_defaults_to_stacking_on_timeout_and_rejects_wrong_actors() -> void:
	var manager: TurnManager = _stack_offer_manager()
	var rejected: Array = _rejections(manager)
	_do(manager, 2, &"stack_choice", {"stack": false})
	check_eq(rejected.size(), 1, "상대 플레이어의 선택은 거부")
	check(manager.stack_offer_pending(), "여전히 대기")
	manager.tick(GameEnums.PHASE_TIME_SELECT + 0.1)
	check(manager.state.get_pawn(12).carrier == manager.state.get_pawn(11), "시간 초과 시 기본값은 업기")
	_do(manager, 1, &"stack_choice", {"stack": true})
	check_eq(rejected.size(), 2, "대기 중이 아니면 거부")
	_dispose(manager)


func test_stack_choice_is_asked_for_every_pawn_and_skipped_by_headless_default() -> void:
	var plain: TurnManager = _new_manager()
	plain.stack_choice_enabled = true
	place(plain.state, 12, 4, [3])
	place(plain.state, 11, 2, [1])
	_set_tool(plain, 1, ScriptedTool.new([2]))
	_do(plain, 1, &"proceed")
	_do(plain, 1, &"roll")
	_do(plain, 1, &"select_pawn", {"pawn_id": 11})
	check(plain.stack_offer_pending(), "일반 기물도 아군 말에 도착하면 업기를 묻는다")
	_dispose(plain)
	var auto: TurnManager = _new_manager(2, true, {1: [Vector2i(GameEnums.PawnKind.YUT, 1), 0, 0, 0]})
	place(auto.state, 12, 4, [3])
	place(auto.state, 11, 2, [1])
	_set_tool(auto, 1, ScriptedTool.new([2]))
	_do(auto, 1, &"proceed")
	_do(auto, 1, &"roll")
	_do(auto, 1, &"select_pawn", {"pawn_id": 11})
	check(not auto.stack_offer_pending() and auto.state.get_pawn(12).carrier == auto.state.get_pawn(11), "기본(헤드리스/AI)은 선택 없이 자동 업기")
	_dispose(auto)

func test_intervention_window_stays_closed_when_nobody_can_use_their_cards() -> void:
	var manager: TurnManager = _new_manager()
	manager.state.give_card(2, &"CNT_04")  # 공격받기 전에는 쓸 수 없는 방어 카드
	manager.state.give_card(1, &"TRP_07")  # 턴 시작 구간에서만 쓰는 카드
	_set_tool(manager, 1, ScriptedTool.new([2]))
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	check_eq(manager.current_state, Phase.PHASE_SELECT_PAWN, "낼 수 있는 카드가 없으면 개입 창을 건너뛴다")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "정산 창도 건너뛰고 다음 턴")
	_dispose(manager)

func test_all_pawns_home_declares_winner_and_stops_game() -> void:
	var manager: TurnManager = _new_manager()
	var finished_signal: Array = []
	manager.game_over.connect(func(winner_id: int, reason: StringName) -> void: finished_signal.append([winner_id, reason]))
	for slot: int in [2, 3, 4]:
		manager.state.finish_stack(manager.state.get_pawn(10 + slot))
	place(manager.state, 11, 22, [21])
	_set_tool(manager, 1, ScriptedTool.new([2]))
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check(manager.is_game_over, "게임 종료")
	check_eq(finished_signal, [[1, &"all_home"]], "승자/사유")
	check_eq(manager.state.winner, 1, "승자 기록")
	_dispose(manager)


func test_first_normal_finisher_ends_and_ranks_the_remaining_race() -> void:
	var manager: TurnManager = _new_manager(4)
	var state: GameState = manager.state
	var events: Array = _collect_events(manager)
	for slot: int in [2,3,4]:state.finish_stack(state.get_pawn(10+slot))
	place(state,21,6,[5]);place(state,31,12,[11]);place(state,41,9,[8])
	var remaining:=VictoryChecker.sort_by_race(state,[2,3,4])
	place(state,11,22,[21]);_set_tool(manager,1,ScriptedTool.new([2]))
	_do(manager,1,&"proceed");_do(manager,1,&"roll");_do(manager,1,&"select_pawn",{"pawn_id":11})
	check(manager.is_game_over,"first all-home winner immediately ends the match")
	var expected: Array[int]=[1];expected.append_array(remaining)
	check_eq(state.rankings,expected,"remaining players retain the pre-cleanup race order")
	check_eq(events.filter(func(e: Dictionary)->bool:return e["kind"]==&"game_over").size(),1,"one final result event")
	_dispose(manager)


func test_yut_four_stack_special_victory_via_turn_manager() -> void:
	var manager: TurnManager = _new_manager(2, true, {1: [Vector2i(GameEnums.PawnKind.YUT, 1), Vector2i(GameEnums.PawnKind.YUT, 2), Vector2i(GameEnums.PawnKind.YUT, 3), Vector2i(GameEnums.PawnKind.YUT, 4)]})
	var state: GameState = manager.state
	for slot: int in [1, 2, 3, 4]:
		place(state, 10 + slot, 22, [21])
	for slot: int in [2, 3, 4]:
		state.stack_pawns(state.get_pawn(11), state.get_pawn(10 + slot))
	_set_tool(manager, 1, ScriptedTool.new([2]))
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check(manager.is_game_over, "특수 승리")
	check_eq(manager.state.winner, 1, "승자")
	_dispose(manager)


func test_no_draft_when_disabled() -> void:
	var manager: TurnManager = _new_manager()
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "드래프트를 끄면 바로 첫 턴")
	_dispose(manager)


func test_state_sync_payload_roundtrips_through_a_client_mirror() -> void:
	var host: TurnManager = _new_manager()
	place(host.state, 11, 8, [7])
	add_law(host.state, &"LAW_02")
	host.state.place_attachment(5, TrapMirrorForce.new(2))
	var payload: Dictionary = host._build_sync_payload()
	var client := TurnManager.new()
	client.boost_gimmicks = false
	tree.root.add_child(client)
	client._rpc_sync_state(payload)  # 클라이언트 수신 경로를 직접 호출
	check_eq(client.state.get_pawn(11).current_tile_idx, 8, "기물 위치 미러링")
	check(client.state.rulebook.has_law(&"LAW_02"), "법전 미러링")
	check(client.state.board.get_tile(5).has_attachment(&"TRP_01"), "설치물 미러링")
	check_eq(client.current_state, host.current_state, "페이즈 미러링")
	tree.root.remove_child(client)
	client.free()
	_dispose(host)


func test_state_enum_has_exactly_the_eight_phases() -> void:
	var names: Array = TurnManager.State.keys()
	check_eq(names, [
		"PHASE_ROUND_START", "PHASE_TURN_BEGIN", "PHASE_ROLL_WAIT", "PHASE_INTERRUPT_ROLL",
		"PHASE_SELECT_PAWN", "PHASE_MOVING_STEP", "PHASE_RESOLUTION", "PHASE_NEUTRAL_NPC"], "8단계 순서")


func test_turn_order_variables_have_documented_defaults() -> void:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	check_eq(manager.player_order, int_array([1, 2, 3, 4]), "기본 플레이 순서")
	check_eq(manager.current_turn_index, 0, "기본 인덱스")
	check_eq(manager.turn_direction, 1, "기본 정방향")
	check_eq(manager.current_state, Phase.PHASE_ROUND_START, "기본 상태")
	manager.free()


func test_reverse_turn_order_flips_direction_and_emits_signal() -> void:
	var manager: TurnManager = _new_manager(3)
	var directions: Array[int] = []
	manager.turn_order_reversed.connect(func(new_direction: int) -> void: directions.append(new_direction))
	manager.reverse_turn_order()
	check_eq(manager.turn_direction, -1, "역방향")
	manager.reverse_turn_order()
	check_eq(manager.turn_direction, 1, "다시 정방향")
	check_eq(directions, [-1, 1] as Array[int], "시그널 인자")
	_dispose(manager)


func test_advance_to_next_player_cycles_and_enters_npc_phase_at_round_end() -> void:
	var manager: TurnManager = _new_manager(3)
	var events: Array = _collect_events(manager)
	var states: Array[int] = []
	manager.phase_changed.connect(func(new_state: int, _player: int, _limit: float) -> void: states.append(new_state))
	check_eq(manager.current_turn_index, 0, "시작")
	manager.advance_to_next_player()
	check_eq(manager.current_turn_index, 1, "다음 플레이어")
	check_eq(manager.state.current_player, 2, "GameState 미러도 갱신")
	manager.advance_to_next_player()
	check_eq(manager.current_turn_index, 2, "세 번째 플레이어")
	check_eq(manager.state.round_number, 1, "아직 1라운드")
	manager.advance_to_next_player()
	check(states.has(Phase.PHASE_NEUTRAL_NPC), "라운드 마지막 턴 뒤 PHASE_NEUTRAL_NPC 진입")
	check_eq(events.filter(func(e: Dictionary) -> bool: return e["kind"] == &"npc_phase_resolved").size(), 1, "NPC 페이즈 실행")
	check_eq(manager.state.round_number, 2, "다음 라운드")
	check_eq(manager.current_turn_index, 0, "인덱스 순환")
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "새 라운드 첫 턴")
	_dispose(manager)


func test_advance_to_next_player_follows_reverse_direction() -> void:
	var manager: TurnManager = _new_manager(4)
	manager.reverse_turn_order()
	manager.advance_to_next_player()
	check_eq(manager.current_turn_index, 3, "역방향이면 0 다음은 마지막 인덱스")
	check_eq(manager.current_player_id(), 4, "4번 플레이어")
	manager.advance_to_next_player()
	check_eq(manager.current_turn_index, 2, "계속 역순")
	_dispose(manager)


## 라운드 도중 리버스: 아직 차례가 없던 사람만 돌고, 모두 정확히 한 번씩 한 뒤 라운드가 끝난다 (누가 두 번·0번 하지 않는다).
func test_reverse_mid_round_still_gives_everyone_exactly_one_turn() -> void:
	var manager: TurnManager = _new_manager(4)
	var turns: Array[int] = [manager.current_player_id()]
	manager.phase_changed.connect(func(new_state: int, player: int, _limit: float) -> void:
		if new_state == Phase.PHASE_TURN_BEGIN and manager.state.round_number == 1:
			turns.append(player))
	manager.advance_to_next_player()  # P1 -> P2
	manager.reverse_turn_order()  # P2가 리버스
	manager.advance_to_next_player()  # 역방향: P1은 이미 했으니 건너뛰고 P4
	check_eq(manager.current_player_id(), 4, "이미 한 P1을 건너뛰고 P4")
	manager.advance_to_next_player()  # P3
	check_eq(manager.current_player_id(), 3, "P3")
	check_eq(manager.state.round_number, 1, "아직 1라운드 (P3 차례가 남았다)")
	manager.advance_to_next_player()  # 모두 끝 -> 다음 라운드
	check_eq(manager.state.round_number, 2, "네 명이 한 번씩 하고 라운드 끝")
	var unique: Dictionary = {}
	for player: int in turns:
		unique[player] = true
	check_eq(turns.size(), 4, "1라운드 차례는 정확히 4번 (%s)" % str(turns))
	check_eq(unique.size(), 4, "네 명 모두 한 번씩 (%s)" % str(turns))
	_dispose(manager)

func test_step_by_step_move_stops_immediately_when_a_trap_fires() -> void:
	var manager: TurnManager = _new_manager()
	var state: GameState = manager.state
	state.place_attachment(3, TrapMirrorForce.new(2))
	var pawn: PlayerPawn = state.get_pawn(11)
	var ctx: RuleContext = make_ctx(state, 6)
	var path: Array[int] = state.board.calculate_path(pawn, 6, ctx)
	var seen_steps: Array[int] = []
	state.pawn_stepped.connect(func(_pawn_id: int, _from: int, to_tile: int) -> void: seen_steps.append(to_tile))
	await manager.execute_step_by_step_move(pawn, path, ctx)
	check_eq(seen_steps, int_array([1, 2, 3]), "함정 칸에서 남은 이동(4, 5, 6)이 취소됨")
	check_eq(manager._move_outcome, MoveExecutor.StepOutcome.TRAPPED, "함정 발동 결과")
	check_eq(pawn.current_tile_idx, 0, "출발선으로 복귀")
	check_eq(state.board.get_tile(3).attachments.size(), 0, "함정은 소모됨")
	_dispose(manager)


func test_step_by_step_move_awaits_between_steps() -> void:
	var manager: TurnManager = _new_manager()
	manager.step_delay_sec = 0.03
	var state: GameState = manager.state
	var pawn: PlayerPawn = state.get_pawn(11)
	var ctx: RuleContext = make_ctx(state, 4)
	var path: Array[int] = state.board.calculate_path(pawn, 4, ctx)
	manager.execute_step_by_step_move(pawn, path, ctx)  # await 하지 않고 시작만 한다
	check_eq(pawn.current_tile_idx, 1, "첫 걸음만 즉시 이동하고 다음 걸음은 대기")
	await tree.create_timer(0.05).timeout
	check(pawn.current_tile_idx > 1 and pawn.current_tile_idx < 4, "시간이 지나며 한 칸씩 진행 중 (현재 %d)" % pawn.current_tile_idx)
	await tree.create_timer(0.3).timeout
	check_eq(pawn.current_tile_idx, 4, "경로 끝까지 이동")
	_dispose(manager)


func test_select_pawn_runs_async_move_to_resolution_with_step_delay() -> void:
	var manager: TurnManager = _new_manager()
	manager.step_delay_sec = 0.02
	_set_tool(manager, 1, ScriptedTool.new([2]))  # 3칸이면 빵집(3번)에서 카드를 받아 개입 창이 열린다
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(manager.current_state, Phase.PHASE_MOVING_STEP, "이동 중에는 PHASE_MOVING_STEP")
	var rejected: Array = _rejections(manager)
	_do(manager, 1, &"select_pawn", {"pawn_id": 12})
	check_eq(rejected.size(), 1, "이동 중 다른 행동은 거부")
	await tree.create_timer(0.3).timeout
	check_eq(manager.state.get_pawn(11).current_tile_idx, 2, "이동 완료")
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "도착 처리 후 다음 플레이어 턴")
	check_eq(manager.current_player_id(), 2, "2번 플레이어")
	_dispose(manager)


func test_trap_during_real_turn_flow_marks_victim_as_hurt() -> void:
	var manager: TurnManager = _new_manager()
	manager.state.place_attachment(2, TrapMirrorForce.new(2))
	_set_tool(manager, 1, ScriptedTool.new([4]))
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(manager.state.get_pawn(11).current_tile_idx, 0, "함정에 걸려 출발선")
	check_eq(manager.state.board.get_tile(2).attachments.size(), 0, "함정 소모")
	check_eq(manager.current_player_id(), 2, "턴 종료")
	_dispose(manager)


func test_a_zero_roll_moves_nothing_and_never_goes_backward() -> void:
	var manager: TurnManager = _new_manager()
	place(manager.state, 11, 5, [4])
	_set_tool(manager, 1, ScriptedTool.new([-1]))
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	check_eq(manager.move_queue, int_array([0]), "음수 눈금은 0칸으로 고정")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(manager.state.get_pawn(11).current_tile_idx, 5, "뒤로 가지 않고 제자리")
	_dispose(manager)


func test_turn_skipped_event_when_no_pawn_can_move() -> void:
	var manager: TurnManager = _new_manager()
	var kinds: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void: kinds.append([kind, data.get("player_id", -1)]))
	for pawn: PlayerPawn in manager.state.pawns_of(1):
		pawn.blocked_this_turn = true
	_set_tool(manager, 1, ScriptedTool.new([3]))
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	check(kinds.has([&"turn_skipped", 1]), "움직일 수 있는 말이 없으면 turn_skipped 이벤트가 나간다")
	_dispose(manager)


func test_cards_are_only_played_before_the_roll_and_once_per_turn() -> void:
	var manager: TurnManager = _new_manager()
	var rejected: Array = _rejections(manager)
	manager.state.give_card(1, &"ACT_04")
	manager.state.give_card(1, &"ACT_04")
	manager.state.give_card(2, &"ACT_04")
	_set_tool(manager, 1, ScriptedTool.new([2]))
	_do(manager, 1, &"play_card", {"card_id": &"ACT_04"})
	check_eq(manager.state.roll_bonus, 4, "굴리기 전에는 카드가 바로 실행된다")
	check(manager.card_played_this_turn(), "이번 턴 카드 사용 기록")
	_do(manager, 1, &"play_card", {"card_id": &"ACT_04"})
	check_eq(rejected.size(), 1, "굴리기 전 카드는 턴당 1장")
	check_eq(rejected[0][2], &"card_limit", "거부 사유는 카드 한도")
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	check_eq(manager.move_queue, int_array([6]), "굴림 2에 로켓 +4")
	check_eq(manager.current_state, Phase.PHASE_SELECT_PAWN, "손패가 있어도 굴림 뒤 개입 창은 열리지 않는다")
	_do(manager, 2, &"play_card", {"card_id": &"ACT_04"})
	check_eq(rejected.back()[2], &"not_playable_now", "굴림 뒤에는 (방어 카드를 빼고) 카드를 낼 수 없다")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	_do(manager, 2, &"proceed")
	check(not manager.card_played_this_turn(), "새 턴에는 카드 사용 기록이 초기화된다")
	_dispose(manager)


func test_card_requires_phase_ownership_and_valid_target() -> void:
	var manager: TurnManager = _new_manager()
	var rejected: Array = _rejections(manager)
	manager.state.give_card(2, &"TRP_07")
	manager.state.give_card(1, &"TRP_07")
	_do(manager, 2, &"play_card", {"card_id": &"TRP_07", "tile": 7})  # 내 턴 아님
	_do(manager, 1, &"play_card", {"card_id": &"TRP_07", "tile": 0})  # 잘못된 대상
	_do(manager, 1, &"play_card", {"card_id": &"ACT_04"})  # 손패에 없음
	_do(manager, 1, &"play_card", {"card_id": &"TRP_07", "tile": 7})  # 정상
	check_eq(rejected.size(), 3, "비정상 요청 3건 거부")
	check(manager.state.board.get_tile(7).has_attachment("TRP_07"), "정상 요청은 설치")
	check((manager.state.hands[1] as Array).is_empty(), "사용한 카드 소모")
	_dispose(manager)


func test_one_trap_per_tile() -> void:
	var manager: TurnManager = _new_manager()
	var state: GameState = manager.state
	state.place_attachment(9, TrapMine.new(2))
	for card_id: StringName in [&"TRP_02", &"TRP_03", &"TRP_05", &"TRP_06", &"TRP_07", &"TRP_08"]:
		var card: BaseCard = CardRegistry.get_card(card_id)
		check(not card.can_play(state, 1, {"tile": 9}), "%s: 함정이 있는 칸에는 설치할 수 없다" % card_id)
		check(card.can_play(state, 1, {"tile": 10}), "%s: 빈 칸에는 설치할 수 있다" % card_id)
	var corner: int = BoardSpec.bonus_corner_tiles[0]
	state.place_attachment(corner, TrapMine.new(2))
	for card_id: StringName in [&"TRP_C01", &"TRP_C02", &"TRP_C03", &"TRP_C04"]:
		check(not CardRegistry.get_card(card_id).can_play(state, 1, {"tile": corner}), "%s: 코너에 함정이 있으면 설치할 수 없다" % card_id)
	var command := PlaceAttachmentCommand.new(1, 9, "TRP_07")
	command.state = state
	check(not command.can_execute(null), "명령도 겹쳐 설치를 거부한다")
	_dispose(manager)


## P1 말이 P2 말을 잡는다. P2는 방어 카드 card_id를 들고 있다.
func _capture_setup(manager: TurnManager, card_id: StringName) -> void:
	var state: GameState = manager.state
	place(state, 11, 1, [0])
	place(state, 21, 3, [2])
	state.give_card(2, card_id)
	_set_tool(manager, 1, ScriptedTool.new([2]))
	manager._begin_turn()
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})


func test_capture_opens_a_counter_offer_and_mirror_force_ejects_the_attacker() -> void:
	var manager: TurnManager = _new_manager()
	var events: Array = _collect_events(manager)
	var rejected: Array = _rejections(manager)
	_capture_setup(manager, &"CNT_02")
	check(manager.counter_pending(), "방어 대기")
	check_eq(int(manager.pending_counter()["victim"]), 2, "피해자 P2")
	check_eq(manager.pending_counter()["cards"], [&"CNT_02"], "낼 수 있는 방어 카드")
	check(events.any(func(e: Dictionary) -> bool: return e["kind"] == &"counter_offer"), "counter_offer 이벤트")
	_do(manager, 1, &"proceed")
	check_eq(rejected.back()[2], &"counter_pending", "방어 대기 중에는 다른 행동을 막는다")
	_do(manager, 2, &"play_card", {"card_id": &"CNT_02"})
	check_eq(manager.state.get_pawn(21).current_tile_idx, 3, "잡힌 말 복원")
	check(not manager.state.get_pawn(11).has_left_start, "공격한 말은 출발선으로")
	check(not manager.counter_pending(), "방어 대기 종료")
	check_eq(manager.state.stat(1, VictoryLaw.KILLS), 0, "처치 기록도 되돌린다")
	check_eq(manager.state.current_player, 2, "턴은 이어서 넘어간다")
	_dispose(manager)


## 2026-10-30 제보: 방어하자마자 투기장의 지배자 달성. 방어 카드의 되갚기 사출(거울의 힘·우노 리버스)은 처치가 아니다:
## 방어한 사람의 처치·하극상, 되갚기로 쫓겨난 공격자의 사출(동네북) 기록이 오르지 않는다. 막힌 공격의 기록도 모두 되돌린다.
func test_defending_never_counts_as_a_kill_for_special_victory() -> void:
	for card_id: StringName in [&"CNT_02"]:
		var manager: TurnManager = _new_manager()
		var state: GameState = manager.state
		state.rulebook.enqueue_law(LawRegistry.create("LAW_01"))
		state.rulebook.enqueue_law(LawRegistry.create("LAW_06"))
		var goal: int = (LawRegistry.create("LAW_01") as VictoryLaw).goal()
		state.add_stat(2, VictoryLaw.KILLS, goal - 1)  # 방어하는 P2가 한 번만 더 잡으면 투기장 달성
		_capture_setup(manager, card_id)
		check(manager.counter_pending(), "%s: 방어 대기" % card_id)
		check_eq(SpecialVictory.shown_progress(state, state.rulebook.active_laws_queue[0] as VictoryLaw, 1, int(manager.pending_counter()["attack"])), 0,
			"%s: 방어 대기 중인 처치는 화면 진행도에 넣지 않는다" % card_id)
		_do(manager, 2, &"play_card", {"card_id": card_id})
		check_eq(state.stat(1, VictoryLaw.KILLS), 0, "%s: 막힌 공격의 처치는 되돌린다" % card_id)
		check_eq(state.stat(2, VictoryLaw.EJECTED), 0, "%s: 막힌 공격의 사출도 되돌린다" % card_id)
		check_eq(state.stat(2, VictoryLaw.KILLS), goal - 1, "%s: 방어의 되갚기 사출은 방어한 사람의 처치가 아니다" % card_id)
		check_eq(state.stat(1, VictoryLaw.EJECTED), 0, "%s: 되갚기로 쫓겨난 공격자도 동네북 기록이 오르지 않는다" % card_id)
		check(not state.is_graduated(2), "%s: 방어했다고 투기장의 지배자를 달성하지 않는다" % card_id)
		check(not state.counter_retaliation, "%s: 되갚기 표시는 끝나면 내린다" % card_id)
		_dispose(manager)


## 우노 리버스가 공격자의 선두 말을 쫓아내도 방어한 사람의 처치·공격자의 사출 기록은 오르지 않는다.
func test_uno_reverse_ejection_is_not_a_kill() -> void:
	var state := make_state()
	state.rulebook.enqueue_law(LawRegistry.create("LAW_01"))
	state.rulebook.enqueue_law(LawRegistry.create("LAW_06"))
	place(state, 11, 9, [8])
	CounterCommand.reflect(state, {"attacker": 1, "card_id": &"ACT_01", "effects": {}}, 2)
	check(not state.get_pawn(11).has_left_start, "공격자의 선두 말은 출발선으로")
	check_eq(state.stat(2, VictoryLaw.KILLS), 0, "되갚기는 처치가 아니다")
	check_eq(state.stat(1, VictoryLaw.EJECTED), 0, "동네북 기록도 오르지 않는다")


## 법전으로 졸업해도 결과·스냅샷에는 졸업 직전의 실제 보드 상태와 달성한 법전 수치가 남는다 (말 철수·법전 삭제 전에 기록).
func test_graduation_keeps_the_real_board_and_the_achieved_law() -> void:
	var manager: TurnManager = _new_manager()
	var state: GameState = manager.state
	state.rulebook.enqueue_law(LawRegistry.create("LAW_01"))
	place(state, 11, 5, [4])
	state.add_stat(1, VictoryLaw.KILLS, (LawRegistry.create("LAW_01") as VictoryLaw).goal())
	manager._judge_special_victory()
	check(state.is_graduated(1) and state.rank_reasons[1] == &"LAW_01", "투기장으로 졸업")
	check(state.rulebook.active_laws_queue.is_empty(), "달성한 법전은 지워진다")
	var record: Dictionary = state.rank_stats[1]
	check_eq(int(record["finished"]), 0, "졸업 직전 실제 완주 수 (철수 뒤 '완주 4/4'가 아니다)")
	var first: Dictionary = (record["pawns"] as Array)[0]
	check(int(first["tile"]) == 5 and bool(first["started"]) and not bool(first["finished"]), "졸업 직전 말 위치")
	check_eq(record["law"], {"id": "LAW_01", "name":"투기장의 지배자", "value": 10, "goal": 10}, "달성한 법전과 수치")
	check(state.get_pawn(11).is_finished, "보드에서는 철수(완주 처리)")
	_dispose(manager)


func test_bites_the_dust_rewinds_the_attackers_turn_and_ends_it() -> void:
	var manager: TurnManager = _new_manager()
	_capture_setup(manager, &"CNT_01")
	check(manager.counter_pending(), "방어 대기")
	_do(manager, 2, &"play_card", {"card_id": &"CNT_01"})
	check_eq(manager.state.get_pawn(11).current_tile_idx, 1, "공격자 말 위치 복원")
	check_eq(manager.state.get_pawn(21).current_tile_idx, 3, "잡힌 말 복원")
	check((manager.state.hands[2] as Array).is_empty(), "방어 카드는 소모된 채")
	check_eq(manager.state.current_player, 2, "공격자의 턴이 끝나고 다음 사람 차례")
	_dispose(manager)


func test_passing_a_counter_offer_keeps_the_damage() -> void:
	var manager: TurnManager = _new_manager()
	_capture_setup(manager, &"CNT_04")
	_do(manager, 2, &"counter_pass")
	check(not manager.counter_pending(), "넘기면 진행")
	check_eq(manager.state.get_pawn(21).current_tile_idx, 0, "피해는 그대로")
	check_eq((manager.state.hands[2] as Array).size(), 1, "카드는 남는다")
	_dispose(manager)


func test_counter_cards_only_work_inside_the_victims_offer() -> void:
	var manager: TurnManager = _new_manager()
	var rejected: Array = _rejections(manager)
	manager.state.give_card(1, &"CNT_04")
	manager._begin_turn()
	_do(manager, 1, &"play_card", {"card_id": &"CNT_04"})
	check_eq(rejected.back(), [1, &"play_card", &"counter_only_when_attacked"], "공격받지 않았으면 방어 카드를 낼 수 없다")
	check_eq((manager.state.hands[1] as Array).size(), 1, "카드는 그대로")
	_dispose(manager)
	# 피격 팝업이 열렸어도 피해자가 아닌 사람은 낼 수 없고, 넘긴 뒤에는 그 공격에 소급해 낼 수 없다
	manager = _new_manager()
	rejected = _rejections(manager)
	manager.state.give_card(1, &"CNT_04")
	_capture_setup(manager, &"CNT_04")
	check(manager.counter_pending(), "P2에게 방어 대기")
	_do(manager, 1, &"play_card", {"card_id": &"CNT_04"})
	check(rejected.back()[0] == 1 and rejected.back()[1] == &"play_card" and (manager.state.hands[1] as Array).has(&"CNT_04"), "피해자가 아니면 거부 (%s)" % str(rejected.back()))
	_do(manager, 2, &"counter_pass")
	_do(manager, 2, &"play_card", {"card_id": &"CNT_04"})
	check_eq(rejected.back(), [2, &"play_card", &"counter_only_when_attacked"], "팝업을 넘긴 뒤에는 소급해 낼 수 없다")
	check_eq(manager.state.get_pawn(21).current_tile_idx, 0, "피해는 그대로")
	_dispose(manager)


func test_uno_reverse_reflects_a_bang_back_to_the_shooter() -> void:
	var manager: TurnManager = _new_manager()
	var state: GameState = manager.state
	place(state, 11, 5, [4])
	place(state, 21, 9, [8])
	state.give_card(1, &"ACT_02")
	state.give_card(2, &"CNT_03")
	_do(manager, 1, &"play_card", {"card_id": &"ACT_02", "target_player": 2})
	check(manager.counter_pending() and manager.current_state == Phase.PHASE_TURN_BEGIN, "뱅! 직후 턴 시작 단계에서 방어 대기")
	_do(manager, 2, &"play_card", {"card_id": &"CNT_03"})
	check_eq(state.get_pawn(21).current_tile_idx, 9, "내 말 복원")
	check(not state.get_pawn(11).has_left_start, "뱅!이 쏜 사람에게 반사")
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "공격자의 턴은 계속된다")
	_dispose(manager)


func test_trap_counters_cyclone_destroys_and_advances() -> void:
	var manager: TurnManager = _new_manager()
	var state: GameState = manager.state
	state.place_attachment(3, TrapSpike.new(2))
	state.give_card(1, &"CNT_05")
	place(state, 11, 1, [0])
	_set_tool(manager, 1, ScriptedTool.new([4]))
	manager._begin_turn()
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(state.get_pawn(11).current_tile_idx, 3, "스파이크에 멈췄다")
	check(manager.counter_pending() and int(manager.pending_counter()["victim"]) == 1, "내 턴에 걸린 함정도 방어할 수 있다")
	_do(manager, 1, &"play_card", {"card_id": &"CNT_05"})
	check(state.board.get_tile(3).attachments.is_empty(), "함정 파괴")
	check_eq(state.get_pawn(11).current_tile_idx, 3 + CardCounter.CYCLONE_STEPS, "+3칸 전진")
	_dispose(manager)


func test_ban_skip_stacked_deck_and_the_world() -> void:
	var manager: TurnManager = _new_manager()
	var state: GameState = manager.state
	var rejected: Array = _rejections(manager)
	state.give_card(1, &"ACT_14")
	state.give_card(2, &"ACT_04")
	_do(manager, 1, &"play_card", {"card_id": &"ACT_14", "target_player": 2})
	check(state.is_banned(2), "밴")
	_set_tool(manager, 1, ScriptedTool.new([1]))
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(state.current_player, 2, "P2 차례")
	_do(manager, 2, &"play_card", {"card_id": &"ACT_04"})
	check_eq(rejected.back()[2], &"banned", "밴 중에는 카드를 못 쓴다")
	_dispose(manager)
	var world: TurnManager = _new_manager()
	world.state.give_card(1, &"ACT_12")
	world.state.forced_roll[1] = 5
	_do(world, 1, &"play_card", {"card_id": &"ACT_12"})
	_set_tool(world, 1, ScriptedTool.new([1, 1]))
	_do(world, 1, &"proceed")
	_do(world, 1, &"roll")
	check_eq(world.move_queue, int_array([5]), "밑장빼기로 고른 결과")
	_do(world, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(world.state.current_player, 1, "더 월드: 한 턴 더")
	_dispose(world)
	var skip: TurnManager = _new_manager()
	skip.state.give_card(1, &"ACT_15")
	_do(skip, 1, &"play_card", {"card_id": &"ACT_15", "target_player": 2})
	_set_tool(skip, 1, ScriptedTool.new([1, 1]))
	_do(skip, 1, &"proceed")
	_do(skip, 1, &"roll")
	_do(skip, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(skip.state.current_player, 1, "우노 스킵: P2를 건너뛰고 다시 P1")
	_dispose(skip)


func _review_manager(players: int) -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = true
	manager.review_enabled = true
	tree.root.add_child(manager)
	var ids: Array[int] = []
	for i: int in range(1, players + 1):
		ids.append(i)
	manager.start_game(ids, 4242)
	return manager


## 증강 확인 단계: 모두 고른 뒤에도 바로 라운드를 시작하지 않고, 모두 [확인]을 누르면 그때 첫 차례가 열린다.
func test_augment_review_waits_for_every_player_before_the_round_starts() -> void:
	var manager: TurnManager = _review_manager(3)
	var events: Array = _collect_events(manager)
	check_eq(manager.current_state, Phase.PHASE_ROUND_START, "1라운드 드래프트")
	for player_id: int in [1, 2, 3]:
		_do(manager, player_id, &"pick_augment", {"index": 0, "pawn_id": player_id * 10 + 1})
	check(manager.review_pending(), "모두 골라도 확인 단계에 머문다")
	check_eq(manager.current_state, Phase.PHASE_ROUND_START, "아직 라운드 시작 전")
	check(events.any(func(e: Dictionary) -> bool: return e["kind"] == &"augment_review"), "확인 단계 알림")
	_do(manager, 2, &"review_done")
	_do(manager, 2, &"review_done")  # 두 번 눌러도 한 번만 센다
	check_eq(manager.review_waiting_for(), int_array([1, 3]), "P2 확인, P1·P3 대기")
	_do(manager, 1, &"review_done")
	check_eq(manager.current_state, Phase.PHASE_ROUND_START, "한 명이라도 남으면 기다린다")
	_do(manager, 3, &"review_done")
	check(not manager.review_pending(), "모두 확인")
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "모두 확인하면 첫 차례가 열린다")
	_dispose(manager)


func test_augment_review_times_out_and_is_off_by_default() -> void:
	var manager: TurnManager = _review_manager(2)
	for player_id: int in [1, 2]:
		_do(manager, player_id, &"pick_augment", {"index": 0, "pawn_id": player_id * 10 + 1})
	check(manager.review_pending(), "확인 단계")
	manager.tick(GameEnums.PHASE_TIME_REVIEW + 0.1)
	check(not manager.review_pending() and manager.current_state == Phase.PHASE_TURN_BEGIN, "시간이 다 되면 확인하지 않은 사람이 있어도 시작한다")
	_dispose(manager)
	var plain := TurnManager.new()
	check(not plain.review_enabled, "엔진 기본값은 확인 단계 없음 (화면이 있는 판에서만 켠다)")
	plain.free()
