# File: res://tests/test_sub_types.gd
# Class: class_name TestSubTypes
# Role: 호기별 세부 기물(PawnSubType) - 체스 폰/나이트/비숍/룩/퀸, 장기 포/차/마/상, 모노폴리 미니카/비행기/증기선/강아지, 바둑 흑돌/백돌의 고유 능력 검증
class_name TestSubTypes
extends TestCase

const Kind := GameEnums.PawnKind
const Sub := GameEnums.PawnSubType


func _units(kind: GameEnums.PawnKind, units: Array) -> Array:
	var loadout: Array = []
	for unit: int in units:
		loadout.append(Vector2i(kind, unit))
	while loadout.size() < 4:
		loadout.append(0)
	return loadout


func _full(kind: GameEnums.PawnKind) -> Array:
	return _units(kind, [1, 2, 3, 4])


# --- 카탈로그 / 진화 -------------------------------------------------------------

func test_every_set_maps_units_to_the_documented_sub_types() -> void:
	var expected: Dictionary = {
		Kind.YUT: [Sub.YUT_MAL, Sub.YUT_MAL, Sub.YUT_MAL, Sub.YUT_MAL],
		Kind.CHESS: [Sub.CHESS_PAWN, Sub.CHESS_KNIGHT, Sub.CHESS_BISHOP, Sub.CHESS_ROOK],
		Kind.JANGGI: [Sub.JANGGI_PO, Sub.JANGGI_CHA, Sub.JANGGI_MA, Sub.JANGGI_SANG],
		Kind.MONOPOLY: [Sub.MONO_CAR, Sub.MONO_PLANE, Sub.MONO_SHIP, Sub.MONO_DOG],
		Kind.GO: [Sub.BADUK_BLACK, Sub.BADUK_WHITE, Sub.BADUK_BLACK, Sub.BADUK_WHITE],
	}
	for kind: GameEnums.PawnKind in expected:
		for unit: int in 4:
			check_eq(PawnCatalog.sub_type_of(kind, unit + 1), (expected[kind] as Array)[unit], "%d세트 %d호기" % [kind, unit + 1])
	check_eq(PawnCatalog.sub_type_of(Kind.CHESS, GameEnums.CHESS_QUEEN_UNIT), Sub.CHESS_QUEEN, "승진한 폰은 퀸")
	check_eq(PawnCatalog.sub_type_of(Kind.BASIC, 0), Sub.NONE, "기본 말은 세부 기물 없음")


func test_labels_letters_and_ability_texts_for_the_ui() -> void:
	var letters: Dictionary = {Sub.CHESS_PAWN: "폰", Sub.CHESS_KNIGHT: "나", Sub.CHESS_BISHOP: "비", Sub.CHESS_ROOK: "룩", Sub.CHESS_QUEEN: "퀸",
			Sub.JANGGI_PO: "포", Sub.JANGGI_CHA: "차", Sub.JANGGI_MA: "마", Sub.JANGGI_SANG: "상",
			Sub.MONO_CAR: "카", Sub.MONO_PLANE: "비", Sub.MONO_SHIP: "배", Sub.MONO_DOG: "개",
			Sub.BADUK_BLACK: "흑", Sub.BADUK_WHITE: "백", Sub.YUT_MAL: "윷"}
	for sub: GameEnums.PawnSubType in letters:
		check_eq(PawnCatalog.SUB_LETTERS[sub], letters[sub], "라벨 %d" % sub)
		check(String(PawnCatalog.SUB_NAMES[sub]) != "" and String(PawnCatalog.SUB_ABILITIES[sub]) != "", "이름·능력 설명 %d" % sub)
	check_eq(PawnCatalog.unit_label(Kind.CHESS, 3), "체스:비숍", "툴팁용 이름")
	check_eq(PawnCatalog.ability_text(Kind.CHESS, 3), "코너 스침 지름길", "비숍 능력 설명")
	check_eq(PawnCatalog.unit_label(Kind.YUT, 4), "윷말", "윷은 1~4호기 모두 윷말")
	check_eq(PawnCatalog.unit_letter(Kind.BASIC, 0), "", "기본 말은 라벨 없음")


