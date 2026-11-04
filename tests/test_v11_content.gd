# File: res://tests/test_v11_content.gd
# Class: class_name TestV11Content
# Role: v1.1 신규 콘텐츠 검증 - 판정 도구(주식 차트·다트), 기물(큐이·멜론), 생떼 카드(기억상실빔·강화 망치), 범용 증강(관성 드리프트·현상금 수배서)
class_name TestV11Content
extends TestCase


func _new_manager(players: Array[int] = [1, 2]) -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	manager.start_game(players, 4242)
	return manager


func _dispose(manager: TurnManager) -> void:
	tree.root.remove_child(manager)
	manager.free()


func _events(manager: TurnManager) -> Array:
	var events: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void: events.append({"kind": kind, "data": data}))
	return events


func _kinds(events: Array) -> Array:
	return events.map(func(event: Dictionary) -> StringName: return event["kind"])


func _place(pawn: PlayerPawn, tile: int) -> void:
	pawn.has_left_start = true
	pawn.is_finished = false
	pawn.current_tile_idx = tile


# ---- 판정 도구: 엘리아스 주식 차트 ----

func test_stock_chart_events_and_price_walk() -> void:
	check(ToolRegistry.ALL_IDS.has(&"DICE_STOCK") and ToolRegistry.create(&"DICE_STOCK") is ToolStockChart, "레지스트리에 주식 차트")
	check(AugmentRegistry.get_def(&"TOOL_DICE_STOCK") != null, "판정 도구 교체 증강")
	check_eq([ToolStockChart.event_for(0), ToolStockChart.event_for(5), ToolStockChart.event_for(6), ToolStockChart.event_for(11), ToolStockChart.event_for(12), ToolStockChart.event_for(99)],
		[&"limit_up", &"limit_up", &"delisted", &"delisted", &"", &""], "상한가 6% · 상장폐지 6% · 나머지 보통")
	check_eq(ToolStockChart.next_delta(6, 0), -3, "가장 낮은 등락")
	check_eq(ToolStockChart.next_delta(6, 99), 3, "가장 높은 등락")
	check_eq(ToolStockChart.next_delta(11, 99), 2, "너무 오르면 기준가 쪽으로 1 당긴다")
	check_eq(ToolStockChart.next_delta(2, 0), -2, "너무 내리면 기준가 쪽으로 1 당긴다")
	var tool := ToolStockChart.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var limit_ups: int = 0
	var crashes: int = 0
	var total: int = 0
	var normals: int = 0
	for i: int in 4000:
		var result: RollResult = tool.roll(rng)
		match StringName(result.details["event"]):
			&"limit_up":
				limit_ups += 1
				check_eq(result.steps, 20, "상한가는 20칸")
				check_eq(tool.price, ToolStockChart.BASE_PRICE, "상한가 뒤 주가는 6으로")
			&"delisted":
				crashes += 1
				check(result.ends_turn and result.steps == 0 and bool(result.details["eject_leader"]), "상장폐지: 0칸 + 턴 종료 + 선두 말 사출")
			_:
				normals += 1
				total += result.steps
				check(result.steps >= ToolStockChart.MIN_PRICE and result.steps <= ToolStockChart.MAX_PRICE and result.steps == tool.price, "보통: 지금 주가만큼 (1~12)")
		check((result.details["history"] as Array).size() <= 4, "차트는 최신 4개까지만 보관")
	check(limit_ups > 150 and limit_ups < 340, "상한가 약 6%% (%d/4000)" % limit_ups)
	check(crashes > 150 and crashes < 340, "상장폐지 약 6%% (%d/4000)" % crashes)
	var mean: float = float(total) / float(normals)
	check(mean > 5.0 and mean < 7.0, "보통 등락의 평균은 기준가 근처 (%.2f)" % mean)


func test_stock_delisting_ejects_the_lead_pawn_and_ends_the_turn() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var roller: int = manager.current_player_id()
	var pawns: Array[PlayerPawn] = state.pawns_of(roller)
	_place(pawns[0], 4)
	_place(pawns[1], 12)
	var events := _events(manager)
	var crash: RollResult = RollResult.make(&"DICE_STOCK", 0, {"event": &"delisted", "eject_leader": true, "history": [6, 0]})
	crash.ends_turn = true
	manager._apply_roll_result(crash)
	check(not pawns[1].has_left_start, "가장 앞선 말(12번 칸)이 대기실로")
	check(pawns[0].has_left_start and pawns[0].current_tile_idx == 4, "다른 말은 그대로")
	check(_kinds(events).has(&"stock_delisted"), "상장폐지 사건")
	check(manager.current_player_id() != roller, "턴이 바로 넘어간다")
	_dispose(manager)


