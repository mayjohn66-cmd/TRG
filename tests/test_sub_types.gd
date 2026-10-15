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
	check(PawnCatalog.ability_text(Kind.CHESS, 3).contains("코너"), "비숍 능력 설명")
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


# --- 장기 -----------------------------------------------------------------------


# --- 모노폴리 ---------------------------------------------------------------------


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


func test_white_stone_is_immune_and_shields_other_allies_on_its_tile() -> void:
	var state := make_state(2, 1, {1: [Vector2i(Kind.GO, 2), 0, 0, 0]})
	place(state, 11, 4, [3])  # 백돌
	place(state, 12, 4, [3])  # 같은 칸의 일반 기물
	place(state, 21, 2, [1])
	check(MoveExecutor.is_capture_immune(state, state.get_pawn(11)), "백돌은 세트 없이도 무적")
	check(MoveExecutor.is_capture_immune(state, state.get_pawn(12)), "같은 칸의 아군도 방어막으로 면역")
	var report: MoveReport = move(state, 21, 2)
	check(report.pushed_back and report.captured_pawn_ids.is_empty(), "아무도 잡히지 않고 침입자가 밀려난다")
	state.get_pawn(11).current_tile_idx = 9
	check(not MoveExecutor.is_capture_immune(state, state.get_pawn(12)), "백돌이 떠나면 방어막도 사라진다")


func test_black_stones_alone_are_not_immune() -> void:
	var state := make_state(2, 1, {1: _units(Kind.GO, [1, 3])})
	place(state, 11, 4, [3])
	place(state, 12, 4, [3])
	place(state, 21, 2, [1])
	var report: MoveReport = move(state, 21, 2)
	check(not report.pushed_back and not report.captured_pawn_ids.is_empty(), "흑돌만 있는 칸은 평범하게 잡힌다")
