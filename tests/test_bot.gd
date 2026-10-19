# File: res://tests/test_bot.gd
# Class: class_name TestBot
# Role: AI 대전 모드의 봇 - BotBrain 휴리스틱(말 선택 점수·증강·함정 타일·개입 카드·룰렛)과 BotController의 대기 시간·개입 창 자동 넘김·드래프트·전체 판 시뮬레이션 검증
class_name TestBot
extends TestCase

const Kind := GameEnums.PawnKind


func _manager(player_count: int = 2, draft: bool = false, loadouts: Dictionary = {}) -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
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
	place(state, 11, 22, [21])           # 눈금 2: 23, 0 -> 결승 완주
	place(state, 12, 3, [2])             # 4, 5 -> 5번의 적을 잡음
	place(state, 13, 4, [3])             # 5, 6 -> 코너(6번)에 정확히 멈춤
	place(state, 14, 0, [], false)       # 출발선 대기 말 꺼내기
	place(state, 21, 5, [4])
	var goal: float = BotBrain.score_move(state, state.get_pawn(11), 2)
	var capture: float = BotBrain.score_move(state, state.get_pawn(12), 2)
	var corner: float = BotBrain.score_move(state, state.get_pawn(13), 2)
	var fresh: float = BotBrain.score_move(state, state.get_pawn(14), 2)
	check(goal > capture and capture > corner and corner > fresh, "완주 > 잡기 > 코너 > 새 말 (%.1f %.1f %.1f %.1f)" % [goal, capture, corner, fresh])
	check_eq(BotBrain.choose_pawn(state, 1, 2), 11, "완주 가능한 말이 1순위")
	place(state, 11, 15, [14])           # 완주 후보를 없앤다 (눈금 2로는 16, 17)
	state.get_pawn(11).has_left_start = true
	check_eq(BotBrain.choose_pawn(state, 1, 2), 12, "다음은 적을 잡을 수 있는 말")
	place(state, 21, 9, [8])
	check_eq(BotBrain.choose_pawn(state, 1, 2), 13, "다음은 코너에 멈출 수 있는 말")


func test_bakery_stop_and_scoring_does_not_change_the_game_state() -> void:
	var state := make_state(2, 1)
	place(state, 11, 2, [1])   # 눈금 2: 3, 4 -> 빵집(4번)
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
	var state := make_state(2, 1, {2: [Vector2i(Kind.GO, 2), 0, 0, 0]})
	place(state, 21, 4, [3])  # 바둑 백돌: 잡을 수 없다
	check(not BotBrain.has_capturable_enemy(state, state.get_pawn(11), 4), "무적인 적은 잡기 후보가 아니다")
	check(not BotBrain.has_capturable_enemy(state, state.get_pawn(11), 0), "출발선은 안전")
	var plain := make_state(2, 1)
	place(plain, 21, 4, [3])
	check(BotBrain.has_capturable_enemy(plain, plain.get_pawn(11), 4), "일반 적은 잡을 수 있다")


# --- 증강 드래프트 ----------------------------------------------------------------

func test_augment_choice_prefers_skill_pieces_then_yut_then_other_pieces_then_tools() -> void:
	var state := make_state()
	var rng: RandomNumberGenerator = _seeded(1)
	var rook: Array[StringName] = [&"TOOL_YUT", &"EVO_%d_4" % Kind.CHESS, &"AUG_LAW_01"]
	check_eq(BotBrain.choose_augment(state, 2, rook, rng), 1, "필살기가 있는 룩 지급이 1순위")
	var yut: Array[StringName] = [&"TOOL_YUT", &"EVO_%d_1" % Kind.YUT, &"EVO_%d_1" % Kind.CHESS]
	check_eq(BotBrain.choose_augment(state, 2, yut, rng), 1, "필살기가 없으면 잡기 추가 굴림의 윷말이 폰보다 먼저")
	var plain: Array[StringName] = [&"TOOL_YUT", &"EVO_%d_1" % Kind.JANGGI, &"AUG_LAW_01"]
	check_eq(BotBrain.choose_augment(state, 2, plain, rng), 1, "필살기 없는 기물도 도구 교체보다는 먼저 (아직 기물이 적을 때)")
	var no_evo: Array[StringName] = [&"CARD_PACKAGE", &"AUG_LAW_01", &"TOOL_HOLDEM"]
	check_eq(BotBrain.choose_augment(state, 2, no_evo, rng), 2, "기물 지급이 없으면 판정 도구 교체가 교칙보다 먼저")


func test_evolution_pawn_choice_is_the_front_most_basic_pawn() -> void:
	var state := make_state()
	place(state, 22, 9, [8])
	place(state, 23, 4, [3])
	check_eq(BotBrain.choose_evolution_pawn(state, 2), 22, "가장 앞선 기본 말을 진화시킨다")


# --- 함정·소환 카드 -----------------------------------------------------------------

func test_trap_tiles_target_the_path_ahead_of_the_leading_enemy_or_corners() -> void:
	var state := make_state(3, 1)
	place(state, 11, 20, [19])  # P1의 선두 말 (결승까지 가장 가까움)
	place(state, 31, 3, [2])
	check_eq(BotBrain.leading_enemy(state, 2).entity_id, 11, "선두 상대 말")
	var allowed: Array[int] = [21, 22, 23, 6, 12, 18]
	var card: BaseCard = CardRegistry.get_card(&"TRP_02")
	for seed_value: int in 20:
		var tile: int = BotBrain.choose_card_tile(state, 2, card, _seeded(seed_value))
		check(allowed.has(tile), "함정은 선두 말 앞 1~4칸 길목이나 코너에 놓는다 (%d)" % tile)
		check(card.can_play(state, 2, {"tile": tile}), "카드가 허용하는 타일")
	var island: BaseCard = CardRegistry.get_card(&"TRP_04")
	var island_tile: int = BotBrain.choose_card_tile(state, 2, island, _seeded(1))
	check([6, 12, 18].has(island_tile), "무인도는 코너에만 (%d)" % island_tile)


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


