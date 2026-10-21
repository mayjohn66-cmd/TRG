# File: res://tests/test_utility_augments.gd
# Class: class_name TestUtilityAugments
# Role: [범용 보급] 증강 3종(UTIL_01~03)과 종류 지정 카드 패키지(CARD_02 방어 보급 · CARD_03 공병 보급)의 표 등록·조건·효과를 검사한다
class_name TestUtilityAugments
extends TestCase


func _state(seed_value: int = 7) -> GameState:
	var state := GameState.new()
	state.boost_gimmicks = false
	state.setup([1, 2, 3, 4] as Array[int], seed_value)
	state.round_number = 5
	return state


func _mine(state: GameState) -> Array[PlayerPawn]:
	return state.pawns_of(1)


func test_table_rows_register_five_new_augments() -> void:
	for id: StringName in [&"UTIL_01", &"UTIL_02", &"UTIL_03", &"CARD_02", &"CARD_03"]:
		check(AugmentRegistry.get_def(id) != null, "%s 등록" % id)
	var potion: AugmentDef = AugmentRegistry.get_def(&"UTIL_01")
	check_eq(potion.category, GameEnums.AugmentCategory.UTILITY, "UTIL 계열")
	check_eq(potion.weight, 90, "UTIL_01 가중치 90")
	check_eq(potion.min_round, 2, "UTIL_01 2라운드부터")
	check_eq(AugmentRegistry.get_def(&"UTIL_02").tier, "PRISMA", "전군 돌연변이 PRISMA")
	check_eq(AugmentRegistry.get_def(&"UTIL_02").min_round, 3, "전군 돌연변이 3라운드부터")
	check_eq(AugmentRegistry.get_def(&"CARD_02").weight, 90, "방어 보급 가중치 90")
	check_eq(AugmentRegistry.get_def(&"CARD_03").weight, 85, "공병 보급 가중치 85")
	check(potion.describe(_state(), 1).contains("+3칸"), "설명의 {p1}이 3으로 바뀐다")
	check_eq(AugmentRegistry.get_def(&"CARD_02").display_name, "[방어 보급] 절대 방어 패키지", "표에서 만든 증강은 표 제목이 이름")


func test_mutation_potion_prefers_spent_skill_pawn_and_recharges_it() -> void:
	var state: GameState = _state()
	var pawns: Array[PlayerPawn] = _mine(state)
	state.give_unit(pawns[0], GameEnums.PawnKind.CHESS, [4] as Array[int])  # 룩
	state.give_unit(pawns[1], GameEnums.PawnKind.YUT, [1] as Array[int])
	pawns[0].skill_used = true
	pawns[0].has_left_start = true
	pawns[0].current_tile_idx = 5
	check_eq(UtilityAugments.mutate_target(state, 1), pawns[0], "필살기를 쓴 진화 기물이 1순위")
	var before: GameEnums.PawnSubType = pawns[0].sub_type()
	var result: Dictionary = AugmentRegistry.get_def(&"UTIL_01").apply(state, 1)
	check(bool(result["ok"]), "변이 성공: %s" % result["text"])
	check(pawns[0].sub_type() != before and pawns[0].kind != GameEnums.PawnKind.BASIC, "다른 진화 기물로 바뀐다")
	check(pawns[0].sub_type() != pawns[1].sub_type(), "내가 가진 기물(윷말)과 겹치지 않는다")
	check(not pawns[0].skill_used, "필살기 재충전")
	check(pawns[0].current_tile_idx != 5, "보드 위 말은 +3칸 전진 (%d)" % pawns[0].current_tile_idx)
	check(str(result["text"]).contains("→"), "로그에 무엇이 무엇으로 바뀌었는지 남는다")


