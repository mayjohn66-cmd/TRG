# File: res://tests/test_pawn_abilities.gd
# Class: class_name TestPawnAbilities
# Role: 나머지 기물 능력(나이트 점프·캐슬링·포 넘기·초나라 포진·알까기·포석)과 ACT_02 뱅!·ACT_03 우노 +4 검증
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


func test_castling_swaps_two_chess_pawns_once_per_turn() -> void:
	var manager: TurnManager = _manager({1: _two(Kind.CHESS)})
	place(manager.state, 11, 4)
	place(manager.state, 12, 9)
	check(manager.can_castle(1), "체스 2기가 판 위에 있으면 캐슬링 가능")
	check(not manager.can_castle(2), "내 턴이 아니면 불가")
	_do(manager, 1, &"castle")
	check_eq(manager.state.get_pawn(11).current_tile_idx, 9, "11번이 9번으로")
	check_eq(manager.state.get_pawn(12).current_tile_idx, 4, "12번이 4번으로")
	check(not manager.can_castle(1), "턴당 1회")
	var rejected: Array = []
	manager.action_rejected.connect(func(_p: int, _a: StringName, reason: StringName) -> void: rejected.append(reason))
	_do(manager, 1, &"castle")
	check_eq(rejected, [&"wrong_phase"], "두 번째 시도는 거부")
	_dispose(manager)


func test_castling_requires_two_chess_pawns_on_board_and_resets_next_turn() -> void:
	var manager: TurnManager = _manager({1: _two(Kind.CHESS)})
	place(manager.state, 11, 4)
	check(not manager.can_castle(1), "판 위에 체스가 하나뿐이면 불가")
	place(manager.state, 12, 4)
	check(not manager.can_castle(1), "같은 타일이면 의미 없음")
	place(manager.state, 12, 8)
	_do(manager, 1, &"castle")
	manager.state.tools[1] = ScriptedTool.new([2])
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	manager.force_timeout()
	check_eq(manager.current_player_id(), 2, "턴이 넘어감")
	manager.advance_to_next_player()
	manager.advance_to_next_player()
	check_eq(manager.current_player_id(), 1, "다시 1번 턴")
	check(manager.can_castle(1), "새 턴에는 다시 사용 가능")
	_dispose(manager)


func test_castling_can_be_undone_by_the_command_stack() -> void:
	var state := make_state(2, 1, {1: _two(Kind.CHESS)})
	place(state, 11, 4)
	place(state, 12, 9)
	var stack: CommandStack = new_stack()
	var ctx: RuleContext = make_ctx(state, 0)
	check(stack.execute_command(CastleCommand.new(1, 11, 12), ctx), "실행")
	check_eq(state.get_pawn(11).current_tile_idx, 9, "교환됨")
	stack.undo_last()
	check_eq(state.get_pawn(11).current_tile_idx, 4, "undo로 복구")
	check(not CastleCommand.new(1, 11, 11).can_execute(ctx), "같은 기물끼리는 불가")


# --- 장기 -------------------------------------------------------------------

func test_janggi_cannon_adds_two_tiles_when_jumping_over_any_pawn() -> void:
	var state := make_state(2, 1, {1: _loadout(Kind.JANGGI)})
	place(state, 11, 8)
	place(state, 21, 10)  # 적군이 경로 중간에
	var over_enemy: MoveReport = move(state, 11, 4)
	check(over_enemy.cannon_bonus, "포 넘기 발동")
	check_eq(state.get_pawn(11).current_tile_idx, 14, "4 + 2 = 6칸")
	var ally := make_state(2, 1, {1: _loadout(Kind.JANGGI)})
	place(ally, 11, 8)
	place(ally, 12, 10)
	check_eq(move(ally, 11, 4).cannon_bonus, true, "아군을 넘어도 발동")
	check_eq(ally.get_pawn(11).current_tile_idx, 14, "마찬가지로 +2")
	var clear := make_state(2, 1, {1: _loadout(Kind.JANGGI)})
	place(clear, 11, 8)
	place(clear, 21, 12)  # 도착 칸의 말은 '넘은' 것이 아니다
	check_eq(move(clear, 11, 4).cannon_bonus, false, "경로 중간에 말이 없으면 보너스 없음")
	check_eq(clear.get_pawn(11).current_tile_idx, 12, "정상 이동")


