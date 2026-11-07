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


func test_stages_rise_at_rounds_8_14_20() -> void:
	check_eq([TempoUp.level(1), TempoUp.level(7), TempoUp.level(8), TempoUp.level(13), TempoUp.level(14), TempoUp.level(20), TempoUp.level(40)], [0, 0, 1, 1, 2, 3, 3], "단계")
	check_eq([TempoUp.move_bonus(7), TempoUp.move_bonus(8), TempoUp.move_bonus(14), TempoUp.move_bonus(20)], [0, 1, 2, 3], "최종 이동 보너스 +1/+2/+3")
	check_eq([TempoUp.stage_name(1), TempoUp.stage_name(2), TempoUp.stage_name(3)], ["과열", "광기", "대붕괴"], "단계 이름")
	check_eq([TempoUp.revenge_bonus(7), TempoUp.revenge_bonus(8), TempoUp.revenge_bonus(14)], [0, 6, 8], "리벤지 부스터")
	check(TempoUp.is_stage_round(8) and TempoUp.is_stage_round(14) and TempoUp.is_stage_round(20) and not TempoUp.is_stage_round(7) and not TempoUp.is_stage_round(15) and not TempoUp.is_stage_round(22), "경고는 단계가 오르는 라운드에만")
	# 결승선 (2026-10-29 목표 12~15분): 시스템은 결승선을 당기지 않는다. [범용] 결승선 당기기(goal_shrink_bonus)로만 당겨진다.
	for round_number: int in [1, 8, 14, 17, 20, 25, 99]:
		check_eq(TempoUp.goal_shrink(round_number), 0, "%d라운드: 시스템 결승선 단축 없음" % round_number)
	check(not TempoUp.in_goal_zone(30, BoardSpec.tile_count - 1), "라운드가 길어져도 결승선은 그대로")
	var state := make_state()
	state.round_number = 20
	check_eq(TempoUp.zone_start_for(state), -1, "증강이 없으면 당겨진 결승선도 없다")
	state.goal_shrink_bonus = 3
	check_eq(TempoUp.zone_start_for(state), BoardSpec.tile_count - 3, "[범용] 결승선 당기기만큼 당겨진다")
	state.goal_shrink_bonus = 999
	check_eq(TempoUp.shrink_for(state), BoardSpec.tile_count - BoardSpec.halfway_tile - 4, "[범용] 결승선 당기기 한도는 반환점 뒤 절반")


func test_augment_weights_and_tempo_multiplier() -> void:
	check_eq(AugmentRegistry.get_def(&"AUG_LAW_01").weight, 5, "법전 5")
	check_eq(AugmentRegistry.get_def(&"SUPER_01").weight, 10, "초증강 10")
	check_eq(AugmentRegistry.get_def(&"EVO_1_1").weight, 50, "말 50")
	check_eq(AugmentRegistry.get_def(&"TOOL_YUT").weight, 50, "도구 50")
	var state := make_state()
	state.round_number = 7
	check_eq(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"SUPER_01"), state), 10.0, "7라운드 초증강 그대로")
	state.round_number = 8
	check_eq(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"SUPER_01"), state), 10.0, "과열(8R): 초증강은 아직 기본 가중치 (풀 합류는 2단계)")
	check(is_equal_approx(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"AUG_LAW_01"), state), 15.0 * MatchRules.LAW_DRAFT_FACTOR), "과열(8R): 법전 풀 합류 + 확률 3배")
	check_eq(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"EVO_1_1"), state), 50.0, "과열: 기초 풀(말)은 그대로")
	state.round_number = 14
	check_eq(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"SUPER_01"), state), 30.0, "광기(14R): 초증강 확률 3배")
	check(is_equal_approx(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"AUG_LAW_01"), state), 15.0 * MatchRules.LAW_DRAFT_FACTOR), "광기: 법전 3배 유지")
	check_eq(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"EVO_1_1"), state), 12.5, "광기: 기초 풀(기물 진화)은 ×0.25")
	check_eq(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"TOOL_YUT"), state), 50.0, "광기: 판정 도구는 그대로")