# ---- 판정 도구: 불스아이 다트 보드 ----

func test_darts_scoring_rings_and_bull() -> void:
	check(ToolRegistry.create(&"DICE_DARTS") is ToolDarts, "레지스트리에 다트")
	var bull: Dictionary = ToolDarts.score(0.02, 0.3)
	check(bool(bull["bull"]) and int(bull["steps"]) == 10, "정중앙 = 불스아이 10칸")
	var first_wedge: int = ToolDarts.WEDGES[0]
	check_eq(int(ToolDarts.score(0.3, 0.01)["steps"]), first_wedge, "안쪽 싱글 = 숫자")
	check_eq(int(ToolDarts.score(0.5, 0.01)["steps"]), first_wedge * 3, "트리플 고리 = 숫자 × 3")
	check_eq(int(ToolDarts.score(0.7, 0.01)["steps"]), first_wedge, "바깥 싱글 = 숫자")
	check_eq(int(ToolDarts.score(0.9, 0.01)["steps"]), first_wedge * 2, "더블 고리 = 숫자 × 2")
	check_eq(ToolDarts.wedge_number(1.0 / 12.0 + 0.001), ToolDarts.WEDGES[1], "각도에 맞는 조각")
	var tool := ToolDarts.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var total: int = 0
	var bulls: int = 0
	for i: int in 3000:
		var result: RollResult = tool.roll(rng)
		total += result.steps
		if bool(result.details["bull"]):
			bulls += 1
			check(result.reroll and result.steps == 10, "불스아이는 10칸 + 한 번 더")
		else:
			check(not result.reroll and result.steps >= 1 and result.steps <= 18, "그 밖은 1~18칸, 재굴림 없음")
	var mean: float = float(total) / 3000.0
	check(mean > 4.0 and mean < 6.5, "조준 없는(봇) 평균 %.2f칸" % mean)
	check(bulls < 120, "봇의 불스아이는 드물다 (%d/3000)" % bulls)


func test_darts_aim_from_the_roll_action_is_used_once() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var roller: int = manager.current_player_id()
	state.tools[roller] = ToolRegistry.create(&"DICE_DARTS")
	var events := _events(manager)
	manager.act(&"proceed", {"player_id": roller})
	manager.act(&"roll", {"player_id": roller, "aim": [0.0, 0.0]})  # 정중앙을 노렸다 (손떨림 최대 0.08 → 불스아이)
	var rolled: Array = events.filter(func(event: Dictionary) -> bool: return event["kind"] == &"roll_resolved")
	check(not rolled.is_empty(), "굴림 결과")
	if not rolled.is_empty():
		var details: Dictionary = rolled[0]["data"]["result"]["details"]
		check(float(details["radius"]) <= ToolDarts.JITTER_RADIUS + 0.0001, "조준한 자리 근처에 꽂힌다 (%.3f)" % float(details["radius"]))
		check(bool(details["bull"]), "정중앙 조준 → 불스아이")
	check_eq((state.tools[roller] as ToolDarts).pending_aim, Vector2(-1, -1), "조준은 한 번 쓰면 비운다")
	_dispose(manager)


# ---- 기물: 괴상한 멜론 ----

func _melon(state: GameState, pawn_id: int) -> PlayerPawn:
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	pawn.evolve(GameEnums.PawnKind.ARCADE, 7)
	return pawn