func test_chosun_formation_restrains_instead_of_capturing() -> void:
	var state := make_state(2, 1, {1: _two(Kind.JANGGI)})
	place(state, 11, 2)
	place(state, 21, 4)
	var report: MoveReport = move(state, 11, 2)
	check_eq(report.captured_pawn_ids, [21], "잡은 것으로 기록")
	check_eq(state.get_pawn(21).current_tile_idx, 4, "출발선으로 가지 않고 제자리")
	check(state.get_pawn(21).has_left_start, "출발 상태 유지")
	check_eq(state.get_pawn(21).restrained_turns, 1, "1턴 구속")
	check_eq(report.restrained_pawn_ids, [21], "보고서에 구속 기록")
	check(not report.extra_turn, "윷놀이 기물이 아니므로 추가 턴은 없음")
	var single := make_state(2, 1, {1: [Vector2i(Kind.JANGGI, 1), 0, 0, 0]})
	place(single, 11, 2)
	place(single, 21, 4)
	move(single, 11, 2)
	check_eq(single.get_pawn(21).current_tile_idx, 0, "1세트는 평소처럼 출발선으로")


# --- 바둑 -------------------------------------------------------------------

func test_go_knock_pushes_the_enemy_two_tiles_instead_of_capturing() -> void:
	var state := make_state(2, 1, {1: [Vector2i(Kind.GO, 1), 0, 0, 0]})
	place(state, 11, 2)
	place(state, 21, 4)
	var report: MoveReport = move(state, 11, 2)
	check_eq(state.get_pawn(11).current_tile_idx, 4, "내 돌이 그 칸을 차지")
	check_eq(state.get_pawn(21).current_tile_idx, 6, "상대는 2칸 앞으로")
	check(state.get_pawn(21).has_left_start, "잡히지 않음")
	check_eq(report.captured_pawn_ids.size(), 0, "잡기 아님")
	check_eq(report.knocked_pawn_ids, [21], "튕김 기록")
	check(not report.extra_turn, "추가 턴 없음")


func test_go_knock_stops_before_the_goal_and_carries_stacks() -> void:
	var state := make_state(2, 1, {1: [Vector2i(Kind.GO, 1), 0, 0, 0]})
	place(state, 11, 17)
	place(state, 21, 18, [17])
	state.get_pawn(22).kind = Kind.BASIC
	place(state, 22, 18, [17])
	state.stack_pawns(state.get_pawn(21), state.get_pawn(22))
	move(state, 11, 1)
	check_eq(state.get_pawn(21).current_tile_idx, 19, "결승선은 넘지 않고 19번에서 멈춤")
	check_eq(state.get_pawn(22).current_tile_idx, 19, "업힌 말도 함께")
	check(not state.get_pawn(21).is_finished, "완주 처리되지 않음")


func test_non_go_pawns_still_capture_normally() -> void:
	var state := make_state(2, 1)
	place(state, 11, 2)
	place(state, 21, 4)
	var report: MoveReport = move(state, 11, 2)
	check_eq(report.captured_pawn_ids, [21], "일반 기물은 잡는다")
	check_eq(state.get_pawn(21).current_tile_idx, 0, "출발선으로")


func test_go_two_set_territory_is_capture_immune_and_pushes_the_intruder_back() -> void:
	var state := make_state(2, 1, {1: _two(Kind.GO)})
	place(state, 11, 6)
	place(state, 21, 3)
	var report: MoveReport = move(state, 21, 3)
	check(report.pushed_back, "침입자는 밀려남")
	check_eq(state.get_pawn(21).current_tile_idx, 5, "한 칸 뒤(5번)로")
	check(state.get_pawn(11).has_left_start and state.get_pawn(11).current_tile_idx == 6, "바둑돌은 그대로")
	check_eq(report.captured_pawn_ids.size(), 0, "잡지 못함")
	check(not report.extra_turn, "추가 턴 없음")
	check(MoveExecutor.is_capture_immune(state, state.get_pawn(11)), "무적 판정")
	var single := make_state(2, 1, {1: [Vector2i(Kind.GO, 1), 0, 0, 0]})
	place(single, 11, 6)
	place(single, 21, 3)
	move(single, 21, 3)
	check_eq(single.get_pawn(11).current_tile_idx, 0, "1세트 바둑돌은 잡힌다")


