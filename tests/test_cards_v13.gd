# File: res://tests/test_cards_v13.gd
# Class: class_name TestCardsV13
# Role: 1.3 신규 카드 7종 엔진 검증 - 뾰족한 성게(TRP_10)·이프리트의 분노(TRP_C05)·피라 대출(ACT_24)·회유책(ACT_25)·수은 가드(ACT_26)·민트초코(CNT_10)·긴급수리(CNT_11)
class_name TestCardsV13
extends TestCase

const NEW_CARDS: Array[StringName] = [&"TRP_10", &"TRP_C05", &"ACT_24", &"ACT_25", &"ACT_26", &"CNT_10", &"CNT_11"]


func _manager(players: int = 2) -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	var ids: Array[int] = []
	for i: int in range(1, players + 1):
		ids.append(i)
	manager.start_game(ids, 4242)
	return manager


func _dispose(manager: TurnManager) -> void:
	tree.root.remove_child(manager)
	manager.free()


func test_new_cards_are_registered_with_table_rows_and_deck_copies() -> void:
	for id: StringName in NEW_CARDS:
		check(CardRegistry.get_card(id) != null, "%s 등록" % id)
		check(CardRegistry.is_enabled(id), "%s 켜짐" % id)
		check(CardRegistry.default_deck().has(id), "%s 기본 덱에 있다" % id)
		check(GameData.text("cards", id, "name") != "", "%s 표에 이름" % id)
		check(ResourceLoader.exists("res://assets/cards/%s.png" % id), "%s 카드 그림" % id)
	check_eq(CardRegistry.type_of(&"TRP_10"), "TRAP", "성게는 함정")
	check_eq(CardRegistry.type_of(&"TRP_C05"), "TRAP_CORNER", "이프리트는 코너 함정")
	check(CardRegistry.get_card(&"TRP_C05").corner_only, "이프리트는 코너에만")
	for id: StringName in [&"CNT_10", &"CNT_11"]:
		check_eq(CardRegistry.get_card(id).category, GameEnums.CardCategory.COUNTER, "%s 방어 카드" % id)
		check_eq(CardCounter.kind_label(id), "공격 방어", "%s [공격 방어]" % id)
	for id: String in ["TRP_10", "TRP_C05"]:
		check(AttachmentRegistry.create(id) != null, "%s 설치물" % id)


func test_spiky_urchin_stops_only_fast_passing_enemies() -> void:
	var state := make_state()
	var trap := AttachmentRegistry.create("TRP_10")
	trap.owner_id = 1
	state.place_attachment(6, trap)
	place(state, 21, 3, [2])
	move(state, 21, 3)  # 4,5,6 도착: 도착 칸이면 멈출 필요가 없다
	check_eq(state.get_pawn(21).current_tile_idx, 6, "도착은 그대로")
	check(state.board.get_tile(6).has_trap(), "도착으로는 발동하지 않는다")
	place(state, 21, 4, [3])
	move(state, 21, 3)  # 눈금 3으로 지나간다
	check_eq(state.get_pawn(21).current_tile_idx, 7, "눈금 3으로 지나가면 걸리지 않는다")
	place(state, 21, 4, [3])
	var report: MoveReport = move(state, 21, 5)  # 눈금 5로 지나간다
	check_eq(state.get_pawn(21).current_tile_idx, 6, "눈금 4 이상으로 지나가면 성게 칸에 멈춘다")
	check(report.stopped_early, "이동이 끊긴다")
	check(not state.board.get_tile(6).has_trap(), "1회용")
	var mine := AttachmentRegistry.create("TRP_10")
	mine.owner_id = 1
	state.place_attachment(10, mine)
	place(state, 11, 8, [7])
	move(state, 11, 5)
	check_eq(state.get_pawn(11).current_tile_idx, 13, "내 말은 걸리지 않는다")


