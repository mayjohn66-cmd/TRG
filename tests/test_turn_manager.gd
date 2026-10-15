# File: res://tests/test_turn_manager.gd
# Class: class_name TestTurnManager
# Role: 8단계 턴 상태 머신·타이머·재굴림·러시안 룰렛 흐름·개입 LIFO·ACT_04/05·드래프트·호스트 권위(명세 1·4·5·7) 통합 검증
class_name TestTurnManager
extends TestCase

const Phase := TurnManager.State


func _new_manager(player_count: int = 2, hotseat: bool = true, loadouts: Dictionary = {}) -> TurnManager:
	var manager := TurnManager.new()
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


func test_reroll_queues_multiple_moves_each_with_its_own_pawn_choice() -> void:
	var manager: TurnManager = _new_manager()
	_set_tool(manager, 1, ScriptedTool.new([ScriptedTool.reroll_of(4), 2]))
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	check_eq(manager.current_state, Phase.PHASE_ROLL_WAIT, "재굴림이면 다시 굴림 대기")
	_do(manager, 1, &"roll")
	check_eq(manager.current_state, Phase.PHASE_SELECT_PAWN, "재굴림 종료 후 선택")
	check_eq(manager.move_queue, int_array([4, 2]), "눈금 대기열")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(manager.current_state, Phase.PHASE_SELECT_PAWN, "대기열이 남아 있으면 다시 기물 선택")
	_do(manager, 1, &"select_pawn", {"pawn_id": 12})
	check_eq(manager.state.get_pawn(11).current_tile_idx, 4, "첫 눈금")
	check_eq(manager.state.get_pawn(12).current_tile_idx, 2, "둘째 눈금")
	check_eq(manager.state.current_player, 2, "턴 종료")
	_dispose(manager)


func test_law_pipeline_modifies_roll_before_move() -> void:
	var manager: TurnManager = _new_manager()
	add_law(manager.state, &"LAW_06")
	_set_tool(manager, 1, ScriptedTool.new([6]))
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	check_eq(manager.move_queue, int_array([1]), "LAW_06이 6을 1로 고정")
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
	check_eq(manager.state.get_pawn(11).current_tile_idx, 6, "6칸 전진")
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


func test_stack_choice_is_skipped_for_non_yut_pawns_law_02_and_headless_default() -> void:
	var plain: TurnManager = _new_manager()
	plain.stack_choice_enabled = true
	place(plain.state, 12, 4, [3])
	place(plain.state, 11, 2, [1])
	_set_tool(plain, 1, ScriptedTool.new([2]))
	_do(plain, 1, &"proceed")
	_do(plain, 1, &"roll")
	_do(plain, 1, &"select_pawn", {"pawn_id": 11})
	check(not plain.stack_offer_pending(), "일반 기물은 선택을 묻지 않음")
	_dispose(plain)
	var sealed: TurnManager = _new_manager(2, true, {1: [Vector2i(GameEnums.PawnKind.YUT, 1), 0, 0, 0]})
	sealed.stack_choice_enabled = true
	add_law(sealed.state, &"LAW_02")
	place(sealed.state, 12, 4, [3])
	place(sealed.state, 11, 2, [1])
	_set_tool(sealed, 1, ScriptedTool.new([2]))
	_do(sealed, 1, &"proceed")
	_do(sealed, 1, &"roll")
	_do(sealed, 1, &"select_pawn", {"pawn_id": 11})
	check(not sealed.stack_offer_pending() and sealed.state.get_pawn(12).carrier == null, "LAW_02가 있으면 제안 자체가 없음")
	_dispose(sealed)
	var auto: TurnManager = _new_manager(2, true, {1: [Vector2i(GameEnums.PawnKind.YUT, 1), 0, 0, 0]})
	place(auto.state, 12, 4, [3])
	place(auto.state, 11, 2, [1])
	_set_tool(auto, 1, ScriptedTool.new([2]))
	_do(auto, 1, &"proceed")
	_do(auto, 1, &"roll")
	_do(auto, 1, &"select_pawn", {"pawn_id": 11})
	check(not auto.stack_offer_pending() and auto.state.get_pawn(12).carrier == auto.state.get_pawn(11), "기본(헤드리스/AI)은 선택 없이 자동 업기")
	_dispose(auto)


