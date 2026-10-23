# File: res://tests/test_bot_temper.gd
# Class: class_name TestBotTemper
# Role: 놀이터 난이도 = 불닭 Fire Level 1~5 파라미터 표(BotTemper.LEVELS) 검사.
#       자비 확률(70%·35%·0%), 연속 처치 자비, 로제의 1등 아닌 사람 보호와 1위 봇 견제, 오리지널의 1위 최우선 견제,
#       마라의 카드·필살기 적극성, 핵불닭의 사람 가중치 2배(잡는 수·대상 카드·함정 위치·이의 있음), 까르보의 법전 증강 회피, 옛 저장값 변환
class_name TestBotTemper
extends TestCase

const HUMAN: Array[int] = [1]


## P1(사람)의 말이 3칸 앞에 있어 P2 봇이 3을 굴리면 잡을 수 있다. 봇에게는 다른 말(대기 중인 22번)도 있다. 사람이 1등이다.
func _capture_board() -> GameState:
	var state := make_state(2)
	place(state, 21, 1, [0])
	place(state, 11, 4, [3])
	return state


func _spare_rate(state: GameState, level: int) -> float:
	var spared: int = 0
	var rng := RandomNumberGenerator.new()
	for seed_value: int in 400:
		rng.seed = seed_value
		if BotTemper.choose_pawn(state, 2, 3, level, HUMAN, rng) != 21:
			spared += 1
	return float(spared) / 400.0


## P3 봇이 1위(말 하나 완주), 사람 P1은 꼴찌. P2 봇의 21번은 3칸 가면 사람(4번 칸), 22번은 3칸 가면 1위 P3의 말(20번 칸).
func _leader_board() -> GameState:
	var state := make_state(4)
	state.get_pawn(31).is_finished = true
	place(state, 32, 20, [19])
	place(state, 41, 18, [17])
	place(state, 11, 4, [3])
	place(state, 21, 1, [0])
	place(state, 22, 17, [16])
	return state


func test_level_table_and_labels() -> void:
	check_eq(BotTemper.ALL, [1, 2, 3, 4, 5] as Array[int], "5단계")
	for level: int in BotTemper.ALL:
		var table: Dictionary = BotTemper.params(level)
		for key: String in ["spare", "card_spare", "recent_mercy", "protect_rank", "leader_bonus", "kill_bonus", "human_weight", "card_passes", "skill_bar", "avoid_law"]:
			check(table.has(key), "Lv.%d 표에 %s" % [level, key])
	check_eq(float(BotTemper.params(1)["spare"]), 0.70, "까르보 자비 70%")
	check_eq(float(BotTemper.params(2)["spare"]), 0.35, "로제 자비 35%")
	for level: int in [3, 4, 5]:
		check_eq(float(BotTemper.params(level)["spare"]), 0.0, "Lv.%d 자비 0%%" % level)
	check_eq(float(BotTemper.params(5)["human_weight"]), 2.0, "핵불닭 사람 가중치 2배")
	check(int(BotTemper.params(4)["card_passes"]) > int(BotTemper.params(3)["card_passes"]), "마라는 카드를 더 적극적으로")
	check_eq(BotTemper.label(1), "Lv.1 까르보", "이름")
	check_eq(BotTemper.label(5), "Lv.5 핵불닭", "이름")
	check_eq(BotTemper.tag(3), "[Lv.3 오리지널]", "디스코드 태그")


func test_sanitize_and_saved_difficulty() -> void:
	check_eq(BotTemper.sanitize("mild"), 1, "옛 순한맛 → 까르보")
	check_eq(BotTemper.sanitize("normal"), 2, "옛 보통맛 → 로제")
	check_eq(BotTemper.sanitize("spicy"), 4, "옛 마라맛 → 마라")
	check_eq(BotTemper.sanitize("nonsense"), BotTemper.DEFAULT_LEVEL, "모르는 값은 기본")
	check_eq(BotTemper.sanitize(9), BotTemper.DEFAULT_LEVEL, "범위 밖은 기본")
	check_eq(BotTemper.sanitize("5"), 5, "글자 숫자")
	var before: int = GameSession.bot_difficulty()
	GameSession.set_bot_difficulty(5)
	check_eq(GameSession.bot_difficulty(), 5, "고른 난이도가 남는다")
	GameSession.set_bot_difficulty(before)


