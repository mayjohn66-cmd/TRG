# File: res://tests/test_super_augments.gd
# Class: class_name TestSuperAugments
# Role: [초증강 : 도박 & 억까] 10종의 조건·효과·드래프트 등장·턴 매니저 연동(영구 가속, 도박사 2배/실패 후퇴, 휴식)을 검사한다
class_name TestSuperAugments
extends TestCase


func _state(seed_value: int = 11) -> GameState:
	var state := GameState.new()
	state.boost_gimmicks = false
	state.setup([1, 2, 3, 4] as Array[int], seed_value)
	return state


func _place(state: GameState, pawn_id: int, tile: int) -> PlayerPawn:
	var pawn: PlayerPawn = state.get_pawn(pawn_id)
	pawn.has_left_start = true
	pawn.current_tile_idx = tile
	return pawn


func _def(effect: StringName) -> AugmentDef:
	return AugmentRegistry.get_def(effect)


func test_ten_super_augments_are_registered_with_names_and_descriptions() -> void:
	check_eq(SuperAugments.ALL_IDS.size(), 10, "초증강 10종")
	var state: GameState = _state()
	for effect: StringName in SuperAugments.ALL_IDS:
		var def: AugmentDef = _def(effect)
		check(def != null and def.category == GameEnums.AugmentCategory.SUPER_GAMBLE, "%s 등록" % effect)
		check(def.display_name.begins_with("[초증강] "), "%s 이름 표기" % effect)
		check(def.describe(state, 1).begins_with("◆"), "%s 설명" % effect)
	check_eq(AugmentDef.category_name(GameEnums.AugmentCategory.SUPER_GAMBLE), "초증강 : 도박 & 억까", "카테고리 이름")
	check_eq(SuperAugments.display_name(SuperAugments.FLIP), "[초증강] 판 뒤집기 (모 아니면 도)", "1번 이름")
	check_eq(SuperAugments.display_name(SuperAugments.REDISTRIBUTE), "[초증강] 공산주의 재분배", "2번 이름")
	check_eq(SuperAugments.display_name(SuperAugments.DICTATOR), "[초증강] 독재자의 날조", "10번 이름")


func test_availability_depends_on_the_board() -> void:
	var state: GameState = _state()
	check(not SuperAugments.is_available(SuperAugments.FLIP, state, 1), "보드에 내 말이 없으면 판 뒤집기 불가")
	check(not SuperAugments.is_available(SuperAugments.DEVIL, state, 1), "제물이 없으면 악마의 계약 불가")
	check(not SuperAugments.is_available(SuperAugments.SNIPER, state, 1), "적 말이 없으면 저격 불가")
	check(not SuperAugments.is_available(SuperAugments.CASTLING, state, 1), "말이 둘 미만이면 캐슬링 불가")
	check(SuperAugments.is_available(SuperAugments.GAMBLER, state, 1) and SuperAugments.is_available(SuperAugments.BAKERY, state, 1) and SuperAugments.is_available(SuperAugments.MINEFIELD, state, 1) and SuperAugments.is_available(SuperAugments.RAID, state, 1), "언제든 되는 초증강")
	_place(state, 11, 8)
	_place(state, 21, 14)
	check(SuperAugments.is_available(SuperAugments.FLIP, state, 1) and SuperAugments.is_available(SuperAugments.DEVIL, state, 1) and SuperAugments.is_available(SuperAugments.SNIPER, state, 1) and SuperAugments.is_available(SuperAugments.CASTLING, state, 1), "말이 나오면 가능")
	check(SuperAugments.is_available(SuperAugments.REDISTRIBUTE, state, 1), "내가 뒤처지면 재분배 가능")
	state.npcs.append(NeutralNPC.new())
	state.npcs.append(NeutralNPC.new())
	state.npcs.append(NeutralNPC.new())
	check(not SuperAugments.is_available(SuperAugments.RAID, state, 1), "NPC가 가득 차면 대습격 불가")


func test_flip_is_all_or_nothing_across_seeds() -> void:
	var finished: int = 0
	var expelled: int = 0
	for seed_value: int in 80:
		var state: GameState = _state(seed_value)
		var pawn: PlayerPawn = _place(state, 11, 10)
		var result: Dictionary = SuperAugments.apply(SuperAugments.FLIP, state, 1)
		check(bool(result["ok"]), "판 뒤집기 적용")
		if pawn.is_finished:
			finished += 1
			check(not bool(state.rest_next_turn.get(1, false)), "성공하면 휴식 없음")
		else:
			expelled += 1
			check(not pawn.has_left_start and pawn.current_tile_idx == GameEnums.GOAL_TILE and bool(state.rest_next_turn.get(1, false)), "실패하면 추방 + 다음 턴 휴식")
	check(finished > 10 and expelled > 10, "50% 안팎으로 갈린다 (완주 %d / 추방 %d)" % [finished, expelled])


