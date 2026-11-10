# File: res://tests/test_trpg_cards.gd
# Class: class_name TestTrpgCards
# Role: TRPG 확장 카드 6종 - 비상 식량(CNT_09)·펭짱 8호(ACT_21)·긴급 엄폐(ACT_22)·전문적 해킹(ACT_23)·목둔 사탕수수밭(TRP_09)·황금장방형 팽이(SUM_04) 엔진 검증
class_name TestTrpgCards
extends TestCase


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
	for id: StringName in [&"CNT_09", &"ACT_21", &"ACT_22", &"ACT_23", &"TRP_09", &"SUM_04"]:
		check(CardRegistry.get_card(id) != null, "%s 등록" % id)
		check(CardRegistry.is_enabled(id), "%s 켜짐" % id)
		check(CardRegistry.default_deck().has(id), "%s 기본 덱에 있다" % id)
		check(GameData.text("cards", id, "name") != "", "%s 표에 이름" % id)
	check_eq(CardRegistry.type_of(&"ACT_21"), "INSTANT", "펭짱 8호는 즉발")
	check_eq(CardRegistry.type_of(&"TRP_09"), "TRAP", "사탕수수밭은 함정")
	check_eq(CardRegistry.type_of(&"SUM_04"), "SUMMON", "팽이는 소환")
	check_eq(CardRegistry.type_of(&"CNT_09"), "COUNTER", "비상 식량은 방어")
	check_eq(CardRegistry.get_card(&"CNT_09").category, GameEnums.CardCategory.COUNTER, "방어 카드 분류")
	check(CardCounter.kind_label(&"CNT_09") == "잡기 방어", "[잡기 방어]")


func test_emergency_rations_blocks_a_capture_and_draws_a_card() -> void:
	var manager := _manager()
	var state: GameState = manager.state
	place(state, 11, 1, [0])
	place(state, 21, 3, [2])
	state.hands[2] = [&"CNT_09"]
	state.tools[1] = ScriptedTool.new([2])
	manager._begin_turn()
	manager.act(&"proceed", {"player_id": 1})
	manager.act(&"roll", {"player_id": 1})
	manager.act(&"select_pawn", {"player_id": 1, "pawn_id": 11})
	check(manager.counter_pending(), "잡기가 방어 창을 연다")
	check_eq(manager.pending_counter().get("cards"), [&"CNT_09"], "비상 식량이 방어 카드로 제시된다")
	var hand_before: int = (state.hands[2] as Array).size()
	manager.act(&"play_card", {"player_id": 2, "card_id": &"CNT_09"})
	check(not manager.counter_pending(), "창이 닫힌다")
	check(not state.has_card(2, &"CNT_09"), "방어 카드는 소모된다")
	check(state.get_pawn(21).has_left_start and state.get_pawn(21).current_tile_idx == 3, "잡기를 막아 말이 제자리")
	check_eq((state.hands[2] as Array).size(), hand_before - 1 + 1, "카드 한 장을 얻는다 (낸 한 장 대신 새 한 장)")
	check(state.get_pawn(11).has_left_start, "공격자는 사출되지 않는다 (되갚기 없음)")
	_dispose(manager)


func test_emergency_cover_gives_a_ward_with_a_box_that_breaks_once() -> void:
	var state := make_state()
	place(state, 11, 4, [3])
	place(state, 12, 0, [], false)
	var card := CardRegistry.get_card(&"ACT_22")
	check(card.could_play(state, 1), "보드 위 말이 있으면 쓸 수 있다")
	check(card.can_play(state, 1, {"pawn_id": 11}), "보드 위 내 말")
	check(not card.can_play(state, 1, {"pawn_id": 12}), "출발선 대기 말은 안 된다")
	check(not card.can_play(state, 1, {"pawn_id": 21}), "남의 말은 안 된다")
	var command: GameCommand = card.create_command(state, 1, {"pawn_id": 11})
	command.bind_state(state)
	check(command.can_execute(RuleContext.new()), "실행 가능")
	command.execute()
	var pawn: PlayerPawn = state.get_pawn(11)
	check(pawn.ward and pawn.ward_box, "택배 박스를 쓴 보호막")
	check(not card.can_play(state, 1, {"pawn_id": 11}), "이미 보호막이 있는 말에는 다시 쓸 수 없다")
	check(state.break_shield(pawn) and not pawn.ward and not pawn.ward_box, "한 번 막으면 박스가 벗겨진다")
	var snapshot: Dictionary = state.pawn_state(pawn)
	check(snapshot.has("ward_box"), "공격 기록에 박스 상태도 들어간다")


func test_professional_hacking_auto_plays_the_targets_next_turn() -> void:
	var manager := _manager()
	var state: GameState = manager.state
	var card := CardRegistry.get_card(&"ACT_23")
	check(card.can_play(state, 1, {"target_player": 2}) and not card.can_play(state, 1, {"target_player": 1}), "대상은 다른 플레이어")
	var command: GameCommand = card.create_command(state, 1, {"target_player": 2})
	command.bind_state(state)
	command.execute()
	check_eq(int(state.hacked_turns.get(2, 0)), 1, "해킹 한 번이 쌓인다")
	# 1번 턴을 넘겨 2번 차례가 오면 그 턴은 해킹 턴이다
	manager.advance_to_next_player()
	check_eq(manager.state.current_player, 2, "2번 차례")
	check_eq(int(state.hacked_turns.get(2, 0)), 0, "해킹은 그 턴 시작에 소모된다")
	check(manager._hack_turn_player == 2, "2번의 이번 턴이 해킹 턴")
	check(manager.phase_time_left <= TurnManager.HACK_AUTO_SECONDS + 0.001, "각 단계가 짧은 대기 뒤 자동으로 넘어간다")
	manager.act(&"play_card", {"player_id": 2, "card_id": &"ACT_14", "target_player": 1})
	check(not state.is_banned(1), "해킹 턴에는 카드를 쓸 수 없다")
	manager.force_timeout()  # 턴 시작 → 굴림 대기
	manager.force_timeout()  # 자동 굴림
	var guard := 0
	while manager.state.current_player == 2 and guard < 20:
		manager.force_timeout()
		guard += 1
	check_eq(manager.state.current_player, 1, "자동 진행으로 그 턴이 끝나고 1번에게 넘어간다")
	check(manager._hack_turn_player == -1, "다음 턴에는 해킹이 풀린다")
	_dispose(manager)


