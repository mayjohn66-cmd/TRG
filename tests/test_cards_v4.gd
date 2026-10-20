# File: res://tests/test_cards_v4.gd
# Class: class_name TestCardsV4
# Role: v4.0 카드 개편 - 새 함정 6종(바나나·스파이크·강제 환승·점프대·톨게이트·타르), 빠루·어디로든 문, 함정 방어(포고령·도굴꾼), 우노 리버스 반사(스킵·밴), 공격 기록 검증 (24칸 보드: 코너 6·12·18)
class_name TestCardsV4
extends TestCase


func _trap_attack(state: GameState) -> Dictionary:
	for entry: Dictionary in state.attack_log:
		if entry["kind"] == &"trap":
			return entry
	return {}


func test_banana_slides_three_and_steals_a_card() -> void:
	var state := make_state()
	state.place_attachment(3, TrapBanana.new(2))
	state.give_card(1, &"ACT_04")
	place(state, 11, 1, [0])
	var report: MoveReport = move(state, 11, 2)
	check(report.stopped_early, "미끄러지며 이동이 끝난다")
	check_eq(state.get_pawn(11).current_tile_idx, 3 + 3, "+3칸 미끄러짐")
	check((state.hands[1] as Array).is_empty() and (state.hands[2] as Array).has(&"ACT_04"), "카드 1장 강탈")
	check(not _trap_attack(state).is_empty(), "함정 피해가 공격 기록에 남는다")


func test_spike_stops_passers_but_not_its_owner() -> void:
	var state := make_state()
	state.place_attachment(3, TrapSpike.new(2))
	place(state, 11, 1, [0])
	check_eq(move(state, 11, 4).path, int_array([2, 3]), "지나가다 3번에 정지")
	check(state.board.get_tile(3).attachments.is_empty(), "1회용")
	state.place_attachment(3, TrapSpike.new(1))
	place(state, 12, 1, [0])
	check_eq(move(state, 12, 4).path.size(), 4, "설치자는 그냥 지나간다")


func test_transfer_portal_swaps_with_the_last_place_pawn() -> void:
	var state := make_state(3)
	state.place_attachment(5, TrapTransfer.new(3))
	place(state, 21, 2, [1])  # 꼴찌 (출발한 말 중 가장 뒤)
	place(state, 11, 4, [3])
	move(state, 11, 1)
	check_eq(state.get_pawn(11).current_tile_idx, 2, "꼴찌 자리로")
	check_eq(state.get_pawn(21).current_tile_idx, 5, "꼴찌는 포탈 자리로")


func test_corner_jump_pad_helps_its_owner_and_ejects_enemies() -> void:
	var state := make_state()
	state.place_attachment(6, TrapJumpPad.new(1))
	place(state, 11, 4, [3])
	move(state, 11, 2)
	check_eq(state.get_pawn(11).current_tile_idx, 6 + 5, "내 말은 +5칸")
	place(state, 21, 4, [3])
	move(state, 21, 2)
	check(not state.get_pawn(21).has_left_start, "적 말은 사출")


func test_tollgate_takes_a_card_or_blocks() -> void:
	var state := make_state()
	state.place_attachment(6, TrapToll.new(2))
	state.give_card(1, &"ACT_04")
	place(state, 11, 4, [3])
	check_eq(move(state, 11, 4).path.size(), 4, "카드를 바치면 지나간다")
	check((state.hands[2] as Array).has(&"ACT_04"), "설치자가 받았다")
	place(state, 12, 4, [3])
	check_eq(move(state, 12, 4).path, int_array([5, 6]), "낼 카드가 없으면 코너에 정지")


func test_tar_pulls_nearby_enemies_into_the_corner() -> void:
	var state := make_state()
	state.place_attachment(12, TrapTar.new(1))
	place(state, 22, 13, [12])
	place(state, 12, 11, [10])
	place(state, 21, 10, [9])
	move(state, 21, 2)
	check_eq(state.get_pawn(21).current_tile_idx, 12, "밟은 적은 코너에 붙는다")
	check_eq(state.get_pawn(22).current_tile_idx, 12, "2칸 안의 적도 끌려온다")
	check_eq(state.get_pawn(12).current_tile_idx, 11, "설치자의 말은 그대로")


func test_crowbar_clears_three_tiles_ahead() -> void:
	var state := make_state()
	place(state, 11, 2, [1])
	place(state, 21, 4, [3])
	state.place_attachment(5, TrapMine.new(2))
	place(state, 22, 7, [6])
	exec(state, CardRegistry.get_card(&"ACT_10").create_command(state, 1, {}))
	check(not state.get_pawn(21).has_left_start, "앞 3칸 안의 적 사출")
	check(state.board.get_tile(5).attachments.is_empty(), "설치물 파괴")
	check(state.get_pawn(22).has_left_start, "4칸 앞은 안전")