func test_redistribute_swaps_with_the_leader_and_steals_a_card() -> void:
	var state: GameState = _state()
	_place(state, 11, 3)    # 내 말: 3번 (뒤처짐)
	_place(state, 21, 20)   # 상대 선두: 20번 (결승에 가까움)
	_place(state, 31, 10)
	state.hands[2] = [&"ACT_04"]
	# 내 가장 뒤처진 말은 아직 출발 전인 12번 말 (출발선 대기도 '가장 뒤처진 말'로 센다)
	check_eq(SuperAugments.laggard_pawn(state, 1).entity_id, 12, "가장 뒤처진 말")
	var result: Dictionary = SuperAugments.apply(SuperAugments.REDISTRIBUTE, state, 1)
	check(bool(result["ok"]), "재분배 적용")
	check_eq(state.get_pawn(12).current_tile_idx, 20, "내 꼴찌 말이 선두 자리로")
	check(state.get_pawn(12).has_left_start, "선두 자리에서는 보드 위 말이 된다")
	check(state.get_pawn(21).current_tile_idx == GameEnums.GOAL_TILE and not state.get_pawn(21).has_left_start, "선두 말은 내 꼴찌의 자리(출발선 대기)로")
	check((state.hands[1] as Array).has(&"ACT_04") and (state.hands[2] as Array).is_empty(), "1등의 카드 1장 강탈")


func test_redistribute_unavailable_when_i_am_already_ahead() -> void:
	var state: GameState = _state()
	_place(state, 11, 22)
	_place(state, 21, 5)
	for pawn: PlayerPawn in state.pawns_of(1):
		if pawn.entity_id != 11:
			pawn.is_finished = true
	check(not SuperAugments.is_available(SuperAugments.REDISTRIBUTE, state, 1), "내가 1등이면 재분배 불가")


func test_devil_sacrifices_a_pawn_for_a_permanent_bonus() -> void:
	var state: GameState = _state()
	_place(state, 11, 9)
	var result: Dictionary = SuperAugments.apply(SuperAugments.DEVIL, state, 1)
	check(bool(result["ok"]), "악마의 계약")
	check(not state.get_pawn(11).has_left_start, "제물로 출발선 복귀")
	check_eq(int(state.permanent_roll_bonus[1]), 3, "영구 +3")
	_place(state, 12, 5)
	SuperAugments.apply(SuperAugments.DEVIL, state, 1)
	check_eq(int(state.permanent_roll_bonus[1]), 6, "겹치면 +6")


func test_minefield_places_five_hidden_traps_on_empty_tiles() -> void:
	var state: GameState = _state(5)
	var placed: Array[int] = []
	state.attachment_placed.connect(func(tile: int, id: String, owner: int) -> void:
		placed.append(tile)
		check(owner == 1 and (id == "TRP_01" or id == "TRP_03"), "거울의 힘 또는 지뢰, 설치자는 나"))
	var result: Dictionary = SuperAugments.apply(SuperAugments.MINEFIELD, state, 1)
	check(bool(result["ok"]), "지뢰밭")
	check_eq(placed.size(), 5, "5곳에 살포")
	var unique: Dictionary = {}
	for tile: int in placed:
		unique[tile] = true
		check(tile != GameEnums.GOAL_TILE, "결승 칸은 피한다")
	check_eq(unique.size(), 5, "서로 다른 타일")


func test_raid_spawns_two_robbers_and_a_ghost_within_the_npc_cap() -> void:
	var state: GameState = _state()
	SuperAugments.apply(SuperAugments.RAID, state, 1)
	check_eq(state.npcs.size(), 3, "도적떼 2 + 고스트 1")
	var robbers: int = 0
	var ghosts: int = 0
	for npc: NeutralNPC in state.npcs:
		if npc.behavior == GameEnums.NpcBehavior.CHASE_NEAREST:
			robbers += 1
		else:
			ghosts += 1
			check_eq(npc.current_tile_idx, GameEnums.HALFWAY_TILE, "고스트는 반환점에서")
	check(robbers == 2 and ghosts == 1, "구성 확인")
	var crowded: GameState = _state()
	crowded.spawn_npc(5, GameEnums.NpcBehavior.CHASE_NEAREST, 1, &"SUM_01")
	SuperAugments.apply(SuperAugments.RAID, crowded, 1)
	check_eq(crowded.npcs.size(), GameEnums.MAX_NPCS, "NPC 상한을 넘지 않는다")


func test_gambler_flag_lasts_one_round_only() -> void:
	var state: GameState = _state()
	SuperAugments.apply(SuperAugments.GAMBLER, state, 2)
	check_eq(int(state.gambler_round[2]), state.round_number, "이번 라운드 기록")