func test_weird_melon_eats_traps_and_grows_to_giant() -> void:
	var state := make_state()
	var melon: PlayerPawn = _melon(state, 11)
	check_eq(melon.sub_type(), GameEnums.PawnSubType.ODD_MELON, "아케이드 7호기 = 괴상한 멜론")
	place(state, 11, 2)
	state.place_attachment(4, TrapPit.new(2))
	var report: MoveReport = move(state, 11, 2)
	check(melon.has_left_start and melon.current_tile_idx == 4, "함정을 밟아도 죽지 않는다 (%d번 칸)" % melon.current_tile_idx)
	check_eq(melon.melon_size, 1, "함정을 먹고 1단계 커진다")
	check(not state.board.get_tile(4).has_trap(), "먹은 함정은 사라진다")
	melon.melon_size = PlayerPawn.MELON_MAX
	check(melon.is_trap_immune() and melon.is_giant_melon(), "3단계: 함정 면역")
	state.place_attachment(6, TrapPit.new(2))
	move(state, 11, 2)
	check(melon.has_left_start and state.board.get_tile(6).has_trap(), "다 자란 멜론은 함정을 무시하고 지나간다 (함정은 남는다)")
	# 다 자란 멜론은 지나가며 스친 적을 처치한다
	place(state, 21, 8)
	move(state, 11, 4)
	check(not state.get_pawn(21).has_left_start, "지나간 칸의 적 말 처치")
	state.send_to_start(melon, 2)
	check_eq(melon.melon_size, 0, "잡히면 다시 작은 멜론")
	check(report != null, "이동 보고서")


# ---- 기물: 모브 큐이 ----

func test_mob_kyui_cucumber_is_edible_and_trap_cards_recharge() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var roller: int = manager.current_player_id()
	var kyui: PlayerPawn = state.pawns_of(roller)[0]
	kyui.evolve(GameEnums.PawnKind.ARCADE, 6)
	check_eq(kyui.sub_type(), GameEnums.PawnSubType.MOB_KYUI, "아케이드 6호기 = 모브 큐이")
	check_eq(PawnCatalog.skill_of(kyui.sub_type()), &"cucumber", "필살기: 오이 설치")
	_place(kyui, 5)
	check(manager.can_use_skill(roller, kyui.entity_id), "보드 위 큐이는 오이를 깔 수 있다")
	manager.act(&"use_skill", {"player_id": roller, "pawn_id": kyui.entity_id})
	var cucumber: TileAttachment = null
	for attachment: TileAttachment in state.board.get_tile(5).attachments:
		if attachment.attachment_id == "TRP_CUKE":
			cucumber = attachment
	check(cucumber != null and kyui.skill_used, "오이가 깔리고 필살기를 썼다")
	# 적이 오이에 멈추면 먹을 수 있는 오이 카드
	var enemy: int = 2 if roller == 1 else 1
	var victim: PlayerPawn = state.pawns_of(enemy)[0]
	_place(victim, 3)
	state.hands[enemy] = []
	MoveExecutor.execute(state, victim, make_ctx(state, 2, enemy))
	check((state.hands[enemy] as Array).has(&"JNK_CUKE"), "오이를 밟은 적은 [오이 카드]를 받는다")
	check(victim.has_left_start, "오이는 사출하지 않는다")
	var cuke: BaseCard = CardRegistry.get_card(&"JNK_CUKE")
	check(cuke is CardCucumber and cuke.could_play(state, enemy) and cuke.is_playable_in(TurnManager.State.PHASE_TURN_BEGIN), "오이 카드는 내 턴 시작에 먹을 수 있다")
	check(not CardRegistry.all_ids().has(&"JNK_CUKE") and not CardRegistry.default_deck().has(&"JNK_CUKE"), "오이 카드는 덱·카드 패키지에 없다")
	# 함정 카드를 얻으면 35% 확률로 필살기 재충전 (여러 번 시도하면 언젠가 찬다)
	var recharged: bool = false
	for i: int in 40:
		state.hands[roller] = []
		state.give_card(roller, &"TRP_02")
		if not kyui.skill_used:
			recharged = true
			break
	check(recharged, "함정 카드 획득으로 필살기가 다시 찬다")
	_dispose(manager)


# ---- 생떼 카드: 기억상실빔 ----

func test_amnesia_beam_blocks_every_ejection_for_the_round() -> void:
	var state := make_state()
	var card: BaseCard = CardRegistry.get_card(&"ACT_16")
	check(card is CardStatus and card.could_play(state, 1), "기억상실빔은 턴 시작 즉발 카드")
	check(exec(state, card.create_command(state, 1, {})), "실행")
	check(state.amnesia_active(), "이번 라운드 동안 켜진다")
	check(not card.could_play(state, 1), "이미 켜져 있으면 또 낼 필요가 없다")
	place(state, 21, 6)
	state.send_to_start(state.get_pawn(21), 1)
	check(state.get_pawn(21).has_left_start, "카드·필살기 사출도 막는다")
	place(state, 11, 4)
	move(state, 11, 2)
	check(state.get_pawn(21).has_left_start and state.get_pawn(11).current_tile_idx == 6, "잡기도 막는다 (같은 칸에 함께 선다)")
	state.place_attachment(8, TrapPit.new(2))
	place(state, 12, 7)
	move(state, 12, 1)
	check(state.get_pawn(12).has_left_start, "함정 사출도 막는다")
	state.round_number += 1
	check(not state.amnesia_active(), "다음 라운드에는 꺼진다")
	state.send_to_start(state.get_pawn(21), 1)
	check(not state.get_pawn(21).has_left_start, "다시 사출된다")


