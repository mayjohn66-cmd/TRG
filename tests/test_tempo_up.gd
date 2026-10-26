# File: res://tests/test_tempo_up.gd
# Class: class_name TestTempoUp
# Role: ⏩ 템포 업(7·14·20라운드 가속: 과열·광기·대붕괴)과 증강 가중치(법전 5·초증강 10·말 50·도구 50), 단계별 증강 등장, 카이지 판정, 판정 도구 중복 억제, AI 대전 조기 종료 검증
class_name TestTempoUp
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


func test_stages_rise_at_rounds_7_14_20() -> void:
	check_eq([TempoUp.level(1), TempoUp.level(6), TempoUp.level(7), TempoUp.level(13), TempoUp.level(14), TempoUp.level(20), TempoUp.level(40)], [0, 0, 1, 1, 2, 3, 3], "단계")
	check_eq([TempoUp.move_bonus(5), TempoUp.move_bonus(7), TempoUp.move_bonus(14), TempoUp.move_bonus(20)], [0, 2, 4, 6], "최종 이동 보너스 +2/+4/+6")
	check_eq([TempoUp.stage_name(1), TempoUp.stage_name(2), TempoUp.stage_name(3)], ["과열", "광기", "대붕괴"], "단계 이름")
	check_eq([TempoUp.revenge_bonus(5), TempoUp.revenge_bonus(7), TempoUp.revenge_bonus(14)], [0, 6, 8], "리벤지 부스터")
	check(TempoUp.is_stage_round(7) and TempoUp.is_stage_round(14) and TempoUp.is_stage_round(20) and not TempoUp.is_stage_round(8) and not TempoUp.is_stage_round(15) and not TempoUp.is_stage_round(22), "경고는 단계가 오르는 라운드에만")
	check_eq([TempoUp.goal_shrink(19), TempoUp.goal_shrink(20), TempoUp.goal_shrink(21), TempoUp.goal_shrink(22)], [0, 2, 4, 6], "결승선은 20라운드부터 라운드마다 2칸씩")
	check(TempoUp.goal_shrink(99) <= BoardSpec.tile_count - BoardSpec.halfway_tile - 4, "반환점 뒤 절반을 넘게 당겨지지 않는다")
	check(TempoUp.in_goal_zone(20, BoardSpec.tile_count - 1) and TempoUp.in_goal_zone(20, BoardSpec.tile_count - 2) and not TempoUp.in_goal_zone(20, BoardSpec.tile_count - 3), "20라운드: 마지막 2칸이 결승선")
	check(not TempoUp.in_goal_zone(19, BoardSpec.tile_count - 1), "19라운드까지는 그대로")


func test_augment_weights_and_tempo_multiplier() -> void:
	check_eq(AugmentRegistry.get_def(&"AUG_LAW_01").weight, 5, "법전 5")
	check_eq(AugmentRegistry.get_def(&"SUPER_01").weight, 10, "초증강 10")
	check_eq(AugmentRegistry.get_def(&"EVO_1_1").weight, 50, "말 50")
	check_eq(AugmentRegistry.get_def(&"TOOL_YUT").weight, 50, "도구 50")
	var state := make_state()
	state.round_number = 6
	check_eq(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"SUPER_01"), state), 10.0, "6라운드 초증강 그대로")
	state.round_number = 7
	check_eq(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"SUPER_01"), state), 30.0, "과열(7R): 초증강 확률 상승")
	check(is_equal_approx(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"AUG_LAW_01"), state), 5.0 * MatchRules.LAW_DRAFT_FACTOR), "과열: 법전은 그대로 (법전 기본 배수만)")
	state.round_number = 14
	check(is_equal_approx(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"AUG_LAW_01"), state), 15.0 * MatchRules.LAW_DRAFT_FACTOR), "광기(14R): 법전 확률 3배")
	check_eq(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"EVO_1_1"), state), 50.0, "말은 그대로")


func test_revenge_boost_grows_with_tempo() -> void:
	var state := make_state()
	var pawn: PlayerPawn = state.get_pawn(11)
	state.round_number = 5
	check_eq(MoveExecutor.revenge_bonus_of(pawn, state), GameData.revenge_bonus(), "기본 리벤지 부스터")
	state.round_number = 7
	check_eq(MoveExecutor.revenge_bonus_of(pawn, state), 6, "7라운드 +6칸")
	state.round_number = 14
	check_eq(MoveExecutor.revenge_bonus_of(pawn, state), 8, "14라운드 +8칸")


