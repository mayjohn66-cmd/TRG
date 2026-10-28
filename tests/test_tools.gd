# File: res://tests/test_tools.gd
# Class: class_name TestTools
# Role: 확정된 판정 도구 7종(D6·윷·룰렛·홀덤·친치로·777·러시안 룰렛)의 눈금 분포·재굴림·누적 규칙 검증
class_name TestTools
extends TestCase


func _rng(seed_value: int = 777) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _card(rank: int, suit: int) -> int:
	return suit * 13 + rank


func test_registry_exposes_exactly_thirteen_tools() -> void:
	check_eq(ToolRegistry.ALL_IDS.size(), 13, "도구 13종 (친치로·화투·마작·타로·야추·블랙잭·핀볼 포함)")
	for tool_id: StringName in ToolRegistry.ALL_IDS:
		check(ToolRegistry.create(tool_id) != null, "%s 생성" % tool_id)


func test_d6_range_and_coverage() -> void:
	var tool := ToolDiceD6.new()
	var rng: RandomNumberGenerator = _rng()
	var seen: Dictionary = {}
	for i: int in 600:
		var result: RollResult = tool.roll(rng)
		seen[result.steps] = true
		check(result.steps >= 1 and result.steps <= 6 and not result.reroll, "D6 범위/재굴림 없음")
	check_eq(seen.size(), 6, "6면 모두 등장")


func test_yut_faces_and_reroll_on_special_four_or_five() -> void:
	var tool := ToolYut.new()
	var rng: RandomNumberGenerator = _rng()
	var seen: Dictionary = {}
	for i: int in 800:
		var result: RollResult = tool.roll(rng)
		var face: int = int(result.details["face"])
		seen[face] = true
		check(result.steps >= 0, "후퇴 눈금은 없다")
		check_eq(result.reroll, face >= 4, "윷·모일 때만 재굴림")
		if face == ToolYut.NAK_FACE:
			check(result.steps == 0 and result.ends_turn and bool(result.details["nak"]), "낙은 0칸 + 턴 종료")
		else:
			check(result.steps == face and not result.ends_turn, "도~모는 나온 만큼")
		check(ToolYut.FACES.has(face), "윷 눈금 집합")
	var faces: Array = seen.keys()
	faces.sort()
	check_eq(faces, [0, 1, 2, 3, 4, 5], "낙 포함 6면 모두 등장")


func test_life_roulette_seven_grants_seven_steps_and_reroll() -> void:
	var tool := ToolLifeRoulette.new()
	var rng: RandomNumberGenerator = _rng()
	var seven_seen: bool = false
	for i: int in 800:
		var result: RollResult = tool.roll(rng)
		check(result.steps >= 1 and result.steps <= 10, "1~10")
		check_eq(result.reroll, result.steps == 7, "7일 때만 재굴림")
		seven_seen = seven_seen or result.steps == 7
	check(seven_seen, "7 당첨 관측")


func test_holdem_hand_evaluation_and_steps() -> void:
	var cases: Array[Dictionary] = [
		{"cards": [_card(0, 0), _card(3, 1), _card(5, 2), _card(8, 3), _card(10, 0)] as Array[int], "hand": &"high_card", "steps": 1},
		{"cards": [_card(3, 0), _card(3, 1), _card(5, 2), _card(8, 3), _card(10, 0)] as Array[int], "hand": &"one_pair", "steps": 3},
		{"cards": [_card(3, 0), _card(3, 1), _card(5, 2), _card(5, 3), _card(10, 0)] as Array[int], "hand": &"two_pair", "steps": 5},
		{"cards": [_card(3, 0), _card(3, 1), _card(3, 2), _card(5, 3), _card(10, 0)] as Array[int], "hand": &"three_kind", "steps": 7},
		{"cards": [_card(4, 0), _card(5, 1), _card(6, 2), _card(7, 3), _card(8, 0)] as Array[int], "hand": &"straight", "steps": 10},
		{"cards": [_card(12, 0), _card(0, 1), _card(1, 2), _card(2, 3), _card(3, 0)] as Array[int], "hand": &"straight", "steps": 10},
		{"cards": [_card(1, 2), _card(4, 2), _card(6, 2), _card(9, 2), _card(11, 2)] as Array[int], "hand": &"flush", "steps": 15},
		{"cards": [_card(3, 0), _card(3, 1), _card(3, 2), _card(5, 3), _card(5, 0)] as Array[int], "hand": &"full_house", "steps": 15},
		{"cards": [_card(3, 0), _card(3, 1), _card(3, 2), _card(3, 3), _card(5, 0)] as Array[int], "hand": &"four_kind", "steps": 15},
		{"cards": [_card(4, 1), _card(5, 1), _card(6, 1), _card(7, 1), _card(8, 1)] as Array[int], "hand": &"straight_flush", "steps": 15},
	]
	for entry: Dictionary in cases:
		var hand: StringName = ToolHoldem.evaluate(entry["cards"])
		check_eq(hand, entry["hand"], "족보 판정")
		check_eq(ToolHoldem.steps_for(hand), entry["steps"], "족보 %s 전진 칸수" % entry["hand"])
	var rng: RandomNumberGenerator = _rng()
	var tool := ToolHoldem.new()
	for i: int in 200:
		var result: RollResult = tool.roll(rng)
		var cards: Array = result.details["cards"]
		var unique: Dictionary = {}
		for card: int in cards:
			unique[card] = true
		check_eq(unique.size(), 5, "5장 중복 없는 드로우")
		check_eq(result.steps, ToolHoldem.steps_for(result.details["hand"]), "결과 칸수 = 족보 칸수")


