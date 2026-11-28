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
	check_eq(ToolRegistry.ALL_IDS.size(), 21, "도구 21종 (TRPG 오미쿠지·아이스크림, 포츈쿠키·캡슐뽑기, 해적 룰렛·스크래치 복권 포함) (친치로·화투·마작·타로·야추·블랙잭·핀볼 + v1.1 주식 차트·다트)")
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


## 1.3.1 리워크 (기획서 GDD 4.2 · 예외 규칙 1.8 · HANDOFF-010): 카이지 4·5·6 사기 주사위 3개 + 1/6 쇼벤.
func test_chinchiro_kaiji_three_dice_hands_and_one_in_six_shoben() -> void:
	var tool := ToolChinchiro.new()
	check_eq(ToolChinchiro.FACES, int_array([4, 4, 5, 5, 6, 6]), "사기 주사위 면: 4·4·5·5·6·6")
	var rng: RandomNumberGenerator = _rng()
	var hands: Dictionary = {}
	var shoben: int = 0
	var total: int = 27000
	for i: int in total:
		var result: RollResult = tool.roll(rng)
		var details: Dictionary = result.details
		var dice: Array = details["dice"]
		check(dice.size() == 3 and dice.all(func(value: int) -> bool: return [4, 5, 6].has(value)), "주사위 3개, 눈은 4·5·6뿐")
		if details["shoben"]:
			shoben += 1
			check(result.steps == 0 and result.ends_turn and not result.reroll and details["hand"] == ToolChinchiro.HAND_SHOBEN, "쇼벤 = 0칸 + 턴 종료")
			check(int(details["out_index"]) >= 0 and int(details["out_index"]) <= 2, "그릇 밖으로 나간 주사위 번호")
			continue
		check(not result.ends_turn and not result.can_continue and int(details["out_index"]) == -1, "쇼벤이 아니면 턴이 이어진다")
		var typed: Array[int] = []
		typed.assign(dice)
		check_eq(result.steps, ToolChinchiro.steps_of(typed), "족보 칸 수")
		check_eq(result.reroll, details["hand"] == ToolChinchiro.HAND_STORM_SIX, "★666만 한 번 더")
		var key: String = "%s%d" % [details["hand"], int(details["eye"])]
		hands[key] = int(hands.get(key, 0)) + 1
	var rolled: int = total - shoben
	check(abs(shoben - total / 6) < total / 6 * 0.08, "쇼벤 약 1/6 (%d / %d)" % [shoben, total])
	for key: String in ["eye4", "eye5", "eye6", "shigoro0"]:
		check(absf(float(hands.get(key, 0)) / rolled - 6.0 / 27.0) < 0.02, "%s 약 6/27 (%d)" % [key, int(hands.get(key, 0))])
	check(absf(float(hands.get("storm0", 0)) / rolled - 2.0 / 27.0) < 0.012, "아라시 444·555 약 2/27")
	check(absf(float(hands.get("storm_six0", 0)) / rolled - 1.0 / 27.0) < 0.008, "★666 약 1/27")


func test_chinchiro_hand_table_for_all_27_throws() -> void:
	for a: int in [4, 5, 6]:
		for b: int in [4, 5, 6]:
			for c: int in [4, 5, 6]:
				var dice: Array[int] = [a, b, c]
				var hand: StringName = ToolChinchiro.hand_of(dice)
				var steps: int = ToolChinchiro.steps_of(dice)
				if a == b and b == c:
					check_eq(hand, ToolChinchiro.HAND_STORM_SIX if a == 6 else ToolChinchiro.HAND_STORM, "트리플은 아라시")
					check_eq(steps, 12 if a == 6 else 10, "아라시 칸")
				elif a != b and b != c and a != c:
					check_eq(hand, ToolChinchiro.HAND_SHIGORO, "4·5·6은 시고로")
					check_eq(steps, 8, "시고로 8칸")
				else:
					var odd: int = a if b == c else (b if a == c else c)
					check_eq(hand, ToolChinchiro.HAND_EYE, "페어 + 하나는 눈")
					check_eq(steps, odd, "나머지 눈만큼 (%d%d%d)" % [a, b, c])
				check(steps >= 4, "메나시(족보 없음)는 없다")


func test_oops_roll_leaves_the_pawn_where_it_stands() -> void:
	var state := make_state(2, 1)
	place(state, 11, 10, [9])
	var report: MoveReport = move(state, 11, 0)
	check_eq(state.get_pawn(11).current_tile_idx, 10, "쇼벤은 0칸이라 제자리")
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


## 증강 카드의 [최소 0칸]은 ToolRegistry.ZERO_OUTCOME에서 온다: 목록이 실제와 맞는지 굴려서 확인한다
## (목록에 있으면 실제로 0칸이 나오고, 없으면 확정 결과가 0칸이 되는 일이 없다). 이어 굴리는 도구는 확정될 때까지 계속 굴린다.
func test_zero_outcome_list_matches_real_rolls() -> void:
	for tool_id: StringName in ToolRegistry.ALL_IDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = 9090
		var tool: BaseJudgmentTool = ToolRegistry.create(tool_id)
		var zero_seen: bool = false
		for _attempt: int in 4000:
			var result: RollResult = tool.roll(rng)
			if result.can_continue:
				continue
			if result.steps == 0:
				zero_seen = true
				break
		check_eq(zero_seen, ToolRegistry.ZERO_OUTCOME.has(tool_id), "%s: 0칸 결과가 %s" % [tool_id, "있다" if zero_seen else "없다"])


## 친치로 굴림 기록 줄이 영어·일본어 화면에 한글을 남기지 않는다 (배포 CI ui_smoke: "ションベン！ (0칸, ターン終了)").
func test_chinchiro_log_lines_translate_fully() -> void:
	for line: String in ["5 · 5 · 5 → 쇼벤! (낙) (0칸, 턴 종료)", "6 · 6 · 6 → ★666 아라시! 12칸", "5 · 5 · 5 → 아라시! 10칸", "4 · 5 · 6 → 시고로! 8칸", "6 · 6 · 4 → 4의 눈 4칸"]:
		for lang: String in ["en", "ja"]:
			check(not L10n.has_hangul(L10n.translate_text(line, lang)), "%s: %s" % [lang, L10n.translate_text(line, lang)])