func test_revenge_boost_grows_with_tempo() -> void:
	var state := make_state()
	var pawn: PlayerPawn = state.get_pawn(11)
	state.round_number = 7
	check_eq(MoveExecutor.revenge_bonus_of(pawn, state), GameData.revenge_bonus(), "기본 리벤지 부스터")
	state.round_number = 8
	check_eq(MoveExecutor.revenge_bonus_of(pawn, state), 6, "8라운드 +6칸")
	state.round_number = 14
	check_eq(MoveExecutor.revenge_bonus_of(pawn, state), 8, "14라운드 +8칸")


func test_stage_round_warns_before_the_round_is_declared() -> void:
	var manager := _new_manager()
	var events: Array = _events(manager)
	manager.state.round_number = 8
	manager._enter_round_start()
	var kinds: Array = _kinds(events)
	check(kinds.has(&"tempo_up"), "8라운드 시작에 템포 업 경고")
	var warning: Dictionary = events[kinds.find(&"tempo_up")]["data"]
	check_eq(int(warning["level"]), 1, "1단계")
	check_eq((warning["lines"] as Array).size(), 4, "효과 문구 3줄 + 법전이 비어 있어 자동 제정 안내 1줄")
	check(str(warning["lines"][3]).contains("자동 제정"), "법전 자동 제정 안내")
	events.clear()
	manager.state.round_number = 9
	manager._enter_round_start()
	check(not _kinds(events).has(&"tempo_up"), "단계가 오르지 않는 라운드는 경고하지 않는다")
	_dispose(manager)


## 중반 법전 보장 (2026-10-29): 1단계(8R)까지 법전이 비어 있으면 무작위 특수 승리 법전 1개를 자동 제정한다. 14·20라운드에는 다시 하지 않는다.
func test_tempo_stage1_enacts_one_law_when_the_codex_is_empty() -> void:
	var manager := _new_manager()
	var events: Array = _events(manager)
	manager.state.round_number = 8
	manager._enter_round_start()
	var ids: Array = manager.state.rulebook.law_ids()
	check_eq(ids.size(), 1, "8라운드: 법전이 비어 있으면 1개 자동 제정")
	check(VictoryLaw.is_victory_id(String(ids[0])), "특수 승리 법전")
	var auto: Array = events.filter(func(event: Dictionary) -> bool: return event["kind"] == &"law_auto_enacted")
	check(auto.size() == 1 and String(auto[0]["data"]["law_id"]) == String(ids[0]), "자동 제정 이벤트")
	for round_number: int in [14, 20]:
		manager.state.round_number = round_number
		manager._enter_round_start()
	check_eq(manager.state.rulebook.law_ids().size(), 1, "14·20라운드에는 더 올리지 않는다")
	_dispose(manager)


func test_auto_law_skips_when_a_law_exists_or_laws_are_off_or_cream() -> void:
	var manager := _new_manager()
	manager.state.rulebook.enqueue_law(LawRegistry.create("LAW_01"))
	manager.state.round_number = 8
	manager._enter_round_start()
	check_eq(manager.state.rulebook.law_ids(), ["LAW_01"], "누가 이미 법전을 뽑았으면 자동 제정하지 않는다")
	_dispose(manager)
	for rules: Dictionary in [{"laws": false}, MatchRules.for_difficulty(1)]:
		var off := TurnManager.new()
		off.boost_gimmicks = false
		off.hotseat_mode = true
		off.draft_enabled = false
		off.match_rules = rules
		tree.root.add_child(off)
		off.start_game([1, 2] as Array[int], 4242)
		off.state.round_number = 8
		off._enter_round_start()
		check(off.state.rulebook.law_ids().is_empty(), "법전 끄기·Lv.1 크림은 자동 제정 없음 (%s)" % str(rules.get("pacing", 0)))
		_dispose(off)
	for level: int in [2, 3, 5]:
		var single := TurnManager.new()
		single.boost_gimmicks = false
		single.hotseat_mode = true
		single.draft_enabled = false
		single.match_rules = MatchRules.for_difficulty(level)
		tree.root.add_child(single)
		single.start_game([1, 2] as Array[int], 4242 + level)
		single.state.round_number = 8
		single._enter_round_start()
		check_eq(single.state.rulebook.law_ids().size(), 1, "Lv.%d: 8라운드에 법전 1개 자동 제정" % level)
		check(MatchRules.victory_law_count(single.state) <= MatchRules.max_laws(single.state), "최대 법전 개수를 넘지 않는다")
		_dispose(single)