func test_castling_shuffles_all_board_pawns_positions() -> void:
	var state: GameState = _state()
	var tiles: Array[int] = [3, 8, 12, 17]
	var ids: Array[int] = [11, 21, 31, 41]
	for i: int in 4:
		_place(state, ids[i], tiles[i])
	var changed: int = 0
	for seed_value: int in 20:
		var trial: GameState = _state(seed_value)
		for i: int in 4:
			_place(trial, ids[i], tiles[i])
		SuperAugments.apply(SuperAugments.CASTLING, trial, 1)
		var after: Array[int] = []
		for id: int in ids:
			after.append(trial.get_pawn(id).current_tile_idx)
		var sorted_after: Array[int] = after.duplicate()
		sorted_after.sort()
		check_eq(sorted_after, tiles, "자리 집합은 그대로(말만 섞인다)")
		if after != tiles:
			changed += 1
	check(changed >= 15, "대부분의 시드에서 실제로 섞인다 (%d/20)" % changed)


func test_bakery_gives_cards_and_hotels_on_every_bakery_tile() -> void:
	var state: GameState = _state()
	var before: int = (state.hands[1] as Array).size()
	var result: Dictionary = SuperAugments.apply(SuperAugments.BAKERY, state, 1)
	check(bool(result["ok"]), "빵집 털이")
	check_eq((state.hands[1] as Array).size(), mini(before + 3, GameEnums.MAX_HAND_SIZE), "카드 3장")
	for tile: int in GameEnums.BAKERY_TILES:
		var has_hotel: bool = false
		for attachment: TileAttachment in state.board.get_tile(tile).attachments:
			if attachment.attachment_id == "HOTEL" and attachment.owner_id == 1:
				has_hotel = true
		check(has_hotel, "%d번 빵집에 내 호텔" % tile)
	SuperAugments.apply(SuperAugments.BAKERY, state, 1)
	check_eq(state.board.get_tile(GameEnums.BAKERY_TILES[0]).attachments.size(), 1, "호텔은 중복 설치되지 않는다")


func test_sniper_ejects_the_leading_enemy_boosts_mine_and_drops_a_cannon() -> void:
	var state: GameState = _state()
	_place(state, 11, 4)
	_place(state, 21, 20)
	_place(state, 31, 15)
	_place(state, 41, 6)
	var result: Dictionary = SuperAugments.apply(SuperAugments.SNIPER, state, 1)
	check(bool(result["ok"]), "저격")
	check_eq(state.get_pawn(21).current_tile_idx, 0, "선두 적 말은 출발선으로 사출")
	check(not state.get_pawn(21).has_left_start and state.get_pawn(21).revenge_boost, "출발 대기 + 복수 부스터")
	check_eq(state.get_pawn(31).current_tile_idx, 15, "2위는 그대로")
	check_eq(state.get_pawn(41).current_tile_idx, 6, "3위는 그대로")
	check_eq(state.get_pawn(11).current_tile_idx, 8, "내 선두 말은 +4칸 전진 (4 -> 8)")
	var cannon: bool = false
	for attachment: TileAttachment in state.board.get_tile(20).attachments:
		cannon = cannon or (attachment.attachment_id == "TRP_05" and attachment.owner_id == 1)
	check(cannon, "사출된 자리에 스프링 대포")


func test_dictator_replaces_the_rulebook_and_advances_a_pawn() -> void:
	var state: GameState = _state()
	state.rulebook.enqueue_law(LawRegistry.create("LAW_04"))
	state.rulebook.enqueue_law(LawRegistry.create("LAW_06"))
	var pawn: PlayerPawn = _place(state, 11, 5)
	var distance_before: int = state.pawn_progress_distance(pawn)
	var result: Dictionary = SuperAugments.apply(SuperAugments.DICTATOR, state, 1)
	check(bool(result["ok"]), "독재자")
	check_eq(state.rulebook.law_ids().size(), 2, "새 교칙 2개만 남는다")
	check(not state.rulebook.has_law("LAW_04") and not state.rulebook.has_law("LAW_06"), "옛 교칙은 전부 밀려났다")
	check(state.pawn_progress_distance(pawn) <= distance_before - 4, "내 말 +4칸 이상 전진 (점프 코너 등 보드 규칙이 그대로 적용된다: %d -> %d)" % [distance_before, state.pawn_progress_distance(pawn)])