func test_evolution_assigns_sub_types_in_pickup_order() -> void:
	var state := make_state()
	for slot: int in [4, 2, 3, 1]:
		state.evolve_pawn(state.get_pawn(10 + slot), Kind.JANGGI)
	check_eq(state.get_pawn(14).sub_type(), Sub.JANGGI_PO, "처음 진화한 말이 포")
	check_eq(state.get_pawn(12).sub_type(), Sub.JANGGI_CHA, "두 번째는 차")
	check_eq(state.get_pawn(13).sub_type(), Sub.JANGGI_MA, "세 번째는 마")
	check_eq(state.get_pawn(11).sub_type(), Sub.JANGGI_SANG, "네 번째는 상")


# --- 체스 -----------------------------------------------------------------------

func test_chess_pawn_promotes_to_queen_when_it_steps_on_the_back_ranks() -> void:
	var state := make_state(2, 1, {1: _units(Kind.CHESS, [1, 1])})
	place(state, 11, 13, [12])
	var report: MoveReport = move(state, 11, 4)  # 14, 15(승진), 16, 17
	check_eq(state.get_pawn(11).sub_type(), Sub.CHESS_QUEEN, "15번을 밟는 순간 퀸으로 승진")
	check_eq(report.promoted_pawn_ids, int_array([11]), "승진 보고")
	check_eq(state.get_pawn(11).display_label(), "체스:퀸", "표기도 퀸")
	var stays := make_state(2, 1, {1: _units(Kind.CHESS, [1])})
	place(stays, 11, 11, [10])
	move(stays, 11, 3)  # 14번에서 멈춤: 아직 승진 구간이 아니다
	check_eq(stays.get_pawn(11).sub_type(), Sub.CHESS_PAWN, "14번까지는 폰 그대로")
	var knight := make_state(2, 1, {1: _units(Kind.CHESS, [2])})
	place(knight, 11, 13, [12])
	move(knight, 11, 3)
	check_eq(knight.get_pawn(11).sub_type(), Sub.CHESS_KNIGHT, "나이트는 승진하지 않는다")


func test_chess_pawn_promotes_on_the_center_tile_including_portal_warp() -> void:
	var state := make_state(2, 1, {1: _units(Kind.CHESS, [1])})
	place(state, 11, 6, [5])
	move(state, 11, 1)  # 7번 옷장에 멈춰 22번으로 워프
	check_eq(state.get_pawn(11).current_tile_idx, 22, "옷장 워프")
	check_eq(state.get_pawn(11).sub_type(), Sub.CHESS_QUEEN, "중앙에 도착하면 승진")
	var passing := make_state(2, 1, {1: _units(Kind.CHESS, [1])})
	place(passing, 11, 21, [10, 25, 26, 22, 23, 24, 15, 16, 17, 18, 19, 0, 1, 2, 3, 4, 5, 20, 21])
	passing.get_pawn(11).step_history = [5, 20, 21]
	move(passing, 11, 2)  # 22를 스쳐 23
	check_eq(passing.get_pawn(11).sub_type(), Sub.CHESS_QUEEN, "스쳐 지나가도 중앙을 밟는 순간 승진")


func test_promotion_survives_snapshot_restore() -> void:
	var state := make_state(2, 1, {1: _units(Kind.CHESS, [1])})
	place(state, 11, 14, [13])
	var snapshot := TurnSnapshot.capture(state)
	move(state, 11, 2)
	check_eq(state.get_pawn(11).sub_type(), Sub.CHESS_QUEEN, "승진")
	snapshot.restore(state)
	check_eq(state.get_pawn(11).sub_type(), Sub.CHESS_PAWN, "되감으면 폰으로 복구")


func test_queen_has_knight_jump_bishop_turn_and_rook_boost() -> void:
	var queen: Array = [Vector2i(Kind.CHESS, GameEnums.CHESS_QUEEN_UNIT), 0, 0, 0]
	var state := make_state(2, 1, {1: queen})
	check(state.get_pawn(11).jumps_over_attachments() and state.get_pawn(11).turns_at_corner_when_passing() and state.get_pawn(11).has_rook_boost(), "퀸은 세 능력을 모두 가진다")
	state.place_attachment(8, TrapPit.new(2))
	place(state, 11, 5, [4])
	var jumped: MoveReport = move(state, 11, 4)  # 룩 +1 = 5칸: 5번에서 출발이라 지름길(20..)로 들어간다
	check(not jumped.stopped_early, "퀸은 함정을 무시하고 점프")
	var rook_only := make_state(2, 1, {1: _units(Kind.CHESS, [4])})
	place(rook_only, 11, 2, [1])
	move(rook_only, 11, 3)
	check_eq(rook_only.get_pawn(11).current_tile_idx, 6, "룩: 외곽 출발이면 3 + 1 = 4칸")