func test_tempo_bonus_is_added_to_the_final_move() -> void:
	var manager := _new_manager()
	var events: Array = _events(manager)
	manager.state.round_number = 15
	manager.state.tools[1] = ScriptedTool.new([2])
	manager.act(&"proceed", {"player_id": 1})
	manager.act(&"roll", {"player_id": 1})
	var boosted: Array = events.filter(func(event: Dictionary) -> bool: return event["kind"] == &"tempo_boosted")
	check_eq(boosted.size(), 1, "템포 업 보너스 이벤트")
	check_eq([int(boosted[0]["data"]["from"]), int(boosted[0]["data"]["to"])], [2, 4], "눈금 2 → 최종 4칸 (광기 +2)")
	check_eq(manager._queued_dice(), 4, "이동 대기열에 반영")
	_dispose(manager)


func test_tempo_bonus_skips_bonus_rolls_in_the_same_turn() -> void:
	var manager := _new_manager()
	manager.state.round_number = 15
	var first: RollResult = RollResult.make(&"YUT", 4, {})
	first.reroll = true
	manager._apply_roll_result(first)
	check_eq(manager._queued_dice(), 6, "첫 이동: 눈금 4 + 광기 2")
	manager.move_queue.clear()
	manager._apply_roll_result(RollResult.make(&"YUT", 3, {}))
	check_eq(manager._queued_dice(), 3, "같은 차례 추가 굴림에는 템포 업 보너스가 없다")
	_dispose(manager)


func test_pulled_in_goal_line_finishes_pawns_on_the_move_and_at_round_start() -> void:
	var state := make_state()
	state.round_number = 22
	state.goal_shrink_bonus = 6
	var zone: int = TempoUp.zone_start_for(state)
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
	check(not standing.is_finished, "증강이 없으면 라운드가 길어져도 결승선은 그대로")
	check(not _kinds(events).has(&"goal_shrunk"), "시스템 결승선 단축 이벤트 없음")
	_dispose(manager)


## 단계별 증강 등장: 1번째 드래프트는 기물 진화만, 2번째는 판정 도구·카드·기물 진화, 3번째(7라운드)부터 법전·초증강이 섞인다.
func test_draft_stages_open_up_categories_gradually() -> void:
	check_eq([AugmentRegistry.draft_number(1), AugmentRegistry.draft_number(4), AugmentRegistry.draft_number(7), AugmentRegistry.draft_number(10)], [1, 2, 3, 4], "몇 번째 드래프트")
	var state := make_state()
	var seen: Dictionary = {1: {}, 4: {}, 7: {}, 10: {}, 16: {}}
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
	check(not (seen[7] as Dictionary).has(category.LAW_ENACT) and not (seen[7] as Dictionary).has(category.SUPER_GAMBLE), "템포 0단계(7라운드): 법전·초증강은 아직 없다")
	check((seen[7] as Dictionary).has(category.UTILITY), "7라운드: 쉬운 범용 보급이 섞인다")
	check((seen[10] as Dictionary).has(category.LAW_ENACT) and not (seen[10] as Dictionary).has(category.SUPER_GAMBLE), "템포 1단계(10라운드): 법전이 합류하고 초증강은 아직 없다")
	check((seen[16] as Dictionary).has(category.LAW_ENACT) and (seen[16] as Dictionary).has(category.SUPER_GAMBLE), "템포 2단계(16라운드): 초증강까지 합류")
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


