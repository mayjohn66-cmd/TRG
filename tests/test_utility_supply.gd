# File: res://tests/test_utility_supply.gd
# Class: class_name TestUtilitySupply
# Role: [범용] 증강 10종 (2026-10): 영구 패시브 4종(이동 +1·손패 상한·굴림 운·리바이브)과 즉발 6종(즉발 카드·보호막·함정 철거·순보·결승선 단축·올 픽션)의
#       조건·효과·저장, 그리고 드래프트 재추첨 흐름을 검사한다.
class_name TestUtilitySupply
extends TestCase


func _apply(state: GameState, effect: StringName, player_id: int = 1) -> Dictionary:
	return AugmentRegistry.get_def(effect).apply(state, player_id)


func _manager(draft: bool) -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = draft
	tree.root.add_child(manager)
	manager.start_game([1, 2, 3, 4] as Array[int], 909)
	return manager


func _dispose(manager: TurnManager) -> void:
	tree.root.remove_child(manager)
	manager.free()


func test_all_ten_are_drafted_as_utility_from_the_table() -> void:
	for effect: StringName in UtilityAugments.NEW_IDS:
		var def: AugmentDef = AugmentRegistry.get_def(effect)
		check(def != null and def.category == GameEnums.AugmentCategory.UTILITY, "%s는 범용 보급" % effect)
		check(def.display_name != "" and not def.display_name.begins_with("AUG_"), "%s 이름" % effect)


func test_move_plus_stacks_twice() -> void:
	var state := make_state(2)
	check(bool(_apply(state, UtilityAugments.MOVE_PLUS)["ok"]), "적용")
	check_eq(int(state.permanent_roll_bonus.get(1, 0)), 1, "모든 굴림 영구 +1칸")
	_apply(state, UtilityAugments.MOVE_PLUS)
	check_eq(int(state.permanent_roll_bonus.get(1, 0)), 2, "두 번째 +1칸")
	check(not AugmentRegistry.get_def(UtilityAugments.MOVE_PLUS).is_available(state, 1), "세 번째부터는 나오지 않는다")


func test_hand_expand_raises_the_hand_limit_and_gives_a_card() -> void:
	var state := make_state(2)
	var before: int = (state.hands[1] as Array).size()
	_apply(state, UtilityAugments.HAND_EXPAND)
	check_eq(state.hand_limit(1), GameEnums.MAX_HAND_SIZE + 1, "손패 상한 +1")
	check_eq((state.hands[1] as Array).size(), before + 1, "카드 1장")
	while (state.hands[1] as Array).size() < GameEnums.MAX_HAND_SIZE + 1:
		state.give_card(1, &"ACT_04")
	check(not state.give_card(1, &"ACT_04"), "늘어난 상한을 넘으면 못 받는다")


func test_lucky_dice_raises_the_average_roll() -> void:
	var state := make_state(2)
	var tool := ToolDiceD6.new()
	var plain: int = 0
	for i: int in 3000:
		plain += UtilityAugments.lucky_roll(state, 1, tool, tool.roll(state.rng)).steps
	_apply(state, UtilityAugments.LUCKY_DICE)
	var lucky: int = 0
	for i: int in 3000:
		lucky += UtilityAugments.lucky_roll(state, 1, tool, tool.roll(state.rng)).steps
	check(float(lucky) / 3000.0 > float(plain) / 3000.0 + 0.4, "굴림 운: 평균 눈금이 오른다 (%.2f → %.2f)" % [plain / 3000.0, lucky / 3000.0])