func test_anywhere_door_warps_my_front_pawn_to_an_empty_tile() -> void:
	var state := make_state()
	var card: BaseCard = CardRegistry.get_card(&"ACT_13")
	place(state, 11, 2, [1])
	place(state, 21, 8, [7])
	check(not card.is_legal(state, 1, {"tile": 8}), "말이 있는 칸은 빈 칸이 아니다")
	check(card.is_legal(state, 1, {"tile": 15}), "빈 칸")
	exec(state, card.create_command(state, 1, {"tile": 15}))
	check_eq(state.get_pawn(11).current_tile_idx, 15, "순간이동")


func test_royal_decree_and_grave_robber_answer_traps() -> void:
	var state := make_state()
	state.place_attachment(3, TrapPit.new(2))
	state.give_card(2, &"ACT_02")
	place(state, 21, 9, [8])
	place(state, 11, 1, [0])
	move(state, 11, 4)
	check(not state.get_pawn(11).has_left_start, "나락에 빠졌다")
	var attack: int = int(_trap_attack(state)["id"])
	var decree: BaseCard = CardRegistry.get_card(&"CNT_06")
	check(decree.is_legal(state, 1, {"attack": attack}) and not CardRegistry.get_card(&"CNT_02").is_legal(state, 1, {"attack": attack}), "함정 방어만 받는다")
	exec(state, decree.create_command(state, 1, {"attack": attack}))
	check_eq(state.get_pawn(11).current_tile_idx, 3, "함정에 걸리기 직전 자리로 복원")
	check((state.hands[1] as Array).has(&"ACT_02"), "설치자의 카드 강탈")
	check(state.board.get_tile(3).attachments.is_empty(), "함정 무효")
	var robber := make_state()
	robber.place_attachment(3, TrapPit.new(2))
	place(robber, 21, 9, [8])
	place(robber, 11, 1, [0])
	move(robber, 11, 4)
	exec(robber, CardRegistry.get_card(&"CNT_07").create_command(robber, 1, {"attack": int(_trap_attack(robber)["id"])}))
	check(robber.get_pawn(11).has_left_start, "함정은 발동하지 않은 것으로 되돌린다")
	check(robber.get_pawn(21).has_left_start, "설치자의 말은 건드리지 않는다")
	check((robber.hands[1] as Array).has(StringName(TrapPit.new(2).attachment_id)), "걸린 함정 카드를 내 패로 가져온다")
	check(robber.board.get_tile(3).attachments.is_empty(), "보드의 함정은 사라진다")


func test_uno_reverse_reflects_skip_and_ban() -> void:
	var state := make_state()
	state.begin_attack({"kind": &"card", "card_id": &"ACT_15", "attacker": 1})
	exec(state, CardRegistry.get_card(&"ACT_15").create_command(state, 1, {"target_player": 2}))
	state.end_attack()
	check(bool(state.rest_next_turn.get(2, false)), "P2 휴식 예약")
	exec(state, CardRegistry.get_card(&"CNT_03").create_command(state, 2, {"attack": int(state.attack_log[0]["id"])}))
	check(not bool(state.rest_next_turn.get(2, false)) and bool(state.rest_next_turn.get(1, false)), "스킵이 공격자에게 반사")
	state.begin_attack({"kind": &"card", "card_id": &"ACT_14", "attacker": 1})
	exec(state, CardRegistry.get_card(&"ACT_14").create_command(state, 1, {"target_player": 2}))
	state.end_attack()
	check(state.is_banned(2), "밴")
	exec(state, CardRegistry.get_card(&"CNT_03").create_command(state, 2, {"attack": int(state.attack_log[1]["id"])}))
	check(not state.is_banned(2) and state.is_banned(1), "밴이 공격자에게 반사")


func test_counters_need_a_matching_attack_of_mine() -> void:
	var state := make_state()
	for card_id: StringName in CardCounter.DEFS.keys():
		check(not CardRegistry.get_card(card_id).could_play(state, 1), "%s: 공격이 없으면 못 쓴다" % card_id)
	place(state, 11, 2, [1])
	place(state, 21, 4, [3])
	move(state, 11, 2)
	check(CardRegistry.get_card(&"CNT_02").could_play(state, 2), "잡힌 사람은 거울의 힘")
	check(not CardRegistry.get_card(&"CNT_02").could_play(state, 1), "잡은 사람은 못 쓴다")
	check(not CardRegistry.get_card(&"CNT_05").could_play(state, 2), "잡기에는 함정 방어을 못 쓴다")