func test_stage_round_warns_before_the_round_is_declared() -> void:
	var manager := _new_manager()
	var events: Array = _events(manager)
	manager.state.round_number = 7
	manager._enter_round_start()
	var kinds: Array = _kinds(events)
	check(kinds.has(&"tempo_up"), "7라운드 시작에 템포 업 경고")
	var warning: Dictionary = events[kinds.find(&"tempo_up")]["data"]
	check_eq(int(warning["level"]), 1, "1단계")
	check_eq((warning["lines"] as Array).size(), 3, "효과 문구 3줄")
	events.clear()
	manager.state.round_number = 8
	manager._enter_round_start()
	check(not _kinds(events).has(&"tempo_up"), "단계가 오르지 않는 라운드는 경고하지 않는다")
	_dispose(manager)


func test_tempo_up_never_enacts_a_special_victory() -> void:
	var manager := _new_manager()
	var events: Array = _events(manager)
	for round_number: int in [7, 14, 20]:
		manager.state.round_number = round_number
		manager._enter_round_start()
	check(manager.state.rulebook.law_ids().is_empty(), "템포 업은 법전을 자동으로 올리지 않는다")
	check(not _kinds(events).has(&"tempo_law"), "자동 등록 이벤트 없음")
	_dispose(manager)


func test_tempo_bonus_is_added_to_the_final_move() -> void:
	var manager := _new_manager()
	var events: Array = _events(manager)
	manager.state.round_number = 15
	manager.state.tools[1] = ScriptedTool.new([2])
	manager.act(&"proceed", {"player_id": 1})
	manager.act(&"roll", {"player_id": 1})
	var boosted: Array = events.filter(func(event: Dictionary) -> bool: return event["kind"] == &"tempo_boosted")
	check_eq(boosted.size(), 1, "템포 업 보너스 이벤트")
	check_eq([int(boosted[0]["data"]["from"]), int(boosted[0]["data"]["to"])], [2, 6], "눈금 2 → 최종 6칸 (광기 +4)")
	check_eq(manager._queued_dice(), 6, "이동 대기열에 반영")
	_dispose(manager)


func test_pulled_in_goal_line_finishes_pawns_on_the_move_and_at_round_start() -> void:
	var state := make_state()
	state.round_number = 22
	var zone: int = TempoUp.goal_zone_start(22)
	place(state, 11, zone - 3, [zone - 4])
	var report: MoveReport = move(state, 11, 6)
	check(report.finished and state.get_pawn(11).is_finished, "당겨진 결승선에 들어서면 완주")
	check_eq(report.path.size(), 3, "남은 눈금은 버린다")
	var manager := _new_manager()
	var events: Array = _events(manager)
	var standing: PlayerPawn = manager.state.get_pawn(21)
	standing.has_left_start = true
	standing.current_tile_idx = BoardSpec.tile_count - 1
	manager.state.round_number = 22
	manager._enter_round_start()
	check(standing.is_finished, "결승선이 당겨져 그 안에 서 있던 말은 바로 완주")
	var shrunk: Array = events.filter(func(event: Dictionary) -> bool: return event["kind"] == &"goal_shrunk")
	check(shrunk.size() == 1 and (shrunk[0]["data"]["finished"] as Array).has(21), "결승선 이벤트에 완주한 말")
	_dispose(manager)


