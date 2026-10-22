# File: res://tests/test_bot_temper.gd
# Class: class_name TestBotTemper
# Role: 놀이터 난이도(순한맛·보통맛·마라맛)와 억까 방지 보정 - 사람 말 처치 회피 확률, 연속 처치 자비, 1위 우선 견제, 공격 카드 대상 돌리기, 순한맛 법전 증강 회피
class_name TestBotTemper
extends TestCase

const HUMAN: Array[int] = [1]


## P1(사람)의 말이 3칸 앞에 있어 P2 봇이 3을 굴리면 잡을 수 있다. 봇에게는 다른 말(대기 중인 22번)도 있다.
func _capture_board() -> GameState:
	var state := make_state(2)
	place(state, 21, 1, [0])
	place(state, 11, 4, [3])
	return state


func _spare_rate(state: GameState, difficulty: StringName) -> float:
	var spared: int = 0
	var rng := RandomNumberGenerator.new()
	for seed_value: int in 400:
		rng.seed = seed_value
		if BotTemper.choose_pawn(state, 2, 3, difficulty, HUMAN, rng) != 21:
			spared += 1
	return float(spared) / 400.0


func test_labels_and_saved_difficulty() -> void:
	check_eq(BotTemper.label(BotTemper.MILD), "순한맛", "순한맛")
	check_eq(BotTemper.label(&"nonsense"), "보통맛", "모르는 값은 보통맛")
	var before: StringName = GameSession.bot_difficulty()
	GameSession.set_bot_difficulty(BotTemper.SPICY)
	check_eq(GameSession.bot_difficulty(), BotTemper.SPICY, "고른 난이도가 남는다")
	GameSession.set_bot_difficulty(before)


func test_spicy_always_takes_the_kill() -> void:
	var state: GameState = _capture_board()
	check_eq(BotBrain.choose_pawn(state, 2, 3), 21, "BotBrain은 잡는 수를 고른다")
	check_eq(_spare_rate(state, BotTemper.SPICY), 0.0, "마라맛은 봐주지 않는다")


func test_mild_spares_about_45_percent() -> void:
	var rate: float = _spare_rate(_capture_board(), BotTemper.MILD)
	check(rate > 0.35 and rate < 0.55, "순한맛은 약 45%% 다른 말을 전진 (%.2f)" % rate)


func test_normal_keeps_the_kill_unless_the_human_was_just_hit() -> void:
	var state: GameState = _capture_board()
	check_eq(_spare_rate(state, BotTemper.NORMAL), 0.0, "보통맛: 2인 판의 2위 사람은 그냥 잡는다")
	state.law_stats[1] = {GameState.LAST_HIT_ROUND: state.round_number - 1}
	var rate: float = _spare_rate(state, BotTemper.NORMAL)
	check(rate > 0.4 and rate < 0.6, "보통맛 자비: 방금 잡힌 사람은 약 50%% 봐준다 (%.2f)" % rate)
	var mild: float = _spare_rate(state, BotTemper.MILD)
	check(mild > 0.7 and mild < 0.9, "순한맛 자비: 약 80%% (%.2f)" % mild)
	state.law_stats[1] = {GameState.LAST_HIT_ROUND: state.round_number - 3}
	check_eq(_spare_rate(state, BotTemper.NORMAL), 0.0, "2라운드가 지나면 자비 끝")


func test_enemy_kill_records_the_round_for_mercy() -> void:
	var state := make_state(2)
	place(state, 11, 4, [3])
	state.round_number = 7
	state.send_to_start(state.get_pawn(11), 2)
	check(BotTemper.recently_hit(state, 1), "잡힌 라운드가 남는다")
	check_eq(int(state.law_stats[1][GameState.LAST_HIT_ROUND]), 7, "7라운드")


func test_normal_hunts_the_leader_before_a_trailing_human() -> void:
	var state := make_state(4)
	# P3(봇)이 1위: 말 하나 완주. P1(사람)은 꼴찌
	state.get_pawn(31).is_finished = true
	place(state, 32, 20, [19])
	place(state, 41, 18, [17])
	place(state, 11, 4, [3])
	# P2 봇: 21번은 3칸 가면 사람(4번 칸), 22번은 3칸 가면 1위 P3의 말(20번 칸)
	place(state, 21, 1, [0])
	place(state, 22, 17, [16])
	check_eq(BotTemper.race_rank(state, 1) >= BotTemper.TRAILING_RANK, true, "사람은 하위권")
	var rng := RandomNumberGenerator.new()
	check_eq(BotTemper.choose_pawn(state, 2, 3, BotTemper.NORMAL, HUMAN, rng), 22, "보통맛: 하위권 사람 대신 1위의 말을 잡는다")
	check_eq(BotTemper.choose_pawn(state, 2, 3, BotTemper.SPICY, HUMAN, rng), BotBrain.choose_pawn(state, 2, 3), "마라맛은 BotBrain 그대로")


func test_targeted_attack_cards_turn_to_the_leading_bot() -> void:
	var state := make_state(4)
	state.get_pawn(31).is_finished = true  # P3 봇이 1위
	place(state, 11, 4, [3])
	place(state, 32, 10, [9])
	var plan: Dictionary = {"card_id": &"ACT_14", "params": {"target_player": 1}}
	var rng := RandomNumberGenerator.new()
	var normal: Dictionary = BotTemper.filter_card_plan(state, 2, plan, BotTemper.NORMAL, HUMAN, rng)
	check_eq(int(normal["params"]["target_player"]), 3, "보통맛: 밴을 사람 대신 1위 봇에게")
	check_eq(BotTemper.filter_card_plan(state, 2, plan, BotTemper.SPICY, HUMAN, rng), plan, "마라맛은 그대로")
	check_eq(BotTemper.filter_card_plan(state, 2, {"card_id": &"ACT_04", "params": {}}, BotTemper.MILD, HUMAN, rng)["card_id"], &"ACT_04", "사람을 노리지 않는 카드는 그대로")


func test_mild_skips_most_attacks_on_a_leading_human() -> void:
	var state := make_state(2)
	place(state, 11, 20, [19])  # 사람이 1위
	place(state, 21, 2, [1])
	var plan: Dictionary = {"card_id": &"ACT_09", "params": {"target_player": 1}}
	var rng := RandomNumberGenerator.new()
	var dropped: int = 0
	for seed_value: int in 400:
		rng.seed = seed_value
		if BotTemper.filter_card_plan(state, 2, plan, BotTemper.MILD, HUMAN, rng).is_empty():
			dropped += 1
	check(dropped > 240 and dropped < 320, "순한맛: 사람을 노리는 데스매치를 약 70%% 거른다 (%d/400)" % dropped)
	rng.seed = 1
	check_eq(BotTemper.filter_card_plan(state, 2, plan, BotTemper.NORMAL, HUMAN, rng), plan, "보통맛: 1위인 사람은 견제한다")


func test_mild_draft_avoids_special_victory_laws() -> void:
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
		check_eq(offers[BotTemper.choose_augment(state, 2, offers, BotTemper.MILD, rng)], other, "순한맛은 법전 증강을 고르지 않는다")
