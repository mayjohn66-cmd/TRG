# File: res://tests/test_duel.gd
# Class: class_name TestDuel
# Role: ACT_09 운명의 가위바위보 결투 검증 - 손 승패표, 대상 지목, 결투 중 행동 잠금, 비김 재대결과 판정승, 승자의 말 고르기(자동 선택 포함), 출발선 한계 후퇴, 도착 칸 함정 연쇄, 시간 초과
class_name TestDuel
extends TestCase

const Phase := TurnManager.State
const ROCK: int = 0
const SCISSORS: int = 1
const PAPER: int = 2


func _new_manager() -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	manager.set_process(false)
	var ids: Array[int] = [1, 2]
	manager.start_game(ids, 4242)
	return manager


func _dispose(manager: TurnManager) -> void:
	tree.root.remove_child(manager)
	manager.free()


func _do(manager: TurnManager, player_id: int, action: StringName, params: Dictionary = {}) -> void:
	var payload: Dictionary = params.duplicate()
	payload["player_id"] = player_id
	manager.act(action, payload)


func _events(manager: TurnManager) -> Array:
	var events: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void: events.append({"kind": kind, "data": data}))
	return events


func _rejections(manager: TurnManager) -> Array:
	var rejected: Array = []
	manager.action_rejected.connect(func(player_id: int, action: StringName, reason: StringName) -> void: rejected.append([player_id, action, reason]))
	return rejected


func _kinds(events: Array) -> Array:
	return events.map(func(entry: Dictionary) -> StringName: return entry["kind"])


## P1이 결투를 걸 준비: P1 손패에 카드, P2의 말 두 개를 보드 위에 올린다.
func _setup(manager: TurnManager, tiles: Array[int] = [10, 14]) -> void:
	manager.state.give_card(1, &"ACT_09")
	for index: int in tiles.size():
		place(manager.state, 21 + index, tiles[index], [tiles[index] - 1])


func _challenge(manager: TurnManager, target: int = 2) -> void:
	_do(manager, 1, &"play_card", {"card_id": &"ACT_09", "target_player": target})


func test_hand_matrix() -> void:
	check_eq(DuelRules.compare(ROCK, SCISSORS), 1, "바위 > 가위")
	check_eq(DuelRules.compare(SCISSORS, PAPER), 1, "가위 > 보")
	check_eq(DuelRules.compare(PAPER, ROCK), 1, "보 > 바위")
	check_eq(DuelRules.compare(SCISSORS, ROCK), -1, "가위 < 바위")
	check_eq(DuelRules.compare(PAPER, PAPER), 0, "같으면 비김")


func test_card_needs_an_opponent_pawn_on_the_board_and_defaults_to_the_leader() -> void:
	var state := make_state(3, 1)
	var card: BaseCard = CardRegistry.get_card(&"ACT_09")
	check(not card.could_play(state, 1), "보드 위에 나온 상대 말이 없으면 못 쓴다")
	check(not card.can_play(state, 1, {"target_player": 2}), "지목해도 말이 없으면 불가")
	place(state, 21, 5, [4])
	place(state, 31, 15, [14])
	check(card.can_play(state, 1, {"target_player": 2}), "말이 나와 있는 상대는 지목 가능")
	check(not card.can_play(state, 2, {"target_player": 2}), "자기 자신은 불가")
	check_eq(DuelRules.default_target(state, 1), 3, "대상을 안 고르면 가장 앞선 상대(P3)")
	var command: DuelCommand = card.create_command(state, 1, {}) as DuelCommand
	check_eq(command.target_player, 3, "자동 지목이 명령에 들어간다")