func test_ifrit_burns_a_card_every_time_an_enemy_passes() -> void:
	var state := make_state()
	var corner: int = BoardSpec.corner_tiles[1]
	var trap := AttachmentRegistry.create("TRP_C05")
	trap.owner_id = 1
	state.place_attachment(corner, trap)
	check(not trap.is_hidden_trap, "공개 함정")
	state.hands[2] = [&"ACT_02", &"ACT_04", &"ACT_12"]
	var burned: Array = []
	state.card_burned.connect(func(player_id: int, card_id: StringName, tile: int) -> void: burned.append([player_id, card_id, tile]))
	place(state, 21, corner - 2, [corner - 3])
	move(state, 21, 4)
	check_eq((state.hands[2] as Array).size(), 2, "지나가면 카드 1장이 탄다")
	check_eq(state.get_pawn(21).current_tile_idx, corner + 2, "말은 멈추지 않는다")
	check(state.board.get_tile(corner).has_trap(), "불꽃은 남는다 (여러 번)")
	place(state, 21, corner - 1, [corner - 2])
	move(state, 21, 1)
	check_eq((state.hands[2] as Array).size(), 1, "멈춰도 1장 더 탄다")
	check_eq(burned.size(), 2, "탈 때마다 알린다")
	check(state.card_deck.has(burned[0][1]), "탄 카드는 덱으로 돌아간다")
	state.hands[1] = [&"ACT_02"]
	place(state, 11, corner - 1, [corner - 2])
	move(state, 11, 2)
	check_eq((state.hands[1] as Array).size(), 1, "내 말은 타지 않는다")
	state.hands[2] = []
	place(state, 21, corner - 1, [corner - 2])
	move(state, 21, 2)
	check_eq(burned.size(), 2, "태울 카드가 없으면 아무 일도 없다")
	for turn: int in 3:
		trap.tick_turn()
	check(trap.is_expired(), "설치자의 턴 3번 뒤 꺼진다")


func test_pira_loan_adds_nine_now_and_takes_three_for_three_turns() -> void:
	var manager := _manager()
	var state: GameState = manager.state
	place(state, 11, 1, [0])
	state.hands[1] = [&"ACT_24"]
	state.tools[1] = ScriptedTool.new([2, 5, 1, 6, 6])
	state.tools[2] = ScriptedTool.new([3, 3, 3, 3])
	manager._begin_turn()
	manager.act(&"play_card", {"player_id": 1, "card_id": &"ACT_24"})
	check(not state.has_card(1, &"ACT_24"), "카드를 썼다")
	check(not CardRegistry.get_card(&"ACT_24").could_play(state, 1), "갚는 중에는 또 빌릴 수 없다")
	manager.act(&"proceed", {"player_id": 1})
	manager.act(&"roll", {"player_id": 1})
	check_eq(manager.move_queue, [11], "이번 굴림 2 + 9 = 11칸")
	var repaid: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"loan_repaid":
			repaid.append([int(data["from"]), int(data["to"])]))
	for turn: int in 4:
		_next_turn_of(manager, 1)
		manager.force_timeout()  # 턴 시작 → 굴림 대기
		manager.act(&"roll", {"player_id": 1})
	check_eq(repaid, [[5, 2], [1, 1], [6, 3]], "다음 내 턴 3번의 첫 굴림 -3칸 (최소 1칸), 4번째 턴부터는 그대로")
	check_eq(int(state.loan_debt.get(1, 0)), 0, "3번 갚으면 끝")
	_dispose(manager)


## 지금 차례를 끝까지 넘겨 player의 다음 차례 시작(TURN_BEGIN)까지 진행한다.
func _next_turn_of(manager: TurnManager, player: int) -> void:
	var guard: int = 0
	while manager.state.current_player == player and guard < 60:
		manager.force_timeout()
		guard += 1
	while not (manager.state.current_player == player and manager.current_state == TurnManager.State.PHASE_TURN_BEGIN) and guard < 160:
		manager.force_timeout()
		guard += 1


