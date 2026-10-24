# File: res://tests/test_super_augments.gd
# Class: class_name TestSuperAugments
# Role: [초증강 : 하이리스크 하이리턴] 12종의 조건·효과·드래프트 등장·턴 매니저 연동(영구 가속, 도박사 2배/과열 즉시 턴 종료, 휴식)을 검사한다
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


func test_twelve_super_augments_are_registered_with_names_and_descriptions() -> void:
	check_eq(SuperAugments.ALL_IDS.size(), 12, "초증강 12종")
	var state: GameState = _state()
	for effect: StringName in SuperAugments.ALL_IDS:
		var def: AugmentDef = _def(effect)
		check(def != null and def.category == GameEnums.AugmentCategory.SUPER_GAMBLE, "%s 등록" % effect)
		check(def.display_name.begins_with("[초증강] "), "%s 이름 표기" % effect)
		check(def.describe(state, 1).begins_with("◆"), "%s 설명" % effect)
	check_eq(AugmentDef.category_name(GameEnums.AugmentCategory.SUPER_GAMBLE), "초증강 : 하이리스크 하이리턴", "카테고리 이름")
	check_eq(SuperAugments.display_name(SuperAugments.FLIP), "[초증강] 판 뒤집기 (모 아니면 도)", "1번 이름")
	check_eq(SuperAugments.display_name(SuperAugments.REDISTRIBUTE), "[초증강] 공산주의 재분배", "2번 이름")
	check_eq(SuperAugments.display_name(SuperAugments.NITRO), "[초증강] 아우토반 니트로", "10번 이름")

func test_availability_depends_on_the_board() -> void:
	var state: GameState = _state()
	check(not SuperAugments.is_available(SuperAugments.FLIP, state, 1), "보드에 내 말이 없으면 판 뒤집기 불가")
	check(not SuperAugments.is_available(SuperAugments.DEVIL, state, 1), "완주한 말이 없으면 악마의 계약 불가")
	check(not SuperAugments.is_available(SuperAugments.SNIPER, state, 1), "적 말이 없으면 저격 불가")
	check(not SuperAugments.is_available(SuperAugments.CASTLING, state, 1), "말이 둘 미만이면 캐슬링 불가")
	check(SuperAugments.is_available(SuperAugments.GAMBLER, state, 1) and SuperAugments.is_available(SuperAugments.BAKERY, state, 1) and SuperAugments.is_available(SuperAugments.MINEFIELD, state, 1) and SuperAugments.is_available(SuperAugments.RAID, state, 1) and SuperAugments.is_available(SuperAugments.REDISTRIBUTE, state, 1), "언제든 되는 초증강")
	_place(state, 11, 8)
	_place(state, 21, 14)
	state.get_pawn(12).is_finished = true
	check(SuperAugments.is_available(SuperAugments.FLIP, state, 1) and SuperAugments.is_available(SuperAugments.DEVIL, state, 1) and SuperAugments.is_available(SuperAugments.SNIPER, state, 1) and SuperAugments.is_available(SuperAugments.CASTLING, state, 1), "말이 나오면 가능")


func test_flip_is_all_or_nothing_across_seeds() -> void:
	var finished: int = 0
	var expelled: int = 0
	for seed_value: int in 80:
		var state: GameState = _state(seed_value)
		var pawn: PlayerPawn = _place(state, 11, 10)
		var result: Dictionary = SuperAugments.apply(SuperAugments.FLIP, state, 1)
		check(bool(result["ok"]), "판 뒤집기 적용")
		check(not bool(state.rest_next_turn.get(1, false)), "휴식 벌칙은 없다")
		if pawn.is_finished:
			finished += 1
		else:
			expelled += 1
			check(not pawn.has_left_start and pawn.current_tile_idx == GameEnums.GOAL_TILE, "실패하면 출발선 추방")
	check(finished > 10 and expelled > 10, "50% 안팎으로 갈린다 (완주 %d / 추방 %d)" % [finished, expelled])