func test_cards_are_only_played_before_the_roll_and_once_per_turn() -> void:
	var manager: TurnManager = _new_manager()
	var rejected: Array = _rejections(manager)
	add_law(manager.state, &"LAW_02")
	add_law(manager.state, &"LAW_05")
	manager.state.give_card(1, &"ACT_06")
	manager.state.give_card(1, &"ACT_06")
	manager.state.give_card(2, &"ACT_06")
	_set_tool(manager, 1, ScriptedTool.new([2]))
	_do(manager, 1, &"play_card", {"card_id": &"ACT_06", "law_id": "LAW_02"})
	check(not manager.state.rulebook.has_law(&"LAW_02"), "굴리기 전에는 카드가 바로 실행된다")
	check(manager.card_played_this_turn(), "이번 턴 카드 사용 기록")
	_do(manager, 1, &"play_card", {"card_id": &"ACT_06", "law_id": "LAW_05"})
	check_eq(rejected.size(), 1, "굴리기 전 카드는 턴당 1장")
	check_eq(rejected[0][2], &"card_limit", "거부 사유는 카드 한도")
	check(manager.state.rulebook.has_law(&"LAW_05"), "두 번째 카드는 실행되지 않음")
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	check_eq(manager.current_state, Phase.PHASE_SELECT_PAWN, "손패가 있어도 굴림 뒤 개입 창은 열리지 않는다")
	_do(manager, 2, &"play_card", {"card_id": &"ACT_06", "law_id": "LAW_05"})
	check_eq(rejected.back()[2], &"not_playable_now", "굴림 뒤에는 (ACT_05를 빼고) 카드를 낼 수 없다")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	_do(manager, 2, &"proceed")
	check(not manager.card_played_this_turn(), "새 턴에는 카드 사용 기록이 초기화된다")
	_dispose(manager)


func test_card_requires_phase_ownership_and_valid_target() -> void:
	var manager: TurnManager = _new_manager()
	var rejected: Array = _rejections(manager)
	manager.state.give_card(2, &"TRP_01")
	manager.state.give_card(1, &"TRP_01")
	_do(manager, 2, &"play_card", {"card_id": &"TRP_01", "tile": 9})  # 내 턴 아님
	_do(manager, 1, &"play_card", {"card_id": &"TRP_01", "tile": 0})  # 잘못된 대상
	_do(manager, 1, &"play_card", {"card_id": &"ACT_06", "law_id": "LAW_01"})  # 손패에 없음
	_do(manager, 1, &"play_card", {"card_id": &"TRP_01", "tile": 9})  # 정상
	check_eq(rejected.size(), 3, "비정상 요청 3건 거부")
	check(manager.state.board.get_tile(9).has_attachment(&"TRP_01"), "정상 요청은 설치")
	check((manager.state.hands[1] as Array).is_empty(), "사용한 카드 소모")
	_dispose(manager)


func test_uno_reverse_card_reverses_turn_order() -> void:
	var manager: TurnManager = _new_manager(3)
	manager.state.give_card(1, &"ACT_01")
	_do(manager, 1, &"play_card", {"card_id": &"ACT_01"})
	check_eq(manager.turn_direction, -1, "역순")
	_set_tool(manager, 1, ScriptedTool.new([1]))
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	check_eq(manager.move_queue, int_array([1]), "눈금")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(manager.state.current_player, 3, "1번 다음은 3번")
	check_eq(manager.state.get_pawn(11).current_tile_idx, 19, "역주행이라 양수 눈금도 출발선에서 19번으로 후퇴")
	_dispose(manager)


func test_act_05_rolls_back_turn_restores_laws_but_keeps_spent_cards() -> void:
	var manager: TurnManager = _new_manager()
	var state: GameState = manager.state
	place(state, 11, 2, [1])
	place(state, 21, 4, [3])
	add_law(state, &"LAW_06")
	state.give_card(2, &"ACT_05")
	state.give_card(1, &"ACT_06")
	_set_tool(manager, 1, ScriptedTool.new([2]))
	manager._begin_turn()  # 위 세팅을 이번 턴 시작 시점으로 저장
	_do(manager, 1, &"play_card", {"card_id": &"ACT_06", "law_id": "LAW_06"})  # 굴리기 전에 법전 파기
	check(not state.rulebook.has_law(&"LAW_06"), "법전 파기됨")
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	check_eq(manager.current_state, Phase.PHASE_SELECT_PAWN, "굴림 뒤 개입 창 없이 바로 기물 선택")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(manager.current_state, Phase.PHASE_RESOLUTION, "ACT_05 대기 창")
	check_eq(state.get_pawn(21).current_tile_idx, 0, "잡힘")
	_do(manager, 2, &"play_card", {"card_id": &"ACT_05"})
	manager.tick(GameEnums.PHASE_TIME_RESOLUTION + 0.1)
	check_eq(state.get_pawn(11).current_tile_idx, 2, "내 말 위치 복원")
	check_eq(state.get_pawn(21).current_tile_idx, 4, "잡힌 말 복원")
	check(state.rulebook.has_law(&"LAW_06"), "법전 큐도 턴 시작 시점으로 복원")
	check((state.hands[2] as Array).is_empty(), "ACT_05 카드는 소모된 채")
	check((state.hands[1] as Array).is_empty(), "이번 턴 소모한 카드는 복구되지 않음")
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "같은 플레이어의 턴이 처음부터 다시")
	check_eq(state.current_player, 1, "같은 플레이어")
	_dispose(manager)


