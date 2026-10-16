# File: res://tests/test_active_skills.gd
# Class: class_name TestActiveSkills
# Role: 세트 효과 삭제 이후의 기물 단독 패시브(백돌 무적·퀸 +2·비숍 +2·포 +3·마 +2·상 +3·윷말 4/5 추가 굴림 등)와 1회용 필살기 4종(흑돌 알까기·차 저격·룩 캐슬링·비행기 워프), 봇의 필살기 판단 검증
class_name TestActiveSkills
extends TestCase

const Phase := TurnManager.State
const Kind := GameEnums.PawnKind


func _units(kind: GameEnums.PawnKind, units: Array) -> Array:
	var loadout: Array = []
	for unit: int in units:
		loadout.append(Vector2i(kind, unit))
	while loadout.size() < 4:
		loadout.append(0)
	return loadout


func _manager(loadouts: Dictionary = {}, players: int = 2) -> TurnManager:
	var manager := TurnManager.new()
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	var ids: Array[int] = []
	for i: int in range(1, players + 1):
		ids.append(i)
	manager.start_game(ids, 777, loadouts)
	return manager


func _dispose(manager: TurnManager) -> void:
	tree.root.remove_child(manager)
	manager.free()


func _do(manager: TurnManager, player_id: int, action: StringName, params: Dictionary = {}) -> void:
	var payload: Dictionary = params.duplicate()
	payload["player_id"] = player_id
	manager.act(action, payload)


func _rejections(manager: TurnManager) -> Array:
	var rejected: Array = []
	manager.action_rejected.connect(func(_player: int, _action: StringName, reason: StringName) -> void: rejected.append(reason))
	return rejected


# --- 단독 패시브 --------------------------------------------------------------

func test_queen_always_moves_two_extra_tiles_and_ignores_traps() -> void:
	var state := make_state(2, 1, {1: _units(Kind.CHESS, [5])})
	place(state, 11, 7, [6])
	state.place_attachment(9, TrapPit.new(2))
	var report: MoveReport = move(state, 11, 3)
	check_eq(report.path.size(), 5, "눈금 3 + 퀸 보너스 2 = 5칸")
	check(not report.stopped_early, "중간 칸 함정은 뛰어넘어 무시")


func test_bishop_gets_two_extra_tiles_only_when_the_path_touches_a_corner() -> void:
	var state := make_state(2, 1, {1: _units(Kind.CHESS, [3])})
	place(state, 11, 3, [2])
	check_eq(move(state, 11, 3).path.size(), 5, "6번 코너를 밟으면 +2칸 (3 + 2)")
	var outer := make_state(2, 1, {1: _units(Kind.CHESS, [3])})
	place(outer, 11, 1, [0])
	check_eq(move(outer, 11, 2).path.size(), 2, "코너를 건드리지 않으면 보너스 없음")
	var halfway := make_state(2, 1, {1: _units(Kind.CHESS, [3])})
	place(halfway, 11, 10, [9])
	check_eq(move(halfway, 11, 3).path.size(), 5, "12번 코너를 스쳐도 +2칸")


func test_cannon_adds_three_tiles_when_any_pawn_is_in_the_middle_of_the_path() -> void:
	var state := make_state(2, 1, {1: _units(Kind.JANGGI, [1])})
	place(state, 11, 1, [0])
	place(state, 21, 3, [2])
	check_eq(move(state, 11, 4).path.size(), 7, "경로 중간에 말이 있으면 +3칸")
	var clear := make_state(2, 1, {1: _units(Kind.JANGGI, [1])})
	place(clear, 11, 1, [0])
	check_eq(move(clear, 11, 4).path.size(), 4, "말이 없으면 기본 눈금")


func test_horse_and_elephant_get_bonus_tiles_only_when_the_tile_ahead_is_clear() -> void:
	for entry: Array in [[3, 2], [4, 3]]:
		var open := make_state(2, 1, {1: _units(Kind.JANGGI, [entry[0]])})
		place(open, 11, 10, [9])
		check_eq(move(open, 11, 2).path.size(), 2 + int(entry[1]), "앞이 비면 +%d칸 (%d호기)" % [entry[1], entry[0]])
		var blocked := make_state(2, 1, {1: _units(Kind.JANGGI, [entry[0]])})
		place(blocked, 11, 10, [9])
		place(blocked, 21, 11, [10])
		check_eq(move(blocked, 11, 2).path.size(), 2, "막혀 있으면 기본 눈금만 이동 (페널티 없음)")


