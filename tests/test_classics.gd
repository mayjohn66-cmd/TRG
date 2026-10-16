# File: res://tests/test_classics.gd
# Class: class_name TestClassics
# Role: 클래식 보드게임 확장 6종 검증 - 쇼기 기물(나리 승급·비차·각행·계마·모치고마 낙하), 판정 도구 3종(화투 고/스톱·리치 마작·타로 덱), 도미노 연쇄 붕괴 함정(TRP_05), 타로 생떼 카드(ACT_07 무너지는 탑 / ACT_08 운명의 수레바퀴), AI 봇 연동
class_name TestClassics
extends TestCase

const Kind := GameEnums.PawnKind
const Sub := GameEnums.PawnSubType
const Phase := TurnManager.State


func _shogi_state(owner_loadout: bool = true) -> GameState:
	var shogi: Array = [Vector2i(Kind.SHOGI, 1), Vector2i(Kind.SHOGI, 2), Vector2i(Kind.SHOGI, 3), Vector2i(Kind.SHOGI, 4)]
	return make_state(2, 1, {1: shogi} if owner_loadout else {})


func _manager(loadouts: Dictionary = {}) -> TurnManager:
	var manager := TurnManager.new()
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	manager.start_game([1, 2] as Array[int], 4242, loadouts)
	return manager


func _dispose(manager: TurnManager) -> void:
	tree.root.remove_child(manager)
	manager.free()


func _do(manager: TurnManager, player_id: int, action: StringName, params: Dictionary = {}) -> void:
	var payload: Dictionary = params.duplicate()
	payload["player_id"] = player_id
	manager.act(action, payload)


# --- 쇼기: 카탈로그 / 증강 ------------------------------------------------------

func test_shogi_catalog_names_letters_and_skill() -> void:
	check_eq(PawnCatalog.display_set_name(Kind.SHOGI), "쇼기", "세트 이름")
	check(PawnCatalog.EVOLVABLE_SETS.has(Kind.SHOGI), "진화 가능한 세트")
	var expected: Array = [["쇼기:보병", "보", "토", Sub.SHOGI_FU], ["쇼기:비차", "비", "용", Sub.SHOGI_HISHA], ["쇼기:각행", "각", "마", Sub.SHOGI_KAKU], ["쇼기:계마", "계", "금", Sub.SHOGI_KEIMA]]
	for unit: int in range(1, 5):
		var entry: Array = expected[unit - 1]
		check_eq(PawnCatalog.sub_type_of(Kind.SHOGI, unit), entry[3], "%d호기 세부 기물" % unit)
		check_eq(PawnCatalog.unit_label(Kind.SHOGI, unit), entry[0], "%d호기 이름" % unit)
		check_eq(PawnCatalog.unit_letter(Kind.SHOGI, unit), entry[1], "%d호기 라벨" % unit)
		check_eq(PawnCatalog.letter_of_pawn(Kind.SHOGI, unit, true), entry[2], "%d호기 승급 라벨" % unit)
		check_eq(PawnCatalog.letter_of_pawn(Kind.SHOGI, unit, false), entry[1], "%d호기 승급 전 라벨" % unit)
	check_eq(PawnCatalog.skill_of(Sub.SHOGI_FU), &"drop", "보병만 필살기(모치고마 낙하)")
	for sub: GameEnums.PawnSubType in [Sub.SHOGI_HISHA, Sub.SHOGI_KAKU, Sub.SHOGI_KEIMA]:
		check_eq(PawnCatalog.skill_of(sub), &"", "나머지 쇼기 기물은 필살기 없음")
	check(PawnCatalog.name_of_pawn(Kind.CHESS, 1, true) == "체스:폰", "쇼기가 아니면 승급 이름이 없다")


func test_shogi_units_are_in_the_augment_pool_and_give_the_right_piece() -> void:
	for unit: int in range(1, 5):
		var def: AugmentDef = AugmentRegistry.get_def(StringName("EVO_%d_%d" % [Kind.SHOGI, unit]))
		check(def != null and def.category == GameEnums.AugmentCategory.PAWN_EVOLUTION, "쇼기 %d호기 기물 지급 증강" % unit)
	var state := make_state(2, 1)
	var def: AugmentDef = AugmentRegistry.get_def(StringName("EVO_%d_1" % Kind.SHOGI))
	check(def.is_available(state, 1), "처음에는 받을 수 있다")
	check(bool(def.apply(state, 1, {"pawn_id": 11})["ok"]), "적용")
	check_eq(state.get_pawn(11).sub_type(), Sub.SHOGI_FU, "1호기는 보병")
	check(not def.is_available(state, 1), "이미 가진 호기는 다시 제시하지 않는다")


# --- 쇼기: 나리(成り) 승급 -----------------------------------------------------

func test_shogi_promotes_when_passing_corner_10() -> void:
	var state: GameState = _shogi_state()
	place(state, 11, 8, [7])
	var report: MoveReport = move(state, 11, 3)  # 9, 10, 11
	check(state.get_pawn(11).promoted, "10번 코너를 지나면 나리 승급")
	check_eq(report.promoted_pawn_ids, int_array([11]), "보고서에 승급한 말")
	check_eq(report.path.size(), 3, "승급한 그 이동에는 보너스가 없다")
	check_eq(state.get_pawn(11).letter(), "토", "보병은 토금")
	check_eq(state.get_pawn(11).display_label(), "쇼기:토금", "승급 이름")
	var again: MoveReport = move(state, 11, 3)
	check_eq(again.path.size(), 4, "승급 뒤에는 이동할 때마다 +1칸")
	check(again.ability_notes.has("나리 승급 +1칸"), "능력 보고")