func test_slot_machine_payouts() -> void:
	check_eq(ToolSlot777.steps_for([0, 1, 2] as Array[int]), 1, "꽝")
	check_eq(ToolSlot777.steps_for([2, 2, 4] as Array[int]), 4, "2개 일치")
	check_eq(ToolSlot777.steps_for([3, 1, 3] as Array[int]), 4, "떨어진 2개 일치")
	check_eq(ToolSlot777.steps_for([1, 1, 1] as Array[int]), 8, "3개 일치")
	check_eq(ToolSlot777.steps_for([5, 5, 5] as Array[int]), 20, "777 잭팟")
	var tool := ToolSlot777.new()
	var rng: RandomNumberGenerator = _rng()
	for i: int in 300:
		var result: RollResult = tool.roll(rng)
		check([1, 4, 8, 20].has(result.steps), "가능한 칸수만 산출")


func test_revolver_accumulates_three_per_empty_and_cashes_out() -> void:
	var tool := ToolRussianRoulette.new()
	tool.load_chamber(4)
	var first: RollResult = tool.roll(_rng())
	check_eq(first.steps, 3, "빈 총 1회 = 3칸")
	check(first.can_continue, "계속 당길 수 있음")
	check(tool.has_pending_state(), "중간 상태 유지")
	var second: RollResult = tool.roll(_rng())
	check_eq(second.steps, 6, "누적 6칸")
	var cashed: RollResult = tool.cash_out()
	check_eq(cashed.steps, 6, "멈추면 누적치만큼 전진")
	check(not cashed.can_continue and not cashed.ends_turn, "확정 결과")
	check(not tool.has_pending_state(), "상태 초기화")
	check(tool.cash_out() == null, "누적이 없으면 cash_out 불가")


func test_revolver_bullet_evaporates_accumulation_and_ends_turn() -> void:
	var tool := ToolRussianRoulette.new()
	tool.load_chamber(2)
	tool.roll(_rng())
	tool.roll(_rng())
	var fired: RollResult = tool.roll(_rng())
	check(fired.ends_turn, "실탄이면 턴 종료")
	check_eq(fired.steps, 0, "이동력 0칸으로 증발")
	check_eq(fired.details["lost"], 6, "증발한 누적치")
	check(not tool.has_pending_state(), "초기화")


func test_revolver_first_chamber_bullet_and_cap_at_fifteen() -> void:
	var tool := ToolRussianRoulette.new()
	tool.load_chamber(0)
	check(tool.roll(_rng()).ends_turn, "첫 발이 실탄")
	var capped := ToolRussianRoulette.new()
	capped.load_chamber(5)
	var last: RollResult = null
	for i: int in 5:
		last = capped.roll(_rng())
	check_eq(last.steps, 15, "최대 15칸")
	check(not last.can_continue, "15칸이면 자동 확정")
	var rng: RandomNumberGenerator = _rng(99)
	var random_tool := ToolRussianRoulette.new()
	for i: int in 300:
		var result: RollResult = random_tool.roll(rng)
		check(result.steps <= 15, "15칸 초과 불가")