func test_white_stone_is_immune_and_slower_while_black_stone_captures_normally() -> void:
	var state := make_state(2, 1, {1: _units(Kind.GO, [2]), 2: _units(Kind.GO, [1])})
	place(state, 11, 4, [3])
	place(state, 21, 2, [1])
	var intruder: MoveReport = move(state, 21, 2)
	check(intruder.pushed_back, "백돌은 잡히지 않아 침입자가 밀려난다")
	check_eq(state.get_pawn(11).current_tile_idx, 4, "백돌은 그대로")
	place(state, 11, 11, [10])
	check_eq(move(state, 11, 4).path.size(), 3, "백돌은 눈금 -1")
	var black := make_state(2, 1, {1: _units(Kind.GO, [1]), 2: _units(Kind.GO, [1])})
	place(black, 11, 2, [1])
	place(black, 21, 4, [3])
	var captured: MoveReport = move(black, 11, 2)
	check_eq(captured.captured_pawn_ids, int_array([21]), "흑돌은 평범하게 잡는다 (알까기 상시 효과 없음)")
	check_eq(black.get_pawn(21).current_tile_idx, 0, "잡힌 말은 출발선으로")


func test_only_yut_pawns_earn_the_capture_extra_turn_and_no_set_effects_remain() -> void:
	var state := make_state(2, 1, {1: _units(Kind.JANGGI, [1, 2, 3, 4])})
	place(state, 11, 2, [1])
	place(state, 21, 4, [3])
	var report: MoveReport = move(state, 11, 2)
	check(not report.extra_turn, "장기 4세트를 모아도 잡기 추가 굴림은 없다")
	check_eq(state.get_pawn(21).current_tile_idx, 0, "초나라 포진 구속 없이 출발선으로")
	check_eq(state.get_pawn(21).restrained_turns, 0, "구속 없음")
	var yut := make_state(2, 1, {1: _units(Kind.YUT, [1])})
	place(yut, 11, 2, [1])
	place(yut, 21, 4, [3])
	check(move(yut, 11, 2).extra_turn, "윷말은 잡으면 추가 굴림")


func test_only_the_mini_car_builds_hotels() -> void:
	var state := make_state(2, 1, {1: _units(Kind.MONOPOLY, [1, 2, 3, 4])})
	place(state, 11, 1, [0])
	place(state, 12, 1, [0])
	check(move(state, 11, 2).hotel_built, "미니카는 호텔 건설")
	check(not move(state, 12, 3).hotel_built, "비행기는 4세트를 모아도 호텔을 못 짓는다")


# --- 필살기 ----------------------------------------------------------------

func test_skill_catalog_has_exactly_four_one_shot_skills() -> void:
	var found: Dictionary = {}
	for kind: GameEnums.PawnKind in PawnCatalog.EVOLVABLE_SETS:
		for unit: int in range(1, 5):
			var skill: StringName = PawnCatalog.skill_of(PawnCatalog.sub_type_of(kind, unit))
			if skill != &"":
				found[skill] = PawnCatalog.unit_label(kind, unit)
	check_eq(found.size(), 5, "필살기는 5종 (알까기·전차·캐슬링·워프·모치고마 낙하)")
	check_eq(found[&"shoot"], "바둑:흑돌", "알까기 슈팅은 흑돌")
	check_eq(found[&"charge"], "장기:차", "직선 저격은 차")
	check_eq(found[&"castle"], "체스:룩", "단독 캐슬링은 룩")
	check_eq(found[&"warp"], "모노:비행기", "직항 워프는 비행기")


