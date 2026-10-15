# File: res://tests/test_bot.gd
# Class: class_name TestBot
# Role: AI 대전 모드의 봇 - BotBrain 휴리스틱(말 선택 점수·증강·함정 타일·개입 카드·룰렛)과 BotController의 대기 시간·개입 창 자동 넘김·드래프트·전체 판 시뮬레이션 검증
class_name TestBot
extends TestCase

const Kind := GameEnums.PawnKind


func _manager(player_count: int = 2, draft: bool = false, loadouts: Dictionary = {}) -> TurnManager:
	var manager := TurnManager.new()
	manager.hotseat_mode = true
	manager.draft_enabled = draft
	tree.root.add_child(manager)
	manager.set_process(false)
	var ids: Array[int] = []
	for i: int in range(1, player_count + 1):
		ids.append(i)
	manager.start_game(ids, 4242, loadouts)
	return manager


func _dispose(manager: TurnManager) -> void:
	tree.root.remove_child(manager)
	manager.free()


func _controller(manager: TurnManager, bots: Array[int], instant: bool = false) -> BotController:
	var controller := BotController.new()
	controller.manager = manager
	controller.bot_players = bots
	controller.instant = instant
	controller.enabled = true
	controller.rng.seed = 99
	defer_free(controller)
	return controller