func test_bishop_turns_at_a_corner_it_only_passes_but_not_under_law_01() -> void:
	var state := make_state(2, 1, {1: _units(Kind.CHESS, [1, 2, 3])})
	place(state, 13, 4, [3])
	var report: MoveReport = move(state, 13, 2)
	check_eq(report.path, int_array([5, 20]), "비숍은 5번을 스쳐도 지름길로 꺾는다")
	var plain := make_state(2, 1, {1: _units(Kind.CHESS, [1, 2, 3])})
	place(plain, 11, 4, [3])
	check_eq(move(plain, 11, 2).path, int_array([5, 6]), "폰은 그냥 지나간다")
	var sealed := make_state(2, 1, {1: _units(Kind.CHESS, [1, 2, 3])})
	var ctx: RuleContext = make_ctx(sealed, 2)
	ctx.allow_shortcut = false  # LAW_01(지름길 공사 중)이 ON_MOVE_CALC에서 하는 일
	place(sealed, 13, 4, [3])
	check_eq(MoveExecutor.execute(sealed, sealed.get_pawn(13), ctx).path, int_array([5, 6]), "LAW_01 중에는 꺾이지 않는다")


func test_rook_boost_only_applies_when_leaving_from_the_outer_track() -> void:
	var state := make_state(2, 1, {1: _units(Kind.CHESS, [4])})
	place(state, 11, 0, [], false)
	move(state, 11, 2)
	check_eq(state.get_pawn(11).current_tile_idx, 3, "출발선에서도 +1칸")
	var inner := make_state(2, 1, {1: _units(Kind.CHESS, [4])})
	place(inner, 11, 21, [20])
	inner.get_pawn(11).step_history = [5, 20, 21]
	var report: MoveReport = move(inner, 11, 1)
	check_eq(report.path.size(), 1, "지름길 안(20번대)에서는 보너스 없음")
	var bishop := make_state(2, 1, {1: _units(Kind.CHESS, [1, 2, 3])})
	place(bishop, 13, 2, [1])
	move(bishop, 13, 2)
	check_eq(bishop.get_pawn(13).current_tile_idx, 4, "비숍에게는 룩 보너스가 없다")


# --- 장기 -----------------------------------------------------------------------

func test_janggi_cannon_is_only_the_first_unit() -> void:
	var state := make_state(2, 1, {1: _full(Kind.JANGGI)})
	place(state, 12, 8, [7])  # 2호기 차는 포 넘기가 없다
	place(state, 21, 10, [9])
	var report: MoveReport = move(state, 12, 4)
	check(not report.cannon_bonus, "차에게는 포 넘기 없음")
	var po := make_state(2, 1, {1: _full(Kind.JANGGI)})
	place(po, 11, 8, [7])
	place(po, 21, 10, [9])
	check(move(po, 11, 4).cannon_bonus, "포는 +2칸")