func test_appeasement_offers_to_lift_ban_skip_and_hack() -> void:
	# 스킵: 창이 뜨고, 쓰면 차례를 정상 진행
	var manager := _manager()
	var state: GameState = manager.state
	state.rest_next_turn[2] = true
	state.hands[2] = [&"ACT_25", &"ACT_04"]
	manager.advance_to_next_player()
	check_eq(state.current_player, 2, "스킵이 미뤄져 2번 차례가 시작된다")
	check(manager.appease_pending(), "회유책 창")
	manager.act(&"roll", {"player_id": 2})
	check(manager.appease_pending(), "창이 떠 있는 동안 다른 행동은 받지 않는다")
	manager.act(&"play_card", {"player_id": 2, "card_id": &"ACT_25"})
	check(not manager.appease_pending() and not bool(state.rest_next_turn.get(2, false)), "스킵이 풀린다")
	check(state.current_player == 2 and manager.current_state == TurnManager.State.PHASE_TURN_BEGIN, "그대로 내 차례")
	manager.act(&"play_card", {"player_id": 2, "card_id": &"ACT_04"})
	check(not state.has_card(2, &"ACT_04"), "회유책은 턴당 1장에 세지 않는다 (다른 카드도 낼 수 있다)")
	_dispose(manager)
	# 스킵 + 그냥 두기: 바로 쉰다
	manager = _manager()
	state = manager.state
	state.rest_next_turn[2] = true
	state.hands[2] = [&"ACT_25"]
	manager.advance_to_next_player()
	manager.act(&"appease_pass", {"player_id": 2})
	check_eq(state.current_player, 1, "그냥 두면 스킵된다")
	check(state.has_card(2, &"ACT_25"), "카드는 남는다")
	_dispose(manager)
	# 밴: 밴 중에도 회유책은 낼 수 있다
	manager = _manager()
	state = manager.state
	state.banned_turns[2] = 2
	state.hands[2] = [&"ACT_25"]
	manager.advance_to_next_player()
	check(manager.appease_pending(), "밴도 창을 띄운다")
	manager.act(&"play_card", {"player_id": 2, "card_id": &"ACT_25"})
	check(not state.is_banned(2), "밴이 풀린다")
	_dispose(manager)
	# 해킹: 쓰면 이번 해킹 턴도 풀린다
	manager = _manager()
	state = manager.state
	state.hacked_turns[2] = 1
	state.hands[2] = [&"ACT_25"]
	manager.advance_to_next_player()
	check(manager.appease_pending() and manager.is_hack_turn(2), "해킹 턴에 창")
	check(manager.phase_time_left > TurnManager.HACK_AUTO_SECONDS, "창이 떠 있는 동안은 짧은 자동 진행 시간이 아니다")
	manager.act(&"play_card", {"player_id": 2, "card_id": &"ACT_25"})
	check(not manager.is_hack_turn(2), "해킹이 풀린다")
	_dispose(manager)
	# 시간 초과 = 그냥 두기
	manager = _manager()
	state = manager.state
	state.rest_next_turn[2] = true
	state.hands[2] = [&"ACT_25"]
	manager.advance_to_next_player()
	manager.force_timeout()
	check_eq(state.current_player, 1, "시간이 다 되면 그냥 두기 (스킵)")
	_dispose(manager)
	# 디버프가 없으면 창도 없고 낼 수도 없다
	manager = _manager()
	state = manager.state
	state.hands[2] = [&"ACT_25"]
	manager.advance_to_next_player()
	check(not manager.appease_pending(), "디버프가 없으면 창이 없다")
	check(not CardRegistry.get_card(&"ACT_25").could_play(state, 2), "디버프가 없으면 쓸 수 없다")
	_dispose(manager)