func test_sugarcane_field_stops_every_pawn_that_steps_on_it() -> void:
	var state := make_state()
	var trap := AttachmentRegistry.create("TRP_09")
	state.place_attachment(6, trap)
	trap.owner_id = 1
	var mine: PlayerPawn = place(state, 11, 3, [2])
	var report: MoveReport = move(state, 11, 5)  # 4,5,6(밭)...
	check_eq(state.get_pawn(11).current_tile_idx, 6, "내 말도 밭에서 멈춘다")
	check(report.stopped_early, "이동이 중단됐다")
	check(state.board.get_tile(6).has_trap(), "함정은 사라지지 않는다")
	place(state, 21, 4, [3])
	var foe_report: MoveReport = move(state, 21, 4)
	check_eq(state.get_pawn(21).current_tile_idx, 6, "적 말도 멈춘다")
	check(foe_report.stopped_early, "적 이동도 중단")
	for turn: int in 3:
		trap.tick_turn()
	check(trap.is_expired(), "설치자의 턴이 3번 지나면 시든다")


func test_golden_top_walks_to_the_nearest_enemy_and_blasts_the_tile() -> void:
	var state := make_state()
	var halfway: int = BoardSpec.halfway_tile
	var npc: NeutralNPC = state.spawn_npc(halfway, GameEnums.NpcBehavior.CHASE_NEAREST, 1, NpcSweep.TOP_ID)
	place(state, 21, halfway + 3, [halfway + 2])  # 정방향 3칸 앞의 적 말
	place(state, 22, halfway - 5, [halfway - 6])  # 역방향 5칸 뒤의 적 말 (더 멀다)
	place(state, 11, halfway + 3, [halfway + 2])  # 같은 칸에 내 말도 있다 (함께 날아간다)
	check(npc.is_top(), "팽이")
	check_eq(NpcSweep.top_direction(state, npc), 1, "가까운 쪽(정방향)을 향한다")
	var first: Dictionary = npc.run_ai(state)
	check_eq(int(first["path"][0]), halfway + 1, "한 라운드에 한 칸")
	check(not bool(first["vanished"]) and (first["caught"] as Array).is_empty(), "아직 부딪히지 않았다")
	var second: Dictionary = npc.run_ai(state)
	check(not bool(second["vanished"]), "두 번째 칸")
	var third: Dictionary = npc.run_ai(state)
	check(bool(third["vanished"]), "말이 있는 칸에 부딪히면 사라진다")
	check((third["caught"] as Array).has(21) and (third["caught"] as Array).has(11), "그 칸의 모든 말(내 말 포함)이 날아간다")
	check(not state.get_pawn(21).has_left_start and not state.get_pawn(11).has_left_start, "출발선으로 돌아갔다")
	check(state.get_pawn(22).has_left_start, "다른 칸의 말은 그대로")


func test_golden_top_card_summons_one_neutral_piece_at_the_top_corner() -> void:
	var state := make_state()
	var card := CardRegistry.get_card(&"SUM_04")
	check(card.needs_tile() and card.could_play(state, 1), "상단 코너를 골라 소환")
	check(card.can_play(state, 1, {"tile": BoardSpec.halfway_tile}) and not card.can_play(state, 1, {"tile": 3}), "소환 칸은 반환점")
	var command: GameCommand = card.create_command(state, 1, {"tile": BoardSpec.halfway_tile})
	command.bind_state(state)
	command.execute()
	check_eq(state.npcs.size(), 1, "팽이가 소환됐다")
	check(not card.could_play(state, 1), "중립 기물은 하나만")


func test_penguin_flies_like_alkkagi_and_ejects_the_enemies_it_hits() -> void:
	var state := make_state()
	var origin: PlayerPawn = place(state, 11, 4, [3])
	var target_tile: int = 8
	place(state, 21, target_tile, [7])
	var card := CardRegistry.get_card(&"ACT_21")
	check(card.could_play(state, 1), "보드 위 말이 있으면 쓸 수 있다")
	var from: Vector2 = BoardLayout.tile_norm(origin.current_tile_idx)
	var to: Vector2 = BoardLayout.tile_norm(target_tile)
	var angle: float = (to - from).angle()
	var shot: Dictionary = PawnSkills.shot_result(state, origin, angle, 1.0)
	check((shot["hits"] as Array).has(21), "겨눈 쪽에 적 말이 걸린다")
	var params: Dictionary = {"pawn_id": 11, "angle": angle, "power": 1.0}
	check(card.can_play(state, 1, params), "사용 가능")
	check(not card.can_play(state, 1, {"pawn_id": 11}), "각도·세기가 없으면 안 된다")
	var command: GameCommand = card.create_command(state, 1, params)
	command.bind_state(state)
	command.execute()
	check(not state.get_pawn(21).has_left_start, "맞은 적 말은 출발선으로 날아갔다")
	check(state.get_pawn(11).has_left_start and state.get_pawn(11).current_tile_idx == 4, "내 말은 움직이지 않는다")