func test_mutation_potion_falls_back_to_a_basic_pawn() -> void:
	var state: GameState = _state()
	var target: PlayerPawn = UtilityAugments.mutate_target(state, 1)
	check(target != null and target.kind == GameEnums.PawnKind.BASIC, "진화 기물이 없으면 기본 말")
	var result: Dictionary = AugmentRegistry.get_def(&"UTIL_01").apply(state, 1)
	check(bool(result["ok"]) and _mine(state).any(func(p: PlayerPawn) -> bool: return p.kind != GameEnums.PawnKind.BASIC), "기본 말이 진화 기물이 된다")
	check(_mine(state).all(func(p: PlayerPawn) -> bool: return not p.has_left_start), "출발 전 말은 전진하지 않는다")


func test_mass_mutation_gives_four_distinct_evolved_pawns() -> void:
	for seed_value: int in [1, 2, 3, 4, 5]:
		var state: GameState = _state(seed_value)
		var pawns: Array[PlayerPawn] = _mine(state)
		pawns[2].skill_used = true
		var result: Dictionary = AugmentRegistry.get_def(&"UTIL_02").apply(state, 1)
		check(bool(result["ok"]), "전군 돌연변이 성공")
		var subs: Array = []
		for pawn: PlayerPawn in pawns:
			check(pawn.kind != GameEnums.PawnKind.BASIC and not pawn.skill_used, "모두 진화 + 필살기 충전")
			check(not subs.has(pawn.sub_type()), "시드 %d: 서로 다른 기물 (%s)" % [seed_value, result["text"]])
			subs.append(pawn.sub_type())


func test_mass_mutation_skips_finished_pawns() -> void:
	var state: GameState = _state()
	var pawns: Array[PlayerPawn] = _mine(state)
	pawns[3].is_finished = true
	AugmentRegistry.get_def(&"UTIL_02").apply(state, 1)
	check_eq(pawns[3].kind, GameEnums.PawnKind.BASIC, "완주한 말은 그대로")


func test_skill_refill_recharges_all_and_gives_a_card() -> void:
	var state: GameState = _state()
	var pawns: Array[PlayerPawn] = _mine(state)
	state.give_unit(pawns[0], GameEnums.PawnKind.CHESS, [4] as Array[int])
	state.give_unit(pawns[1], GameEnums.PawnKind.JANGGI, [2] as Array[int])  # 차
	pawns[0].skill_used = true
	pawns[1].skill_used = true
	var hand_before: int = (state.hands[1] as Array).size()
	var result: Dictionary = AugmentRegistry.get_def(&"UTIL_03").apply(state, 1)
	check(bool(result["ok"]), "리필 성공")
	check(not pawns[0].skill_used and not pawns[1].skill_used, "쓴 필살기가 모두 다시 충전")
	check_eq((state.hands[1] as Array).size(), hand_before + 1, "생떼 카드 1장")


func test_counter_package_gives_only_counter_cards() -> void:
	var state: GameState = _state()
	var result: Dictionary = AugmentRegistry.get_def(&"CARD_02").apply(state, 1)
	check(bool(result["ok"]), "방어 보급 성공")
	var hand: Array = state.hands[1]
	check_eq(hand.size(), 2, "2장")
	for card_id: Variant in hand:
		check_eq(CardRegistry.type_of(card_id), "COUNTER", "방어 카드만 (%s)" % card_id)


func test_engineer_package_gives_one_corner_trap_and_one_trap() -> void:
	var state: GameState = _state()
	AugmentRegistry.get_def(&"CARD_03").apply(state, 1)
	var types: Array = (state.hands[1] as Array).map(func(card_id: Variant) -> String: return CardRegistry.type_of(card_id))
	types.sort()
	check_eq(types, ["TRAP", "TRAP_CORNER"], "코너 함정 1장 + 일반 함정 1장")


func test_card_package_needs_hand_room() -> void:
	var state: GameState = _state()
	for i: int in GameEnums.MAX_HAND_SIZE:
		state.give_card(1, &"ACT_02")
	check(not AugmentRegistry.get_def(&"CARD_02").is_available(state, 1), "손패가 가득 차면 나오지 않는다")
	check(AugmentRegistry.get_def(&"UTIL_03").is_available(state, 1) == false, "쓴 필살기도 없고 손패도 가득이면 리필 주사도 나오지 않는다")
