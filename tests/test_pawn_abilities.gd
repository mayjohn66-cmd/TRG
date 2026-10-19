# File: res://tests/test_pawn_abilities.gd
# Class: class_name TestPawnAbilities
# Role: 나머지 기물 능력(나이트 점프·캐슬링·포 넘기·초나라 포진·알까기·포석)과 ACT_02 뱅! 저격·ACT_03 우노 +4 검증
class_name TestPawnAbilities
extends TestCase

const Phase := TurnManager.State
const Kind := GameEnums.PawnKind


func _loadout(kind: GameEnums.PawnKind) -> Array:
	return [Vector2i(kind, 1), Vector2i(kind, 2), Vector2i(kind, 3), Vector2i(kind, 4)]


func _two(kind: GameEnums.PawnKind) -> Array:
	return [Vector2i(kind, 1), Vector2i(kind, 2), 0, 0]


func _manager(loadouts: Dictionary = {}, players: int = 3) -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
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


# --- 체스 -------------------------------------------------------------------

func test_knight_jump_ignores_intermediate_traps_but_not_the_landing_trap() -> void:
	var state := make_state(2, 1, {1: _loadout(Kind.CHESS)})
	state.place_attachment(3, TrapPit.new(2))
	place(state, 12, 1)  # 2호기 나이트
	var jumped: MoveReport = move(state, 12, 4)
	check(not jumped.stopped_early, "중간 칸 함정 무시")
	check_eq(state.get_pawn(12).current_tile_idx, 5, "5번까지 도약")
	check(state.board.get_tile(3).has_attachment("TRP_02"), "무시한 함정은 그대로 남음")
	place(state, 11, 1)  # 1호기 폰은 걸린다
	var pawn_hit: MoveReport = move(state, 11, 4)
	check(pawn_hit.stopped_early, "다른 기물은 중간 함정에 걸림")
	check_eq(state.get_pawn(11).current_tile_idx, 3, "함정 칸에서 정지")
	var landing := make_state(2, 1, {1: _loadout(Kind.CHESS)})
	landing.place_attachment(5, TrapPit.new(2))
	place(landing, 12, 1)
	var landed: MoveReport = move(landing, 12, 4)
	check(landed.stopped_early, "도착 칸 함정은 발동")
	check_eq(landing.get_pawn(12).restrained_turns, 2, "구속됨")


func test_knight_jump_ignores_hotels_on_the_way() -> void:
	var state := make_state(2, 1, {1: _loadout(Kind.CHESS)})
	state.place_attachment(3, Hotel.new(2))
	place(state, 12, 1)
	var report: MoveReport = move(state, 12, 4)
	check(not report.stopped_early, "중간 호텔 무시")
	check(state.board.get_tile(3).has_attachment("HOTEL"), "호텔은 소모되지 않음")


# --- 장기 -------------------------------------------------------------------


# --- 바둑 -------------------------------------------------------------------


func test_non_go_pawns_still_capture_normally() -> void:
	var state := make_state(2, 1)
	place(state, 11, 2)
	place(state, 21, 4)
	var report: MoveReport = move(state, 11, 2)
	check_eq(report.captured_pawn_ids, [21], "일반 기물은 잡는다")
	check_eq(state.get_pawn(21).current_tile_idx, 0, "출발선으로")


# --- ACT_02 뱅! 저격 저격 ------------------------------------------------------------

func test_bang_targets_players_with_pawns_on_the_board() -> void:
	var state := make_state(3, 1)
	check_eq(BangCommand.target_players(state, 1), [], "보드에 나온 상대 말이 없으면 대상 없음")
	place(state, 21, 7)
	check_eq(BangCommand.target_players(state, 1), [2], "나온 말이 있는 상대만 대상")
	place(state, 31, 9)
	check_eq(BangCommand.target_players(state, 1), [2, 3], "여러 상대")
	place(state, 11, 5)
	check(not BangCommand.target_players(state, 1).has(1), "나 자신은 대상이 아니다")
	place(state, 22, 12)
	check_eq(BangCommand.find_target(state, 2).entity_id, 22, "선두 말(결승에 가까운 말)이 저격당한다")