## 단계별 증강 등장: 1번째 드래프트는 기물 진화만, 2번째는 판정 도구·카드·기물 진화, 3번째(7라운드)부터 법전·초증강이 섞인다.
func test_draft_stages_open_up_categories_gradually() -> void:
	check_eq([AugmentRegistry.draft_number(1), AugmentRegistry.draft_number(4), AugmentRegistry.draft_number(7), AugmentRegistry.draft_number(10)], [1, 2, 3, 4], "몇 번째 드래프트")
	var state := make_state()
	var seen: Dictionary = {1: {}, 4: {}, 7: {}}
	for round_number: int in seen:
		state.round_number = round_number
		for seed_value: int in 60:
			state.rng.seed = seed_value
			for offer: StringName in AugmentRegistry.generate_offers(state, 1):
				(seen[round_number] as Dictionary)[AugmentRegistry.get_def(offer).category] = true
			check_eq(AugmentRegistry.generate_offers(state, 1).size(), GameEnums.DRAFT_OFFER_COUNT, "%d라운드: 선택지 3장" % round_number)
	var category := GameEnums.AugmentCategory
	check_eq((seen[1] as Dictionary).keys(), [category.PAWN_EVOLUTION], "1번째 드래프트는 기물 진화만")
	for kind: int in (seen[4] as Dictionary):
		check([category.TOOL_SWAP, category.CARD_PACKAGE, category.PAWN_EVOLUTION].has(kind), "2번째 드래프트는 판정 도구·카드·기물 진화 (%d)" % kind)
	check((seen[4] as Dictionary).has(category.TOOL_SWAP) and (seen[4] as Dictionary).has(category.CARD_PACKAGE), "2번째에 판정 도구·카드가 나온다")
	check(not (seen[4] as Dictionary).has(category.LAW_ENACT) and not (seen[4] as Dictionary).has(category.SUPER_GAMBLE), "2번째까지 법전·초증강 없음")
	check((seen[7] as Dictionary).has(category.LAW_ENACT) and (seen[7] as Dictionary).has(category.SUPER_GAMBLE), "7라운드(3번째)부터 법전·초증강이 섞인다")
	state.round_number = 1
	state.rng.seed = 3
	var current: Array[StringName] = AugmentRegistry.generate_offers(state, 1)
	check_eq(AugmentRegistry.get_def(AugmentRegistry.reroll_candidate(state, 1, current)).category, category.PAWN_EVOLUTION, "1번째 드래프트 다시 뽑기도 기물 진화")


## 기물 진화를 더 받을 수 없으면(기본 말이 없음) 첫 드래프트도 다른 계열로 채운다.
func test_first_draft_falls_back_when_no_pawn_evolution_is_possible() -> void:
	var state := make_state()
	state.round_number = 1
	for pawn: PlayerPawn in state.pawns_of(1):
		pawn.kind = GameEnums.PawnKind.CHESS
	var offers: Array[StringName] = AugmentRegistry.generate_offers(state, 1)
	check_eq(offers.size(), GameEnums.DRAFT_OFFER_COUNT, "그래도 3장")
	for offer: StringName in offers:
		check(AugmentRegistry.get_def(offer).category != GameEnums.AugmentCategory.PAWN_EVOLUTION, "받을 수 없는 기물 진화는 없다")


## 카이지의 한방 역전법은 리벤지 부스터 칸과 템포 업 보너스를 빼고 센다 (요구 16칸).
func test_kaiji_counts_without_revenge_and_tempo_bonus() -> void:
	check_eq((LawRegistry.create("LAW_04") as VictoryLaw).goal(), 16, "한방 16칸")
	var manager := _new_manager()
	var report := MoveReport.new()
	report.path.assign(range(1, 19))  # 18칸 이동
	report.revenge_bonus = 8
	manager._move_tempo_bonus = 3
	check_eq(manager.kaiji_steps(report), 7, "18칸 - 리벤지 8 - 템포 3 = 7칸")
	report.revenge_bonus = 0
	manager._move_tempo_bonus = 0
	check_eq(manager.kaiji_steps(report), 18, "보너스가 없으면 그대로")
	# 실제 굴림: 15라운드(템포 +4)에 눈금 2를 굴려 6칸 이동해도 카이지는 2칸으로 센다
	var events: Array = _events(manager)
	manager.state.rulebook.enqueue_law(LawRegistry.create("LAW_04"))
	manager.state.round_number = 15
	manager.state.tools[1] = ScriptedTool.new([2])
	manager.act(&"proceed", {"player_id": 1})
	manager.act(&"roll", {"player_id": 1})
	if manager.current_state == TurnManager.State.PHASE_SELECT_PAWN:
		manager.act(&"select_pawn", {"player_id": 1, "pawn_id": manager.state.selectable_pawns(1, 4)[0].entity_id})
	check(events.any(func(event: Dictionary) -> bool: return event["kind"] == &"move_resolved"), "이동했다")
	check_eq(manager.state.stat(1, VictoryLaw.BEST_MOVE), 2, "템포 업 +4를 뺀 2칸만 기록")
	_dispose(manager)