func test_revive_gives_one_more_turn_once() -> void:
	var manager := _manager(false)
	var state: GameState = manager.state
	_apply(state, UtilityAugments.EXTRA_TURN)
	check(not AugmentRegistry.get_def(UtilityAugments.EXTRA_TURN).is_available(state, 1), "장전 중에는 다시 나오지 않는다")
	var bust := RollResult.make(&"SCRIPTED", 0)
	bust.ends_turn = true
	state.tools[1] = ScriptedTool.new([bust, bust])
	manager.act(&"proceed", {"player_id": 1})
	manager.act(&"roll", {"player_id": 1})
	check_eq(manager.current_player_id(), 1, "턴 종료 굴림이어도 같은 사람이 한 턴 더")
	check_eq(int(state.revive_charges.get(1, 0)), 0, "리바이브는 한 번 쓰면 사라진다")
	manager.act(&"proceed", {"player_id": 1})
	manager.act(&"roll", {"player_id": 1})
	check_eq(manager.current_player_id(), 2, "두 번째 턴 종료는 그대로 넘어간다")
	_dispose(manager)


func test_card_pack_gives_two_instant_cards() -> void:
	var state := make_state(2)
	var before: int = (state.hands[1] as Array).size()
	_apply(state, UtilityAugments.CARD_PACK2)
	var hand: Array = state.hands[1]
	check_eq(hand.size(), before + 2, "카드 2장")
	for index: int in range(before, hand.size()):
		check_eq(CardRegistry.type_of(hand[index]), "INSTANT", "즉발 카드")


func test_shield_blocks_one_capture_on_the_leading_pawn() -> void:
	var state := make_state(2)
	place(state, 11, 5, [4])
	place(state, 12, 9, [8])
	_apply(state, UtilityAugments.SELECT_SHIELD)
	check(state.get_pawn(12).ward and not state.get_pawn(11).ward, "컴퓨터·자동 선택은 선두 말에 보호막")
	check(MoveExecutor.is_capture_immune(state, state.get_pawn(12)), "보호막 말은 잡기 면역으로 보인다")
	check(state.break_shield(state.get_pawn(12)) and not state.get_pawn(12).ward, "한 번 막고 사라진다")
	var picked: Dictionary = UtilityAugments.apply_shield_to(state, 1, 11)
	check(bool(picked["ok"]) and state.get_pawn(11).ward, "고른 말에 보호막")
	var empty := make_state(2)
	_apply(empty, UtilityAugments.SELECT_SHIELD)
	check(empty.get_pawn(11).ward, "보드에 말이 없으면 다음에 출격할 첫 말에")


func test_trap_clear_removes_an_enemy_trap_or_gives_a_card() -> void:
	var state := make_state(2)
	var trap: TileAttachment = AttachmentRegistry.create("TRP_02")
	trap.owner_id = 2
	state.board.get_tile(7).add_attachment(trap)
	var mine: TileAttachment = AttachmentRegistry.create("TRP_02")
	mine.owner_id = 1
	state.board.get_tile(9).add_attachment(mine)
	_apply(state, UtilityAugments.TRAP_CLEAR1)
	check(state.board.get_tile(7).attachments.is_empty(), "상대 함정 철거")
	check_eq(state.board.get_tile(9).attachments.size(), 1, "내 함정은 그대로")
	var before: int = (state.hands[1] as Array).size()
	_apply(state, UtilityAugments.TRAP_CLEAR1)
	check_eq((state.hands[1] as Array).size(), before + 1, "철거할 함정이 없으면 카드 1장")


func test_catch_up_moves_the_rearmost_pawn_behind_the_leader() -> void:
	var state := make_state(2)
	place(state, 21, 18, [17])
	place(state, 11, 3, [2])
	place(state, 12, 10, [9])
	_apply(state, UtilityAugments.CATCH_UP)
	check_eq(state.get_pawn(11).current_tile_idx, 17, "가장 뒤처진 내 말이 선두(18번) 바로 뒤로")
	check_eq(state.get_pawn(12).current_tile_idx, 10, "다른 말은 그대로")
	var fresh := make_state(2)
	place(fresh, 21, 12, [11])
	_apply(fresh, UtilityAugments.CATCH_UP)
	check(fresh.get_pawn(11).has_left_start and fresh.get_pawn(11).current_tile_idx == 11, "보드에 말이 없으면 대기 말을 꺼내 선두 뒤로")