func test_redistribute_copies_the_last_place_layout_and_redeals_hands() -> void:
	var state: GameState = _state()
	_place(state, 11, 20)
	state.get_pawn(12).is_finished = true  # P1: 완주 1 + 20번
	_place(state, 21, 14)
	_place(state, 22, 9)
	_place(state, 31, 5)   # P3: 5번 하나 (꼴찌)
	_place(state, 41, 12)
	state.hands[1] = [&"ACT_04", &"ACT_04", &"ACT_04"] as Array[StringName]
	state.hands[2] = [&"ACT_02"] as Array[StringName]
	var result: Dictionary = SuperAugments.apply(SuperAugments.REDISTRIBUTE, state, 2)
	check(bool(result["ok"]), "재분배 적용")
	for owner: int in [1, 2, 4]:
		var tiles: Array[int] = []
		var finished: int = 0
		for pawn: PlayerPawn in state.pawns_of(owner):
			tiles.append(pawn.current_tile_idx)
			finished += 1 if pawn.is_finished else 0
		tiles.sort()
		check_eq(tiles, int_array([0, 0, 0, 5]), "P%d의 말 배치가 꼴찌(P3)와 같다" % owner)
		check_eq(finished, 0, "P%d의 완주도 꼴찌와 같다 (0개)" % owner)
	for owner: int in [1, 2, 3, 4]:
		check_eq((state.hands[owner] as Array).size(), SuperAugments.redistribute_cards(), "P%d 손패 2장" % owner)


func test_devil_returns_a_finished_pawn_for_a_permanent_bonus() -> void:
	var state: GameState = _state()
	var finished: PlayerPawn = state.get_pawn(12)
	finished.is_finished = true
	finished.has_left_start = true
	var result: Dictionary = SuperAugments.apply(SuperAugments.DEVIL, state, 1)
	check(bool(result["ok"]), "악마의 계약")
	check(not finished.is_finished and not finished.has_left_start and finished.current_tile_idx == GameEnums.GOAL_TILE, "완주 말이 출발선으로 돌아왔다")
	check_eq(int(state.permanent_roll_bonus[1]), 3, "영구 +3")
	check(not SuperAugments.is_available(SuperAugments.DEVIL, state, 1), "더 이상 완주 말이 없다")


func test_minefield_places_mines_on_empty_normal_tiles_and_gives_a_trap_card() -> void:
	var state: GameState = _state(5)
	var placed: Array[int] = []
	state.attachment_placed.connect(func(tile: int, id: String, owner: int) -> void:
		placed.append(tile)
		check(owner == 1 and id == "TRP_03", "지뢰, 설치자는 나"))
	var result: Dictionary = SuperAugments.apply(SuperAugments.MINEFIELD, state, 1)
	check(bool(result["ok"]), "지뢰밭")
	check_eq(placed.size(), 2, "2곳에 매설")
	for tile: int in placed:
		check(not BoardSpec.corner_tiles.has(tile) and not BoardSpec.bakery_tiles.has(tile) and not BoardSpec.portal_tiles.has(tile) and not BoardSpec.dash_tiles.has(tile), "%d번은 일반 타일" % tile)
	check_eq((state.hands[1] as Array).size(), 1, "함정 카드 1장")
	var card: BaseCard = CardRegistry.get_card((state.hands[1] as Array)[0])
	check(card.category == GameEnums.CardCategory.TRAP and not card.corner_only, "일반 함정 카드")


func test_raid_gives_a_summon_card_and_steals_one_card_from_each_other_player() -> void:
	var state: GameState = _state()
	for victim: int in [2, 3, 4]:
		state.give_card(victim, &"TRP_01")
		state.give_card(victim, &"TRP_02")
	var result: Dictionary = SuperAugments.apply(SuperAugments.RAID, state, 1)
	check(bool(result["ok"]), "대습격")
	var hand: Array = state.hands[1]
	check_eq(hand.size(), 1 + 3, "소환 카드 1장 + 세 명에게서 1장씩")
	check_eq(CardRegistry.get_card(hand[0]).category, GameEnums.CardCategory.SUMMON, "첫 장은 중립 기물 카드")
	for victim: int in [2, 3, 4]:
		check_eq((state.hands[victim] as Array).size(), 1, "%d번 플레이어는 1장을 빼앗겼다" % victim)
	check(state.npcs.is_empty(), "기물을 바로 풀지는 않는다")