# ---- 생떼 카드: 강화 망치 ----

func test_enhancement_hammer_first_upgrade_is_free_then_risk() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var roller: int = manager.current_player_id()
	state.hands[roller] = [&"ACT_17"]
	var events := _events(manager)
	manager.act(&"play_card", {"player_id": roller, "card_id": &"ACT_17"})
	check(manager.hammer_pending(roller) and manager.hammer_level(roller) == 1, "카드를 내면 첫 강화는 무조건 성공: +1")
	manager.act(&"proceed", {"player_id": roller})
	check(manager.current_state == TurnManager.State.PHASE_TURN_BEGIN, "강화를 고르는 동안은 굴릴 수 없다")
	manager.act(&"hammer_stop", {"player_id": roller})
	check(not manager.hammer_pending(roller) and int(state.hammer_bonus.get(roller, 0)) == 1, "멈추면 +1 확정")
	manager.act(&"proceed", {"player_id": roller})
	manager.act(&"roll", {"player_id": roller})
	var applied: Array = events.filter(func(event: Dictionary) -> bool: return event["kind"] == &"hammer_applied")
	check(applied.size() == 1 and int(applied[0]["data"]["to"]) == int(applied[0]["data"]["from"]) + 1, "다음 굴림 결과 +1")
	check(not state.hammer_bonus.has(roller), "강화는 한 번 쓰면 사라진다")
	_dispose(manager)
	# 실패하면 주사위가 부서져 턴이 끝난다 (성공하면 +1씩)
	var failed: bool = false
	var succeeded: bool = false
	for seed_value: int in range(1, 60):
		var m := TurnManager.new()
		m.boost_gimmicks = false
		m.hotseat_mode = true
		m.draft_enabled = false
		tree.root.add_child(m)
		m.start_game([1, 2] as Array[int], seed_value)
		var who: int = m.current_player_id()
		m.state.hands[who] = [&"ACT_17"]
		m.act(&"play_card", {"player_id": who, "card_id": &"ACT_17"})
		m.act(&"hammer_up", {"player_id": who})
		if m.hammer_pending(who):
			succeeded = succeeded or m.hammer_level(who) == 2
		elif m.current_player_id() != who:
			failed = true
			check(not m.state.hammer_bonus.has(who), "실패하면 강화가 남지 않는다")
		tree.root.remove_child(m)
		m.free()
		if failed and succeeded:
			break
	check(succeeded, "두 번째 강화 성공 → +2")
	check(failed, "두 번째 강화 실패 → 턴 종료")
	check_eq([TurnManager.hammer_chance(1), TurnManager.hammer_chance(2), TurnManager.hammer_chance(3), TurnManager.hammer_chance(4)], [70, 55, 40, 25], "강화 확률은 갈수록 낮아진다")


# ---- 범용 증강: 관성 드리프트 ----

func test_inertia_drift_adds_two_per_corner_passed() -> void:
	var state := make_state()
	var corner: int = BoardSpec.bonus_corner_tiles[0]
	check_eq(MoveExecutor.drift_corners([corner - 1, corner, corner + 1] as Array[int]), 1, "지나간 코너 1개")
	check_eq(MoveExecutor.drift_corners([corner - 1, corner] as Array[int]), 0, "코너에 멈추면 지나간 것이 아니다")
	place(state, 11, corner - 2)
	move(state, 11, 4)
	var plain: int = state.get_pawn(11).current_tile_idx
	check(UtilityAugments.is_available(UtilityAugments.DRIFT, state, 1), "드리프트를 받을 수 있다")
	UtilityAugments.apply(UtilityAugments.DRIFT, state, 1)
	check(not UtilityAugments.is_available(UtilityAugments.DRIFT, state, 1), "한 번만")
	place(state, 11, corner - 2)
	move(state, 11, 4)
	check_eq(state.get_pawn(11).current_tile_idx, plain + UtilityAugments.DRIFT_STEPS, "코너를 지나면 +2칸")


