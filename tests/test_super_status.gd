# File: res://tests/test_super_status.gd
# Class: class_name TestSuperStatus
# Role: 기간이 있는 초증강 4종 - 평화주의자(SUPER_13) · 날조와 선동(SUPER_14) · 눈먼 자의 도시(SUPER_15) · 사출 목걸이(SUPER_16)의 규칙 검증
class_name TestSuperStatus
extends TestCase


func _state(round_number: int = 4) -> GameState:
	var state: GameState = make_state(2, 321)
	state.round_number = round_number
	return state


func test_next_draft_round_follows_the_three_round_schedule() -> void:
	check_eq(SuperStatus.next_draft_round(4), 7, "4라운드 증강 뒤 다음 증강전은 7라운드")
	check_eq(SuperStatus.next_draft_round(5), 7, "5라운드에서는 7라운드")
	check_eq(SuperStatus.next_draft_round(7), 10, "7라운드 증강 뒤는 10라운드")


# --- 평화주의자 -------------------------------------------------------------------------------------------

func test_pacifist_pawns_cannot_be_captured_and_cannot_capture() -> void:
	var state: GameState = _state()
	place(state, 11, 5, [4])
	place(state, 21, 8, [7])
	var result: Dictionary = SuperAugments.apply(SuperAugments.PACIFIST, state, 1)
	check(bool(result["ok"]) and SuperStatus.pacifist_active(state, 1), "평화주의자가 켜진다")
	var swept: MoveReport = move(state, 21, 0 + 0)  # 제자리 (아무 일 없음)
	check(swept != null, "이동 보고가 있다")
	# 상대가 평화주의자의 말 위로 가도 잡지 못한다 (한 칸에 함께 선다)
	place(state, 21, 3, [2])
	move(state, 21, 2)  # 3 -> 5: 평화주의자의 말이 서 있는 칸
	check(state.get_pawn(11).has_left_start and state.get_pawn(11).current_tile_idx == 5, "평화주의자의 말은 잡히지 않는다")
	check_eq(state.get_pawn(21).current_tile_idx, 5, "상대 말은 같은 칸에 함께 선다")
	# 평화주의자도 남을 잡지 못한다
	place(state, 11, 6, [5])
	place(state, 21, 9, [8])
	move(state, 11, 3)  # 6 -> 9
	check(state.get_pawn(21).has_left_start and state.get_pawn(21).current_tile_idx == 9, "평화주의자는 상대 말을 잡지 못한다")
	check(not SuperStatus.blocks_capture_by(state, 2, state.get_pawn(11)), "상대(평화주의자 아님)의 사출 차단 규칙은 따로 면역이 맡는다")
	check(SuperStatus.blocks_capture_by(state, 1, state.get_pawn(21)), "평화주의자가 날리는 사출은 막힌다")


func test_pacifist_cannot_play_kill_cards_and_ends_at_the_next_draft_round() -> void:
	var state: GameState = _state()
	SuperAugments.apply(SuperAugments.PACIFIST, state, 1)
	place(state, 21, 8, [7])
	check_eq(BangCommand.target_players(state, 1), [] as Array[int], "평화주의자는 뱅의 대상이 없다")
	check(SuperStatus.card_blocked(state, 1, &"ACT_02") and SuperStatus.card_blocked(state, 1, &"ACT_13"), "말을 날리는 카드는 막힌다")
	check(not SuperStatus.card_blocked(state, 1, &"ACT_04"), "로켓 부스터 같은 카드는 쓸 수 있다")
	check(not SuperStatus.card_blocked(state, 2, &"ACT_02"), "상대는 영향이 없다")
	state.round_number = 6
	check(SuperStatus.pacifist_active(state, 1), "7라운드 증강전이 오기 전까지 이어진다")
	state.round_number = 7
	check(not SuperStatus.pacifist_active(state, 1), "증강전 라운드가 되면 끝난다")


# --- 날조와 선동 -------------------------------------------------------------------------------------------

func test_agitation_discards_my_hand_and_forces_attack_cards_onto_the_target() -> void:
	var state: GameState = make_state(3, 99)
	state.round_number = 4
	place(state, 21, 8, [7])
	place(state, 31, 9, [8])
	place(state, 11, 5, [4])
	state.hands[1] = [&"ACT_02", &"ACT_04", &"TRP_06"]
	var result: Dictionary = SuperAugments.apply(SuperAugments.AGITATE, state, 1, {"target_player": 3})
	check(bool(result["ok"]), "선동이 적용된다")
	check((state.hands[1] as Array).is_empty(), "내 손패는 모두 버린다")
	check_eq(SuperStatus.forced_target(state, 2), 3, "다른 사람의 공격은 지정 대상으로 몰린다")
	check_eq(BangCommand.target_players(state, 2), [3] as Array[int], "P2의 뱅은 P3만 겨눌 수 있다")
	check_eq(BangCommand.target_players(state, 1), [3] as Array[int], "선동한 사람도 같은 대상만 겨눌 수 있다")
	var by_target: Array[int] = BangCommand.target_players(state, 3)
	check(by_target.has(1) and by_target.has(2), "대상 본인의 공격은 그대로 (P1·P2 모두 겨눌 수 있다)")
	var status_targets: Array[int] = StatusCardCommand.targets(state, 2)
	check_eq(status_targets, [3] as Array[int], "밴·스킵·해킹·메죵도 같은 대상으로 몰린다")
	state.round_number = 7
	check(BangCommand.target_players(state, 2).has(1), "다음 증강전이 오면 풀린다")