func test_mercy_chance_by_level() -> void:
	var state: GameState = _capture_board()
	check_eq(BotTemper.race_rank(state, 1), 1, "사람이 1등 (보호 대상 아님)")
	check_eq(BotBrain.choose_pawn(state, 2, 3), 21, "BotBrain은 잡는 수를 고른다")
	var carbonara: float = _spare_rate(state, 1)
	check(carbonara > 0.62 and carbonara < 0.78, "까르보는 약 70%% 다른 말을 전진 (%.2f)" % carbonara)
	var rose: float = _spare_rate(state, 2)
	check(rose > 0.27 and rose < 0.43, "로제는 약 35%% (%.2f)" % rose)
	for level: int in [3, 4, 5]:
		check_eq(_spare_rate(state, level), 0.0, "Lv.%d는 봐주지 않는다" % level)
	check_eq(_spare_rate(state, BotTemper.RAW), 0.0, "RAW는 BotBrain 그대로")


func test_recent_mercy_only_on_soft_levels() -> void:
	var state: GameState = _capture_board()
	state.law_stats[1] = {GameState.LAST_HIT_ROUND: state.round_number - 1}
	var rose: float = _spare_rate(state, 2)
	check(rose > 0.4 and rose < 0.6, "로제 자비: 방금 잡힌 사람은 약 50%% 봐준다 (%.2f)" % rose)
	var carbonara: float = _spare_rate(state, 1)
	check(carbonara > 0.72 and carbonara < 0.88, "까르보 자비: 약 80%% (%.2f)" % carbonara)
	check_eq(_spare_rate(state, 3), 0.0, "오리지널은 연속 처치도 봐주지 않는다")
	state.law_stats[1] = {GameState.LAST_HIT_ROUND: state.round_number - 3}
	var later: float = _spare_rate(state, 2)
	check(later > 0.27 and later < 0.43, "2라운드가 지나면 기본 자비로 (%.2f)" % later)


func test_enemy_kill_records_the_round_for_mercy() -> void:
	var state := make_state(2)
	place(state, 11, 4, [3])
	state.round_number = 7
	state.send_to_start(state.get_pawn(11), 2)
	check(BotTemper.recently_hit(state, 1), "잡힌 라운드가 남는다")
	check_eq(int(state.law_stats[1][GameState.LAST_HIT_ROUND]), 7, "7라운드")


func test_leader_focus_and_human_weight() -> void:
	var state: GameState = _leader_board()
	check(BotTemper.race_rank(state, 1) >= 2, "사람은 1등이 아니다")
	var rng := RandomNumberGenerator.new()
	check_eq(BotTemper.choose_pawn(state, 2, 3, 2, HUMAN, rng), 22, "로제: 1등 아닌 사람 대신 1위 봇의 말을 잡는다")
	check_eq(BotTemper.choose_pawn(state, 2, 3, 3, HUMAN, rng), 22, "오리지널: 1위 최우선 견제")
	check_eq(BotTemper.choose_pawn(state, 2, 3, 5, HUMAN, rng), 21, "핵불닭: 사람 가중치 2배로 사람 말을 잡는다")
	check_eq(BotTemper.choose_pawn(state, 2, 3, BotTemper.RAW, HUMAN, rng), BotBrain.choose_pawn(state, 2, 3), "RAW는 BotBrain 그대로")


func test_original_hunts_a_leading_human() -> void:
	var state := make_state(4)
	state.get_pawn(11).is_finished = true  # 사람이 1위
	place(state, 12, 4, [3])
	place(state, 32, 20, [19])
	place(state, 21, 1, [0])
	place(state, 22, 17, [16])
	check_eq(BotTemper.race_rank(state, 1), 1, "사람이 1등")
	var rng := RandomNumberGenerator.new()
	check_eq(BotTemper.choose_pawn(state, 2, 3, 3, HUMAN, rng), 21, "오리지널: 1등인 사람의 말을 잡는다")


func test_targeted_attack_cards_by_level() -> void:
	var state := make_state(4)
	state.get_pawn(31).is_finished = true  # P3 봇이 1위
	place(state, 11, 4, [3])
	place(state, 32, 10, [9])
	var plan: Dictionary = {"card_id": &"ACT_14", "params": {"target_player": 1}}
	var rng := RandomNumberGenerator.new()
	var rose: Dictionary = BotTemper.filter_card_plan(state, 2, plan, 2, HUMAN, rng)
	check_eq(int(rose["params"]["target_player"]), 3, "로제: 밴을 1등 아닌 사람 대신 1위 봇에게")
	check_eq(BotTemper.filter_card_plan(state, 2, plan, 3, HUMAN, rng), plan, "오리지널은 그대로")
	check_eq(BotTemper.filter_card_plan(state, 2, {"card_id": &"ACT_04", "params": {}}, 1, HUMAN, rng)["card_id"], &"ACT_04", "사람을 노리지 않는 카드는 그대로")
	# 핵불닭: 봇(P3)을 노린 밴을, 사람이 (가중치로 나눈) 거리로 더 위협적이면 사람에게 돌린다
	var bot_plan: Dictionary = {"card_id": &"ACT_14", "params": {"target_player": 3}}
	place(state, 11, 14, [13])
	var nuclear: Dictionary = BotTemper.filter_card_plan(state, 2, bot_plan, 5, HUMAN, rng)
	check_eq(int(nuclear["params"]["target_player"]), 1, "핵불닭: 공격 카드를 사람에게 몰아준다")
	check_eq(int(BotTemper.filter_card_plan(state, 2, bot_plan, 4, HUMAN, rng)["params"]["target_player"]), 3, "마라는 대상을 바꾸지 않는다")