func test_mercury_guard_blocks_one_attack_card_ejection_only() -> void:
	var state := make_state()
	place(state, 21, 9, [8])
	var card := CardRegistry.get_card(&"ACT_26")
	check(card.can_play(state, 2, {"pawn_id": 21}) and not card.can_play(state, 2, {"pawn_id": 11}), "내 보드 위 말에만")
	var command: GameCommand = card.create_command(state, 2, {"pawn_id": 21})
	command.bind_state(state)
	command.execute()
	var pawn: PlayerPawn = state.get_pawn(21)
	check(pawn.mercury, "수은 보호막")
	check(not card.can_play(state, 2, {"pawn_id": 21}), "이미 있는 말에는 다시 못 씌운다")
	state.begin_attack({"kind": &"capture", "attacker": 1})
	state.send_to_start(pawn, 1)
	state.end_attack()
	check(not pawn.has_left_start, "잡기는 막지 않는다")
	place(state, 21, 9, [8])
	pawn.mercury = true
	state.begin_attack({"kind": &"card", "card_id": &"ACT_02", "attacker": 1})
	state.send_to_start(pawn, 1)
	state.end_attack()
	check(pawn.has_left_start and pawn.current_tile_idx == 9 and not pawn.mercury, "공격 카드 사출을 1회 막고 사라진다")
	state.begin_attack({"kind": &"card", "card_id": &"ACT_02", "attacker": 1})
	state.send_to_start(pawn, 1)
	state.end_attack()
	check(not pawn.has_left_start, "두 번째는 못 막는다")
	check(state.pawn_state(pawn).has("mercury"), "공격 기록·동기화에 수은 상태가 들어간다")


func _bang_counter(counter_id: StringName) -> Array:
	var manager := _manager()
	var state: GameState = manager.state
	place(state, 21, 9, [8])
	state.hands[1] = [&"ACT_02"]
	state.hands[2] = [counter_id]
	manager._begin_turn()
	manager.act(&"play_card", {"player_id": 1, "card_id": &"ACT_02", "target_player": 2})
	return [manager, state]


func test_mint_chocolate_blocks_an_attack_card_and_draws() -> void:
	var pair: Array = _bang_counter(&"CNT_10")
	var manager: TurnManager = pair[0]
	var state: GameState = pair[1]
	check(manager.counter_pending(), "BANG!이 방어 창을 연다")
	check_eq(manager.pending_counter().get("cards"), [&"CNT_10"], "민트초코가 제시된다")
	manager.act(&"play_card", {"player_id": 2, "card_id": &"CNT_10"})
	check(state.get_pawn(21).has_left_start and state.get_pawn(21).current_tile_idx == 9, "사출을 막아 제자리")
	check_eq((state.hands[2] as Array).size(), 1, "민트초코를 내고 카드 1장을 얻는다")
	check(not state.has_card(2, &"CNT_10"), "방어 카드는 소모")
	_dispose(manager)


func test_emergency_repair_blocks_an_attack_card_and_takes_it() -> void:
	var pair: Array = _bang_counter(&"CNT_11")
	var manager: TurnManager = pair[0]
	var state: GameState = pair[1]
	check(manager.counter_pending(), "BANG!이 방어 창을 연다")
	manager.act(&"play_card", {"player_id": 2, "card_id": &"CNT_11"})
	check(state.get_pawn(21).has_left_start, "사출을 막는다")
	check_eq(state.hands[2], [&"ACT_02"], "막은 BANG! 카드를 내 손패로 가져온다")
	_dispose(manager)
	# 잡기는 막지 못한다 (공격 방어)
	manager = _manager()
	state = manager.state
	place(state, 11, 1, [0])
	place(state, 21, 3, [2])
	state.hands[2] = [&"CNT_10", &"CNT_11"]
	state.tools[1] = ScriptedTool.new([2])
	manager._begin_turn()
	manager.act(&"proceed", {"player_id": 1})
	manager.act(&"roll", {"player_id": 1})
	manager.act(&"select_pawn", {"player_id": 1, "pawn_id": 11})
	check(not manager.counter_pending(), "잡기에는 공격 방어 카드를 낼 수 없다")
	_dispose(manager)