func test_shogi_promotes_on_center_22_and_ignores_other_kinds() -> void:
	var state: GameState = _shogi_state()
	place(state, 11, 20, [5], true)  # 20 -> 21 -> 22
	move(state, 11, 2)
	check(state.get_pawn(11).promoted, "중앙 22번에 닿으면 승급")
	var warp_state: GameState = _shogi_state()
	place(warp_state, 11, 6, [5])
	move(warp_state, 11, 1)  # 7번 옷장 -> 22번 워프
	check_eq(warp_state.get_pawn(11).current_tile_idx, GameEnums.CENTER_TILE, "옷장 워프로 중앙")
	check(warp_state.get_pawn(11).promoted, "워프로 22번에 도착해도 승급")
	var other: GameState = make_state(2, 1, {1: [Vector2i(Kind.CHESS, 1), Vector2i(Kind.JANGGI, 1), Kind.BASIC, Kind.BASIC]})
	place(other, 12, 8, [7])
	move(other, 12, 3)
	check(not other.get_pawn(12).promoted and not other.get_pawn(13).promoted, "쇼기가 아닌 기물은 승급하지 않는다")


func test_shogi_promotion_is_permanent_but_rolled_back_by_snapshots() -> void:
	var state: GameState = _shogi_state()
	var before: TurnSnapshot = TurnSnapshot.capture(state)
	place(state, 11, 8, [7])
	move(state, 11, 3)
	check(state.get_pawn(11).promoted, "승급")
	state.send_to_start(state.get_pawn(11), 2)
	check(state.get_pawn(11).promoted, "잡혀서 출발선으로 가도 승급은 유지된다 (영구)")
	var after: TurnSnapshot = TurnSnapshot.capture(state)
	before.restore(state)
	check(not state.get_pawn(11).promoted, "ACT_05 롤백은 이번 턴 시작 시점의 승급 상태로 돌린다")
	after.restore(state)
	check(state.get_pawn(11).promoted, "스냅샷에 승급 상태가 담긴다")


func test_shogi_stacked_members_promote_together() -> void:
	var yut: GameState = make_state(2, 1, {1: [Vector2i(Kind.YUT, 1), Vector2i(Kind.SHOGI, 2), Kind.BASIC, Kind.BASIC]})
	place(yut, 11, 8, [7])
	place(yut, 12, 8, [7])
	yut.stack_pawns(yut.get_pawn(11), yut.get_pawn(12))
	move(yut, 11, 3)
	check(yut.get_pawn(12).promoted, "업혀 있는 쇼기 말도 함께 승급")


# --- 쇼기: 병종별 능력 ---------------------------------------------------------

func test_shogi_hisha_gets_straight_line_bonus_and_promoted_everywhere() -> void:
	var state: GameState = _shogi_state()
	place(state, 12, 2, [1])
	check_eq(move(state, 12, 2).path.size(), 4, "외곽 직선에서는 +2칸")
	var diagonal: GameState = _shogi_state()
	place(diagonal, 12, 21, [20])
	check_eq(move(diagonal, 12, 2).path.size(), 2, "대각선에서는 보너스 없음")
	var promoted: GameState = _shogi_state()
	place(promoted, 12, 20, [5])
	promoted.get_pawn(12).promoted = true
	check_eq(move(promoted, 12, 2).path.size(), 5, "나리 승급(용왕)하면 대각선에서도 +2칸, 승급 +1칸")


func test_shogi_kaku_turns_at_corner_when_passing_and_promoted_strikes_ahead() -> void:
	var state: GameState = _shogi_state()
	place(state, 13, 3, [2])
	var report: MoveReport = move(state, 13, 3)
	check_eq(report.path, int_array([4, 5, 20]), "코너를 스치기만 해도 대각선 지름길로 꺾인다")
	var strike: GameState = _shogi_state()
	place(strike, 13, 1, [0])
	strike.get_pawn(13).promoted = true
	place(strike, 21, 5, [4])
	var strike_report: MoveReport = move(strike, 13, 2)  # 2 + 1(승급) = 3칸: 2, 3, 4번
	check_eq(strike.get_pawn(13).current_tile_idx, 4, "4번에 멈춤")
	check(not strike.get_pawn(21).has_left_start, "바로 앞 1칸(5번)의 적 말도 처치")
	check(strike_report.ability_notes.has("용마 앞 1칸 추가 처치"), "능력 보고")
	var plain: GameState = _shogi_state()
	place(plain, 13, 1, [0])
	place(plain, 21, 5, [4])
	move(plain, 13, 2)
	check(plain.get_pawn(21).has_left_start, "승급 전 각행은 앞 칸을 치지 못한다")


