# File: res://tests/test_tempo_up.gd
# Class: class_name TestTempoUp
# Role: ⏩ 템포 업(10·20·30라운드 가속: 과열·광기·대붕괴)과 증강 가중치(법전 5·초증강 10·말 50·도구 50) 검증
class_name TestTempoUp
extends TestCase


func _new_manager() -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	manager.start_game([1, 2] as Array[int], 4242)
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


func test_stages_rise_at_rounds_8_15_22() -> void:
	check_eq([TempoUp.level(1), TempoUp.level(7), TempoUp.level(8), TempoUp.level(14), TempoUp.level(15), TempoUp.level(22), TempoUp.level(40)], [0, 0, 1, 1, 2, 3, 3], "단계")
	check_eq([TempoUp.move_bonus(5), TempoUp.move_bonus(8), TempoUp.move_bonus(15), TempoUp.move_bonus(22)], [0, 1, 2, 3], "최종 이동 보너스 +1/+2/+3")
	check_eq([TempoUp.stage_name(1), TempoUp.stage_name(2), TempoUp.stage_name(3)], ["과열", "광기", "대붕괴"], "단계 이름")
	check_eq([TempoUp.revenge_bonus(5), TempoUp.revenge_bonus(8), TempoUp.revenge_bonus(15)], [0, 6, 8], "리벤지 부스터")
	check(TempoUp.is_stage_round(8) and TempoUp.is_stage_round(15) and TempoUp.is_stage_round(22) and not TempoUp.is_stage_round(10) and not TempoUp.is_stage_round(20) and not TempoUp.is_stage_round(9), "경고는 단계가 오르는 라운드에만")
	check_eq([TempoUp.goal_shrink(21), TempoUp.goal_shrink(22), TempoUp.goal_shrink(23), TempoUp.goal_shrink(24)], [0, 2, 4, 6], "결승선은 22라운드부터 라운드마다 2칸씩")
	check(TempoUp.goal_shrink(99) <= BoardSpec.tile_count - BoardSpec.halfway_tile - 4, "반환점 뒤 절반을 넘게 당겨지지 않는다")
	check(TempoUp.in_goal_zone(22, BoardSpec.tile_count - 1) and TempoUp.in_goal_zone(22, BoardSpec.tile_count - 2) and not TempoUp.in_goal_zone(22, BoardSpec.tile_count - 3), "22라운드: 마지막 2칸이 결승선")
	check(not TempoUp.in_goal_zone(21, BoardSpec.tile_count - 1), "21라운드까지는 그대로")


func test_augment_weights_and_tempo_multiplier() -> void:
	check_eq(AugmentRegistry.get_def(&"AUG_LAW_01").weight, 5, "법전 5")
	check_eq(AugmentRegistry.get_def(&"SUPER_01").weight, 10, "초증강 10")
	check_eq(AugmentRegistry.get_def(&"EVO_1_1").weight, 50, "말 50")
	check_eq(AugmentRegistry.get_def(&"TOOL_YUT").weight, 50, "도구 50")
	var state := make_state()
	state.round_number = 7
	check_eq(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"AUG_LAW_01"), state), 5.0, "7라운드 법전 그대로")
	state.round_number = 8
	check_eq(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"AUG_LAW_01"), state), 15.0, "8라운드부터 법전 확률 상승")
	check_eq(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"SUPER_01"), state), 30.0, "초증강 확률 상승")
	check_eq(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"EVO_1_1"), state), 50.0, "말은 그대로")


func test_revenge_boost_grows_with_tempo() -> void:
	var state := make_state()
	var pawn: PlayerPawn = state.get_pawn(11)
	state.round_number = 5
	check_eq(MoveExecutor.revenge_bonus_of(pawn, state), GameData.revenge_bonus(), "기본 리벤지 부스터")
	state.round_number = 8
	check_eq(MoveExecutor.revenge_bonus_of(pawn, state), 6, "8라운드 +6칸")
	state.round_number = 15
	check_eq(MoveExecutor.revenge_bonus_of(pawn, state), 8, "15라운드 +8칸")


func test_stage_round_warns_before_the_round_is_declared() -> void:
	var manager := _new_manager()
	var events: Array = _events(manager)
	manager.state.round_number = 8
	manager._enter_round_start()
	var kinds: Array = _kinds(events)
	check(kinds.has(&"tempo_up"), "8라운드 시작에 템포 업 경고")
	var warning: Dictionary = events[kinds.find(&"tempo_up")]["data"]
	check_eq(int(warning["level"]), 1, "1단계")
	check_eq((warning["lines"] as Array).size(), 3, "효과 문구 3줄")
	events.clear()
	manager.state.round_number = 9
	manager._enter_round_start()
	check(not _kinds(events).has(&"tempo_up"), "단계가 오르지 않는 라운드는 경고하지 않는다")
	_dispose(manager)


func test_round_15_enacts_a_random_special_victory() -> void:
	var manager := _new_manager()
	var events: Array = _events(manager)
	check(manager.state.rulebook.law_ids().is_empty(), "처음엔 법전이 비어 있다")
	manager.state.round_number = 15
	manager._enter_round_start()
	check_eq(manager.state.rulebook.law_ids().size(), 1, "특수 승리 1개 등록")
	check(_kinds(events).find(&"tempo_up") < _kinds(events).find(&"tempo_law"), "경고가 먼저, 등록이 뒤")
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
	check_eq([int(boosted[0]["data"]["from"]), int(boosted[0]["data"]["to"])], [2, 4], "눈금 2 → 최종 4칸 (광기 +2)")
	check_eq(manager._queued_dice(), 4, "이동 대기열에 반영")
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