func test_janggi_cha_rams_the_first_enemy_on_the_way() -> void:
	var state := make_state(2, 1, {1: _units(Kind.JANGGI, [2])})
	place(state, 11, 8, [7])
	place(state, 21, 9, [8])
	place(state, 22, 11, [10])
	var report: MoveReport = move(state, 11, 4)  # 9, 10, 11, 12
	check_eq(state.get_pawn(11).current_tile_idx, 12, "차는 멈추지 않고 12번까지 간다")
	check_eq(state.get_pawn(21).current_tile_idx, 0, "첫 번째 적은 들이받혀 출발선으로")
	check_eq(state.get_pawn(22).current_tile_idx, 11, "두 번째 적은 그대로 (이동 한 번에 하나)")
	check_eq(report.rammed_pawn_ids, int_array([21]), "들이받기 보고")
	check_eq(report.captured_pawn_ids, int_array([21]), "들이받기는 잡기로 센다")
	check(state.hurt_players.has(2), "피해자 기록(ACT_05 조건)")
	check(not report.extra_turn, "장기 4세트가 아니면 추가 굴림 없음")
	var two_set := make_state(2, 1, {1: _units(Kind.JANGGI, [1, 2])})
	place(two_set, 12, 8, [7])
	place(two_set, 21, 9, [8])
	move(two_set, 12, 4)
	check_eq(two_set.get_pawn(21).current_tile_idx, 9, "장기 2세트 초나라 포진: 들이받힌 말은 출발선 대신 제자리에서")
	check_eq(two_set.get_pawn(21).restrained_turns, 1, "1턴 구속")


func test_janggi_cha_ram_skips_immune_stones_and_normal_capture_happens_on_landing() -> void:
	var state := make_state(2, 1, {1: _units(Kind.JANGGI, [2]), 2: _units(Kind.GO, [1, 2])})
	place(state, 11, 8, [7])
	place(state, 21, 9, [8])   # 포석 무적: 건너뛴다
	place(state, 22, 12, [11])  # 도착 칸의 적은 평소 잡기
	var report: MoveReport = move(state, 11, 4)
	check_eq(state.get_pawn(21).current_tile_idx, 9, "무적 바둑돌은 들이받히지 않는다")
	check(report.rammed_pawn_ids.is_empty(), "들이받기 없음")
	check(report.pushed_back, "도착 칸의 무적 바둑돌도 잡히지 않아 이동한 말이 밀려난다")
	var landing := make_state(2, 1, {1: _units(Kind.JANGGI, [2])})
	place(landing, 11, 8, [7])
	place(landing, 21, 10, [9])
	var plain: MoveReport = move(landing, 11, 2)  # 10번에 도착: 경로 중간이 아니므로 일반 잡기
	check(plain.rammed_pawn_ids.is_empty() and plain.captured_pawn_ids == int_array([21]), "도착 칸은 일반 잡기로 처리")


func test_janggi_cha_ram_grants_extra_turn_only_with_four_set() -> void:
	var state := make_state(2, 1, {1: _full(Kind.JANGGI)})
	place(state, 12, 8, [7])
	place(state, 21, 9, [8])
	check(move(state, 12, 3).extra_turn, "4세트 차의 들이받기는 추가 굴림")


func test_janggi_ma_gets_plus_one_when_open_and_one_tile_when_blocked() -> void:
	var open_state := make_state(2, 1, {1: _units(Kind.JANGGI, [1, 2, 3])})
	place(open_state, 13, 2, [1])
	move(open_state, 13, 3)
	check_eq(open_state.get_pawn(13).current_tile_idx, 6, "앞이 비면 3 + 1 = 4칸")
	var blocked := make_state(2, 1, {1: _units(Kind.JANGGI, [1, 2, 3])})
	place(blocked, 13, 2, [1])
	place(blocked, 21, 3, [2])  # 멱 막힘 (적이든 아군이든)
	var report: MoveReport = move(blocked, 13, 5)
	check_eq(blocked.get_pawn(13).current_tile_idx, 3, "막히면 1칸만 이동")
	check(report.captured_pawn_ids == int_array([21]), "1칸 이동한 도착 칸의 적은 잡는다")
	var ally := make_state(2, 1, {1: _units(Kind.JANGGI, [1, 2, 3])})
	place(ally, 13, 2, [1])
	place(ally, 11, 3, [2])
	move(ally, 13, 4)
	check_eq(ally.get_pawn(13).current_tile_idx, 3, "아군이 막아도 1칸")


func test_janggi_sang_needs_two_clear_tiles_for_plus_two() -> void:
	var clear := make_state(2, 1, {1: _full(Kind.JANGGI)})
	place(clear, 14, 2, [1])
	move(clear, 14, 2)
	check_eq(clear.get_pawn(14).current_tile_idx, 6, "앞 2칸이 비면 2 + 2 = 4칸")
	var blocked := make_state(2, 1, {1: _full(Kind.JANGGI)})
	place(blocked, 14, 2, [1])
	place(blocked, 21, 4, [3])  # 두 번째 칸에 말
	move(blocked, 14, 3)
	check_eq(blocked.get_pawn(14).current_tile_idx, 5, "말이 있으면 기본 눈금만 이동")
	var one: MoveReport = move(clear, 14, 1)
	check(one.ability_notes.has("상 도약 +2칸"), "눈금 1이면 앞 1칸만 확인")