func test_go_two_set_reduces_dice_by_one_with_minimum_one() -> void:
	var state := make_state(2, 1, {1: _two(Kind.GO)})
	place(state, 11, 1)
	move(state, 11, 4)
	check_eq(state.get_pawn(11).current_tile_idx, 4, "눈금 4 -> 3칸")
	place(state, 12, 1)
	move(state, 12, 1)
	check_eq(state.get_pawn(12).current_tile_idx, 2, "눈금 1도 최소 1칸")
	var single := make_state(2, 1, {1: [Vector2i(Kind.GO, 1), 0, 0, 0]})
	place(single, 11, 1)
	move(single, 11, 4)
	check_eq(single.get_pawn(11).current_tile_idx, 5, "1세트는 페널티 없음")


# --- ACT_02 뱅! -----------------------------------------------------------------

func test_bang_targets_the_front_most_enemy_within_three_tiles() -> void:
	var state := make_state(3, 1)
	place(state, 11, 5)
	place(state, 21, 7)
	place(state, 31, 8)   # 더 앞선 적
	place(state, 22, 13)  # 사거리 밖
	check_eq(BangCommand.find_target(state, 1).entity_id, 31, "가장 앞선 적 조준")
	place(state, 31, 9)   # 4칸 거리 -> 사거리 밖
	check_eq(BangCommand.find_target(state, 1).entity_id, 21, "사거리 안에서 선택")
	place(state, 21, 2)   # 뒤쪽 3칸도 사거리
	check_eq(BangCommand.find_target(state, 1).entity_id, 21, "뒤 3칸 포함")
	place(state, 21, 1)
	check(BangCommand.find_target(state, 1) == null, "아무도 없으면 대상 없음")
	var home := make_state(2, 1)
	place(home, 11, 1)
	check(BangCommand.find_target(home, 1) == null, "출발선 대기 말은 맞힐 수 없다")


func test_bang_is_dodged_by_discarding_a_card_or_sends_the_target_home() -> void:
	var state := make_state(2, 1)
	place(state, 11, 5)
	place(state, 21, 6)
	state.give_card(2, &"ACT_01")
	var stack: CommandStack = new_stack()
	var dodges: Array = []
	state.bang_resolved.connect(func(shooter: int, target: int, dodged: bool, card: StringName) -> void: dodges.append([shooter, target, dodged, card]))
	check(stack.execute_command(BangCommand.new(1), make_ctx(state, 0)), "발사")
	check_eq(dodges, [[1, 21, true, &"ACT_01"]], "회피(빗나감)")
	check_eq((state.hands[2] as Array).size(), 0, "카드 한 장 버림")
	check_eq(state.get_pawn(21).current_tile_idx, 6, "말은 그대로")
	stack.execute_command(BangCommand.new(1), make_ctx(state, 0))
	check_eq(dodges.back(), [1, 21, false, &""], "손패가 비어 명중")
	check_eq(state.get_pawn(21).current_tile_idx, 0, "출발선으로")
	check(not state.get_pawn(21).has_left_start, "출발 전 상태")


func test_bang_card_is_playable_only_at_turn_begin_with_a_target() -> void:
	var manager: TurnManager = _manager({}, 2)
	var rejected: Array = []
	manager.action_rejected.connect(func(_p: int, _a: StringName, reason: StringName) -> void: rejected.append(reason))
	manager.state.give_card(1, &"ACT_02")
	_do(manager, 1, &"play_card", {"card_id": &"ACT_02"})
	check_eq(rejected, [&"invalid_target"], "대상이 없으면 사용 불가")
	place(manager.state, 11, 5)
	place(manager.state, 21, 7)
	var events: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void: events.append([kind, data]))
	_do(manager, 1, &"play_card", {"card_id": &"ACT_02"})
	check(not manager.state.has_card(1, &"ACT_02"), "카드 소모")
	check_eq(manager.state.get_pawn(21).current_tile_idx, 0, "손패 없는 상대는 출발선으로")
	var kinds: Array = events.map(func(e: Array) -> StringName: return e[0])
	check(kinds.has(&"bang_resolved"), "bang_resolved 이벤트")
	_dispose(manager)


# --- ACT_03 우노 +4 ---------------------------------------------------------------