## 카이지의 한방 역전법 (2026-11 제보 수정): 한 차례 동안 말 하나가 전진한 칸 수를 모두 더한다 (리벤지 부스터·템포 업·추가 굴림 포함, 요구 16칸).
func test_kaiji_counts_the_whole_turn_for_one_pawn() -> void:
	check_eq((LawRegistry.create("LAW_04") as VictoryLaw).goal(), 16, "한방 16칸")
	var manager := _new_manager()
	var booster := MoveReport.new()
	booster.pawn_id = 11
	booster.path.assign(range(1, 9))  # 리벤지 부스터 선행 전진 8칸
	booster.revenge_bonus = 8
	check_eq(manager.kaiji_steps(booster), 8, "부스터 8칸도 센다")
	var dice := MoveReport.new()
	dice.pawn_id = 11
	dice.path.assign(range(9, 20))  # 이어서 주사위 11칸
	check_eq(manager.kaiji_steps(dice), 19, "같은 차례 같은 말: 8 + 11 = 19칸 (예전에는 따로 세어 9/16)")
	var other := MoveReport.new()
	other.pawn_id = 12
	other.path.assign(range(1, 4))
	check_eq(manager.kaiji_steps(other), 3, "다른 말은 따로 센다")
	manager._begin_turn()
	check_eq(manager.kaiji_steps(other), 6 if manager.state.is_graduated(manager.current_player_id()) else 3, "새 차례에는 0부터 다시")
	# 실제 굴림: 15라운드(템포 +2)에 눈금 2를 굴리면 4칸 전진으로 센다
	var events: Array = _events(manager)
	manager.state.rulebook.enqueue_law(LawRegistry.create("LAW_04"))
	manager.state.round_number = 15
	manager.state.tools[1] = ScriptedTool.new([2])
	manager.act(&"proceed", {"player_id": 1})
	manager.act(&"roll", {"player_id": 1})
	if manager.current_state == TurnManager.State.PHASE_SELECT_PAWN:
		manager.act(&"select_pawn", {"player_id": 1, "pawn_id": manager.state.selectable_pawns(1, 4)[0].entity_id})
	check(events.any(func(event: Dictionary) -> bool: return event["kind"] == &"move_resolved"), "이동했다")
	check_eq(manager.state.stat(1, VictoryLaw.BEST_MOVE), 4, "템포 업 +2까지 더한 4칸")
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
	# 2026-10-30 핫픽스: 실제 말 4개 완주는 온라인·4인 수동(사람 자리 지정 없음)에서도 그 자리에서 판을 끝낸다. 맨 뒤 한 명은 꼴찌.
	var full := _new_manager([1, 2, 3, 4] as Array[int])
	full._graduate(1, VictoryChecker.ALL_HOME)
	check(full._end_if_decided() and full.is_game_over, "말 4개 완주는 사람 자리 지정이 없어도 바로 끝난다")
	check_eq(full.state.rank_reasons[full.state.rankings[3]], VictoryChecker.LAST_PLACE, "맨 뒤 한 명은 꼴찌")
	_dispose(full)