func test_rook_castle_swaps_with_an_ally_once_and_keeps_the_roll() -> void:
	var manager: TurnManager = _manager({1: _units(Kind.CHESS, [4, 1])})
	place(manager.state, 11, 5, [4])
	place(manager.state, 12, 9, [8])
	var rejected: Array = _rejections(manager)
	check(manager.can_use_skill(1, 11), "턴 시작에 룩 필살기 사용 가능")
	_do(manager, 1, &"use_skill", {"pawn_id": 11, "partner": 12})
	check_eq(manager.state.get_pawn(11).current_tile_idx, 9, "룩이 아군 위치로")
	check_eq(manager.state.get_pawn(12).current_tile_idx, 5, "아군이 룩 위치로")
	check(manager.state.get_pawn(11).skill_used, "사용 완료")
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "굴림 전이므로 같은 단계에 머문다")
	_do(manager, 1, &"use_skill", {"pawn_id": 11, "partner": 12})
	check_eq(rejected.size(), 1, "게임당 1회만")
	manager.command_stack.undo_last()
	check(not manager.state.get_pawn(11).skill_used, "ACT_05식 되감기로 필살기도 되돌아간다")
	_dispose(manager)


func test_chariot_charges_to_the_first_enemy_and_captures_it() -> void:
	var manager: TurnManager = _manager({1: _units(Kind.JANGGI, [2])})
	place(manager.state, 11, 1, [0])
	place(manager.state, 21, 4, [3])
	place(manager.state, 22, 8, [7])
	_do(manager, 1, &"use_skill", {"pawn_id": 11})
	check_eq(manager.state.get_pawn(11).current_tile_idx, 4, "가장 앞의 적이 선 타일까지 돌진")
	check_eq(manager.state.get_pawn(21).current_tile_idx, 0, "그 적을 잡음")
	check(not manager.state.get_pawn(21).has_left_start, "출발선으로 쫓겨남")
	check(manager.state.get_pawn(22).has_left_start, "뒤의 적은 그대로")
	check(manager.state.get_pawn(11).skill_used, "사용 완료")
	check_eq(manager.current_player_id(), 2, "주사위 대신이라 바로 턴 종료")
	_dispose(manager)


func test_chariot_without_enemies_runs_to_the_end_corner() -> void:
	var manager: TurnManager = _manager({1: _units(Kind.JANGGI, [2])})
	place(manager.state, 11, 7, [6])
	_do(manager, 1, &"use_skill", {"pawn_id": 11})
	check_eq(manager.state.get_pawn(11).current_tile_idx, 12, "적이 없으면 다음 코너(12번)까지")
	_dispose(manager)


func test_plane_warps_to_a_bakery_or_corner_in_place_of_rolling() -> void:
	var manager: TurnManager = _manager({1: _units(Kind.MONOPOLY, [2])})
	place(manager.state, 11, 1, [0])
	var rejected: Array = _rejections(manager)
	_do(manager, 1, &"use_skill", {"pawn_id": 11, "tile": 5})
	check_eq(rejected.size(), 1, "빵집·코너가 아닌 타일은 거부")
	_do(manager, 1, &"use_skill", {"pawn_id": 11, "tile": 14})
	check_eq(manager.state.get_pawn(11).current_tile_idx, 14, "빵집으로 직항")
	check_eq((manager.state.hands[1] as Array).size(), 1, "도착한 빵집에서 카드 획득")
	check(manager.state.get_pawn(11).skill_used, "사용 완료")
	check_eq(manager.current_player_id(), 2, "턴 종료")
	_dispose(manager)


func test_black_stone_shot_eliminates_every_enemy_on_the_line_and_lands_on_the_nearest_tile() -> void:
	var manager: TurnManager = _manager({1: _units(Kind.GO, [1])})
	place(manager.state, 11, 1, [0])
	place(manager.state, 21, 3, [2])
	place(manager.state, 22, 5, [4])
	place(manager.state, 23, 15, [14])
	_do(manager, 1, &"use_skill", {"pawn_id": 11, "angle": -PI / 2.0, "power": 1.0})
	check(not manager.state.get_pawn(21).has_left_start and not manager.state.get_pawn(22).has_left_start, "직선에 닿은 적은 모두 출발선으로 탈락")
	check(manager.state.get_pawn(23).has_left_start, "직선 밖의 적은 무사")
	check_eq(manager.state.get_pawn(11).current_tile_idx, 6, "멈춘 좌표에서 가장 가까운 타일(코너 6번)에 안착, 점프는 하지 않는다")
	check(manager.state.get_pawn(11).skill_used, "사용 완료")
	_dispose(manager)