func test_challenger_wins_and_picks_which_pawn_to_eject() -> void:
	var manager: TurnManager = _new_manager()
	_setup(manager)
	var events: Array = _events(manager)
	_challenge(manager)
	check(manager.duel_pending(), "결투 시작")
	check_eq(manager.pending_duel()["step"], &"pick", "손 고르는 단계")
	check(manager.state.hands[1].is_empty(), "카드는 소모")
	var rejected: Array = _rejections(manager)
	_do(manager, 1, &"roll")
	_do(manager, 1, &"proceed")
	check_eq(rejected.size(), 2, "결투 중에는 굴리기·진행이 잠긴다")
	check_eq(rejected[0][2], &"duel_pending", "거절 이유")
	_do(manager, 1, &"duel_pick", {"hand": ROCK})
	_do(manager, 1, &"duel_pick", {"hand": PAPER})
	check_eq(rejected.size(), 3, "같은 손을 두 번 낼 수 없다")
	_do(manager, 2, &"duel_pick", {"hand": SCISSORS})
	check_eq(manager.pending_duel()["step"], &"strike", "이기면 말 고르는 단계 (후보 2개)")
	check_eq(manager.pending_duel()["winner"], 1, "신청자 승")
	_do(manager, 2, &"duel_strike", {"pawn_id": 21})
	check_eq(rejected.size(), 4, "진 사람은 말을 고를 수 없다")
	_do(manager, 1, &"duel_strike", {"pawn_id": 11})
	check_eq(rejected.size(), 5, "상대 말이 아니면 안 된다")
	_do(manager, 1, &"duel_strike", {"pawn_id": 22})
	check(not manager.duel_pending(), "결투 종료")
	check_eq(manager.state.get_pawn(22).current_tile_idx, 0, "고른 말이 14번에서 출발선으로 사출")
	check(not manager.state.get_pawn(22).has_left_start, "출발 대기 상태")
	check_eq(manager.state.get_pawn(21).current_tile_idx, 10, "다른 말은 그대로")
	check_eq(manager.state.get_pawn(11).current_tile_idx, 3, "승자의 말은 +3칸 전진 (출발 대기 말이 0 -> 3)")
	check(_kinds(events).has(&"duel_started") and _kinds(events).has(&"duel_revealed") and _kinds(events).has(&"duel_strike_wait") and _kinds(events).has(&"duel_resolved"), "결투 이벤트 순서")
	_do(manager, 1, &"proceed")
	check_eq(manager.current_state, Phase.PHASE_ROLL_WAIT, "결투가 끝나면 평소처럼 진행")
	_dispose(manager)


func test_defender_can_win_and_ejects_the_challengers_lead_pawn() -> void:
	var manager: TurnManager = _new_manager()
	_setup(manager)
	place(manager.state, 11, 8, [7])
	place(manager.state, 12, 3, [2])
	_challenge(manager)
	_do(manager, 1, &"duel_pick", {"hand": SCISSORS})
	_do(manager, 2, &"duel_pick", {"hand": ROCK})
	check_eq(manager.pending_duel()["winner"], 2, "상대가 이기면 역관광")
	check_eq(manager.pending_duel()["loser"], 1, "진 사람은 신청자")
	_do(manager, 2, &"duel_strike", {"pawn_id": 11})
	check_eq(manager.state.get_pawn(11).current_tile_idx, 0, "신청자의 말이 8번에서 출발선으로 사출")
	check_eq(manager.state.get_pawn(12).current_tile_idx, 3, "다른 말은 그대로")
	_dispose(manager)


func test_draws_rematch_and_two_draws_hand_the_win_to_the_challenger() -> void:
	var manager: TurnManager = _new_manager()
	_setup(manager)
	var events: Array = _events(manager)
	_challenge(manager)
	_do(manager, 1, &"duel_pick", {"hand": PAPER})
	_do(manager, 2, &"duel_pick", {"hand": PAPER})
	check(manager.duel_pending() and manager.pending_duel()["step"] == &"pick", "첫 무승부: 다시 고른다")
	check((manager.pending_duel()["picks"] as Dictionary).is_empty(), "손이 초기화")
	_do(manager, 1, &"duel_pick", {"hand": ROCK})
	_do(manager, 2, &"duel_pick", {"hand": ROCK})
	check_eq(manager.pending_duel()["winner"], 1, "연속 2번 비기면 신청자 판정승")
	var reveals: Array = events.filter(func(entry: Dictionary) -> bool: return entry["kind"] == &"duel_revealed")
	check_eq(reveals.size(), 2, "공개 이벤트 2번")
	check_eq(reveals[0]["data"]["winner"], -1, "첫 공개는 무승부")
	check_eq(reveals[1]["data"]["decided_by"], &"draws", "판정승 사유")
	_dispose(manager)


func test_single_candidate_is_pushed_automatically_and_start_line_is_the_limit() -> void:
	var manager: TurnManager = _new_manager()
	manager.state.give_card(1, &"ACT_09")
	place(manager.state, 21, 1, [0])
	_challenge(manager)
	_do(manager, 1, &"duel_pick", {"hand": PAPER})
	_do(manager, 2, &"duel_pick", {"hand": ROCK})
	check(not manager.duel_pending(), "말이 하나뿐이면 자동 선택되어 바로 끝난다")
	check(not manager.state.get_pawn(21).has_left_start and manager.state.get_pawn(21).current_tile_idx == 0, "1번 말은 출발선까지만 밀려 출발 전으로 돌아간다 (23번으로 넘어가지 않음)")
	_dispose(manager)


func test_loser_without_board_pawns_ends_the_duel_without_effect() -> void:
	var manager: TurnManager = _new_manager()
	manager.state.give_card(1, &"ACT_09")
	place(manager.state, 21, 5, [4])
	place(manager.state, 11, 0, [], false)
	_challenge(manager)
	_do(manager, 1, &"duel_pick", {"hand": ROCK})
	_do(manager, 2, &"duel_pick", {"hand": PAPER})
	check(not manager.duel_pending(), "밀 말이 없으면 효과 없이 끝난다")
	check_eq(manager.state.get_pawn(21).current_tile_idx, 5, "상대 말은 그대로")
	_dispose(manager)