func test_shogi_keima_ignores_traps_on_first_two_tiles_only() -> void:
	var state: GameState = _shogi_state()
	state.place_attachment(2, TrapMirrorForce.new(2))
	state.place_attachment(3, TrapMirrorForce.new(2))
	place(state, 14, 1, [0])
	var report: MoveReport = move(state, 14, 4)  # 2, 3, 4, 5
	check(not report.trapped and state.get_pawn(14).current_tile_idx == 5, "첫 2칸의 함정은 뛰어넘는다")
	var third: GameState = _shogi_state()
	third.place_attachment(4, TrapMirrorForce.new(2))
	place(third, 14, 1, [0])
	var third_report: MoveReport = move(third, 14, 4)
	check(third_report.trapped, "셋째 칸의 함정은 걸린다")
	var landing: GameState = _shogi_state()
	landing.place_attachment(3, TrapMirrorForce.new(2))
	place(landing, 14, 1, [0])
	check(move(landing, 14, 2).trapped, "도착 칸이면 첫 2칸 안이어도 판정한다")
	var basic: GameState = make_state(2, 1)
	basic.place_attachment(2, TrapMirrorForce.new(2))
	place(basic, 11, 1, [0])
	check(move(basic, 11, 3).trapped, "계마가 아닌 말은 둘째 칸 함정에 걸린다")


# --- 쇼기: 모치고마 낙하 -------------------------------------------------------

func test_drop_skill_places_a_waiting_pawn_behind_the_fu() -> void:
	var manager: TurnManager = _manager({1: [Vector2i(Kind.SHOGI, 1), Kind.BASIC, Kind.BASIC, Kind.BASIC]})
	var state: GameState = manager.state
	place(state, 11, 6, [5])
	check(manager.can_use_skill(1, 11), "보병은 보드 위에 있으면 필살기를 쓸 수 있다")
	var events: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void: events.append([kind, data]))
	_do(manager, 1, &"use_skill", {"pawn_id": 11, "partner": 13})
	check_eq(state.get_pawn(13).current_tile_idx, 5, "보병 바로 뒷칸(5번)에 낙하")
	check(state.get_pawn(13).has_left_start, "낙하한 말은 출발한 상태")
	check(state.get_pawn(11).skill_used, "필살기 사용 완료")
	check(not state.get_pawn(12).has_left_start, "다른 대기 말은 그대로")
	var skill_events: Array = events.filter(func(entry: Array) -> bool: return entry[0] == &"skill_used")
	check_eq(skill_events.size(), 1, "필살기 이벤트")
	check_eq(skill_events[0][1]["tile"], 5, "이벤트에 낙하 타일")
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "낙하는 주사위를 대신하지 않는다 (굴리기 전 그대로)")
	check(not manager.can_use_skill(1, 11), "한 번만 쓸 수 있다")
	_dispose(manager)


func test_drop_skill_uses_front_tile_when_behind_is_the_start_and_captures() -> void:
	var manager: TurnManager = _manager({1: [Vector2i(Kind.SHOGI, 1), Kind.BASIC, Kind.BASIC, Kind.BASIC]})
	var state: GameState = manager.state
	place(state, 11, 1, [0])
	check_eq(PawnSkills.drop_tile(state, state.get_pawn(11)), 2, "뒷칸이 출발선이면 앞칸에 낙하")
	place(state, 21, 2, [1])
	_do(manager, 1, &"use_skill", {"pawn_id": 11})
	check_eq(state.get_pawn(12).current_tile_idx, 2, "대기 말 하나(가장 앞 슬롯)가 낙하")
	check(not state.get_pawn(21).has_left_start, "낙하한 자리의 적 말은 잡힌다")
	_dispose(manager)


func test_drop_skill_needs_a_waiting_pawn() -> void:
	var manager: TurnManager = _manager({1: [Vector2i(Kind.SHOGI, 1), Kind.BASIC, Kind.BASIC, Kind.BASIC]})
	var state: GameState = manager.state
	place(state, 11, 6, [5])
	for slot: int in [12, 13, 14]:
		place(state, slot, 3, [2])
	var rejected: Array = []
	manager.action_rejected.connect(func(player_id: int, action: StringName, reason: StringName) -> void: rejected.append(reason))
	_do(manager, 1, &"use_skill", {"pawn_id": 11})
	check_eq(rejected, [&"invalid_skill"] as Array, "대기 말이 없으면 거부")
	check(not state.get_pawn(11).skill_used, "사용 완료로 처리되지 않는다")
	_dispose(manager)


# --- 화투 ----------------------------------------------------------------------

func test_hwatu_hand_evaluation() -> void:
	check_eq(ToolHwatu.evaluate([0, 8])["steps"], 8, "1월 광 + 3월 광 = 광땡 8칸")
	check_eq(ToolHwatu.evaluate([0, 8])["label"], "광땡", "광땡 이름")
	check_eq(ToolHwatu.evaluate([4, 5])["steps"], 6, "2땡 6칸")
	check_eq(ToolHwatu.evaluate([16, 17])["steps"], 7, "5땡 7칸")
	check_eq(ToolHwatu.evaluate([36, 37])["steps"], 8, "장땡 8칸")
	check_eq(ToolHwatu.evaluate([1, 5])["steps"], 2, "3끗 2칸")
	check_eq(ToolHwatu.evaluate([13, 9])["steps"], 4, "7끗 4칸")
	check_eq(ToolHwatu.evaluate([13, 5])["steps"], 3, "6끗 3칸")
	check_eq(ToolHwatu.evaluate([13, 21])["id"], &"mangtong", "4월 + 6월 = 망통")
	check_eq(ToolHwatu.evaluate([13, 21])["steps"], 0, "망통 0칸")
	check(ToolHwatu.is_gwang(40) and not ToolHwatu.is_gwang(41) and not ToolHwatu.is_gwang(12), "광은 1·3·8·11·12월의 첫 패")
	check_eq(ToolHwatu.card_type(3), &"pi", "한 달의 마지막 패는 피")
	check_eq(ToolHwatu.card_name(0), "1월 광", "패 이름")