# --- 모노폴리 ---------------------------------------------------------------------

func test_only_the_mini_car_builds_hotels_until_the_four_set() -> void:
	var state := make_state(2, 1, {1: _units(Kind.MONOPOLY, [1, 2, 3])})
	place(state, 11, 0, [], false)
	place(state, 12, 0, [], false)
	check(move(state, 11, 2).hotel_built, "미니카는 호텔 건설")
	check(not move(state, 12, 3).hotel_built, "비행기는 건설하지 않는다")
	var full := make_state(2, 1, {1: _full(Kind.MONOPOLY)})
	for pawn_id: int in [12, 13, 14]:
		place(full, pawn_id, 0, [], false)
		check(move(full, pawn_id, 2 + pawn_id % 10).hotel_built, "4세트면 %d번 말도 호텔 건설" % pawn_id)


func test_plane_warps_to_the_next_corner_instead_of_the_center() -> void:
	var state := make_state(2, 1, {1: _units(Kind.MONOPOLY, [1, 2])})
	place(state, 12, 6, [5])
	var report: MoveReport = move(state, 12, 1)  # 7번 옷장
	check_eq(state.get_pawn(12).current_tile_idx, 10, "7번 옷장 -> 10번 코너")
	check(report.warped, "워프 보고")
	place(state, 12, 16, [15])
	move(state, 12, 1)  # 17번 옷장
	check_eq(state.get_pawn(12).current_tile_idx, 19, "17번 옷장 -> 결승 직전 19번")
	place(state, 11, 6, [5])
	move(state, 11, 1)
	check_eq(state.get_pawn(11).current_tile_idx, 22, "미니카는 평소처럼 중앙으로")


func test_steamship_destroys_only_the_first_hostile_attachment_without_triggering_it() -> void:
	var state := make_state(2, 1, {1: _units(Kind.MONOPOLY, [1, 2, 3])})
	state.place_attachment(8, TrapPit.new(2))
	state.place_attachment(9, TrapMirrorForce.new(2))
	state.place_attachment(8, TrapMirrorForce.new(1))  # 내 설치물은 건드리지 않는다
	place(state, 13, 6, [5])
	var report: MoveReport = move(state, 13, 3)  # 7, 8, 9
	check_eq(report.destroyed_attachments.size(), 1, "첫 번째 칸의 상대 설치물만 파괴")
	check_eq((report.destroyed_attachments[0] as Dictionary)["attachment_id"], "TRP_02", "나락 파괴")
	check(not state.board.get_tile(8).has_attachment("TRP_02"), "파괴됨")
	check(state.board.get_tile(8).has_attachment("TRP_01"), "내 설치물은 남는다")
	check(report.trapped, "두 번째 함정(9번 거울의 힘)은 평소처럼 발동")
	var plain := make_state(2, 1, {1: _units(Kind.MONOPOLY, [1])})
	plain.place_attachment(8, TrapPit.new(2))
	place(plain, 11, 6, [5])
	check(move(plain, 11, 4).stopped_early, "미니카는 함정에 걸린다")


func test_dog_draws_a_card_for_every_bakery_it_only_passes() -> void:
	var state := make_state(2, 1, {1: _full(Kind.MONOPOLY)})
	place(state, 14, 6, [5])
	var report: MoveReport = move(state, 14, 4)  # 7, 8(빵집 통과), 9, 10
	check_eq(report.dog_cards, 1, "스친 빵집에서 카드 1장")
	check_eq((state.hands[1] as Array).size(), 1, "손패에 반영")
	var car := make_state(2, 1, {1: _full(Kind.MONOPOLY)})
	place(car, 11, 6, [5])
	check_eq(move(car, 11, 4).dog_cards, 0, "다른 기물은 스치기만 해서는 카드가 없다")
	var landing := make_state(2, 1, {1: _full(Kind.MONOPOLY)})
	place(landing, 14, 6, [5])
	move(landing, 14, 2)  # 8번 빵집에 도착: 평소 보너스 한 장만
	check_eq((landing.hands[1] as Array).size(), 1, "도착한 빵집은 한 장")