func test_black_stone_shot_skips_immune_white_stones_and_takes_whole_stacks() -> void:
	var state := make_state(2, 1, {1: _units(Kind.GO, [1]), 2: _units(Kind.GO, [2, 1])})
	place(state, 11, 1, [0])
	place(state, 21, 3, [2])
	place(state, 22, 5, [4])
	var shot: Dictionary = PawnSkills.shot_result(state, state.get_pawn(11), -PI / 2.0, 1.0)
	check(not (shot["hits"] as Array).has(21), "백돌은 무적이라 맞지 않는다")
	check((shot["hits"] as Array).has(22), "흑돌은 맞는다")
	check_eq(shot["landing"], 6, "도착 타일")
	check(BoardLayout.nearest_tile(Vector2(1.0, 1.0)) != 0, "출발선(0번)은 안착 후보에서 제외")


func test_skills_are_refused_in_the_wrong_phase_or_state() -> void:
	var manager: TurnManager = _manager({1: _units(Kind.JANGGI, [2])})
	var rejected: Array = _rejections(manager)
	_do(manager, 1, &"use_skill", {"pawn_id": 11})
	check_eq(rejected.size(), 1, "출발선에 있는 말은 필살기를 못 쓴다")
	place(manager.state, 11, 1, [0])
	manager.state.tools[1] = ScriptedTool.new([2])
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	check_eq(manager.current_state, Phase.PHASE_SELECT_PAWN, "말 선택 단계")
	_do(manager, 1, &"use_skill", {"pawn_id": 11})
	check_eq(rejected.size(), 2, "굴린 뒤(말 선택 단계)에는 못 쓴다")
	manager.state.get_pawn(11).skill_used = false
	_do(manager, 2, &"use_skill", {"pawn_id": 21})
	check_eq(rejected.size(), 3, "남의 턴에는 못 쓴다")
	_dispose(manager)


func test_bot_uses_skills_only_when_the_angle_is_good() -> void:
	var state := make_state(2, 1, {2: _units(Kind.JANGGI, [2])})
	place(state, 21, 1, [0])
	check(BotBrain.plan_skill(state, 2).is_empty(), "적이 없으면 차 필살기를 아낀다")
	place(state, 11, 14, [13])
	place(state, 12, 16, [15])
	var plan: Dictionary = BotBrain.plan_skill(state, 2)
	check(not plan.is_empty() and int(plan["pawn_id"]) == 21, "앞선 적을 잡을 수 있으면 사용")
	var shooter := make_state(2, 1, {2: _units(Kind.GO, [1])})
	place(shooter, 21, 1, [0])
	place(shooter, 11, 3, [2])
	place(shooter, 12, 5, [4])
	var shot_plan: Dictionary = BotBrain.plan_skill(shooter, 2)
	check(not shot_plan.is_empty() and (shot_plan["params"] as Dictionary).has("angle"), "흑돌은 적 두 개를 꿰는 각을 찾는다")
	var shot: Dictionary = PawnSkills.shot_result(shooter, shooter.get_pawn(21), float(shot_plan["params"]["angle"]), float(shot_plan["params"]["power"]))
	check((shot["hits"] as Array).size() >= 2, "고른 각이 실제로 둘 이상 맞힌다")


func test_bot_controller_fires_a_skill_during_its_turn() -> void:
	var manager: TurnManager = _manager({2: _units(Kind.JANGGI, [2])})
	place(manager.state, 21, 1, [0])
	place(manager.state, 11, 14, [13])
	manager.advance_to_next_player()
	check_eq(manager.current_player_id(), 2, "봇 턴")
	var bot := BotController.new()
	bot.manager = manager
	bot.enabled = true
	bot.instant = true
	defer_free(bot)
	for i: int in 6:
		bot.tick(0.1)
		if manager.state.get_pawn(21).skill_used:
			break
	check(manager.state.get_pawn(21).skill_used, "봇이 필살기를 사용")
	check_eq(manager.state.get_pawn(11).current_tile_idx, 0, "잡힌 말은 출발선")
	_dispose(manager)