func test_hwatu_go_and_stop_flow() -> void:
	var tool := ToolHwatu.new()
	var rng := RandomNumberGenerator.new()
	tool.forced_draws = [1, 5]  # 3끗 = 2칸
	var first: RollResult = tool.roll(rng)
	check(first.can_continue and tool.has_pending_state() and first.steps == 2, "망통이 아니면 [스톱/고] 선택 대기")
	check_eq((first.details["new_cards"] as Array).size(), 2, "처음에는 패 2장")
	var stop: RollResult = tool.cash_out()
	check(stop.steps == 2 and not stop.can_continue and not tool.has_pending_state(), "스톱하면 누적 칸수 확정")
	tool.forced_draws = [1, 5, 40, 17]  # 고! 광(+5) -> 고! 열끗(+4)
	tool.roll(rng)
	var go_one: RollResult = tool.roll(rng)
	check(go_one.can_continue and go_one.steps == 7 and int(go_one.details["go_count"]) == 1, "첫 고: 광 +5칸 -> 누적 7칸, 계속 선택")
	var go_two: RollResult = tool.roll(rng)
	check(not go_two.can_continue and go_two.steps == 11 and not tool.has_pending_state(), "투고(최대 2회)는 자동 확정: +4칸 -> 11칸")


func test_hwatu_pi_bust_collapses_the_total_to_one_step() -> void:
	var tool := ToolHwatu.new()
	var rng := RandomNumberGenerator.new()
	tool.forced_draws = [36, 37, 3]  # 장땡 8칸 뒤 [고!]에서 피
	var first: RollResult = tool.roll(rng)
	check_eq(first.steps, 8, "장땡 8칸")
	var bust: RollResult = tool.roll(rng)
	check(bool(bust.details["bust"]) and bust.steps == 1 and int(bust.details["lost"]) == 8, "피박: 8칸이 1칸으로")
	check(not bust.can_continue and not tool.has_pending_state(), "피박은 강제 이동으로 끝난다")


func test_hwatu_mangtong_ends_the_turn_and_distribution_is_sane() -> void:
	var tool := ToolHwatu.new()
	var rng := RandomNumberGenerator.new()
	tool.forced_draws = [13, 21]
	var dead: RollResult = tool.roll(rng)
	check(dead.ends_turn and dead.steps == 0 and not tool.has_pending_state(), "망통 0칸 턴 종료")
	rng.seed = 7
	var seen: Dictionary = {}
	for i: int in 600:
		var result: RollResult = ToolHwatu.new().roll(rng)
		seen[result.details["hand"]] = true
		check(result.steps >= 0 and result.steps <= 8, "첫 판은 0~8칸")
	check(seen.has(&"mangtong") and seen.has(&"kkeut") and seen.has(&"ttaeng"), "망통·끗·땡이 모두 나온다")


func test_hwatu_in_turn_manager_flow_go_then_stop() -> void:
	var manager: TurnManager = _manager()
	var tool := ToolHwatu.new()
	tool.forced_draws = [1, 5, 40]
	manager.state.tools[1] = tool
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	check_eq(manager.current_state, Phase.PHASE_ROLL_WAIT, "고/스톱 선택 대기 (계속 굴림 단계)")
	check(manager.move_queue.is_empty(), "아직 이동 대기열에 쌓이지 않는다")
	_do(manager, 1, &"roll")  # 고!
	check_eq(manager.current_state, Phase.PHASE_ROLL_WAIT, "한 번 더 선택 대기")
	_do(manager, 1, &"stop")
	check_eq(manager.current_state, Phase.PHASE_SELECT_PAWN, "스톱하면 말 선택")
	check_eq(manager.move_queue, [7] as Array[int], "2 + 5 = 7칸")
	_dispose(manager)


func test_hwatu_timeout_cashes_out_the_pending_total() -> void:
	var manager: TurnManager = _manager()
	var tool := ToolHwatu.new()
	tool.forced_draws = [1, 5]
	manager.state.tools[1] = tool
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	manager.force_timeout()
	check_eq(manager.current_state, Phase.PHASE_SELECT_PAWN, "시간 초과면 스톱 처리")
	check_eq(manager.move_queue, [2] as Array[int], "누적 2칸")
	_dispose(manager)


# --- 리치 마작 -----------------------------------------------------------------

func test_mahjong_hand_classification() -> void:
	check_eq(ToolMahjong.evaluate([5, 5, 5]), &"kotsu", "같은 패 3개 = 커쯔")
	check_eq(ToolMahjong.evaluate([0, 1, 2]), &"shuntsu", "1-2-3만 = 슌쯔")
	check_eq(ToolMahjong.evaluate([11, 9, 10]), &"shuntsu", "순서와 상관없이 연속 숫자")
	check_eq(ToolMahjong.evaluate([8, 9, 10]), &"pinfu", "9만-1통-2통은 다른 문양이라 슌쯔가 아니다")
	check_eq(ToolMahjong.evaluate([3, 3, 12]), &"toitsu", "같은 패 2개 = 또이츠")
	check_eq(ToolMahjong.evaluate([27, 28, 29]), &"yakuman", "백·발·중 = 대삼원")
	check_eq(ToolMahjong.evaluate([0, 17, 28]), &"yakuman", "서로 다른 요구패 3개 = 국사무쌍")
	check_eq(ToolMahjong.evaluate([1, 4, 20]), &"pinfu", "불일치 = 핑후")
	check_eq(ToolMahjong.tile_name(0), "1만", "1만")
	check_eq(ToolMahjong.tile_name(13), "5통", "5통")
	check_eq(ToolMahjong.tile_name(26), "9삭", "9삭")
	check_eq(ToolMahjong.tile_name(29), "중", "중")