func test_agitation_without_a_choice_picks_the_leading_rival() -> void:
	var state: GameState = make_state(3, 5)
	state.round_number = 4
	state.get_pawn(21).is_finished = true  # P2가 앞서 있다
	SuperAugments.apply(SuperAugments.AGITATE, state, 1, {})
	check_eq(SuperStatus.forced_target(state, 3), 2, "고르지 않으면 결승에 가장 가까운 상대 (P2)")


# --- 눈먼 자의 도시 ----------------------------------------------------------------------------------------

func test_blind_city_makes_friendly_pawns_capturable_for_one_round_only() -> void:
	var state: GameState = _state(5)
	place(state, 11, 8, [7])
	place(state, 12, 5, [4])
	SuperAugments.apply(SuperAugments.BLIND_CITY, state, 1)
	check(SuperStatus.blind_active(state), "이번 라운드 동안 켜진다")
	move(state, 12, 3)  # 5 -> 8: 같은 편 말이 서 있는 칸
	check(not state.get_pawn(11).has_left_start and state.get_pawn(11).current_tile_idx == 0, "같은 편 말도 출발선으로 잡힌다")
	check_eq(state.get_pawn(12).current_tile_idx, 8, "움직인 말은 그 칸에 선다")
	state.round_number = 6
	check(not SuperStatus.blind_active(state), "다음 라운드에는 꺼진다")
	place(state, 13, 10, [9])
	place(state, 14, 6, [5])
	move(state, 14, 4)  # 6 -> 10: 평소에는 같은 편 말을 잡지 않는다
	check(state.get_pawn(13).has_left_start, "눈먼 자의 도시가 끝나면 같은 편 말을 잡지 않는다")


# --- 사출 목걸이 -------------------------------------------------------------------------------------------

func test_necklace_doubles_movement_blocks_captures_and_explodes_at_round_end() -> void:
	var state: GameState = _state()
	place(state, 11, 5, [4])
	place(state, 21, 11, [10])
	var result: Dictionary = SuperAugments.apply(SuperAugments.NECKLACE, state, 1, {"pawn_id": 11})
	check(bool(result["ok"]) and SuperStatus.is_necklace(state, state.get_pawn(11)), "목걸이가 채워진다")
	var path: Array[int] = MoveExecutor.preview_path(state, state.get_pawn(11), 3)
	check_eq(path.size(), 6, "눈금 3의 이동 거리는 2배인 6칸")
	# 목걸이를 찬 말은 모든 공격을 막는다
	check(MoveExecutor.is_capture_immune(state, state.get_pawn(11)), "잡기 면역")
	place(state, 21, 3, [2])
	move(state, 21, 2)  # 3 -> 5: 목걸이 말 위
	check(state.get_pawn(11).current_tile_idx == 5 and state.get_pawn(11).has_left_start, "잡히지 않는다")
	# 라운드가 끝나면 터진다
	var exploded: Array[int] = SuperStatus.explode_necklaces(state)
	check_eq(exploded, [11] as Array[int], "라운드 끝에 목걸이가 터진 말")
	check(not state.get_pawn(11).has_left_start and state.get_pawn(11).current_tile_idx == 0, "출발선으로 사출된다")
	check(not SuperStatus.is_necklace(state, state.get_pawn(11)), "터진 목걸이는 사라진다")


func test_necklace_needs_a_pawn_on_the_board_and_expires_with_the_round() -> void:
	var state: GameState = _state()
	check(not SuperAugments.is_available(SuperAugments.NECKLACE, state, 1), "보드에 말이 없으면 고를 수 없다")
	place(state, 11, 5, [4])
	check(SuperAugments.is_available(SuperAugments.NECKLACE, state, 1), "보드에 말이 있으면 고를 수 있다")
	SuperAugments.apply(SuperAugments.NECKLACE, state, 1, {"pawn_id": 11})
	state.round_number = 5
	check(not SuperStatus.is_necklace(state, state.get_pawn(11)), "다음 라운드가 되면 효과가 없다 (터지는 것은 라운드 끝에서)")
	var picked: Dictionary = SuperAugments.apply(SuperAugments.NECKLACE, state, 1, {"pawn_id": 12})  # 보드에 없는 말은 가장 앞선 말로
	check(bool(picked["ok"]) and SuperStatus.is_necklace(state, state.get_pawn(11)), "잘못 고르면 가장 앞선 말에 채운다")


func test_status_survives_snapshot_round_trip() -> void:
	var state: GameState = _state()
	place(state, 11, 5, [4])
	SuperAugments.apply(SuperAugments.PACIFIST, state, 2)
	SuperAugments.apply(SuperAugments.NECKLACE, state, 1, {"pawn_id": 11})
	var snapshot: TurnSnapshot = TurnSnapshot.capture(state)
	state.super_status.clear()
	snapshot.restore(state, true)
	check(SuperStatus.pacifist_active(state, 2) and SuperStatus.is_necklace(state, state.get_pawn(11)), "스냅샷으로 되돌려도 효과가 남아 있다")
