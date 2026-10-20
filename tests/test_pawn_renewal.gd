# File: res://tests/test_pawn_renewal.gd
# Class: class_name TestPawnRenewal
# Role: v4.0 기물 리뉴얼(룩·비차 직진, 각행·용마 코너, 상 +2)과 신규 아케이드 기물 5종(킹 체커·루도 복수자·8번 공·스타 카트·지뢰찾기 공병)의 패시브, 새 필살기 6종(피앙케토·코끼리 지진·용왕 베기·용마 십자 베기·뱅크샷·지뢰 매설) 검증 (24칸 보드: 코너 6·12·18)
class_name TestPawnRenewal
extends TestCase

const Kind := GameEnums.PawnKind
const Phase := TurnManager.State


func _units(kind: GameEnums.PawnKind, units: Array) -> Array:
	var loadout: Array = []
	for unit: int in units:
		loadout.append(Vector2i(kind, unit))
	while loadout.size() < 4:
		loadout.append(0)
	return loadout


func _manager(loadouts: Dictionary) -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	manager.start_game([1, 2] as Array[int], 777, loadouts)
	return manager


func _dispose(manager: TurnManager) -> void:
	tree.root.remove_child(manager)
	manager.free()


func _skill(manager: TurnManager, pawn_id: int, params: Dictionary = {}) -> void:
	var payload: Dictionary = params.duplicate()
	payload["player_id"] = 1
	payload["pawn_id"] = pawn_id
	manager.act(&"use_skill", payload)


# --- 리뉴얼 패시브 --------------------------------------------------------------

func test_rook_and_hisha_get_plus_two_only_on_a_straight_line() -> void:
	for loadout: Array in [_units(Kind.CHESS, [4]), _units(Kind.SHOGI, [2])]:
		var state := make_state(2, 1, {1: loadout})
		place(state, 11, 1, [0])
		check_eq(move(state, 11, 3).path, int_array([2, 3, 4, 5, 6]), "코너를 꺾지 않는 직진 +2")
		var turn := make_state(2, 1, {1: loadout})
		place(turn, 11, 4, [3])
		check_eq(move(turn, 11, 3).path, int_array([5, 6, 7]), "코너를 지나 꺾으면 보너스 없음")


func test_kaku_gets_two_at_a_corner_and_three_as_dragon_horse() -> void:
	var state := make_state(2, 1, {1: _units(Kind.SHOGI, [3])})
	place(state, 11, 4, [3])
	check_eq(move(state, 11, 2).path.size(), 4, "코너를 밟으면 +2")
	var horse := make_state(2, 1, {1: _units(Kind.SHOGI, [3])})
	place(horse, 11, 4, [3])
	horse.get_pawn(11).promoted = true
	check_eq(move(horse, 11, 2).path.size(), 2 + 1 + 3, "용마: 나리 +1 + 코너 +3")


# --- 아케이드 패시브 ------------------------------------------------------------

func test_checkers_king_captures_enemies_it_passes_over() -> void:
	var state := make_state(2, 1, {1: _units(Kind.ARCADE, [1])})
	place(state, 11, 1, [0])
	place(state, 21, 2, [1])
	place(state, 22, 3, [2])
	var report: MoveReport = move(state, 11, 3)
	check(not state.get_pawn(21).has_left_start and not state.get_pawn(22).has_left_start, "지나간 칸의 적 둘을 처치")
	check(report.captured_pawn_ids.has(21) and report.captured_pawn_ids.has(22), "보고서에 처치 기록")
	check_eq(state.stat(1, VictoryLaw.KILLS), 2, "처치 기록")


func test_ludo_avenger_revenge_booster_is_eight() -> void:
	var state := make_state(2, 1, {1: _units(Kind.ARCADE, [2])})
	state.boost_gimmicks = true
	var pawn: PlayerPawn = state.get_pawn(11)
	pawn.revenge_boost = true
	check_eq(move(state, 11, 2).path.size(), 2 + 8, "복수 부스터 +8")


func test_eight_ball_rolls_three_more_after_a_kill() -> void:
	var state := make_state(2, 1, {1: _units(Kind.ARCADE, [3])})
	place(state, 11, 1, [0])
	place(state, 21, 3, [2])
	move(state, 11, 2)
	check(not state.get_pawn(21).has_left_start, "처치")
	check_eq(state.get_pawn(11).current_tile_idx, 3 + MoveExecutor.EIGHT_BALL_CHARGE, "처치 후 +3칸")


func test_star_kart_ignores_traps_and_gets_two_on_follow_ups() -> void:
	var state := make_state(2, 1, {1: _units(Kind.ARCADE, [4])})
	place(state, 11, 1, [0])
	state.place_attachment(3, TrapMine.new(2))
	move(state, 11, 3)
	check_eq(state.get_pawn(11).current_tile_idx, 4, "지뢰를 그냥 지나간다")
	check_eq(state.board.get_tile(3).attachments.size(), 1, "카트는 해체하지 않는다")
	var ctx: RuleContext = make_ctx(state, 3)
	ctx.charge_depth = 1
	check_eq(MoveExecutor.plan_path(state, state.get_pawn(11), ctx, MoveReport.new()).size(), 5, "추가 이동 +2")


