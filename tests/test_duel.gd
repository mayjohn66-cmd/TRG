# File: res://tests/test_duel.gd
# Class: class_name TestDuel
# Role: ACT_09 일기토 데스매치 검증 - 6종 미니게임 준비값·판정(가위바위보·할리갈리·컬링·석양의 무법자·E카드·스피키 룰렛), 대상 지목, 행동 잠금, 패자 선두 말 자동 사출, 하극상 +5칸, 시간 초과, 동기화, 봇 밸런스
class_name TestDuel
extends TestCase

const Phase := TurnManager.State
const ROCK: int = 0
const SCISSORS: int = 1
const PAPER: int = 2


func _new_manager(game: int = DuelRules.Game.RPS) -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	manager.set_process(false)
	var ids: Array[int] = [1, 2]
	manager.start_game(ids, 4242)
	manager.duel_game_override = game
	return manager


func _dispose(manager: TurnManager) -> void:
	tree.root.remove_child(manager)
	manager.free()


func _do(manager: TurnManager, player_id: int, action: StringName, params: Dictionary = {}) -> void:
	var payload: Dictionary = params.duplicate()
	payload["player_id"] = player_id
	manager.act(action, payload)


func _events(manager: TurnManager) -> Array:
	var events: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void: events.append({"kind": kind, "data": data}))
	return events


func _rejections(manager: TurnManager) -> Array:
	var rejected: Array = []
	manager.action_rejected.connect(func(player_id: int, action: StringName, reason: StringName) -> void: rejected.append([player_id, action, reason]))
	return rejected


func _kinds(events: Array) -> Array:
	return events.map(func(entry: Dictionary) -> StringName: return entry["kind"])


## P1이 결투를 걸 준비: P1 손패에 카드, P2의 말 두 개를 보드 위에 올린다.
func _setup(manager: TurnManager, tiles: Array[int] = [10, 14]) -> void:
	manager.state.give_card(1, &"ACT_09")
	for index: int in tiles.size():
		place(manager.state, 21 + index, tiles[index], [tiles[index] - 1])


func _challenge(manager: TurnManager, target: int = 2) -> void:
	_do(manager, 1, &"play_card", {"card_id": &"ACT_09", "target_player": target})


func test_hand_matrix() -> void:
	check_eq(DuelRules.compare(ROCK, SCISSORS), 1, "바위 > 가위")
	check_eq(DuelRules.compare(SCISSORS, PAPER), 1, "가위 > 보")
	check_eq(DuelRules.compare(PAPER, ROCK), 1, "보 > 바위")
	check_eq(DuelRules.compare(SCISSORS, ROCK), -1, "가위 < 바위")
	check_eq(DuelRules.compare(PAPER, PAPER), 0, "같으면 비김")


func test_card_needs_an_opponent_pawn_on_the_board_and_defaults_to_the_leader() -> void:
	var state := make_state(3, 1)
	var card: BaseCard = CardRegistry.get_card(&"ACT_09")
	check(not card.could_play(state, 1), "보드 위에 나온 상대 말이 없으면 못 쓴다")
	check(not card.can_play(state, 1, {"target_player": 2}), "지목해도 말이 없으면 불가")
	place(state, 21, 5, [4])
	place(state, 31, 15, [14])
	check(card.can_play(state, 1, {"target_player": 2}), "말이 나와 있는 상대는 지목 가능")
	check(not card.can_play(state, 2, {"target_player": 2}), "자기 자신은 불가")
	check_eq(DuelRules.default_target(state, 1), 3, "대상을 안 고르면 가장 앞선 상대(P3)")


func test_game_is_drawn_at_random_from_six() -> void:
	var seen: Dictionary = {}
	for seed_value: int in 60:
		var manager: TurnManager = _new_manager(-1)
		manager.state.rng.seed = seed_value
		_setup(manager)
		_challenge(manager)
		seen[int(manager.pending_duel()["game"])] = true
		_dispose(manager)
	check_eq(seen.size(), DuelRules.GAME_COUNT, "6종이 모두 추첨된다")