## 특수 판정 도구를 이미 가진 사람에게는 판정 도구 교체 증강이 드물게 나오고, 봇은 다른 계열을 먼저 고른다.
func test_tool_swap_is_rare_and_unwanted_once_a_special_tool_is_held() -> void:
	var state := make_state()
	state.round_number = 7
	var yut: AugmentDef = AugmentRegistry.get_def(&"TOOL_YUT")
	var holdem: AugmentDef = AugmentRegistry.get_def(&"TOOL_HOLDEM")
	check_eq(AugmentRegistry.effective_weight(holdem, state, 1), float(holdem.weight), "기본 주사위면 그대로")
	state.tools[1] = ToolRegistry.create(&"YUT")
	check(AugmentRegistry.has_special_tool(state, 1), "윷을 쓰고 있다")
	check_eq(AugmentRegistry.effective_weight(holdem, state, 1), float(holdem.weight) * AugmentRegistry.OWNED_TOOL_SWAP_FACTOR, "특수 도구가 있으면 크게 줄인다")
	var with_tool: int = 0
	var without_tool: int = 0
	for seed_value: int in 200:
		state.rng.seed = seed_value
		state.tools[1] = ToolRegistry.create(&"YUT")
		if AugmentRegistry.generate_offers(state, 1).any(func(id: StringName) -> bool: return AugmentRegistry.get_def(id).category == GameEnums.AugmentCategory.TOOL_SWAP):
			with_tool += 1
		state.rng.seed = seed_value
		state.tools[1] = ToolRegistry.create(&"D6")
		if AugmentRegistry.generate_offers(state, 1).any(func(id: StringName) -> bool: return AugmentRegistry.get_def(id).category == GameEnums.AugmentCategory.TOOL_SWAP):
			without_tool += 1
	check(with_tool * 2 < without_tool, "특수 도구가 있으면 판정 도구 증강이 훨씬 덜 나온다 (%d vs %d)" % [with_tool, without_tool])
	state.tools[2] = ToolRegistry.create(&"YUT")
	var offers: Array[StringName] = [&"TOOL_HOLDEM", &"CARD_PACKAGE", &"AUG_LAW_01"]
	var rng := RandomNumberGenerator.new()
	for seed_value: int in 20:
		rng.seed = seed_value
		check(offers[BotBrain.choose_augment(state, 2, offers, rng)] != &"TOOL_HOLDEM", "특수 도구를 가진 봇은 판정 도구를 다시 고르지 않는다")
	state.tools[2] = ToolRegistry.create(&"D6")
	check_eq(offers[BotBrain.choose_augment(state, 2, offers, rng)], &"TOOL_HOLDEM", "기본 주사위 봇은 판정 도구를 고른다")
	check(yut != null, "윷 증강")


## AI 대전: 사람 자리(end_when_graduated)가 졸업하면 남은 컴퓨터는 레이스 진행 순서(완주 수 → 남은 칸)로 순위가 매겨지고 판이 바로 끝난다.
func test_single_player_game_ends_when_the_human_graduates() -> void:
	var manager := _new_manager([1, 2, 3, 4] as Array[int])
	var state: GameState = manager.state
	var events: Array = _events(manager)
	manager.end_when_graduated.assign([1])
	state.get_pawn(41).is_finished = true  # P4: 1개 완주
	place(state, 21, 20, [19])  # P2: 결승에 더 가깝다
	place(state, 31, 5, [4])
	manager._graduate(1, VictoryChecker.ALL_HOME)
	check(manager._end_if_decided(), "사람이 졸업하면 바로 끝난다")
	check(manager.is_game_over, "게임 종료")
	check_eq(state.rankings, [1, 4, 2, 3] as Array[int], "1위 사람, 그다음 완주 수 → 남은 칸 순서")
	check_eq(state.rank_reasons.get(4), VictoryChecker.RACE_ORDER, "남은 컴퓨터는 진행 순위로 확정")
	check(_kinds(events).has(&"game_over"), "결과 화면으로")
	_dispose(manager)
	# 온라인·4인 수동(end_when_graduated 비어 있음)은 끝까지 진행한다
	var full := _new_manager([1, 2, 3, 4] as Array[int])
	full._graduate(1, VictoryChecker.ALL_HOME)
	check(not full._end_if_decided() and not full.is_game_over, "사람 자리 지정이 없으면 계속")
	_dispose(full)