# ---- 범용 증강: 현상금 수배서 ----

func test_bounty_marks_the_leading_enemy_and_pays_ten_on_capture() -> void:
	var state := make_state()
	place(state, 21, 5)
	place(state, 22, 12)
	check_eq(UtilityAugments.bounty_target(state, 1).entity_id, 22, "가장 앞선 적 말이 수배된다")
	var result: Dictionary = UtilityAugments.apply(UtilityAugments.BOUNTY, state, 1)
	check(bool(result["ok"]) and int(state.bounties[1]) == 22, "수배 마크")
	check_eq(UtilityAugments.hunters_of(state, 22), [1] as Array[int], "사냥꾼 목록")
	check(not UtilityAugments.is_available(UtilityAugments.BOUNTY, state, 1), "현상금은 하나씩")
	var claimed: Array = []
	state.bounty_claimed.connect(func(hunter: int, pawn_id: int, steps: int) -> void: claimed.append([hunter, pawn_id, steps]))
	place(state, 11, 9)
	move(state, 11, 3)
	check(not state.get_pawn(22).has_left_start, "수배된 말을 잡았다")
	check_eq(claimed, [[1, 22, 10]], "현상금 +10칸")
	check_eq(state.get_pawn(11).current_tile_idx, 12 + UtilityAugments.BOUNTY_STEPS, "잡은 자리에서 10칸 더 간다")
	check(not state.bounties.has(1), "현상금은 한 번 받으면 끝")


# ---- 봇 4명이 새 콘텐츠만 쥐고 끝까지 한 판 ----

func test_bots_finish_games_with_all_v11_content() -> void:
	for seed_value: int in [11, 12, 13]:
		var manager := TurnManager.new()
		manager.boost_gimmicks = false
		manager.hotseat_mode = true
		manager.draft_enabled = true
		manager.stack_choice_enabled = true
		tree.root.add_child(manager)
		manager.set_process(false)
		manager.start_game([1, 2, 3, 4] as Array[int], seed_value * 1000 + 3)
		var state: GameState = manager.state
		state.tools[1] = ToolRegistry.create(&"DICE_STOCK")
		state.tools[2] = ToolRegistry.create(&"DICE_DARTS")
		state.tools[3] = ToolRegistry.create(&"DICE_STOCK")
		state.tools[4] = ToolRegistry.create(&"DICE_DARTS")
		for player_id: int in [1, 2, 3, 4]:
			var pawns: Array[PlayerPawn] = state.pawns_of(player_id)
			pawns[0].evolve(GameEnums.PawnKind.ARCADE, 6)
			pawns[1].evolve(GameEnums.PawnKind.ARCADE, 7)
			state.hands[player_id] = [&"ACT_16", &"ACT_17", &"TRP_02"]
			state.drift_players[player_id] = true
		var controller := BotController.new()
		controller.manager = manager
		controller.bot_players = [1, 2, 3, 4] as Array[int]
		controller.instant = true
		controller.enabled = true
		controller.rng.seed = seed_value
		defer_free(controller)
		var ticks: int = 0
		var hammers: Array[int] = [0]  # 람다는 지역 정수를 값으로 잡으므로 배열에 센다
		manager.event_received.connect(func(kind: StringName, _data: Dictionary) -> void:
			if kind == &"hammer_result" or kind == &"hammer_banked":
				hammers[0] += 1)
		while not manager.is_game_over and ticks < 60000:
			controller.tick(0.0)
			ticks += 1
		check(manager.is_game_over and state.winner != -1, "시드 %d: v1.1 콘텐츠로도 한 판이 끝난다 (%d틱, 라운드 %d)" % [seed_value, ticks, state.round_number])
		check(not state.hammer_pending.values().any(func(_v: Variant) -> bool: return true) or manager.is_game_over, "강화 망치 선택이 걸린 채 멈추지 않는다")
		check(hammers[0] > 0, "시드 %d: 봇이 강화 망치를 썼다 (%d)" % [seed_value, hammers[0]])
		tree.root.remove_child(manager)
		manager.free()