func _seeded(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# --- 말 선택 점수 -----------------------------------------------------------------

func test_pawn_choice_follows_goal_then_capture_then_stop_spot_then_advance() -> void:
	var state := make_state(2, 1)
	place(state, 11, 18, [17])           # 눈금 2: 19, 0 -> 결승 완주
	place(state, 12, 2, [1])             # 3, 4 -> 4번의 적을 잡음
	place(state, 13, 3, [2])             # 4, 5 -> 코너(5번)에 정확히 멈춤
	place(state, 14, 0, [], false)       # 출발선 대기 말 꺼내기
	place(state, 21, 4, [3])
	var goal: float = BotBrain.score_move(state, state.get_pawn(11), 2)
	var capture: float = BotBrain.score_move(state, state.get_pawn(12), 2)
	var corner: float = BotBrain.score_move(state, state.get_pawn(13), 2)
	var fresh: float = BotBrain.score_move(state, state.get_pawn(14), 2)
	check(goal > capture and capture > corner and corner > fresh, "완주 > 잡기 > 코너 > 새 말 (%.1f %.1f %.1f %.1f)" % [goal, capture, corner, fresh])
	check_eq(BotBrain.choose_pawn(state, 1, 2), 11, "완주 가능한 말이 1순위")
	place(state, 11, 5, [4])             # 완주 후보를 없앤다 (눈금 2로는 6, 7)
	state.get_pawn(11).has_left_start = true
	check_eq(BotBrain.choose_pawn(state, 1, 2), 12, "다음은 적을 잡을 수 있는 말")
	place(state, 21, 9, [8])
	check_eq(BotBrain.choose_pawn(state, 1, 2), 13, "다음은 코너에 멈출 수 있는 말")


func test_bakery_stop_and_scoring_does_not_change_the_game_state() -> void:
	var state := make_state(2, 1)
	place(state, 11, 1, [0])   # 눈금 2: 2, 3 -> 빵집(3번)
	place(state, 13, 0, [], false)
	state.rulebook.enqueue_law(LawRegistry.create("LAW_06"))
	var events: Array = []
	state.rulebook.law_applied.connect(func(_law: LawResource, _timing: String, _before: int, _after: int, _modified: bool) -> void: events.append(true))
	var tile_before: int = state.get_pawn(11).current_tile_idx
	var history_before: Array[int] = state.get_pawn(11).step_history.duplicate()
	var bakery: float = BotBrain.score_move(state, state.get_pawn(11), 2)
	var plain: float = BotBrain.score_move(state, state.get_pawn(13), 2)
	check(bakery >= BotBrain.SCORE_STOP_SPOT, "빵집에 멈추면 +40 이상 (%.1f)" % bakery)
	check(plain < bakery, "출발선 대기 말(+20)보다 빵집 정차가 높다 (%.1f < %.1f)" % [plain, bakery])
	check_eq(state.get_pawn(11).current_tile_idx, tile_before, "점수 계산은 말을 움직이지 않는다")
	check_eq(state.get_pawn(11).step_history, history_before, "이동 이력도 그대로")
	check_eq(events.size(), 0, "법전 미리보기(Dry-Run)는 law_applied 시그널을 내지 않는다")


func test_capture_scoring_ignores_immune_enemies_and_the_start_tile() -> void:
	var state := make_state(2, 1, {2: [Vector2i(Kind.GO, 1), Vector2i(Kind.GO, 2), 0, 0]})
	place(state, 21, 4, [3])  # 바둑 2세트 포석: 잡을 수 없다
	check(not BotBrain.has_capturable_enemy(state, state.get_pawn(11), 4), "무적인 적은 잡기 후보가 아니다")
	check(not BotBrain.has_capturable_enemy(state, state.get_pawn(11), 0), "출발선은 안전")
	var plain := make_state(2, 1)
	place(plain, 21, 4, [3])
	check(BotBrain.has_capturable_enemy(plain, plain.get_pawn(11), 4), "일반 적은 잡을 수 있다")


# --- 증강 드래프트 ----------------------------------------------------------------

func test_augment_choice_prefers_completing_an_owned_set() -> void:
	var state := make_state(2, 1, {2: [Vector2i(Kind.CHESS, 1), 0, 0, 0]})
	var rng: RandomNumberGenerator = _seeded(1)
	var offers: Array[StringName] = [&"TOOL_YUT", &"EVO_%d_2" % Kind.CHESS, &"AUG_LAW_01"]
	check_eq(BotBrain.choose_augment(state, 2, offers, rng), 1, "보유한 체스 세트를 2세트로 완성하는 진화가 1순위")
	var four := make_state(2, 1, {2: [Vector2i(Kind.GO, 1), Vector2i(Kind.GO, 2), Vector2i(Kind.GO, 3), 0]})
	var offers_four: Array[StringName] = [&"CARD_PACKAGE", &"AUG_LAW_01", &"EVO_%d_2" % Kind.GO]
	check_eq(BotBrain.choose_augment(four, 2, offers_four, rng), 2, "4세트 완성도 1순위")
	var other_set: Array[StringName] = [&"TOOL_YUT", &"EVO_%d_1" % Kind.JANGGI, &"AUG_LAW_01"]
	check_eq(BotBrain.choose_augment(state, 2, other_set, rng), 0, "이미 다른 세트를 가졌다면 새 세트를 흩뿌리지 않고 판정 도구를 고른다")
	var no_evo: Array[StringName] = [&"CARD_PACKAGE", &"AUG_LAW_01", &"TOOL_HOLDEM"]
	check_eq(BotBrain.choose_augment(state, 2, no_evo, rng), 2, "진화가 없으면 판정 도구 교체가 교칙보다 먼저")
	var first_set := make_state()
	var start: Array[StringName] = [&"CARD_PACKAGE", &"AUG_LAW_01", &"EVO_%d_1" % Kind.YUT]
	check_eq(BotBrain.choose_augment(first_set, 2, start, rng), 2, "아직 세트가 하나도 없으면 첫 세트를 시작한다 (그렇지 않으면 봇이 영원히 기본 말뿐)")


func test_evolution_pawn_choice_is_the_front_most_basic_pawn() -> void:
	var state := make_state()
	place(state, 22, 9, [8])
	place(state, 23, 4, [3])
	check_eq(BotBrain.choose_evolution_pawn(state, 2), 22, "가장 앞선 기본 말을 진화시킨다")


# --- 함정·소환 카드 -----------------------------------------------------------------

func test_trap_tiles_target_the_path_ahead_of_the_leading_enemy_or_corners() -> void:
	var state := make_state(3, 1)
	place(state, 11, 12, [11])  # P1의 선두 말 (결승까지 가장 가까움)
	place(state, 31, 3, [2])
	check_eq(BotBrain.leading_enemy(state, 2).entity_id, 11, "선두 상대 말")
	var allowed: Array[int] = [13, 14, 15, 16, 5, 10, 22]
	var card: BaseCard = CardRegistry.get_card(&"TRP_02")
	for seed_value: int in 20:
		var tile: int = BotBrain.choose_card_tile(state, 2, card, _seeded(seed_value))
		check(allowed.has(tile), "함정은 선두 말 앞 1~4칸 길목이나 코너에 놓는다 (%d)" % tile)
		check(card.can_play(state, 2, {"tile": tile}), "카드가 허용하는 타일")
	var island: BaseCard = CardRegistry.get_card(&"TRP_04")
	var island_tile: int = BotBrain.choose_card_tile(state, 2, island, _seeded(1))
	check([5, 10, 15].has(island_tile), "무인도는 코너에만 (%d)" % island_tile)


func test_turn_card_plans_use_traps_about_sixty_percent_of_the_time() -> void:
	var state := make_state(2, 1)
	place(state, 11, 8, [7])
	var hits: int = 0
	var trials: int = 400
	for seed_value: int in trials:
		state.hands[2] = [&"TRP_01"] as Array[StringName]
		var tried: Dictionary = {}
		var plan: Dictionary = BotBrain.plan_turn_card(state, 2, tried, _seeded(seed_value + 1))
		check(tried.has(&"TRP_01"), "검토한 카드는 tried에 기록된다")
		if not plan.is_empty():
			hits += 1
			check(((plan["params"] as Dictionary).has("tile")) and plan["card_id"] == &"TRP_01", "타일이 정해진 계획")
	var ratio: float = float(hits) / float(trials)
	check(ratio > 0.5 and ratio < 0.7, "함정 사용 확률은 약 60%% (%.2f)" % ratio)
	var again: Dictionary = {&"TRP_01": true}
	state.hands[2] = [&"TRP_01"] as Array[StringName]
	check(BotBrain.plan_turn_card(state, 2, again, _seeded(1)).is_empty(), "이미 검토한 카드는 다시 쓰지 않는다")


func test_window_card_reverse_only_against_a_humans_high_roll() -> void:
	var state := make_state(2, 1)
	state.hands[2] = [&"ACT_01"] as Array[StringName]
	var phase: int = TurnManager.State.PHASE_INTERRUPT_ROLL
	var used: int = 0
	for seed_value: int in 40:
		var plan: Dictionary = BotBrain.plan_window_card(state, 2, phase, 6, false, 1, {}, _seeded(seed_value))
		if not plan.is_empty():
			used += 1
			check_eq(plan["card_id"], &"ACT_01", "고눈금에는 역주행으로 끼어든다")
	check(used > 15, "P1이 6을 굴리면 자주 끼어든다 (%d/40)" % used)
	for seed_value: int in 40:
		check(BotBrain.plan_window_card(state, 2, phase, 3, false, 1, {}, _seeded(seed_value)).is_empty(), "낮은 눈금에는 개입하지 않는다")
		check(BotBrain.plan_window_card(state, 2, phase, 6, true, 3, {}, _seeded(seed_value)).is_empty(), "봇의 턴에는 개입하지 않는다")


func test_window_card_rollback_when_the_bot_was_hurt() -> void:
	var state := make_state(2, 1)
	state.hands[2] = [&"ACT_05"] as Array[StringName]
	state.turn_snapshot = TurnSnapshot.capture(state)
	check(BotBrain.plan_window_card(state, 2, TurnManager.State.PHASE_RESOLUTION, 0, false, 1, {}, _seeded(1)).is_empty(), "다치지 않았으면 쓰지 않는다")
	state.hurt_players.append(2)
	var plan: Dictionary = BotBrain.plan_window_card(state, 2, TurnManager.State.PHASE_RESOLUTION, 0, false, 1, {}, _seeded(1))
	check_eq(plan.get("card_id", &""), &"ACT_05", "말이 잡혔다면 되감기")


func test_roulette_stops_after_two_or_three_pulls() -> void:
	var tool := ToolRussianRoulette.new()
	tool.load_chamber(5)
	check(not BotBrain.should_stop_roulette(tool, 2), "아직 당기지 않았다")
	tool.accumulated = 3
	check(not BotBrain.should_stop_roulette(tool, 2), "1회 당김: 계속")
	tool.accumulated = 6
	check(BotBrain.should_stop_roulette(tool, 2), "2회 당김: 멈춤")
	check(not BotBrain.should_stop_roulette(tool, 3), "목표가 3회면 계속")
	tool.accumulated = 9
	check(BotBrain.should_stop_roulette(tool, 3), "3회 당김: 멈춤")
	check(not BotBrain.should_stop_roulette(ToolDiceD6.new(), 2), "룰렛이 아니면 해당 없음")


# --- BotController: 대기 시간 ------------------------------------------------------

func test_bot_turn_follows_the_documented_pacing() -> void:
	var manager: TurnManager = _manager(2)
	manager.advance_to_next_player()  # P2(봇)의 턴 시작
	check_eq(manager.current_player_id(), 2, "봇 턴")
	var controller: BotController = _controller(manager, [2])
	manager.state.tools[2] = ScriptedTool.new([2])
	controller.tick(0.0)
	check_eq(manager.current_state, TurnManager.State.PHASE_TURN_BEGIN, "턴 시작 직후에는 행동하지 않는다")
	controller.tick(0.45)
	check_eq(manager.current_state, TurnManager.State.PHASE_TURN_BEGIN, "0.5초 전에는 카드/함정 판단 전")
	controller.tick(0.1)
	check_eq(manager.current_state, TurnManager.State.PHASE_ROLL_WAIT, "0.5초 뒤 판단을 마치고 굴리러 진행")
	controller.tick(0.2)
	check_eq(manager.current_state, TurnManager.State.PHASE_ROLL_WAIT, "굴리기 직전 잠깐 대기")
	controller.tick(0.2)
	check(manager.current_state != TurnManager.State.PHASE_ROLL_WAIT, "굴렸다")
	var before: int = manager.state.get_pawn(21).current_tile_idx
	controller.tick(0.5)
	check_eq(manager.state.get_pawn(21).current_tile_idx, before, "굴림 결과를 확인하는 0.6초 동안은 말을 움직이지 않는다")
	controller.tick(0.7)
	controller.tick(0.6)
	check_eq(manager.state.get_pawn(21).current_tile_idx, 2, "대기 뒤 말을 옮긴다")
	check_eq(manager.current_player_id(), 1, "봇의 턴이 끝나면 사람(P1)의 턴")
	_dispose(manager)


func test_instant_bots_act_once_per_tick_without_waiting() -> void:
	var manager: TurnManager = _manager(2)
	manager.advance_to_next_player()
	var controller: BotController = _controller(manager, [2], true)
	manager.state.tools[2] = ScriptedTool.new([2])
	controller.tick(0.0)
	check_eq(manager.current_state, TurnManager.State.PHASE_ROLL_WAIT, "instant: 첫 틱에 바로 진행")
	controller.tick(0.0)
	var guard: int = 0
	while manager.current_player_id() == 2 and guard < 20:
		controller.tick(0.0)
		guard += 1
	check_eq(manager.current_player_id(), 1, "instant: 대기 없이 턴을 끝냄")
	check_eq(manager.state.get_pawn(21).current_tile_idx, 2, "이동 완료")
	_dispose(manager)


func test_bots_do_nothing_on_the_humans_turn_or_when_disabled() -> void:
	var manager: TurnManager = _manager(2)
	var controller: BotController = _controller(manager, [2], true)
	for i: int in 5:
		controller.tick(1.0)
	check_eq(manager.current_state, TurnManager.State.PHASE_TURN_BEGIN, "사람의 턴에는 봇이 움직이지 않는다")
	manager.advance_to_next_player()
	controller.set_enabled(false)
	for i: int in 5:
		controller.tick(1.0)
	check_eq(manager.current_state, TurnManager.State.PHASE_TURN_BEGIN, "끄면 봇의 차례여도 멈춘다")
	controller.set_enabled(true)
	controller.tick(0.0)
	check(manager.current_state != TurnManager.State.PHASE_TURN_BEGIN or controller._wait == 0.0, "다시 켜면 즉시 행동을 이어 간다")
	_dispose(manager)


func test_busy_check_pauses_the_bots_while_a_roll_animation_plays() -> void:
	var manager: TurnManager = _manager(2)
	manager.advance_to_next_player()
	var controller: BotController = _controller(manager, [2], true)
	var busy: Array = [true]
	controller.busy_check = func() -> bool: return busy[0]
	for i: int in 5:
		controller.tick(1.0)
	check_eq(manager.current_state, TurnManager.State.PHASE_TURN_BEGIN, "연출 중에는 기다린다")
	busy[0] = false
	controller.tick(0.0)
	check(manager.current_state != TurnManager.State.PHASE_TURN_BEGIN, "연출이 끝나면 진행")
	_dispose(manager)


# --- BotController: 개입 창 / 업기 / 드래프트 -----------------------------------------

func _human_roll_to_window(manager: TurnManager) -> void:
	manager.state.tools[1] = ScriptedTool.new([2])
	manager.act(&"proceed", {"player_id": 1})
	manager.act(&"roll", {"player_id": 1})


func test_intervention_window_closes_by_itself_when_the_human_has_no_card() -> void:
	var manager: TurnManager = _manager(2)
	manager.state.rulebook.enqueue_law(LawRegistry.create("LAW_04"))
	manager.state.give_card(2, &"ACT_06")  # 법전이 있으니 봇에게 개입 창이 열린다
	_human_roll_to_window(manager)
	check_eq(manager.current_state, TurnManager.State.PHASE_INTERRUPT_ROLL, "개입 창이 열림")
	var controller: BotController = _controller(manager, [2])
	controller.tick(0.0)
	controller.tick(0.5)  # 봇이 고민(낼 카드 없음)
	check_eq(manager.current_state, TurnManager.State.PHASE_INTERRUPT_ROLL, "봇 판단 직후에는 아직 열려 있다")
	controller.tick(0.7)
	check_eq(manager.current_state, TurnManager.State.PHASE_INTERRUPT_ROLL, "0.8초가 지나기 전")
	controller.tick(0.2)
	check_eq(manager.current_state, TurnManager.State.PHASE_SELECT_PAWN, "0.8초 뒤 P1이 패스를 누르지 않아도 자동으로 넘어간다")
	_dispose(manager)


func test_intervention_window_waits_for_a_human_who_holds_a_playable_card() -> void:
	var manager: TurnManager = _manager(2)
	manager.state.give_card(1, &"ACT_01")  # P1이 낼 수 있는 개입 카드
	manager.state.give_card(2, &"ACT_06")
	manager.state.rulebook.enqueue_law(LawRegistry.create("LAW_04"))
	_human_roll_to_window(manager)
	var controller: BotController = _controller(manager, [2], true)
	for i: int in 10:
		controller.tick(1.0)
	check_eq(manager.current_state, TurnManager.State.PHASE_INTERRUPT_ROLL, "P1에게 [카드 사용 / 패스] 선택 시간을 준다")
	manager.force_timeout()  # P1이 패스를 누른 것
	check_eq(manager.current_state, TurnManager.State.PHASE_SELECT_PAWN, "패스하면 진행")
	_dispose(manager)


func test_bot_reverses_a_human_high_roll_when_it_holds_the_card() -> void:
	var used: int = 0
	for seed_value: int in 12:
		var manager: TurnManager = _manager(2)
		manager.state.give_card(2, &"ACT_01")
		manager.state.tools[1] = ScriptedTool.new([6])
		manager.act(&"proceed", {"player_id": 1})
		manager.act(&"roll", {"player_id": 1})
		var controller: BotController = _controller(manager, [2], true)
		controller.rng.seed = seed_value + 1
		for i: int in 4:
			controller.tick(0.0)
		if manager.state.reverse_move_rounds_left > 0:
			used += 1
		_dispose(manager)
	check(used >= 4, "봇이 P1의 6에 우노 리버스로 끼어든다 (%d/12)" % used)


func test_bots_choose_stacking_for_yut_pawns() -> void:
	var manager: TurnManager = _manager(2, false, {2: [Vector2i(Kind.YUT, 1), Vector2i(Kind.CHESS, 1), 0, 0]})
	manager.stack_choice_enabled = true
	manager.advance_to_next_player()
	place(manager.state, 22, 4, [3])
	place(manager.state, 21, 2, [1])
	for pawn_id: int in [22, 23, 24]:
		manager.state.get_pawn(pawn_id).blocked_this_turn = true  # 윷 말 하나만 움직일 수 있게 한다
	manager.state.tools[2] = ScriptedTool.new([2])
	var controller: BotController = _controller(manager, [2], true)
	var guard: int = 0
	while manager.current_player_id() == 2 and guard < 30:
		controller.tick(0.0)
		guard += 1
	check_eq(manager.state.get_pawn(22).carrier, manager.state.get_pawn(21), "봇은 업기 선택에서 [업기]를 고른다")
	_dispose(manager)


func test_bots_draft_after_the_human_has_picked() -> void:
	var manager: TurnManager = _manager(3, true)
	var controller: BotController = _controller(manager, [2, 3], true)
	check_eq(manager.current_state, TurnManager.State.PHASE_ROUND_START, "1라운드 드래프트")
	for i: int in 5:
		controller.tick(0.0)
	check_eq(manager.draft_pending_players().size(), 3, "P1이 고르기 전에는 봇도 고르지 않는다")
	manager.act(&"pick_augment", {"player_id": 1, "index": 0})
	for i: int in 5:
		controller.tick(0.0)
	check(manager.current_state != TurnManager.State.PHASE_ROUND_START, "P1이 고르면 봇들이 차례로 골라 드래프트가 끝난다")
	for player_id: int in [2, 3]:
		check_eq((manager.augments[player_id] as Array).size(), 1, "P%d가 증강을 골랐다" % player_id)
	_dispose(manager)


# --- 전체 판 시뮬레이션 -------------------------------------------------------------

func test_four_bots_finish_whole_games_without_getting_stuck() -> void:
	for seed_value: int in [1, 2, 3]:
		var manager := TurnManager.new()
		manager.hotseat_mode = true
		manager.draft_enabled = true
		manager.stack_choice_enabled = true
		tree.root.add_child(manager)
		manager.set_process(false)
		manager.start_game([1, 2, 3, 4] as Array[int], seed_value * 1000 + 7)
		var controller: BotController = _controller(manager, [1, 2, 3, 4], true)
		controller.rng.seed = seed_value
		var ticks: int = 0
		while not manager.is_game_over and ticks < 60000:
			controller.tick(0.0)
			ticks += 1
		check(manager.is_game_over, "시드 %d: 봇끼리 한 판이 끝까지 진행된다 (%d틱, 라운드 %d)" % [seed_value, ticks, manager.state.round_number])
		check(manager.state.winner != -1, "시드 %d: 승자가 있다" % seed_value)
		_dispose(manager)