func test_rps_winner_ejects_the_losers_lead_pawn_and_advances_three() -> void:
	var manager: TurnManager = _new_manager()
	_setup(manager)
	place(manager.state, 11, 5, [4])
	var events: Array = _events(manager)
	var rejected: Array = _rejections(manager)
	_challenge(manager)
	check(manager.duel_pending(), "결투 대기")
	_do(manager, 1, &"roll")
	check_eq(rejected.back(), [1, &"roll", &"duel_pending"], "결투 중에는 다른 행동을 막는다")
	_do(manager, 1, &"duel_pick", {"value": ROCK})
	_do(manager, 2, &"duel_pick", {"value": SCISSORS})
	check(not manager.duel_pending(), "승패가 나면 말을 고르지 않고 바로 끝난다")
	check(not manager.state.get_pawn(22).has_left_start, "패자의 선두 말(14번)이 출발선으로")
	check_eq(manager.state.get_pawn(21).current_tile_idx, 10, "다른 말은 그대로")
	check_eq(manager.state.get_pawn(11).current_tile_idx, 8, "승자의 선두 말 +3칸")
	var revealed: Dictionary = events.filter(func(e: Dictionary) -> bool: return e["kind"] == &"duel_revealed")[0]["data"]
	check_eq(revealed["detail"], "(바위 vs 가위)", "결과 문구")
	check_eq(int(revealed["game"]), DuelRules.Game.RPS, "종목 기록")
	_dispose(manager)


func test_rps_draw_rematches_once_then_the_challenger_wins() -> void:
	var manager: TurnManager = _new_manager()
	_setup(manager)
	_challenge(manager)
	_do(manager, 1, &"duel_pick", {"value": ROCK})
	_do(manager, 2, &"duel_pick", {"value": ROCK})
	check(manager.duel_pending(), "비기면 재대결")
	_do(manager, 1, &"duel_pick", {"value": PAPER})
	_do(manager, 2, &"duel_pick", {"value": PAPER})
	check(not manager.duel_pending(), "재대결도 비기면 끝")
	check(not manager.state.get_pawn(22).has_left_start, "신청자 판정승: 수비자의 선두 말 사출")
	_dispose(manager)


func test_halli_galli_cards_hit_exactly_five_within_five_cards() -> void:
	var rng := RandomNumberGenerator.new()
	for seed_value: int in 200:
		rng.seed = seed_value
		var cards: Array[int] = DuelRules.halli_cards(rng)
		check(cards.size() >= 2 and cards.size() <= DuelRules.HALLI_MAX_CARDS, "카드 2~5장")
		for index: int in range(1, cards.size()):
			var total: int = cards[index - 1] + cards[index]
			check(cards[index] >= 1 and cards[index] <= 4, "그림 1~4개")
			check((total == 5) == (index == cards.size() - 1), "마지막 카드에서 처음으로 합 5")


func test_reaction_games_first_valid_press_wins_and_early_press_is_a_foul() -> void:
	var setup: Dictionary = {"signal": 2.0, "fake": -1.0}
	var quick: int = DuelRules.Game.QUICKDRAW
	check_eq(int(DuelRules.resolve(quick, setup, 1, 2, {1: 2400, 2: 2300})["winner"]), 2, "신호 뒤 먼저 쏜 쪽 승")
	var foul: Dictionary = DuelRules.resolve(quick, setup, 1, 2, {1: 1900, 2: 2600})
	check(int(foul["winner"]) == 2 and foul["decided_by"] == &"foul", "신호 전에 쏘면 부정출발 패배")
	check_eq(int(DuelRules.resolve(quick, setup, 1, 2, {1: -1, 2: -1})["winner"]), 1, "아무도 안 쏘면 신청자 승")
	check_eq(DuelRules.detail_text(quick, setup, 1, 2, {1: 2420, 2: 1900}), "(0.42초 vs 반칙)", "결과 문구")
	var halli: Dictionary = {"cards": [2, 1, 4], "interval": 0.55}
	check_eq(DuelRules.reaction_mark(DuelRules.Game.HALLI, halli), 1.1, "세 번째 카드(1+4=5)가 깔리는 1.10초가 정답")
	check_eq(int(DuelRules.resolve(DuelRules.Game.HALLI, halli, 1, 2, {1: 1000, 2: 1500})["winner"]), 2, "5가 아닐 때 치면 헛스윙 반칙패")