func test_turn_card_bot_uses_reverse_and_objection_sometimes() -> void:
	var state := make_state(2, 1)
	state.rulebook.enqueue_law(LawRegistry.create("LAW_04"))
	var reverse_used: int = 0
	var objection_used: int = 0
	for seed_value: int in 60:
		state.hands[2] = [&"ACT_01"] as Array[StringName]
		var plan: Dictionary = BotBrain.plan_turn_card(state, 2, {}, _seeded(seed_value))
		if not plan.is_empty():
			reverse_used += 1
		state.hands[2] = [&"ACT_06"] as Array[StringName]
		plan = BotBrain.plan_turn_card(state, 2, {}, _seeded(seed_value))
		if not plan.is_empty():
			objection_used += 1
			check_eq(plan["params"]["law_id"], "LAW_04", "있는 교칙만 파기한다")
	check(reverse_used > 3 and reverse_used < 40, "우노 리버스는 가끔 쓴다 (%d/60)" % reverse_used)
	check(objection_used > 8, "법전이 있으면 이의 있음!을 자주 쓴다 (%d/60)" % objection_used)
	state.rulebook.active_laws_queue.clear()
	state.hands[2] = [&"ACT_06"] as Array[StringName]
	check(BotBrain.plan_turn_card(state, 2, {}, _seeded(1)).is_empty(), "법전이 비어 있으면 쓰지 않는다")


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
	var d_start: float = BotController.DELAY_TURN_START
	var d_pre: float = BotController.DELAY_PRE_ROLL
	var d_result: float = BotController.DELAY_ROLL_RESULT
	var d_move: float = BotController.DELAY_MOVE
	controller.tick(0.0)
	check_eq(manager.current_state, TurnManager.State.PHASE_TURN_BEGIN, "턴 시작 직후에는 행동하지 않는다")
	controller.tick(d_start - 0.05)
	check_eq(manager.current_state, TurnManager.State.PHASE_TURN_BEGIN, "턴 시작 대기가 끝나기 전에는 카드/함정 판단 전")
	controller.tick(0.1)
	check_eq(manager.current_state, TurnManager.State.PHASE_ROLL_WAIT, "대기 뒤 판단을 마치고 굴리러 진행")
	controller.tick(d_pre - 0.05)
	check_eq(manager.current_state, TurnManager.State.PHASE_ROLL_WAIT, "굴리기 직전 잠깐 대기")
	controller.tick(0.1)
	check(manager.current_state != TurnManager.State.PHASE_ROLL_WAIT, "굴렸다")
	var before: int = manager.state.get_pawn(21).current_tile_idx
	controller.tick(d_result - 0.1)
	check_eq(manager.state.get_pawn(21).current_tile_idx, before, "굴림 결과를 확인하는 동안은 말을 움직이지 않는다")
	controller.tick(0.2)
	controller.tick(d_move + 0.1)
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


func _hurt_setup(manager: TurnManager, victim: int, mover: int) -> void:
	# mover의 말(1호)이 victim의 말(1호)이 서 있는 4번 칸으로 2칸 이동해 잡는다.
	var mover_pawn: int = mover * 10 + 1
	var victim_pawn: int = victim * 10 + 1
	place(manager.state, mover_pawn, 2, [1])
	place(manager.state, victim_pawn, 4, [3])
	manager.state.tools[mover] = ScriptedTool.new([2])
	manager.state.give_card(victim, &"ACT_05")
	manager._begin_turn()
	manager.act(&"proceed", {"player_id": mover})
	manager.act(&"roll", {"player_id": mover})
	manager.act(&"select_pawn", {"player_id": mover, "pawn_id": mover_pawn})


func test_window_waits_for_a_hurt_human_who_holds_the_rollback_card() -> void:
	var manager: TurnManager = _manager(2)
	_hurt_setup(manager, 2, 1)
	check_eq(manager.current_state, TurnManager.State.PHASE_RESOLUTION, "피해자가 ACT_05를 들고 있어 정산 창이 열림")
	# P2가 사람이라고 보고 봇 목록에서 뺀다 (봇은 P1만): 사람이 고를 때까지 자동으로 닫히지 않는다.
	var controller: BotController = _controller(manager, [1], true)
	for i: int in 10:
		controller.tick(1.0)
	check_eq(manager.current_state, TurnManager.State.PHASE_RESOLUTION, "사람에게 [발동 / 넘기기] 선택 시간을 준다")
	manager.force_timeout()  # 사람이 넘기기를 누르거나 시간이 지난 것
	check(manager.current_state != TurnManager.State.PHASE_RESOLUTION, "넘기면 진행")
	_dispose(manager)


func test_bot_rolls_back_when_it_is_hurt_and_holds_the_card() -> void:
	var manager: TurnManager = _manager(2)
	_hurt_setup(manager, 2, 1)
	var controller: BotController = _controller(manager, [2], true)
	for i: int in 10:
		controller.tick(1.0)
	check_eq(manager.state.get_pawn(21).current_tile_idx, 4, "봇이 ACT_05로 되돌려 말이 제자리")
	check((manager.state.hands[2] as Array).is_empty(), "ACT_05 소모")
	_dispose(manager)


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
		manager.boost_gimmicks = false
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
