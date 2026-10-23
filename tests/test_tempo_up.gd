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


func test_stages_rise_at_rounds_10_20_30() -> void:
	check_eq([TempoUp.level(1), TempoUp.level(9), TempoUp.level(10), TempoUp.level(19), TempoUp.level(20), TempoUp.level(30), TempoUp.level(40)], [0, 0, 1, 1, 2, 3, 3], "단계")
	check_eq([TempoUp.move_bonus(5), TempoUp.move_bonus(10), TempoUp.move_bonus(20), TempoUp.move_bonus(30)], [0, 1, 2, 3], "최종 이동 보너스 +1/+2/+3")
	check_eq([TempoUp.stage_name(1), TempoUp.stage_name(2), TempoUp.stage_name(3)], ["과열", "광기", "대붕괴"], "단계 이름")
	check_eq([TempoUp.revenge_bonus(5), TempoUp.revenge_bonus(10), TempoUp.revenge_bonus(20)], [0, 6, 8], "리벤지 부스터")
	check(TempoUp.is_stage_round(10) and TempoUp.is_stage_round(20) and TempoUp.is_stage_round(30) and not TempoUp.is_stage_round(11), "경고는 단계가 오르는 라운드에만")
	check_eq([TempoUp.goal_shrink(29), TempoUp.goal_shrink(30), TempoUp.goal_shrink(31), TempoUp.goal_shrink(32)], [0, 2, 4, 6], "결승선은 30라운드부터 라운드마다 2칸씩")
	check(TempoUp.goal_shrink(99) <= BoardSpec.tile_count - BoardSpec.halfway_tile - 4, "반환점 뒤 절반을 넘게 당겨지지 않는다")
	check(TempoUp.in_goal_zone(30, BoardSpec.tile_count - 1) and TempoUp.in_goal_zone(30, BoardSpec.tile_count - 2) and not TempoUp.in_goal_zone(30, BoardSpec.tile_count - 3), "30라운드: 마지막 2칸이 결승선")
	check(not TempoUp.in_goal_zone(29, BoardSpec.tile_count - 1), "29라운드까지는 그대로")


func test_augment_weights_and_tempo_multiplier() -> void:
	check_eq(AugmentRegistry.get_def(&"AUG_LAW_01").weight, 5, "법전 5")
	check_eq(AugmentRegistry.get_def(&"SUPER_01").weight, 10, "초증강 10")
	check_eq(AugmentRegistry.get_def(&"EVO_1_1").weight, 50, "말 50")
	check_eq(AugmentRegistry.get_def(&"TOOL_YUT").weight, 50, "도구 50")
	var state := make_state()
	state.round_number = 9
	check_eq(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"AUG_LAW_01"), state), 5.0, "9라운드 법전 그대로")
	state.round_number = 10
	check_eq(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"AUG_LAW_01"), state), 15.0, "10라운드부터 법전 확률 상승")
	check_eq(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"SUPER_01"), state), 30.0, "초증강 확률 상승")
	check_eq(AugmentRegistry.effective_weight(AugmentRegistry.get_def(&"EVO_1_1"), state), 50.0, "말은 그대로")


func test_revenge_boost_grows_with_tempo() -> void:
	var state := make_state()
	var pawn: PlayerPawn = state.get_pawn(11)
	state.round_number = 5
	check_eq(MoveExecutor.revenge_bonus_of(pawn, state), GameData.revenge_bonus(), "기본 리벤지 부스터")
	state.round_number = 10
	check_eq(MoveExecutor.revenge_bonus_of(pawn, state), 6, "10라운드 +6칸")
	state.round_number = 20
	check_eq(MoveExecutor.revenge_bonus_of(pawn, state), 8, "20라운드 +8칸")


func test_stage_round_warns_before_the_round_is_declared() -> void:
	var manager := _new_manager()
	var events: Array = _events(manager)
	manager.state.round_number = 10
	manager._enter_round_start()
	var kinds: Array = _kinds(events)
	check(kinds.has(&"tempo_up"), "10라운드 시작에 템포 업 경고")
	var warning: Dictionary = events[kinds.find(&"tempo_up")]["data"]
	check_eq(int(warning["level"]), 1, "1단계")
	check_eq((warning["lines"] as Array).size(), 3, "효과 문구 3줄")
	events.clear()
	manager.state.round_number = 11
	manager._enter_round_start()
	check(not _kinds(events).has(&"tempo_up"), "단계가 오르지 않는 라운드는 경고하지 않는다")
	_dispose(manager)


func test_round_20_enacts_a_random_special_victory() -> void:
	var manager := _new_manager()
	var events: Array = _events(manager)
	check(manager.state.rulebook.law_ids().is_empty(), "처음엔 법전이 비어 있다")
	manager.state.round_number = 20
	manager._enter_round_start()
	check_eq(manager.state.rulebook.law_ids().size(), 1, "특수 승리 1개 등록")
	check(_kinds(events).find(&"tempo_up") < _kinds(events).find(&"tempo_law"), "경고가 먼저, 등록이 뒤")
	_dispose(manager)


func test_tempo_bonus_is_added_to_the_final_move() -> void:
	var manager := _new_manager()
	var events: Array = _events(manager)
	manager.state.round_number = 20
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
	state.round_number = 30
	var zone: int = TempoUp.goal_zone_start(30)
	place(state, 11, zone - 3, [zone - 4])
	var report: MoveReport = move(state, 11, 6)
	check(report.finished and state.get_pawn(11).is_finished, "당겨진 결승선에 들어서면 완주")
	check_eq(report.path.size(), 3, "남은 눈금은 버린다")
	var manager := _new_manager()
	var events: Array = _events(manager)
	var standing: PlayerPawn = manager.state.get_pawn(21)
	standing.has_left_start = true
	standing.current_tile_idx = BoardSpec.tile_count - 1
	manager.state.round_number = 30
	manager._enter_round_start()
	check(standing.is_finished, "결승선이 당겨져 그 안에 서 있던 말은 바로 완주")
	var shrunk: Array = events.filter(func(event: Dictionary) -> bool: return event["kind"] == &"goal_shrunk")
	check(shrunk.size() == 1 and (shrunk[0]["data"]["finished"] as Array).has(21), "결승선 이벤트에 완주한 말")
	_dispose(manager)