func test_attack_spare_on_a_leading_human() -> void:
	var state := make_state(2)
	place(state, 11, 20, [19])  # 사람이 1위
	place(state, 21, 2, [1])
	var plan: Dictionary = {"card_id": &"ACT_09", "params": {"target_player": 1}}
	var rng := RandomNumberGenerator.new()
	var dropped: Dictionary = {1: 0, 2: 0, 3: 0}
	for level: int in dropped:
		for seed_value: int in 400:
			rng.seed = seed_value
			if BotTemper.filter_card_plan(state, 2, plan, level, HUMAN, rng).is_empty():
				dropped[level] += 1
	check(dropped[1] > 290 and dropped[1] < 350, "까르보: 사람을 노리는 데스매치를 약 80%% 거른다 (%d/400)" % dropped[1])
	check(dropped[2] > 110 and dropped[2] < 170, "로제: 약 35%% (%d/400)" % dropped[2])
	check_eq(dropped[3], 0, "오리지널: 1등인 사람은 견제한다")


func test_mala_plays_cards_more_often() -> void:
	var state := make_state(2)
	place(state, 21, 2, [1])
	state.hands[2] = [&"ACT_04"]  # 긴급 로켓 부스터: BotBrain은 60%만 쓴다
	var rng := RandomNumberGenerator.new()
	var played: Dictionary = {3: 0, 4: 0}
	for level: int in played:
		for seed_value: int in 400:
			rng.seed = seed_value
			if not BotTemper.plan_turn_card(state, 2, level, {}, rng).is_empty():
				played[level] += 1
	check(played[3] > 200 and played[3] < 280, "오리지널은 약 60%% (%d/400)" % played[3])
	check(played[4] > 350, "마라는 약 94%% (%d/400)" % played[4])
	check(float(BotTemper.params(4)["skill_bar"]) < float(BotTemper.params(3)["skill_bar"]), "마라는 필살기 문턱이 낮다")


func test_nuclear_sets_traps_in_front_of_the_human() -> void:
	var state := make_state(2)
	place(state, 11, 5, [4])
	place(state, 21, 20, [19])
	var trap: StringName = &""
	for card_id: StringName in CardRegistry.all_ids():
		var card: BaseCard = CardRegistry.get_card(card_id)
		if card.category == GameEnums.CardCategory.TRAP and card.needs_tile():
			trap = card_id
			break
	check(trap != &"", "설치형 함정 카드가 있다")
	var front: PlayerPawn = state.front_pawn_of(1)
	var ahead: Array[int] = []
	for steps: int in range(1, 5):
		var path: Array[int] = state.board.calculate_path(front, steps, RuleContext.new())
		if not path.is_empty():
			ahead.append(path.back())
	var plan: Dictionary = {"card_id": trap, "params": {"tile": 30}}
	var nuclear: Dictionary = BotTemper.filter_card_plan(state, 2, plan, 5, HUMAN, RandomNumberGenerator.new())
	check(ahead.has(int(nuclear["params"]["tile"])), "핵불닭: 함정을 사람 선두 말 1~4칸 앞에 (%s)" % str(nuclear["params"]))


func test_carbonara_draft_avoids_special_victory_laws() -> void:
	var state := make_state(2)
	var law: StringName = &""
	var other: StringName = &""
	for definition: AugmentDef in AugmentRegistry.all():
		if definition.category == GameEnums.AugmentCategory.LAW_ENACT and law == &"":
			law = definition.augment_id
		elif definition.category == GameEnums.AugmentCategory.TOOL_SWAP and other == &"":
			other = definition.augment_id
	var offers: Array[StringName] = [law, other]
	var rng := RandomNumberGenerator.new()
	for seed_value: int in 20:
		rng.seed = seed_value
		check_eq(offers[BotTemper.choose_augment(state, 2, offers, 1, rng)], other, "까르보는 법전 증강을 고르지 않는다")