func test_mahjong_category_rolls_match_the_spec_steps() -> void:
	var tool := ToolMahjong.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var expected: Dictionary = {&"pinfu": 2, &"toitsu": 3, &"shuntsu": 5, &"kotsu": 8, &"yakuman": 12}
	for category: StringName in expected.keys():
		for i: int in 20:
			var result: RollResult = tool.roll_category(category, rng)
			check_eq(result.steps, int(expected[category]), "%s 칸수" % category)
			check_eq((result.details["tiles"] as Array).size(), 3, "패 3개")
			check_eq(ToolMahjong.evaluate(result.details["tiles"]), category, "만든 패가 조합 판정과 일치 (%s)" % category)
			check_eq(result.reroll, category == &"yakuman", "역만만 한 번 더")


func test_mahjong_roll_distribution_has_about_eight_percent_yakuman() -> void:
	var tool := ToolMahjong.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var counts: Dictionary = {}
	var total: int = 4000
	for i: int in total:
		var result: RollResult = tool.roll(rng)
		counts[result.details["hand"]] = int(counts.get(result.details["hand"], 0)) + 1
		check(result.steps >= 2 and result.steps <= 12, "2~12칸")
	var yakuman_rate: float = float(counts.get(&"yakuman", 0)) / float(total)
	check(yakuman_rate > 0.06 and yakuman_rate < 0.10, "역만 확률 약 8%% (%.3f)" % yakuman_rate)
	for category: StringName in [&"pinfu", &"toitsu", &"shuntsu", &"kotsu"]:
		check(int(counts.get(category, 0)) > 0, "%s도 나온다" % category)
	var names: Dictionary = {}
	for i: int in 300:
		names[tool.roll_category(&"yakuman", rng).details["label"]] = true
	check(names.has("대삼원") and names.has("국사무쌍"), "역만은 대삼원·국사무쌍 두 가지")


# --- 타로 덱 -------------------------------------------------------------------

func test_tarot_fates_and_blessing() -> void:
	var tool := ToolTarot.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var fool_values: Dictionary = {}
	for i: int in 40:
		fool_values[tool.roll_fate(&"fool", rng).steps] = true
	check(fool_values.has(-2) and fool_values.has(7) and fool_values.size() == 2, "광대는 -2칸 또는 +7칸")
	check_eq(tool.roll_fate(&"chariot", rng).steps, 6, "전차 6칸")
	var wheel: RollResult = tool.roll_fate(&"wheel", rng)
	check(wheel.steps == 4 and wheel.reroll, "수레바퀴 4칸 + 한 번 더")
	check_eq(tool.roll_fate(&"world", rng).steps, 9, "세계 9칸")
	check_eq(tool.tarot_next_bonus, 0, "아직 축복 예약 없음")
	var hanged: RollResult = tool.roll_fate(&"hanged", rng)
	check_eq(hanged.steps, 1, "매달린 남자는 이번에 1칸")
	check_eq(tool.tarot_next_bonus, 8, "다음 굴림에 +8칸 축복 예약 (tarot_next_bonus = 8)")
	var blessed: RollResult = tool.roll_fate(&"world", rng)
	check_eq(blessed.steps, 17, "다음 굴림은 9 + 8칸")
	check_eq(int(blessed.details["bonus"]), 8, "축복 상세")
	check_eq(tool.tarot_next_bonus, 0, "축복은 한 번만")
	check_eq(tool.roll_fate(&"world", rng).steps, 9, "그다음은 평소대로")


func test_tarot_random_roll_covers_all_five_arcana() -> void:
	var tool := ToolTarot.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var fates: Dictionary = {}
	for i: int in 200:
		tool.tarot_next_bonus = 0
		var result: RollResult = tool.roll(rng)
		fates[result.details["fate"]] = true
		check(int(result.details["flipped"]) >= 0 and int(result.details["flipped"]) < 5, "뒤집힌 카드는 5장 중 하나")
	check_eq(fates.size(), 5, "다섯 가지 운명이 모두 나온다")


func test_new_tools_are_registered_and_swappable() -> void:
	for id: StringName in [&"DICE_HWATU", &"DICE_MAHJONG", &"DICE_TAROT"]:
		check(ToolRegistry.ALL_IDS.has(id), "%s 등록" % id)
		check_eq(ToolRegistry.create(id).tool_id, id, "%s 생성" % id)
		var def: AugmentDef = AugmentRegistry.get_def(StringName("TOOL_%s" % id))
		check(def != null and def.category == GameEnums.AugmentCategory.TOOL_SWAP, "%s 판정 도구 교체 증강" % id)
	check_eq(ToolRegistry.create(&"DICE_HWATU").display_name, "화투 고스톱 패", "화투 이름")
	check_eq(ToolRegistry.create(&"DICE_MAHJONG").display_name, "리치 마작 만리장성", "마작 이름")
	check_eq(ToolRegistry.create(&"DICE_TAROT").display_name, "점성술사의 타로 덱", "타로 이름")