func test_super_category_appears_at_most_once_per_draft_and_not_every_time() -> void:
	var state: GameState = _state()
	for pawn_id: int in [11, 12]:
		_place(state, pawn_id, 8 + pawn_id % 10)
	_place(state, 21, 14)
	var drafts_with_super: int = 0
	for i: int in 200:
		var offers: Array[StringName] = AugmentRegistry.generate_offers(state, 1)
		var supers: int = 0
		for offer: StringName in offers:
			if AugmentRegistry.get_def(offer).category == GameEnums.AugmentCategory.SUPER_GAMBLE:
				supers += 1
		check(supers <= 1, "한 번의 드래프트에 초증강은 최대 1장")
		if supers == 1:
			drafts_with_super += 1
	check(drafts_with_super > 20 and drafts_with_super < 160, "초증강은 가끔만 나온다 (%d/200)" % drafts_with_super)


# --- 턴 매니저 연동 --------------------------------------------------------------

func _manager() -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	manager.start_game([1, 2] as Array[int], 4242, {})
	return manager


func _dispose(manager: TurnManager) -> void:
	tree.root.remove_child(manager)
	manager.free()


func _roll(manager: TurnManager, player: int, face: int) -> void:
	manager.state.tools[player] = ScriptedTool.new([face])
	manager.act(&"proceed", {"player_id": player})
	manager.act(&"roll", {"player_id": player})


func test_devil_bonus_adds_to_every_roll_forever() -> void:
	var manager: TurnManager = _manager()
	var player: int = manager.current_player_id()
	manager.state.permanent_roll_bonus[player] = 3
	_roll(manager, player, 2)
	check_eq(manager.move_queue, [5] as Array[int], "눈금 2 + 영구 3 = 5")
	_dispose(manager)


func test_gambler_doubles_the_move_during_its_round() -> void:
	var manager: TurnManager = _manager()
	var player: int = manager.current_player_id()
	manager.state.gambler_round[player] = manager.state.round_number
	_roll(manager, player, 4)
	check_eq(manager.move_queue, [8] as Array[int], "눈금 4가 x2 = 8")
	_dispose(manager)


func test_gambler_applies_after_other_bonuses_and_only_in_its_round() -> void:
	var manager: TurnManager = _manager()
	var player: int = manager.current_player_id()
	manager.state.gambler_round[player] = manager.state.round_number
	manager.state.permanent_roll_bonus[player] = 3
	_roll(manager, player, 3)
	check_eq(manager.move_queue, [12] as Array[int], "(3 + 영구 3) x 2 = 12")
	_dispose(manager)
	var other: TurnManager = _manager()
	var p2: int = other.current_player_id()
	other.state.gambler_round[p2] = other.state.round_number - 1
	_roll(other, p2, 4)
	check_eq(other.move_queue, [4] as Array[int], "지난 라운드의 도박사는 이번 라운드에 효력이 없다")
	_dispose(other)


func test_gambler_overheat_ejects_the_moved_pawn_after_a_doubled_move() -> void:
	var manager: TurnManager = _manager()
	var player: int = manager.current_player_id()
	manager.state.gambler_round[player] = manager.state.round_number
	var pawn_a: PlayerPawn = manager.state.get_pawn(player * 10 + 1)
	var pawn_b: PlayerPawn = manager.state.get_pawn(player * 10 + 2)
	for pawn: PlayerPawn in [pawn_a, pawn_b]:
		pawn.has_left_start = true
	pawn_a.current_tile_idx = 10
	pawn_a.step_history.assign([8, 9, 10])
	pawn_b.current_tile_idx = 6
	pawn_b.step_history.assign([3, 4, 5, 6])
	var events: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"gambler_busted":
			events.append(data))
	_roll(manager, player, 1)
	check_eq(manager.move_queue, [2] as Array[int], "눈금 1도 x2로 이동은 한다")
	manager.act(&"select_pawn", {"player_id": player, "pawn_id": pawn_a.entity_id})
	check_eq(events.size(), 1, "과열 이벤트")
	check(not pawn_a.has_left_start and pawn_a.current_tile_idx == 0 and pawn_a.revenge_boost, "이동한 말이 출발선으로 사출 + 복수 부스터")
	check_eq(pawn_b.current_tile_idx, 6, "다른 말은 그대로")
	_dispose(manager)


func test_rest_next_turn_skips_exactly_one_turn() -> void:
	var manager: TurnManager = _manager()
	var first: int = manager.current_player_id()
	var second: int = 2 if first == 1 else 1
	manager.state.rest_next_turn[first] = true
	var events: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"turn_rested":
			events.append(int(data["player_id"])))
	# 첫 사람의 턴을 끝내면 한 바퀴 돌아 다시 첫 사람 차례가 올 때 쉰다
	manager.force_timeout()
	var guard: int = 0
	while events.is_empty() and guard < 400 and not manager.is_game_over:
		guard += 1
		manager.force_timeout()
	check_eq(events, [first], "쉬어야 하는 사람의 차례가 건너뛰어졌다")
	check(not bool(manager.state.rest_next_turn.get(first, false)), "휴식은 한 번만")
	_dispose(manager)