## 증강 풀의 단계적 확장: 표의 min_tempo/max_tempo가 정한다 (초반 쉬운 증강 → 중반 판세 개입형 → 후반 초증강).
func test_pool_expands_with_tempo_stages() -> void:
	var state := make_state()
	var expect: Dictionary = {&"EVO_1_1": 0, &"TOOL_YUT": 0, &"CARD_PACKAGE": 0, &"AUG_UTIL_MOVE_PLUS": 0, &"AUG_LAW_01": 1, &"CARD_02": 1, &"UTIL_03": 1, &"SUPER_01": 2, &"SUPER_11": 2, &"UTIL_02": 2}
	for id: StringName in expect:
		check_eq(AugmentRegistry.get_def(id).min_tempo, int(expect[id]), "%s 합류 단계" % id)
	for round_number: int in [4, 7, 8, 13, 14, 20]:
		state.round_number = round_number
		var tempo: int = TempoUp.level(round_number)
		for id: StringName in expect:
			var def: AugmentDef = AugmentRegistry.get_def(id)
			if def.category == GameEnums.AugmentCategory.LAW_ENACT or def.category == GameEnums.AugmentCategory.SUPER_GAMBLE:
				# 초증강은 판 위 상황에도 좌우되므로(말이 없으면 못 쓴다) 합류 전에는 반드시 막히는지만 본다
				if tempo < int(expect[id]):
					check(not def.is_available(state, 1), "%s: %d라운드(템포 %d)에는 아직 풀에 없다" % [id, round_number, tempo])
				elif def.category == GameEnums.AugmentCategory.LAW_ENACT:
					check(def.is_available(state, 1), "%s: %d라운드(템포 %d)부터 풀에 있다" % [id, round_number, tempo])
	# max_tempo: 그 단계를 넘으면 풀에서 빠진다
	var rows: Array = (GameData.table("augments") as Dictionary).values().duplicate(true)
	for row: Dictionary in rows:
		if str(row["id"]) == "TOOL_YUT":
			row["max_tempo"] = "1"
	GameData.override_table("augments", rows)
	AugmentRegistry.reload()
	var yut: AugmentDef = AugmentRegistry.get_def(&"TOOL_YUT")
	state.round_number = 13
	check(yut.is_available(state, 1), "max_tempo 1: 템포 1단계(13라운드)까지는 나온다")
	state.round_number = 14
	check(not yut.is_available(state, 1), "max_tempo 1: 템포 2단계부터는 빠진다")
	GameData.override_table("augments")
	AugmentRegistry.reload()
	check_eq(TempoUp.effect_lines(1).size(), 3, "1단계 안내 3줄 (고급 증강 합류 포함)")
	check(str(TempoUp.effect_lines(1)[2]).contains("고급 증강") and str(TempoUp.effect_lines(2)[2]).contains("초증강"), "템포 업 안내에 풀 합류 문구")


## 자동 법전 사전 예고: 1단계(8R) 두 라운드 전(6R)에 어떤 법전이 열릴지 정해 알리고, 8R에 그 법전을 그대로 제정한다.
func test_auto_law_is_announced_two_rounds_ahead_and_enacted_as_announced() -> void:
	var manager := _new_manager()
	var events: Array = _events(manager)
	manager.state.round_number = 5
	manager._enter_round_start()
	check(not _kinds(events).has(&"law_auto_preview") and manager.state.auto_law_preview == "", "5라운드에는 아직 예고가 없다")
	manager.state.round_number = 6
	manager._enter_round_start()
	check(_kinds(events).has(&"law_auto_preview"), "6라운드 시작에 법전 예고")
	var preview: String = manager.state.auto_law_preview
	var data: Dictionary = events[_kinds(events).find(&"law_auto_preview")]["data"]
	check(preview != "" and String(data["law_id"]) == preview and int(data["open_round"]) == 8, "예고에 법전과 열리는 라운드가 실린다")
	var count: int = events.filter(func(e: Dictionary) -> bool: return e["kind"] == &"law_auto_preview").size()
	manager.state.round_number = 7
	manager._enter_round_start()
	check_eq(events.filter(func(e: Dictionary) -> bool: return e["kind"] == &"law_auto_preview").size(), count, "7라운드에는 같은 예고를 다시 뽑지 않는다")
	check_eq(manager.state.auto_law_preview, preview, "예고한 법전은 그대로")
	manager.state.round_number = 8
	manager._enter_round_start()
	check(manager.state.rulebook.has_law(preview) and manager.state.auto_law_preview == "", "8라운드에 예고한 법전이 그대로 제정된다")
	_dispose(manager)