func test_uno_plus_four_sets_pending_penalty_on_the_next_player_following_direction() -> void:
	var state := make_state(3, 1)
	state.turn_direction = 1
	var stack: CommandStack = new_stack()
	stack.execute_command(PenaltyBombCommand.new(1), make_ctx(state, 0))
	check_eq(state.penalty_of(2), -4, "다음 플레이어에게 -4")
	var reversed := make_state(3, 1)
	reversed.turn_direction = -1
	new_stack().execute_command(PenaltyBombCommand.new(1), make_ctx(reversed, 0))
	check_eq(reversed.penalty_of(3), -4, "역방향이면 반대편 플레이어")


func test_penalty_applies_immediately_without_an_instant_card() -> void:
	var manager: TurnManager = _manager({}, 3)
	place(manager.state, 21, 9, [8])
	place(manager.state, 22, 4, [3])
	manager.state.pending_penalty[2] = -4
	var events: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void: events.append([kind, data]))
	manager.advance_to_next_player()  # 1 -> 2 번 턴 시작
	check_eq(manager.current_player_id(), 2, "2번 턴")
	check_eq(manager.state.get_pawn(21).current_tile_idx, 5, "가장 앞선 말이 4칸 후퇴")
	check_eq(manager.state.get_pawn(22).current_tile_idx, 4, "다른 말은 그대로")
	check_eq(manager.state.penalty_of(2), 0, "페널티 해소")
	var kinds: Array = events.map(func(e: Array) -> StringName: return e[0])
	check(kinds.has(&"bomb_applied"), "bomb_applied 이벤트")
	_dispose(manager)


func test_pass_bomb_consumes_an_instant_card_and_doubles_the_penalty() -> void:
	var manager: TurnManager = _manager({}, 3)
	place(manager.state, 21, 9, [8])
	place(manager.state, 31, 11, [10])
	manager.state.give_card(2, &"ACT_06")
	manager.state.pending_penalty[2] = -4
	manager.advance_to_next_player()
	check(manager.can_pass_bomb(2), "즉발 카드가 있으면 떠넘기기 가능")
	check_eq(manager.state.get_pawn(21).current_tile_idx, 9, "아직 후퇴하지 않음")
	_do(manager, 2, &"pass_bomb")
	check(not manager.state.has_card(2, &"ACT_06"), "즉발 카드 소모")
	check_eq(manager.state.penalty_of(2), 0, "내 페널티 해소")
	check_eq(manager.state.penalty_of(3), -8, "다음 플레이어에게 -8")
	check_eq(manager.state.get_pawn(21).current_tile_idx, 9, "내 말은 무사")
	manager.advance_to_next_player()  # 3번 턴: 즉발 카드 없음 -> 즉시 8칸 후퇴
	check_eq(manager.current_player_id(), 3, "3번 턴")
	check_eq(manager.state.get_pawn(31).current_tile_idx, 3, "11번 -> 8칸 후퇴")
	_dispose(manager)


func test_declining_the_bomb_applies_the_penalty_when_rolling() -> void:
	var manager: TurnManager = _manager({}, 2)
	place(manager.state, 21, 9, [8])
	manager.state.give_card(2, &"ACT_06")
	manager.state.pending_penalty[2] = -4
	manager.advance_to_next_player()
	manager.state.tools[2] = ScriptedTool.new([1])
	_do(manager, 2, &"proceed")
	check_eq(manager.state.get_pawn(21).current_tile_idx, 5, "넘기지 않고 진행하면 후퇴 적용")
	check(manager.state.has_card(2, &"ACT_06"), "카드는 그대로")
	var rejected: Array = []
	manager.action_rejected.connect(func(_p: int, _a: StringName, reason: StringName) -> void: rejected.append(reason))
	_do(manager, 2, &"pass_bomb")
	check_eq(rejected, [&"wrong_phase"], "이미 지난 뒤에는 떠넘길 수 없다")
	_dispose(manager)


func test_pass_bomb_is_rejected_without_instant_card_or_penalty() -> void:
	var manager: TurnManager = _manager({}, 2)
	var rejected: Array = []
	manager.action_rejected.connect(func(_p: int, _a: StringName, reason: StringName) -> void: rejected.append(reason))
	_do(manager, 1, &"pass_bomb")
	check_eq(rejected, [&"wrong_phase"], "페널티가 없으면 거부")
	check(not manager.can_pass_bomb(1), "버튼 비활성")
	_dispose(manager)