# --- TRP_05 도미노 연쇄 붕괴 ---------------------------------------------------

func test_domino_pushes_the_mover_back_three_and_chains_others_two() -> void:
	var state := make_state(2, 1)
	state.place_attachment(6, TrapDomino.new(2))
	place(state, 11, 3, [2])
	place(state, 12, 5, [4])
	place(state, 21, 4, [3])
	place(state, 23, 9, [8])
	var chain: Array = []
	state.domino_collapsed.connect(func(pawn_id: int, _passed: Array[int], chained: Array[int]) -> void: chain.append([pawn_id, chained]))
	var report: MoveReport = move(state, 11, 3)  # 4, 5, 6: 6번 도미노
	check(report.stopped_early, "도미노에 걸려 이동이 중단된다")
	check_eq(state.get_pawn(11).current_tile_idx, 3, "밟은 말은 3칸 뒤(3번)로 밀려난다")
	check_eq(state.get_pawn(12).current_tile_idx, 3, "5번의 말은 2칸 연쇄 후퇴 (같은 편이라 3번에서 함께 선다)")
	check_eq(state.get_pawn(21).current_tile_idx, 2, "4번의 적 말도 2칸 연쇄 후퇴")
	check_eq(state.get_pawn(23).current_tile_idx, 9, "경로 밖의 말은 그대로")
	check_eq(chain.size(), 1, "연쇄 신호")
	check_eq(chain[0][0], 11, "신호의 주인공")
	check_eq((chain[0][1] as Array).size(), 2, "연쇄로 밀린 말 2개")
	check(not state.board.get_tile(6).has_attachment("TRP_05"), "한 번 발동하면 사라진다")


func test_domino_chain_can_push_an_enemy_onto_the_mover_and_get_it_captured() -> void:
	var state := make_state(2, 1)
	state.place_attachment(6, TrapDomino.new(2))
	place(state, 11, 3, [2])
	place(state, 21, 5, [4])
	move(state, 11, 3)
	check_eq(state.get_pawn(11).current_tile_idx, 3, "밟은 말은 3번으로")
	check(not state.get_pawn(21).has_left_start, "연쇄로 밀린 적 말이 밟은 말의 칸에 겹치면 도착 처리로 잡힌다")


func test_domino_affects_any_pawn_including_the_owners_and_without_chain() -> void:
	var state := make_state(2, 1)
	state.place_attachment(9, TrapDomino.new(1))
	place(state, 11, 7, [6])
	move(state, 11, 2)  # 8, 9: 설치한 사람의 말도 걸린다
	check_eq(state.get_pawn(11).current_tile_idx, 6, "설치자의 말도 3칸 뒤로 (9 -> 6)")
	var calm := make_state(2, 1)
	calm.place_attachment(9, TrapDomino.new(2))
	place(calm, 21, 8, [7])
	place(calm, 12, 13, [12])
	var chain_report: Array = []
	calm.domino_collapsed.connect(func(_id: int, _passed: Array[int], chained: Array[int]) -> void: chain_report.append(chained.size()))
	move(calm, 21, 1)
	check_eq(chain_report, [0] as Array, "경로에 다른 말이 없으면 연쇄는 0")
	check_eq(calm.get_pawn(12).current_tile_idx, 13, "다른 말은 영향 없음")


func test_domino_hidden_trap_serializes_and_card_places_it() -> void:
	var state := make_state(2, 1)
	var card: BaseCard = CardRegistry.get_card(&"TRP_05")
	check(card != null and card.category == GameEnums.CardCategory.TRAP and card.needs_tile(), "타일 설치형 함정 카드")
	check_eq(card.display_name, "도미노 연쇄 붕괴", "카드 이름")
	check(card.can_play(state, 1, {"tile": 9}), "일반 타일에는 설치 가능")
	check(not card.can_play(state, 1, {"tile": GameEnums.GOAL_TILE}) and not card.can_play(state, 1, {"tile": GameEnums.CENTER_TILE}), "출발선·중앙에는 설치 불가")
	check(exec(state, card.create_command(state, 1, {"tile": 9})), "설치")
	check(state.board.get_tile(9).has_attachment("TRP_05"), "9번 타일에 도미노")
	check(not card.can_play(state, 1, {"tile": 9}), "같은 타일에 중복 설치 불가")
	var attachment: TileAttachment = state.board.get_tile(9).attachments[0]
	check(attachment.is_hidden_trap and attachment.owner_id == 1, "은신 함정, 설치자 기록")
	var restored: TileAttachment = AttachmentRegistry.from_dict(attachment.serialize())
	check(restored is TrapDomino and restored.owner_id == 1, "직렬화 복원")
	check(CardRegistry.all_ids().has(&"TRP_05"), "카드 풀에 포함")


# --- ACT_07 무너지는 탑 --------------------------------------------------------