func test_winner_boost_triggers_the_trap_on_the_landing_tile() -> void:
	var manager: TurnManager = _new_manager()
	manager.state.give_card(1, &"ACT_09")
	manager.state.place_attachment(8, TrapMirrorForce.new(2))
	place(manager.state, 11, 5, [4])
	place(manager.state, 22, 3, [2])
	var triggers: Array = []
	manager.state.attachment_triggered.connect(func(tile: int, id: String, pawn_id: int, _cutscene: StringName) -> void: triggers.append([tile, id, pawn_id]))
	_challenge(manager)
	_do(manager, 1, &"duel_pick", {"hand": ROCK})
	_do(manager, 2, &"duel_pick", {"hand": SCISSORS})
	_do(manager, 1, &"duel_strike", {"pawn_id": 22})
	check_eq(triggers, [[8, "TRP_01", 11]], "승자의 말이 +3칸 착지한 8번의 거울의 힘이 터진다")
	check(not manager.state.get_pawn(11).has_left_start, "함정에 걸려 출발선으로 돌아간다")
	_dispose(manager)


func test_winner_boost_passes_through_its_own_trap() -> void:
	var manager: TurnManager = _new_manager()
	manager.state.give_card(1, &"ACT_09")
	manager.state.place_attachment(8, TrapMirrorForce.new(1))  # P1의 함정: P1의 말에는 발동하지 않는다
	place(manager.state, 11, 5, [4])
	place(manager.state, 22, 3, [2])
	_challenge(manager)
	_do(manager, 1, &"duel_pick", {"hand": ROCK})
	_do(manager, 2, &"duel_pick", {"hand": SCISSORS})
	_do(manager, 1, &"duel_strike", {"pawn_id": 22})
	check_eq(manager.state.get_pawn(11).current_tile_idx, 8, "자기 함정은 무사 통과")
	check(manager.state.get_pawn(11).has_left_start, "출발선으로 가지 않는다")
	_dispose(manager)


func test_timeout_picks_random_hands_and_pushes_the_leading_pawn() -> void:
	var manager: TurnManager = _new_manager()
	_setup(manager)
	_challenge(manager)
	check(manager.phase_time_left > 0.0, "결투 손 고르기에는 제한 시간이 있다")
	var serial: int = manager.phase_serial
	manager.force_timeout()
	var guard: int = 0
	while manager.duel_pending() and guard < 12:
		manager.force_timeout()
		guard += 1
	check(not manager.duel_pending(), "시간 초과만으로 결투가 끝까지 진행된다")
	check(manager.phase_serial != serial, "단계가 바뀔 때마다 직렬 번호가 오른다")
	_dispose(manager)


func test_non_participants_cannot_pick() -> void:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	manager.set_process(false)
	var ids: Array[int] = [1, 2, 3]
	manager.start_game(ids, 4242)
	manager.state.give_card(1, &"ACT_09")
	place(manager.state, 21, 5, [4])
	var rejected: Array = _rejections(manager)
	_do(manager, 1, &"play_card", {"card_id": &"ACT_09", "target_player": 2})
	_do(manager, 3, &"duel_pick", {"hand": ROCK})
	check_eq(rejected, [[3, &"duel_pick", &"not_your_duel"]], "제3자는 손을 낼 수 없다")
	_dispose(manager)


func test_duel_state_roundtrips_through_the_sync_payload() -> void:
	var manager: TurnManager = _new_manager()
	_setup(manager)
	_challenge(manager)
	_do(manager, 1, &"duel_pick", {"hand": ROCK})
	var payload: Dictionary = manager._build_sync_payload()
	check_eq((payload["duel"] as Dictionary)["step"], &"pick", "동기화 페이로드에 결투 상태")
	check_eq(((payload["duel"] as Dictionary)["picks"] as Dictionary).size(), 1, "먼저 낸 손도 포함")
	_dispose(manager)


func test_bots_play_a_whole_duel_by_themselves() -> void:
	var manager: TurnManager = _new_manager()
	_setup(manager)
	var controller := BotController.new()
	controller.manager = manager
	controller.bot_players = [1, 2] as Array[int]
	controller.instant = true
	controller.enabled = true
	controller.rng.seed = 7
	defer_free(controller)
	_challenge(manager)
	var guard: int = 0
	while manager.duel_pending() and guard < 40:
		controller.tick(0.1)
		guard += 1
	check(not manager.duel_pending(), "봇끼리의 결투가 손 고르기부터 말 밀어내기까지 끝난다 (%d틱)" % guard)
	_dispose(manager)