func test_minesweeper_defuses_enemy_traps_for_a_card() -> void:
	var state := make_state(2, 1, {1: _units(Kind.ARCADE, [5])})
	place(state, 11, 1, [0])
	state.place_attachment(3, TrapMine.new(2))
	state.place_attachment(4, TrapMine.new(1))
	var report: MoveReport = move(state, 11, 4)
	check_eq(state.get_pawn(11).current_tile_idx, 5, "함정 면역")
	check(state.board.get_tile(3).attachments.is_empty(), "적 지뢰 해체")
	check_eq(state.board.get_tile(4).attachments.size(), 1, "내 지뢰는 그대로")
	check_eq(report.defused_cards, 1, "해체 카드 1장")
	check_eq((state.hands[1] as Array).size(), 1, "손패 +1")


# --- 새 필살기 -----------------------------------------------------------------

func test_bishop_fianchetto_warps_to_the_diagonal_corner() -> void:
	var manager: TurnManager = _manager({1: _units(Kind.CHESS, [3])})
	place(manager.state, 11, 2, [1])
	check_eq(PawnSkills.fianchetto_tile(manager.state.get_pawn(11)), 2 * BoardSpec.side, "0번 코너의 대각선 = 반환점")
	_skill(manager, 11)
	check_eq(manager.state.get_pawn(11).current_tile_idx, 2 * BoardSpec.side, "대각선 코너로 이동")
	check(manager.state.get_pawn(11).skill_used, "1회 사용")
	_dispose(manager)
	var late := make_state(2, 1, {1: _units(Kind.CHESS, [3])})
	place(late, 11, 3 * BoardSpec.side + 1, [3 * BoardSpec.side])
	check_eq(PawnSkills.fianchetto_tile(late.get_pawn(11)), -1, "결승을 넘으면 쓸 수 없다")


func test_elephant_quake_destroys_attachments_two_tiles_around_and_keeps_the_roll() -> void:
	var manager: TurnManager = _manager({1: _units(Kind.JANGGI, [4])})
	var state: GameState = manager.state
	place(state, 11, 8, [7])
	for tile: int in [6, 7, 9, 10, 11]:
		state.place_attachment(tile, TrapMine.new(2))
	_skill(manager, 11)
	for tile: int in [6, 7, 9, 10]:
		check(state.board.get_tile(tile).attachments.is_empty(), "%d번 설치물 파괴" % tile)
	check_eq(state.board.get_tile(11).attachments.size(), 1, "3칸 떨어진 설치물은 남는다")
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "굴림은 그대로 남는다")
	manager.command_stack.undo_last()
	check_eq(state.board.get_tile(6).attachments.size(), 1, "되감기로 복원")
	_dispose(manager)


func test_hisha_slash_needs_promotion_and_cuts_two_tiles_ahead() -> void:
	var manager: TurnManager = _manager({1: _units(Kind.SHOGI, [2])})
	var state: GameState = manager.state
	place(state, 11, 8, [7])
	place(state, 21, 9, [8])
	place(state, 22, 10, [9])
	place(state, 23, 11, [10])
	check(not manager.can_use_skill(1, 11), "승급 전에는 못 쓴다")
	state.get_pawn(11).promoted = true
	_skill(manager, 11)
	check(not state.get_pawn(21).has_left_start and not state.get_pawn(22).has_left_start, "앞 2칸 처치")
	check(state.get_pawn(23).has_left_start, "3칸 앞은 안전")
	_dispose(manager)


func test_kaku_horse_cuts_one_tile_ahead_and_behind() -> void:
	var manager: TurnManager = _manager({1: _units(Kind.SHOGI, [3])})
	var state: GameState = manager.state
	place(state, 11, 8, [7])
	place(state, 21, 7, [6])
	place(state, 22, 9, [8])
	place(state, 23, 10, [9])
	state.get_pawn(11).promoted = true
	_skill(manager, 11)
	check(not state.get_pawn(21).has_left_start and not state.get_pawn(22).has_left_start, "앞뒤 1칸 처치")
	check(state.get_pawn(23).has_left_start, "2칸 앞은 안전")
	_dispose(manager)


func test_eight_ball_bank_shot_dashes_to_the_nearest_enemy_ahead() -> void:
	var manager: TurnManager = _manager({1: _units(Kind.ARCADE, [3])})
	var state: GameState = manager.state
	place(state, 11, 2, [1])
	place(state, 21, 8, [7])
	place(state, 22, 14, [13])
	check_eq(PawnSkills.bank_shot_path(state, state.get_pawn(11)).back(), 8, "가장 가까운 적까지")
	_skill(manager, 11)
	check(not state.get_pawn(21).has_left_start, "들이받아 처치")
	check_eq(state.get_pawn(11).current_tile_idx, 8 + MoveExecutor.EIGHT_BALL_CHARGE, "처치 후 +3칸 (패시브)")
	_dispose(manager)


func test_minesweeper_plants_a_mine_on_its_tile() -> void:
	var manager: TurnManager = _manager({1: _units(Kind.ARCADE, [5])})
	var state: GameState = manager.state
	place(state, 11, 8, [7])
	_skill(manager, 11)
	var tile: TileNode = state.board.get_tile(8)
	check(tile.attachments.size() == 1 and tile.attachments[0].attachment_id == "TRP_03" and tile.attachments[0].owner_id == 1, "내 지뢰가 깔렸다")
	check(state.get_pawn(11).skill_used, "1회 사용")
	_dispose(manager)
