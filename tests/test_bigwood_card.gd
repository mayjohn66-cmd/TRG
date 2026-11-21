## CNT_08 local registration and real defense-window behavior.
class_name TestBigwoodCard
extends TestCase

func _manager() -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.draft_enabled = false
	manager.hotseat_mode = true
	tree.root.add_child(manager)
	defer_free(manager)
	manager.start_game([1, 2], 4242)
	manager.set_process(false)
	return manager

func _capture(manager: TurnManager) -> void:
	place(manager.state, 11, 1, [0])
	place(manager.state, 21, 3, [2])
	manager.state.hands[2] = [&"CNT_08"]
	manager.state.tools[1] = ScriptedTool.new([2])
	manager._begin_turn()
	manager.act(&"proceed", {"player_id": 1})
	manager.act(&"roll", {"player_id": 1})
	manager.act(&"select_pawn", {"player_id": 1, "pawn_id": 11})

func test_registered_in_deck_supply_and_live_card_data() -> void:
	var card := CardRegistry.get_card(&"CNT_08")
	check(card is CardCounter, "registry returns the real counter implementation")
	check_eq(card.display_name, "이쪽을 봐라!", "name from local CSV")
	check_eq(card.category, GameEnums.CardCategory.COUNTER, "defense category")
	check_eq(CardRegistry.default_deck().count(&"CNT_08"), 1, "one default deck copy")
	check(CardRegistry.ids_of_type("COUNTER").has(&"CNT_08"), "available in defense supply")
	check_eq(GameData.text("cards", &"CNT_08", "icon_file"), "CNT_08.png", "approved artwork")
	check(ResourceLoader.exists("res://assets/cards/CNT_08.png"), "art is imported")
	check_eq(MainBoard.card_summary(&"CNT_08"), "[잡기 방어] 잡기 1회 회피", "live description: 분류는 설명 머리표에")
	check_eq(MainBoard.category_label(card), "방어", "모서리 배지는 [방어] (2026-11-04)")
	for phase: int in [TurnManager.State.PHASE_TURN_BEGIN, TurnManager.State.PHASE_ROLL_WAIT, TurnManager.State.PHASE_RESOLUTION]:
		check(not card.is_playable_in(phase), "not a regular turn/interrupt card")
	var row: Dictionary = GameData.table("cards")["CNT_08"]
	check(not str(row["name_en"]).is_empty() and not str(row["name_ja"]).is_empty(), "localized names")

func test_only_capture_can_be_answered_and_no_reuse() -> void:
	var state := make_state()
	for kind: StringName in [CardCounter.CAPTURE, CardCounter.CARD, CardCounter.TRAP]:
		var entry := {"kind": kind, "countered": false}
		check_eq(CardCounter.answers(state, &"CNT_08", entry), kind == CardCounter.CAPTURE, "capture only: %s" % kind)
	check(not CardCounter.answers(state, &"CNT_08", {"kind": CardCounter.CAPTURE, "countered": true}), "already defended attacks cannot be reused")

func test_real_window_restores_without_retaliation_or_kill_counts() -> void:
	var manager := _manager()
	var state := manager.state
	add_law(state, "LAW_01")
	add_law(state, "LAW_06")
	add_law(state, "LAW_08")
	_capture(manager)
	check(manager.counter_pending(), "capture opens defense window")
	check_eq(manager.pending_counter().get("cards"), [&"CNT_08"], "new card offered")
	check_eq(state.stat(1, &"kills"), 0, "kill not committed while waiting")
	check_eq(state.stat(2, &"ejected"), 0, "death law not committed while waiting")
	manager.act(&"play_card", {"player_id": 1, "card_id": &"CNT_08"})
	check(state.has_card(2, &"CNT_08") and manager.counter_pending(), "only victim may play it")
	manager.act(&"play_card", {"player_id": 2, "card_id": &"CNT_08"})
	check(not manager.counter_pending(), "window closes and turn resumes")
	check(not state.has_card(2, &"CNT_08"), "one card consumed")
	check(state.get_pawn(21).has_left_start and state.get_pawn(21).current_tile_idx == 3, "victim restored to actual tile")
	check(state.get_pawn(11).has_left_start and state.get_pawn(11).current_tile_idx == 3, "attacker is not ejected")
	for key: StringName in [&"kills", &"underdog", GameState.TALLY_KILLS]:
		check_eq(state.stat(1, key), 0, "blocked capture never counted: %s" % key)
	for key: StringName in [&"ejected", GameState.TALLY_DEATHS]:
		check_eq(state.stat(2, key), 0, "surviving victim not counted: %s" % key)
	check(not manager.is_game_over, "blocked capture does not win a law")

func test_declining_or_banned_defense_counts_only_the_actual_capture() -> void:
	for banned: bool in [false, true]:
		var manager := _manager()
		if banned:
			manager.state.banned_turns[2] = 2
		_capture(manager)
		if banned:
			check(not manager.counter_pending(), "banned victim gets no defense offer")
		else:
			check(manager.counter_pending(), "victim may choose to pass")
			manager.act(&"counter_pass", {"player_id": 2})
		check(manager.state.has_card(2, &"CNT_08"), "unused card remains")
		check(not manager.state.get_pawn(21).has_left_start, "accepted capture stays")
		check_eq(manager.state.stat(1, GameState.TALLY_KILLS), 1, "one actual kill")
		check_eq(manager.state.stat(2, GameState.TALLY_DEATHS), 1, "one actual death")

func test_no_offer_for_attack_card_and_cannot_play_at_turn_begin() -> void:
	var manager := _manager()
	var state := manager.state
	state.hands[1] = [&"ACT_02", &"CNT_08"]
	state.hands[2] = [&"CNT_08"]
	place(state, 11, 1, [0])
	place(state, 21, 5, [4])
	manager.act(&"play_card", {"player_id": 1, "card_id": &"CNT_08"})
	check(state.has_card(1, &"CNT_08"), "own turn cannot use defense without an offer")
	manager.act(&"play_card", {"player_id": 2, "card_id": &"CNT_08"})
	check(state.has_card(2, &"CNT_08"), "no use outside defense window")
	manager.act(&"play_card", {"player_id": 1, "card_id": &"ACT_02", "target_player": 2})
	check(not manager.counter_pending(), "attack card cannot open CNT_08 defense")
	check(not state.get_pawn(21).has_left_start, "attack card still hits")
	check(state.has_card(2, &"CNT_08"), "capture defense stays unused")

func test_bot_actually_uses_new_card() -> void:
	var manager := _manager()
	_capture(manager)
	var controller := BotController.new()
	controller.manager = manager
	controller.bot_players = [2]
	controller.instant = true
	controller.enabled = true
	controller.rng.seed = 99
	defer_free(controller)
	for i: int in 4:
		if not manager.counter_pending():
			break
		controller.tick(0.0)
	check(not manager.counter_pending(), "bot resolves the offer")
	check(not manager.state.has_card(2, &"CNT_08"), "bot spends the new card")
	check(manager.state.get_pawn(21).has_left_start, "bot victim survives")
	check(manager.state.get_pawn(11).has_left_start, "bot defense does not retaliate")