func test_curling_closest_to_the_edge_wins_and_overshoot_falls() -> void:
	var curling: int = DuelRules.Game.CURLING
	check_eq(int(DuelRules.resolve(curling, {}, 1, 2, {1: 960, 2: 880})["winner"]), 1, "96% > 88%")
	check_eq(int(DuelRules.resolve(curling, {}, 1, 2, {1: 1001, 2: 500})["winner"]), 2, "100% 초과는 추락 자멸패")
	check_eq(int(DuelRules.resolve(curling, {}, 1, 2, {1: 1000, 2: 999})["winner"]), 1, "딱 100%는 안전")
	check_eq(DuelRules.detail_text(curling, {}, 1, 2, {1: 960, 2: 880}), "(96.0% vs 88.0%)", "결과 문구")


func test_ecard_upset_gives_the_defender_five_tiles() -> void:
	var manager: TurnManager = _new_manager(DuelRules.Game.ECARD)
	_setup(manager)
	place(manager.state, 11, 5, [4])
	place(manager.state, 22, 3, [2])
	place(manager.state, 21, 2, [1])
	_challenge(manager)
	_do(manager, 1, &"duel_pick", {"value": DuelRules.ECARD_QUEEN})
	_do(manager, 2, &"duel_pick", {"value": DuelRules.ECARD_REBEL})
	check(not manager.state.get_pawn(11).has_left_start, "반란군이 여왕을 잡았다: 신청자의 선두 말 사출")
	check_eq(manager.state.get_pawn(22).current_tile_idx, 8, "하극상 보너스: 수비자의 선두 말 +5칸")
	check_eq(int(DuelRules.resolve(DuelRules.Game.ECARD, {}, 1, 2, {1: 1, 2: 1})["winner"]), 1, "둘 다 평민이면 신청자 승")
	check_eq(int(DuelRules.resolve(DuelRules.Game.ECARD, {}, 1, 2, {1: 1, 2: 0})["winner"]), 1, "평민 > 반란군")
	check_eq(int(DuelRules.resolve(DuelRules.Game.ECARD, {}, 1, 2, {1: 0, 2: 1})["winner"]), 1, "여왕 > 평민")
	_dispose(manager)


func test_barrel_players_alternate_and_the_bomb_loses() -> void:
	var manager: TurnManager = _new_manager(DuelRules.Game.BARREL)
	_setup(manager)
	var rejected: Array = _rejections(manager)
	_challenge(manager)
	var bomb: int = int((manager.pending_duel()["setup"] as Dictionary)["bomb"])
	_do(manager, 2, &"duel_pick", {"value": 0})
	check_eq(rejected.back(), [2, &"duel_pick", &"not_your_turn"], "신청자부터")
	var safe: Array[int] = []
	for hole: int in DuelRules.BARREL_HOLES:
		if hole != bomb:
			safe.append(hole)
	_do(manager, 1, &"duel_pick", {"value": safe[0]})
	check(manager.duel_pending() and int(manager.pending_duel()["turn"]) == 2, "안전하면 상대 차례")
	_do(manager, 2, &"duel_pick", {"value": safe[0]})
	check_eq(rejected.back(), [2, &"duel_pick", &"invalid_value"], "이미 꽂은 구멍은 안 된다")
	_do(manager, 2, &"duel_pick", {"value": bomb})
	check(not manager.duel_pending(), "폭탄을 찌르면 끝")
	check(not manager.state.get_pawn(22).has_left_start, "찌른 수비자가 패배: 선두 말 사출")
	_dispose(manager)


func test_loser_without_board_pawns_ends_the_duel_without_effect() -> void:
	var manager: TurnManager = _new_manager()
	manager.state.give_card(1, &"ACT_09")
	place(manager.state, 21, 5, [4])
	place(manager.state, 11, 0, [], false)
	_challenge(manager)
	_do(manager, 1, &"duel_pick", {"value": ROCK})
	_do(manager, 2, &"duel_pick", {"value": PAPER})
	check(not manager.duel_pending(), "밀 말이 없으면 효과 없이 끝난다")
	check_eq(manager.state.get_pawn(21).current_tile_idx, 5, "상대 말은 그대로")
	_dispose(manager)