func test_bang_ejects_the_front_pawn_to_the_start_line() -> void:
	var state := make_state(2, 1)
	place(state, 21, 6)
	place(state, 22, 9)  # 선두
	var stack: CommandStack = new_stack()
	var results: Array = []
	state.bang_resolved.connect(func(shooter: int, target: int, from_tile: int, to_tile: int) -> void: results.append([shooter, target, from_tile, to_tile]))
	check(stack.execute_command(BangCommand.new(1, 2), make_ctx(state, 0)), "발사")
	check_eq(results, [[1, 22, 9, 0]], "선두 말이 출발선으로 사출")
	check_eq(state.get_pawn(22).current_tile_idx, 0, "0번 출발선")
	check(not state.get_pawn(22).has_left_start and state.get_pawn(22).revenge_boost, "출발 대기 상태 + 복수 부스터")
	check_eq(state.get_pawn(21).current_tile_idx, 6, "다른 말은 그대로")
	check(not stack.execute_command(BangCommand.new(1, 1), make_ctx(state, 0)), "나 자신은 저격할 수 없다")


func test_bang_card_is_playable_only_at_turn_begin_with_a_chosen_target() -> void:
	var manager: TurnManager = _manager({}, 2)
	var rejected: Array = []
	manager.action_rejected.connect(func(_p: int, _a: StringName, reason: StringName) -> void: rejected.append(reason))
	manager.state.give_card(1, &"ACT_02")
	_do(manager, 1, &"play_card", {"card_id": &"ACT_02", "target_player": 2})
	check_eq(rejected, [&"invalid_target"], "대상이 없으면 사용 불가")
	place(manager.state, 21, 7)
	_do(manager, 1, &"play_card", {"card_id": &"ACT_02"})
	check_eq(rejected.back(), &"invalid_target", "저격할 상대를 고르지 않으면 사용 불가")
	var events: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void: events.append([kind, data]))
	_do(manager, 1, &"play_card", {"card_id": &"ACT_02", "target_player": 2})
	check(not manager.state.has_card(1, &"ACT_02"), "카드 소모")
	check_eq(manager.state.get_pawn(21).current_tile_idx, 0, "상대 선두 말이 출발선으로 사출")
	var kinds: Array = events.map(func(e: Array) -> StringName: return e[0])
	check(kinds.has(&"bang_resolved"), "bang_resolved 이벤트")
	_dispose(manager)


# --- ACT_03 우노 +4 ---------------------------------------------------------------

func test_uno_plus_four_ejects_the_next_players_front_pawn_and_boosts_mine() -> void:
	var state := make_state(3, 1)
	state.turn_direction = 1
	place(state, 21, 9)
	place(state, 22, 4)
	place(state, 11, 1, [0])
	var stack: CommandStack = new_stack()
	var results: Array = []
	state.bomb_resolved.connect(func(shooter: int, victim: int, pawn_id: int, from_tile: int, to_tile: int) -> void: results.append([shooter, victim, pawn_id, from_tile, to_tile]))
	check(stack.execute_command(PenaltyBombCommand.new(1), make_ctx(state, 0)), "발동")
	check_eq(results, [[1, 2, 21, 9, 0]], "다음 플레이어의 선두 말이 출발선으로 사출")
	check_eq(state.get_pawn(21).current_tile_idx, 0, "사출")
	check_eq(state.get_pawn(22).current_tile_idx, 4, "다른 말은 그대로")
	check_eq(state.get_pawn(11).current_tile_idx, 5, "내 선두 말은 +4칸 전진 (1 -> 5)")
	var reversed := make_state(3, 1)
	reversed.turn_direction = -1
	place(reversed, 31, 9)
	check(new_stack().execute_command(PenaltyBombCommand.new(1), make_ctx(reversed, 0)), "역방향 발동")
	check_eq(reversed.get_pawn(31).current_tile_idx, 0, "역방향이면 반대편 플레이어")
	check_eq(reversed.get_pawn(11).current_tile_idx, 4, "보드에 말이 없으면 출발 대기 말이 +4칸 나간다")


func test_uno_plus_four_needs_a_pawn_on_the_board_and_is_played_at_turn_begin() -> void:
	var manager: TurnManager = _manager({}, 2)
	var rejected: Array = []
	manager.action_rejected.connect(func(_p: int, _a: StringName, reason: StringName) -> void: rejected.append(reason))
	manager.state.give_card(1, &"ACT_03")
	_do(manager, 1, &"play_card", {"card_id": &"ACT_03"})
	check_eq(rejected, [&"invalid_target"], "다음 플레이어의 말이 보드에 없으면 사용 불가")
	place(manager.state, 21, 9, [8])
	var events: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void: events.append([kind, data]))
	_do(manager, 1, &"play_card", {"card_id": &"ACT_03"})
	check_eq(manager.state.get_pawn(21).current_tile_idx, 0, "즉시 출발선으로 사출")
	check(not manager.state.has_card(1, &"ACT_03"), "카드 소모")
	var kinds: Array = events.map(func(e: Array) -> StringName: return e[0])
	check(kinds.has(&"bomb_applied"), "bomb_applied 이벤트")
	_dispose(manager)