func test_runaway_train_clears_one_whole_side_of_pawns_and_traps() -> void:
	var state: GameState = _state(3)
	for tile: int in BoardSpec.tile_count:
		if tile % 2 == 1:
			state.place_attachment(tile, TrapMine.new(2))
	_place(state, 11, 3)
	_place(state, 21, BoardSpec.side + 3)
	_place(state, 31, 2 * BoardSpec.side + 3)
	_place(state, 41, 3 * BoardSpec.side + 3)
	var result: Dictionary = SuperAugments.apply(SuperAugments.RUNAWAY, state, 1)
	check(bool(result["ok"]), "폭주 기관차")
	var cleared_sides: int = 0
	for side_index: int in 4:
		var pawn: PlayerPawn = state.get_pawn([11, 21, 31, 41][side_index])
		var side_cleared: bool = not pawn.has_left_start
		var traps_left: int = 0
		for step: int in range(1, BoardSpec.side + 1):
			var tile: int = posmod(side_index * BoardSpec.side + step, BoardSpec.tile_count)
			traps_left += state.board.get_tile(tile).attachments.size()
		if side_cleared:
			cleared_sides += 1
			check_eq(traps_left, 0, "기관차가 지난 변의 함정은 모두 파괴")
		else:
			check(traps_left > 0, "다른 변의 함정은 그대로")
	check_eq(cleared_sides, 1, "정확히 한 변만 쓸었다 (내 말도 예외 없음)")


func test_sweep_snapshot_precedes_clearing_without_changing_rng_or_route() -> void:
	var state := _state(17)
	_place(state,11,10)
	state.place_attachment(11,TrapMine.new(2))
	var snapshots: Array = []
	state.npc_sweep_started.connect(func(id: StringName,route: Array[int]) -> void:
		snapshots.append({"id":id,"route":route.duplicate(),"pawn_present":state.get_pawn(11).has_left_start,"traps_present":state.board.get_tile(11).attachments.size()}))
	var rng_before := state.rng.state
	var result := NpcSweep.run(state,8,1,8,&"TRAIN",1,true)
	check_eq(snapshots.size(),1,"One presentation snapshot per sweep")
	check(snapshots[0].pawn_present and snapshots[0].traps_present==1,"Snapshot observes victims and traps before clearing")
	check_eq(snapshots[0].route,result.path,"Snapshot and authoritative route match")
	check_eq(state.rng.state,rng_before,"Presentation snapshot consumes no gameplay RNG")
	check(not state.get_pawn(11).has_left_start and state.board.get_tile(11).attachments.is_empty(),"Sweep still applies immediately in the engine")


func test_joint_responsibility_bonds_my_front_and_rear_pawns() -> void:
	var state: GameState = _state()
	check(not SuperAugments.is_available(SuperAugments.GUARANTEE, state, 1), "보드에 말이 둘 이상 있어야 한다")
	_place(state, 11, 4)
	_place(state, 12, 9)
	_place(state, 13, 15)
	check(SuperAugments.is_available(SuperAugments.GUARANTEE, state, 1), "선택 가능")
	check(bool(SuperAugments.apply(SuperAugments.GUARANTEE, state, 1)["ok"]), "연대책임")
	check_eq(int(state.bonds.get(13, -1)), 11, "선두(13)와 후방(11)이 묶인다")
	check(not state.bonds.has(12), "가운데 말은 그대로")
	var restored: GameState = _state()
	TurnSnapshot.from_dict(TurnSnapshot.capture(state).to_dict()).restore(restored)
	check_eq(int(restored.bonds.get(11, -1)), 13, "스냅샷으로 복원된다")
	# 하나가 골인하면 둘 다 골인
	state.finish_stack(state.get_pawn(13))
	check(state.get_pawn(11).is_finished, "후방 말도 함께 골인")
	check(not state.get_pawn(12).is_finished, "묶이지 않은 말은 그대로")
	check(state.bonds.is_empty(), "결과가 나면 묶음은 풀린다")


func test_joint_responsibility_ejects_both_pawns_together() -> void:
	var state: GameState = _state()
	_place(state, 11, 4)
	_place(state, 13, 15)
	SuperAugments.apply(SuperAugments.GUARANTEE, state, 1)
	state.send_to_start(state.get_pawn(11), 2)
	check(not state.get_pawn(11).has_left_start and not state.get_pawn(13).has_left_start, "하나가 탈락하면 둘 다 탈락")
	check(state.bonds.is_empty(), "묶음 해제")


func test_bakery_gives_cards_and_launches_a_waiting_pawn_to_the_first_bakery() -> void:
	var state: GameState = _state()
	var result: Dictionary = SuperAugments.apply(SuperAugments.BAKERY, state, 1)
	check(bool(result["ok"]), "빵집 털이")
	check_eq((state.hands[1] as Array).size(), 3 + 1, "카드 3장 + 빵집 도착 카드 1장")
	var launched: PlayerPawn = state.get_pawn(11)
	check(launched.has_left_start and launched.current_tile_idx == BoardSpec.bakery_tiles[0], "대기 말이 첫 빵집으로 출격")