func test_winner_boost_triggers_the_trap_on_the_landing_tile() -> void:
	var manager: TurnManager = _new_manager()
	manager.state.give_card(1, &"ACT_09")
	manager.state.place_attachment(8, TrapMirrorForce.new(2))
	place(manager.state, 11, 5, [4])
	place(manager.state, 22, 3, [2])
	var triggers: Array = []
	manager.state.attachment_triggered.connect(func(tile: int, id: String, pawn_id: int, _cutscene: StringName) -> void: triggers.append([tile, id, pawn_id]))
	_challenge(manager)
	_do(manager, 1, &"duel_pick", {"value": ROCK})
	_do(manager, 2, &"duel_pick", {"value": SCISSORS})
	check_eq(triggers, [[8, "TRP_01", 11]], "승자의 말이 +3칸 착지한 8번의 거울의 힘이 터진다")
	check(not manager.state.get_pawn(11).has_left_start, "함정에 걸려 출발선으로 돌아간다")
	_dispose(manager)


func test_timeout_finishes_every_game() -> void:
	for game: int in DuelRules.GAME_COUNT:
		var manager: TurnManager = _new_manager(game)
		_setup(manager)
		_challenge(manager)
		check(manager.phase_time_left > 0.0, "%s: 제한 시간이 있다" % DuelRules.game_name(game))
		var guard: int = 0
		while manager.duel_pending() and guard < 12:
			manager.force_timeout()
			guard += 1
		check(not manager.duel_pending(), "%s: 시간 초과만으로 결투가 끝까지 진행된다" % DuelRules.game_name(game))
		_dispose(manager)


func test_non_participants_cannot_pick() -> void:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	manager.set_process(false)
	var ids: Array[int] = [1, 2, 3]
	manager.start_game(ids, 4242)
	manager.duel_game_override = DuelRules.Game.RPS
	manager.state.give_card(1, &"ACT_09")
	place(manager.state, 21, 5, [4])
	var rejected: Array = _rejections(manager)
	_do(manager, 1, &"play_card", {"card_id": &"ACT_09", "target_player": 2})
	_do(manager, 3, &"duel_pick", {"value": ROCK})
	check_eq(rejected, [[3, &"duel_pick", &"not_your_duel"]], "제3자는 값을 낼 수 없다")
	_dispose(manager)


func test_duel_state_roundtrips_through_the_sync_payload() -> void:
	var manager: TurnManager = _new_manager(DuelRules.Game.HALLI)
	_setup(manager)
	_challenge(manager)
	_do(manager, 1, &"duel_pick", {"value": 3000})
	var payload: Dictionary = manager._build_sync_payload()
	var duel: Dictionary = payload["duel"]
	check_eq(duel["step"], &"pick", "동기화 페이로드에 결투 상태")
	check_eq(int(duel["game"]), DuelRules.Game.HALLI, "종목")
	check(not (duel["setup"]["cards"] as Array).is_empty(), "카드 순서도 함께")
	check_eq((duel["picks"] as Dictionary).size(), 1, "먼저 낸 값도 포함")
	_dispose(manager)


func test_bots_play_every_game_by_themselves() -> void:
	for game: int in DuelRules.GAME_COUNT:
		var manager: TurnManager = _new_manager(game)
		_setup(manager)
		var controller := BotController.new()
		controller.manager = manager
		controller.bot_players = [1, 2] as Array[int]
		controller.instant = true
		controller.enabled = true
		controller.rng.seed = 7
		_challenge(manager)
		var guard: int = 0
		while manager.duel_pending() and guard < 60:
			controller.tick(0.1)
			guard += 1
		check(not manager.duel_pending(), "%s: 봇끼리 끝까지 (%d틱)" % [DuelRules.game_name(game), guard])
		controller.free()
		_dispose(manager)


func test_bot_reaction_and_curling_balance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var setup: Dictionary = {"signal": 2.0, "fake": -1.0}
	var overshoot: int = 0
	for i: int in 400:
		var pressed: int = DuelRules.bot_input(DuelRules.Game.QUICKDRAW, setup, false, rng)
		check(pressed >= 2380 and pressed <= 2680, "반응 0.38~0.68초 (%d)" % pressed)
		var curl: int = DuelRules.bot_input(DuelRules.Game.CURLING, {}, false, rng)
		if curl > DuelRules.CURLING_EDGE:
			overshoot += 1
		else:
			check(curl >= 720 and curl <= 960, "정밀도 72~96%% (%d)" % curl)
	check(overshoot > 30 and overshoot < 95, "약 15%% 확률로 100%% 초과 실수 (%d/400)" % overshoot)