func test_tower_targets_the_most_crowded_tile() -> void:
	var state := make_state(2, 1)
	place(state, 11, 8, [7])
	place(state, 21, 8, [7])
	place(state, 22, 8, [7])
	place(state, 12, 15, [14])
	check_eq(TarotEffects.tower_target(state, 1), 8, "말이 가장 많은 8번 타일")
	var tie := make_state(2, 1)
	place(tie, 11, 5, [4])
	place(tie, 21, 5, [4])
	place(tie, 12, 12, [11])
	place(tie, 22, 12, [11])
	place(tie, 23, 12, [11])
	place(tie, 13, 14, [13])
	place(tie, 14, 14, [13])
	check_eq(TarotEffects.tower_target(tie, 1), 12, "수가 더 많은 쪽 (3개)")
	var enemy_heavy := make_state(2, 1)
	place(enemy_heavy, 11, 5, [4])
	place(enemy_heavy, 12, 5, [4])
	place(enemy_heavy, 21, 12, [11])
	place(enemy_heavy, 22, 12, [11])
	check_eq(TarotEffects.tower_target(enemy_heavy, 1), 12, "동수면 적 말이 많은 타일")


func test_tower_falls_back_to_the_leading_enemy_and_needs_pawns() -> void:
	var state := make_state(2, 1)
	check_eq(TarotEffects.tower_target(state, 1), -1, "보드 위에 말이 없으면 대상 없음")
	var card: BaseCard = CardRegistry.get_card(&"ACT_07")
	check(not card.could_play(state, 1), "대상이 없으면 낼 수 없다")
	place(state, 11, 4, [3])
	place(state, 21, 12, [11])
	place(state, 22, 6, [5])
	check_eq(TarotEffects.tower_target(state, 1), 12, "뭉친 곳이 없으면 가장 앞선 적 말(12번)")
	check(card.could_play(state, 1), "낼 수 있다")
	check_eq(card.display_name, "XVI. 무너지는 탑", "카드 이름")
	check(card.is_playable_in(Phase.PHASE_TURN_BEGIN) and not card.is_playable_in(Phase.PHASE_RESOLUTION), "내 턴 시작에만")


func test_tower_scatters_everyone_and_breaks_stacks() -> void:
	var state := make_state(2, 1, {1: [Vector2i(Kind.YUT, 1), Vector2i(Kind.YUT, 2), Kind.BASIC, Kind.BASIC]})
	place(state, 11, 8, [7])
	place(state, 12, 8, [7])
	state.stack_pawns(state.get_pawn(11), state.get_pawn(12))
	place(state, 21, 8, [7])
	place(state, 22, 3, [2])
	var scattered_signal: Array = []
	state.tower_struck.connect(func(tile: int, scattered: Array[Dictionary]) -> void: scattered_signal.append([tile, scattered.size()]))
	var command := TowerCommand.new(1)
	check(exec(state, command), "무너지는 탑 실행")
	check_eq(command.struck_tile, 8, "8번에 벼락")
	var allowed: Array[int] = TarotEffects.tower_scatter_tiles(state, 8)
	for pawn_id: int in [11, 12, 21]:
		var pawn: PlayerPawn = state.get_pawn(pawn_id)
		check(pawn.current_tile_idx != 8 and allowed.has(pawn.current_tile_idx), "말 %d은 앞뒤 1~2칸 인접 타일로 흩어진다 (%d번)" % [pawn_id, pawn.current_tile_idx])
		check(pawn.carrier == null and pawn.carried.is_empty(), "업기 해제")
	check_eq(state.get_pawn(22).current_tile_idx, 3, "다른 타일의 말은 그대로")
	check_eq(scattered_signal, [[8, 3]] as Array, "신호: 8번에서 말 3개")
	check(not allowed.has(GameEnums.GOAL_TILE) and not allowed.has(8), "출발선과 제자리는 흩어질 곳이 아니다")
	var within: Array[int] = state.board.tiles_within(8, 2)
	for tile: int in allowed:
		check(within.has(tile), "반경 2칸 이내")


func test_tower_scatter_is_deterministic_with_the_state_seed() -> void:
	var results: Array = []
	for run: int in 2:
		var state := make_state(2, 777)
		place(state, 11, 8, [7])
		place(state, 21, 8, [7])
		exec(state, TowerCommand.new(1))
		results.append([state.get_pawn(11).current_tile_idx, state.get_pawn(21).current_tile_idx])
	check_eq(results[0], results[1], "같은 시드면 같은 산개")


# --- ACT_08 운명의 수레바퀴 ----------------------------------------------------

func test_wheel_swaps_my_trailing_pawn_with_the_leading_enemy() -> void:
	var state := make_state(2, 1)
	place(state, 11, 3, [2])
	place(state, 12, 9, [8])
	place(state, 21, 15, [14])
	place(state, 22, 6, [5])
	check_eq(TarotEffects.trailing_own(state, 1).entity_id, 11, "내 가장 뒤처진 말")
	check_eq(TarotEffects.leading_enemy(state, 1).entity_id, 21, "가장 앞선 적 말")
	var events: Array = []
	state.wheel_turned.connect(func(player_id: int, mine_id: int, enemy_id: int, outcome: StringName) -> void: events.append([player_id, mine_id, enemy_id, outcome]))
	var command := WheelOfFortuneCommand.new(1)
	check(exec(state, command), "수레바퀴 실행")
	check_eq(state.get_pawn(11).current_tile_idx, 15, "내 꼴찌 말이 15번으로")
	check_eq(state.get_pawn(21).current_tile_idx, 3, "적 선두가 3번으로")
	check_eq(state.get_pawn(12).current_tile_idx, 9, "다른 말은 그대로")
	check_eq(events, [[1, 11, 21, &"swap"]] as Array, "신호")
	check_eq(command.outcome, &"swap", "결과 기록")