# --- 바둑 -----------------------------------------------------------------------

func test_only_black_stones_knock_and_white_stones_capture_normally() -> void:
	var black := make_state(2, 1, {1: _units(Kind.GO, [1])})
	place(black, 11, 2, [1])
	place(black, 21, 4, [3])
	var knocked: MoveReport = move(black, 11, 2)
	check_eq(knocked.knocked_pawn_ids, int_array([21]), "흑돌은 알까기")
	check_eq(black.get_pawn(21).current_tile_idx, 6, "2칸 튕김")
	var white := make_state(2, 1, {1: _units(Kind.GO, [1, 2])})
	place(white, 12, 2, [1])
	place(white, 21, 4, [3])
	var captured: MoveReport = move(white, 12, 3)  # 포석 2세트: 눈금 -1 = 2칸
	check_eq(captured.captured_pawn_ids, int_array([21]), "백돌은 평소처럼 잡는다")
	check_eq(white.get_pawn(21).current_tile_idx, 0, "출발선으로")
	check(not captured.extra_turn, "추가 굴림은 없다")
	var third := make_state(2, 1, {1: _units(Kind.GO, [1, 2, 3])})
	check(third.get_pawn(13).sub_type() == Sub.BADUK_BLACK, "3호기도 흑돌")


func test_white_stone_shields_other_allies_on_its_tile() -> void:
	var state := make_state(2, 1, {1: [Vector2i(Kind.GO, 2), 0, 0, 0]})
	place(state, 11, 4, [3])  # 백돌
	place(state, 12, 4, [3])  # 같은 칸의 일반 기물
	place(state, 21, 2, [1])
	var report: MoveReport = move(state, 21, 2)
	check_eq(report.captured_pawn_ids, int_array([11]), "방어막은 백돌 자신에게는 없다 - 백돌이 잡힌다")
	check_eq(state.get_pawn(12).current_tile_idx, 4, "같은 칸의 아군은 면역이라 살아남는다")
	check(state.get_pawn(12).has_left_start, "출발 상태 유지")
	check(MoveExecutor.is_capture_immune(state, state.get_pawn(12)) == false, "백돌이 떠나면 방어막도 사라진다")


func test_everyone_immune_pushes_the_attacker_back() -> void:
	var state := make_state(2, 1, {1: _units(Kind.GO, [1, 2])})  # 바둑 2세트 포석: 바둑돌 전원 무적
	place(state, 11, 4, [3])
	place(state, 12, 4, [3])
	place(state, 13, 4, [3])  # 기본 말 (백돌 방어막)
	place(state, 21, 2, [1])
	var report: MoveReport = move(state, 21, 2)
	check(report.pushed_back, "잡을 수 있는 말이 없으면 침입자가 밀려난다")
	check_eq(state.get_pawn(21).current_tile_idx, 3, "한 칸 뒤로")
	check(report.captured_pawn_ids.is_empty(), "아무도 잡히지 않음")


func test_pawn_tooltip_texts_name_the_unit_and_set_synergy() -> void:
	check_eq(PawnCatalog.full_name(GameEnums.PawnKind.CHESS, 3), "[체스 3호기 - 비숍]", "전체 이름")
	check_eq(PawnCatalog.full_name(GameEnums.PawnKind.BASIC, 1), "[기본 말]", "기본 말 이름")
	var line: String = PawnCatalog.synergy_line(GameEnums.PawnKind.CHESS, 2)
	check(line.contains("체스 세트 (2/4)") and line.contains("2세트 활성: 캐슬링") and line.contains("체크메이트"), "세트 시너지 현황 (%s)" % line)
	check(PawnCatalog.synergy_line(GameEnums.PawnKind.GO, 1).contains("2세트 대기: 포석"), "1세트면 2세트 효과는 대기")
	check_eq(PawnCatalog.synergy_line(GameEnums.PawnKind.BASIC, 1), "", "기본 말은 시너지 없음")