func test_act_05_cannot_be_played_by_unharmed_player() -> void:
	var manager: TurnManager = _new_manager()
	var rejected: Array = _rejections(manager)
	manager.state.give_card(2, &"ACT_05")
	manager.state.give_card(1, &"ACT_05")
	place(manager.state, 11, 2, [1])
	place(manager.state, 21, 4, [3])
	_set_tool(manager, 1, ScriptedTool.new([2]))
	manager._begin_turn()
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(manager.current_state, Phase.PHASE_RESOLUTION, "피해를 입은 P2가 ACT_05를 낼 수 있어 창이 열린다")
	_do(manager, 1, &"play_card", {"card_id": &"ACT_05"})
	check_eq(rejected.size(), 1, "피해 없는 플레이어의 ACT_05는 거부")
	_dispose(manager)


func test_intervention_window_stays_closed_when_nobody_can_use_their_cards() -> void:
	var manager: TurnManager = _new_manager()
	manager.state.give_card(2, &"ACT_05")  # 피해자가 없으면 쓸 수 없는 카드
	manager.state.give_card(1, &"TRP_01")  # 턴 시작 구간에서만 쓰는 카드
	_set_tool(manager, 1, ScriptedTool.new([2]))
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	check_eq(manager.current_state, Phase.PHASE_SELECT_PAWN, "낼 수 있는 카드가 없으면 개입 창을 건너뛴다")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "정산 창도 건너뛰고 다음 턴")
	_dispose(manager)


func test_act_04_finishes_a_pawn_that_backed_off_to_the_last_tile() -> void:
	var manager: TurnManager = _new_manager()
	manager.state.give_card(1, &"ACT_04")
	_set_tool(manager, 1, ScriptedTool.new([-1]))
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	check_eq(manager.current_state, Phase.PHASE_SELECT_PAWN, "굴림 뒤 개입 창 없음")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(manager.state.get_pawn(11).current_tile_idx, 19, "0번에서 빽도 후퇴는 19번")
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "ACT_04는 정산 창이 아니라 다음 내 턴의 굴리기 전에 쓴다")
	manager.state.hands[1] = [&"ACT_04"] as Array[StringName]
	manager.state.current_player = 1
	manager.current_turn_index = manager.player_order.find(1)
	manager._begin_turn()
	_do(manager, 1, &"play_card", {"card_id": &"ACT_04", "pawn_id": 11})
	check(manager.state.get_pawn(11).is_finished, "ACT_04로 즉시 완주")
	_dispose(manager)


func test_all_pawns_home_declares_winner_and_stops_game() -> void:
	var manager: TurnManager = _new_manager()
	var finished_signal: Array = []
	manager.game_over.connect(func(winner_id: int, reason: StringName) -> void: finished_signal.append([winner_id, reason]))
	for slot: int in [2, 3, 4]:
		manager.state.finish_stack(manager.state.get_pawn(10 + slot))
	place(manager.state, 11, 18, [17])
	_set_tool(manager, 1, ScriptedTool.new([2]))
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check(manager.is_game_over, "게임 종료")
	check_eq(finished_signal, [[1, &"all_home"]], "승자/사유")
	check_eq(manager.state.winner, 1, "승자 기록")
	_dispose(manager)


func test_yut_four_stack_special_victory_via_turn_manager() -> void:
	var manager: TurnManager = _new_manager(2, true, {1: [Vector2i(GameEnums.PawnKind.YUT, 1), Vector2i(GameEnums.PawnKind.YUT, 2), Vector2i(GameEnums.PawnKind.YUT, 3), Vector2i(GameEnums.PawnKind.YUT, 4)]})
	var state: GameState = manager.state
	for slot: int in [1, 2, 3, 4]:
		place(state, 10 + slot, 18, [17])
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


func test_uno_reverse_card_flips_turn_direction_through_signal() -> void:
	var manager: TurnManager = _new_manager(3)
	manager.state.give_card(1, &"ACT_01")
	_do(manager, 1, &"play_card", {"card_id": &"ACT_01"})
	check_eq(manager.turn_direction, -1, "카드 실행이 TurnManager 방향을 뒤집음")
	check_eq(manager.state.reverse_move_rounds_left, 1, "이동 역주행 1라운드")
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