func test_wheel_retreats_the_enemy_when_i_have_no_pawn_on_the_field() -> void:
	var state := make_state(2, 1)
	place(state, 21, 12, [10, 11])
	check(TarotEffects.trailing_own(state, 1) == null, "내 말은 보드 위에 없다")
	var command := WheelOfFortuneCommand.new(1)
	check(exec(state, command), "실행")
	check_eq(command.outcome, &"retreat", "후퇴 결과")
	check_eq(state.get_pawn(21).current_tile_idx, 8, "가장 앞선 적 말이 4칸 후퇴 (12 -> 8)")


func test_wheel_cannot_be_played_without_an_enemy_on_the_field() -> void:
	var state := make_state(2, 1)
	place(state, 11, 5, [4])
	var card: BaseCard = CardRegistry.get_card(&"ACT_08")
	check(not card.could_play(state, 1), "보드 위에 적 말이 없으면 낼 수 없다")
	place(state, 21, 7, [6])
	check(card.could_play(state, 1) and card.can_play(state, 1, {}), "적 말이 있으면 낼 수 있다")
	check_eq(card.display_name, "X. 운명의 수레바퀴", "카드 이름")
	check(card.is_playable_in(Phase.PHASE_TURN_BEGIN) and not card.is_playable_in(Phase.PHASE_ROLL_WAIT), "내 턴 시작(굴리기 전)에만")


func test_tarot_cards_follow_the_one_card_per_turn_rule_in_the_manager() -> void:
	var manager: TurnManager = _manager()
	var state: GameState = manager.state
	place(state, 11, 3, [2])
	place(state, 21, 15, [14])
	state.give_card(1, &"ACT_08")
	state.give_card(1, &"ACT_07")
	var rejected: Array = []
	manager.action_rejected.connect(func(player_id: int, action: StringName, reason: StringName) -> void: rejected.append(reason))
	_do(manager, 1, &"play_card", {"card_id": &"ACT_08"})
	check_eq(state.get_pawn(11).current_tile_idx, 15, "수레바퀴가 즉시 발동")
	_do(manager, 1, &"play_card", {"card_id": &"ACT_07"})
	check_eq(rejected, [&"card_limit"] as Array, "굴리기 전 카드는 턴당 1장")
	_dispose(manager)


func test_new_cards_are_in_the_deck_and_registry() -> void:
	for card_id: StringName in [&"TRP_05", &"ACT_07", &"ACT_08"]:
		check(CardRegistry.get_card(card_id) != null, "%s 등록" % card_id)
		check(CardRegistry.default_deck().has(card_id), "%s 기본 덱에 포함" % card_id)
	check_eq(CardRegistry.get_card(&"ACT_06").display_name, "이의 있음! 법전 파기", "기존 ACT_06은 그대로")


# --- AI 봇 --------------------------------------------------------------------

func test_bot_hwatu_goes_once_at_most() -> void:
	var tool := ToolHwatu.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	check(not BotBrain.hwatu_should_go(tool, rng), "진행 중이 아니면 고하지 않는다")
	tool.forced_draws = [1, 5]
	tool.roll(rng)
	var goes: int = 0
	for seed_value: int in 60:
		var test_rng := RandomNumberGenerator.new()
		test_rng.seed = seed_value + 1
		if BotBrain.hwatu_should_go(tool, test_rng):
			goes += 1
	check(goes > 15 and goes < 45, "첫 고는 확률적으로 도전 (%d/60)" % goes)
	tool.forced_draws = [40]
	tool.roll(rng)  # 고 1회
	for seed_value: int in 30:
		var test_rng := RandomNumberGenerator.new()
		test_rng.seed = seed_value + 1
		check(not BotBrain.hwatu_should_go(tool, test_rng), "이미 한 번 고했으면 스톱")


func test_bot_uses_drop_skill_and_tarot_cards_sensibly() -> void:
	var state: GameState = _shogi_state()
	place(state, 11, 6, [5])
	var option: Dictionary = BotBrain.skill_option(state, state.get_pawn(11))
	check(not option.is_empty() and float(option["value"]) > BotBrain.SKILL_USE_THRESHOLD, "대기 말이 있으면 낙하를 쓸 가치가 있다")
	check(int((option["params"] as Dictionary)["partner"]) in [12, 13, 14], "낙하시킬 대기 말을 고른다")
	check(not BotBrain.plan_skill(state, 1).is_empty(), "plan_skill이 낙하를 고른다")
	for slot: int in [12, 13, 14]:
		place(state, slot, 3, [2])
	check(BotBrain.skill_option(state, state.get_pawn(11)).is_empty(), "대기 말이 없으면 쓰지 않는다")
	var wheel_state := make_state(2, 1)
	place(wheel_state, 11, 1, [0])
	place(wheel_state, 21, 16, [15])
	wheel_state.hands[1] = [&"ACT_08"] as Array[StringName]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var plan: Dictionary = BotBrain.plan_turn_card(wheel_state, 1, {}, rng)
	check_eq(plan.get("card_id", &""), &"ACT_08", "내가 크게 뒤처지고 적이 앞서 있으면 수레바퀴를 쓴다")
	var even := make_state(2, 1)
	place(even, 11, 14, [13])
	place(even, 21, 15, [14])
	even.hands[1] = [&"ACT_08"] as Array[StringName]
	check(BotBrain.plan_turn_card(even, 1, {}, rng).is_empty(), "차이가 작으면 쓰지 않는다")