func test_chinchiro_rolls_high_with_a_one_in_six_oops_that_moves_zero() -> void:
	var tool := ToolChinchiro.new()
	check_eq(ToolChinchiro.FACES, int_array([4, 4, 5, 5, 6, -6]), "판정 배열 (-6은 물리 주사위의 삐끗 면)")
	var rng: RandomNumberGenerator = _rng()
	var counts: Dictionary = {}
	for i: int in 6000:
		var result: RollResult = tool.roll(rng)
		counts[result.steps] = int(counts.get(result.steps, 0)) + 1
		check_eq(result.details["oops"], result.steps == 0, "삐끗 표시")
		check(not result.reroll and not result.ends_turn and not result.can_continue, "단순 1회 판정")
	check(counts.keys().all(func(face: int) -> bool: return [0, 4, 5, 6].has(face)), "나올 수 있는 눈금은 0·4·5·6뿐 (후퇴 없음)")
	check(counts[0] > 800 and counts[0] < 1200, "삐끗(0칸)은 약 1/6 (%d)" % counts[0])
	check(counts[4] > 1800 and counts[5] > 1800, "4·5는 각 약 1/3")


func test_oops_roll_leaves_the_pawn_where_it_stands() -> void:
	var state := make_state(2, 1)
	place(state, 11, 10, [9])
	var report: MoveReport = move(state, 11, 0)
	check_eq(state.get_pawn(11).current_tile_idx, 10, "삐끗은 0칸이라 제자리")
	check(report.path.is_empty(), "걸음 없음")



func test_yut_capped_throw_is_do_gae_geol_only() -> void:
	var tool := ToolYut.new()
	var rng: RandomNumberGenerator = _rng()
	var seen: Dictionary = {}
	for i: int in 300:
		var result: RollResult = tool.roll_capped(rng)
		seen[result.steps] = true
		check(result.steps >= 1 and result.steps <= 3 and not result.reroll and not result.ends_turn, "상한 뒤 던지기는 도·개·걸 (재굴림·낙 없음)")
	check_eq(seen.size(), 3, "도·개·걸 모두 등장")


func test_yut_reroll_chain_caps_at_three() -> void:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	manager.start_game([1, 2, 3, 4] as Array[int], 7)
	var tool := ToolYut.new()
	var rerolls := 0
	for chain: int in [0, 1, 2]:
		manager._roll_chain = chain
		for i: int in 200:
			if manager._roll_with_modifiers(1, tool).reroll:
				rerolls += 1
	check(rerolls > 0, "재굴림 3번까지는 윷·모가 나온다")
	manager._roll_chain = ToolYut.MAX_REROLLS
	for i: int in 200:
		var result: RollResult = manager._roll_with_modifiers(1, tool)
		check(result.steps >= 1 and result.steps <= 3 and not result.reroll and not result.ends_turn, "재굴림 3번 뒤 던지기는 도·개·걸 중 하나")
	tree.root.remove_child(manager)
	manager.free()


func test_yut_bonus_throw_raises_the_nak_weight() -> void:
	var tool := ToolYut.new()
	var rng: RandomNumberGenerator = _rng()
	var naks := 0
	var seen: Dictionary = {}
	tool.bonus_throw = true
	for i: int in 4000:
		var result: RollResult = tool.roll(rng)
		seen[int(result.details["face"])] = true
		if bool(result.details["nak"]):
			naks += 1
	var share: float = float(naks) / 4000.0
	check(share > 0.37 and share < 0.46, "추가 던지기의 낙은 약 6/14 (%.2f)" % share)
	check_eq(seen.size(), 6, "다른 면도 모두 나온다")
	tool.bonus_throw = false
	naks = 0
	for i: int in 4000:
		if bool(tool.roll(rng).details["nak"]):
			naks += 1
	check(float(naks) / 4000.0 < 0.24, "첫 던지기의 낙은 약 1/5")
	var rerolls := 0
	for i: int in 4000:
		if tool.roll(rng).reroll:
			rerolls += 1
	check(float(rerolls) / 4000.0 > 0.16 and float(rerolls) / 4000.0 < 0.24, "윷·모는 약 1/5 (%.2f)" % (float(rerolls) / 4000.0))