func test_shorten_goal_pulls_everyones_finish_line() -> void:
	var state := make_state(2)
	state.round_number = 2
	check(not TempoUp.in_zone_for(state, BoardSpec.tile_count - 1), "처음엔 결승선 그대로")
	_apply(state, UtilityAugments.SHORTEN_GOAL)
	check_eq(TempoUp.shrink_for(state), 2, "2칸 당겨진다")
	check(TempoUp.in_zone_for(state, BoardSpec.tile_count - 2) and not TempoUp.in_zone_for(state, BoardSpec.tile_count - 3), "마지막 2칸이 결승선")
	place(state, 11, BoardSpec.tile_count - 4, [BoardSpec.tile_count - 5])
	var report: MoveReport = move(state, 11, 2)
	check(report.finished, "당겨진 결승선에 들어서면 완주")


func test_all_fiction_makes_everyone_pick_again_after_all_picks() -> void:
	var manager := _manager(true)
	var state: GameState = manager.state
	state.round_number = 7
	manager._enter_round_start()
	(manager._draft_offers[1] as Array)[0] = UtilityAugments.REROLL_ALL_AUG
	(manager._draft_offers[2] as Array)[0] = &"CARD_PACKAGE"
	var hand_before: int = (state.hands[2] as Array).size()
	manager.act(&"pick_augment", {"player_id": 1, "index": 0})
	manager.act(&"pick_augment", {"player_id": 2, "index": 0})
	check_eq((state.hands[2] as Array).size(), hand_before, "모두 고르기 전에는 발동하지 않는다")
	manager.act(&"pick_augment", {"player_id": 3, "index": 0})
	manager.act(&"pick_augment", {"player_id": 4, "index": 0})
	check_eq(manager.current_state, TurnManager.State.PHASE_ROUND_START, "올 픽션: 드래프트가 끝나지 않고")
	check_eq(manager.draft_pending_players(), int_array([1, 2, 3, 4]), "모두 다시 고른다")
	check_eq((state.hands[2] as Array).size(), hand_before, "버린 선택(카드 패키지)은 적용되지 않는다")
	check_eq(state.reshuffle_round, 7, "이번 라운드에 썼다")
	for player_id: int in [1, 2, 3, 4]:
		check(not manager.draft_offers_for(player_id).has(UtilityAugments.REROLL_ALL_AUG), "새 선택지에 올 픽션은 없다 (P%d)" % player_id)
	for player_id: int in [1, 2, 3, 4]:
		manager.auto_pick_draft_now(player_id)
	check(manager.current_state != TurnManager.State.PHASE_ROUND_START, "두 번째 선택이 끝나면 드래프트가 끝난다")
	for player_id: int in [1, 2, 3, 4]:
		check(not (manager.augments[player_id] as Array).is_empty(), "P%d 증강 적용" % player_id)
	_dispose(manager)


func test_utility_state_survives_snapshots() -> void:
	var state := make_state(2)
	_apply(state, UtilityAugments.HAND_EXPAND)
	_apply(state, UtilityAugments.LUCKY_DICE)
	_apply(state, UtilityAugments.EXTRA_TURN)
	_apply(state, UtilityAugments.SHORTEN_GOAL)
	var snapshot: TurnSnapshot = TurnSnapshot.capture(state)
	state.hand_bonus.clear()
	state.lucky_dice.clear()
	state.revive_charges.clear()
	state.goal_shrink_bonus = 0
	snapshot.restore(state)
	check(state.hand_limit(1) == GameEnums.MAX_HAND_SIZE + 1 and int(state.lucky_dice.get(1, 0)) == 1 and int(state.revive_charges.get(1, 0)) == 1 and state.goal_shrink_bonus == 2, "되감기·동기화로 범용 기록 복원")