func test_sniper_ejects_the_leading_enemy_and_boosts_mine() -> void:
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
	check_eq(state.get_pawn(11).current_tile_idx, 8, "내 선두 말은 +4칸 전진 (4 -> 8)")
	check(state.board.get_tile(20).attachments.is_empty(), "스프링 대포는 더 이상 깔지 않는다")


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

func test_nitro_dashes_the_front_pawn_to_the_next_corner() -> void:
	var state: GameState = _state()
	check(not SuperAugments.is_available(SuperAugments.NITRO, state, 1), "보드 위에 내 말이 없으면 고를 수 없다")
	var front: PlayerPawn = _place(state, 11, 3)
	_place(state, 12, 1)  # 뒤에 있는 내 말은 그대로
	check(SuperAugments.is_available(SuperAugments.NITRO, state, 1), "보드 위에 말이 있으면 고를 수 있다")
	var dashes: Array = []
	state.nitro_dashed.connect(func(pawn_id: int, path: Array[int], blocked: int) -> void: dashes.append([pawn_id, path, blocked]))
	var result: Dictionary = SuperAugments.apply(SuperAugments.NITRO, state, 1)
	check(bool(result["ok"]), "적용")
	check_eq(front.current_tile_idx, BoardSpec.side, "선두 말이 다음 코너(%d번)까지 직진" % BoardSpec.side)
	check_eq(state.get_pawn(12).current_tile_idx, 1, "다른 말은 그대로")
	check_eq(dashes.size(), 1, "질주 연출 신호")
	check_eq(dashes[0][2], -1, "막힘 없음")
	check(not state.rulebook.has_personal("SUPER_10", 1), "더 이상 영구 패시브가 아니다")


func test_nitro_stops_at_the_first_pawn_and_ejects_everyone_there() -> void:
	var state: GameState = _state()
	var front: PlayerPawn = _place(state, 11, 2)
	var enemy: PlayerPawn = _place(state, 21, 5)
	var other: PlayerPawn = _place(state, 41, 5)  # 같은 칸의 다른 사람 말도 함께 날아간다
	var beyond: PlayerPawn = _place(state, 31, 6)
	SuperAugments.apply(SuperAugments.NITRO, state, 1)
	check_eq(front.current_tile_idx, 5, "말이 서 있는 첫 칸에서 멈춘다")
	check(not enemy.has_left_start and not other.has_left_start, "그 칸의 말은 모두 출발선으로")
	check(beyond.has_left_start and beyond.current_tile_idx == 6, "그 뒤의 말은 무사")


func test_nitro_on_the_last_side_crosses_the_finish_line() -> void:
	var state: GameState = _state()
	var front: PlayerPawn = _place(state, 11, BoardSpec.tile_count - 3)
	SuperAugments.apply(SuperAugments.NITRO, state, 1)
	check(front.is_finished, "다음 코너가 결승선이면 완주한다")

func test_super_category_appears_at_most_once_per_draft_and_not_every_time() -> void:
	var state: GameState = _state()
	for pawn_id: int in [11, 12]:
		_place(state, pawn_id, 8 + pawn_id % 10)
	_place(state, 21, 14)
	state.round_number = 7  # 초증강은 7라운드(세 번째 드래프트)부터
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


func test_gambler_overheat_ends_the_turn_at_once_without_moving() -> void:
	var manager: TurnManager = _manager()
	var player: int = manager.current_player_id()
	manager.state.gambler_round[player] = manager.state.round_number
	var pawn_a: PlayerPawn = manager.state.get_pawn(player * 10 + 1)
	pawn_a.has_left_start = true
	pawn_a.current_tile_idx = 10
	pawn_a.step_history.assign([8, 9, 10])
	var events: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"gambler_busted":
			events.append(data))
	_roll(manager, player, 1)
	check_eq(events.size(), 1, "과열 이벤트")
	check(manager.move_queue.is_empty(), "이동하지 않는다 (0칸)")
	check(manager.current_player_id() != player, "차례가 바로 다음 사람으로 넘어간다")
	check(pawn_a.has_left_start and pawn_a.current_tile_idx == 10, "말은 사출되지 않고 그 자리에 있다")
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
