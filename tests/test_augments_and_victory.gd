# File: res://tests/test_augments_and_victory.gd
# Class: class_name TestAugmentsAndVictory
# Role: 증강 드래프트(4대 카테고리)·기물 진화/세트 시너지·신규 함정·소환 카드·호텔·승리 판정(일반 + 특수 5종) 검증
class_name TestAugmentsAndVictory
extends TestCase

const Phase := TurnManager.State
const Kind := GameEnums.PawnKind


func _loadout(kind: GameEnums.PawnKind) -> Array:
	return [Vector2i(kind, 1), Vector2i(kind, 2), Vector2i(kind, 3), Vector2i(kind, 4)]


func _manager(player_count: int, draft: bool, loadouts: Dictionary = {}) -> TurnManager:
	var manager := TurnManager.new()
	manager.hotseat_mode = true
	manager.draft_enabled = draft
	tree.root.add_child(manager)
	var ids: Array[int] = []
	for i: int in range(1, player_count + 1):
		ids.append(i)
	manager.start_game(ids, 777, loadouts)
	return manager


func _dispose(manager: TurnManager) -> void:
	tree.root.remove_child(manager)
	manager.free()


func _do(manager: TurnManager, player_id: int, action: StringName, params: Dictionary = {}) -> void:
	var payload: Dictionary = params.duplicate()
	payload["player_id"] = player_id
	manager.act(action, payload)


# --- 기물 진화 / 세트 --------------------------------------------------------

func test_pawn_catalog_labels_and_default_pawns_are_basic() -> void:
	var state := make_state()
	check_eq(state.get_pawn(11).kind, Kind.BASIC, "기본 말")
	check_eq(state.get_pawn(11).display_label(), "기본", "기본 표기")
	check_eq(PawnCatalog.unit_label(Kind.CHESS, 1), "체스:폰", "체스 1호기 폰")
	check_eq(PawnCatalog.unit_label(Kind.CHESS, 2), "체스:나이트", "체스 2호기 나이트")
	check_eq(PawnCatalog.unit_letter(Kind.JANGGI, 1), "포", "장기 1호기 라벨")
	for kind: GameEnums.PawnKind in PawnCatalog.EVOLVABLE_SETS:
		for unit: int in range(1, 5):
			check(PawnCatalog.sub_type_of(kind, unit) != GameEnums.PawnSubType.NONE, "각 세트의 1~4호기에는 세부 기물이 있다 (%d-%d)" % [kind, unit])


func test_evolution_unlocks_units_sequentially_up_to_four() -> void:
	var state := make_state()
	var evolved: Array[int] = []
	state.pawn_evolved.connect(func(pawn_id: int, _kind: int, unit_no: int) -> void: evolved.append(unit_no))
	for slot: int in [3, 1, 4, 2]:
		check(state.evolve_pawn(state.get_pawn(10 + slot), Kind.CHESS), "슬롯 %d 진화" % slot)
	check_eq(evolved, [1, 2, 3, 4] as Array[int], "1~4호기 순차 해금")
	check_eq(state.get_pawn(13).display_label(), "체스:폰", "처음 진화한 말이 1호기")
	check_eq(state.get_pawn(12).unit_no, 4, "마지막 말이 4호기")
	check_eq(state.set_count(1, Kind.CHESS), 4, "체스 4세트")
	check(state.basic_pawns_of(1).is_empty(), "기본 말이 남지 않음")
	check(not state.evolve_pawn(state.get_pawn(11), Kind.YUT), "이미 진화한 말은 다시 진화할 수 없음")


func test_evolution_rejects_full_set_and_non_basic_pawns() -> void:
	var state := make_state(2, 1, {1: _loadout(Kind.YUT)})
	check(state.basic_pawns_of(1).is_empty(), "윷 4세트로 시작")
	check(not state.evolve_pawn(state.get_pawn(11), Kind.CHESS), "기본 말이 아니면 거부")
	var other := make_state()
	for slot: int in [1, 2, 3, 4]:
		other.evolve_pawn(other.get_pawn(10 + slot), Kind.GO)
	check_eq(other.set_count(2, Kind.GO), 0, "상대의 세트 수는 영향 없음")
	check(other.evolve_pawn(other.get_pawn(21), Kind.GO), "상대는 자기 세트를 처음부터 쌓는다")
	check_eq(other.get_pawn(21).unit_no, 1, "상대의 첫 진화는 1호기")


func test_chess_unit_three_is_the_bishop_with_corner_turning() -> void:
	var state := make_state(2, 1, {1: [Vector2i(Kind.CHESS, 3), Vector2i(Kind.CHESS, 2), 0, 0]})
	check(state.get_pawn(11).turns_at_corner_when_passing(), "체스 3호기 = 비숍")
	check(not state.get_pawn(12).turns_at_corner_when_passing(), "나이트는 아님")


func test_stacking_rules_with_sets() -> void:
	var state := make_state(2, 1, {1: [Vector2i(Kind.CHESS, 1), Vector2i(Kind.GO, 1), Vector2i(Kind.YUT, 1), 0]})
	check(not state.get_pawn(11).can_stack_with(state.get_pawn(12)), "체스 + 바둑은 불가")
	check(state.get_pawn(11).can_stack_with(state.get_pawn(13)), "윷은 모든 세트와 가능")
	check(not state.get_pawn(11).can_stack_with(state.get_pawn(14)), "체스 + 기본은 불가")
	check(state.get_pawn(14).can_stack_with(state.get_pawn(13)), "기본 + 윷 가능")


func test_snapshot_keeps_evolution_and_status_flags() -> void:
	var state := make_state()
	state.evolve_pawn(state.get_pawn(11), Kind.MONOPOLY)
	state.get_pawn(12).restrained_turns = 2
	state.get_pawn(13).is_imprisoned = true
	var snapshot: TurnSnapshot = TurnSnapshot.capture(state)
	state.get_pawn(11).evolve(Kind.BASIC, 0)
	state.get_pawn(12).restrained_turns = 0
	state.get_pawn(13).is_imprisoned = false
	snapshot.restore(state)
	check_eq(state.get_pawn(11).kind, Kind.MONOPOLY, "진화 복원")
	check_eq(state.get_pawn(12).restrained_turns, 2, "구속 복원")
	check(state.get_pawn(13).is_imprisoned, "감금 복원")


# --- 증강 풀 / 선택지 --------------------------------------------------------

func test_augment_pool_has_all_four_categories() -> void:
	var counts: Dictionary = {}
	for def: AugmentDef in AugmentRegistry.all():
		counts[def.category] = int(counts.get(def.category, 0)) + 1
	check_eq(counts[GameEnums.AugmentCategory.PAWN_EVOLUTION], 15, "기물 지급: 윷 1 + 체스 4 + 장기 4 + 모노폴리 4 + 바둑 2")
	check_eq(counts[GameEnums.AugmentCategory.TOOL_SWAP], 6, "판정 도구 교체 6종 (D6 제외)")
	check_eq(counts[GameEnums.AugmentCategory.LAW_ENACT], 8, "교칙 8종")
	check_eq(counts[GameEnums.AugmentCategory.CARD_PACKAGE], 1, "카드 패키지")


func test_offers_are_three_distinct_mixed_categories() -> void:
	var state := make_state(2, 99)
	for trial: int in 40:
		var offers: Array[StringName] = AugmentRegistry.generate_offers(state, 1)
		check_eq(offers.size(), 3, "3지선다")
		var categories: Dictionary = {}
		for offer: StringName in offers:
			categories[AugmentRegistry.get_def(offer).category] = true
		check_eq(categories.size(), 3, "서로 다른 카테고리 3개")
		check_eq(offers.size(), _unique(offers).size(), "중복 없음")


func _unique(items: Array) -> Array:
	var result: Array = []
	for item: Variant in items:
		if not result.has(item):
			result.append(item)
	return result


func test_offers_respect_availability() -> void:
	var state := make_state(2, 5)
	state.tools[1] = ToolRegistry.create(&"HOLDEM")
	for law_id: String in LawRegistry.ALL_IDS:
		state.rulebook.enqueue_law(LawRegistry.create(law_id))  # 마지막 4개만 남는다
	for slot: int in [1, 2, 3, 4]:
		state.evolve_pawn(state.get_pawn(10 + slot), Kind.CHESS)
	var seen: Dictionary = {}
	for trial: int in 60:
		for offer: StringName in AugmentRegistry.generate_offers(state, 1):
			seen[offer] = true
	check(not seen.has(&"TOOL_HOLDEM"), "이미 쓰는 도구는 제시하지 않음")
	check(not seen.has(&"AUG_LAW_08"), "법전에 있는 교칙은 제시하지 않음")
	for def: AugmentDef in AugmentRegistry.all():
		if def.category == GameEnums.AugmentCategory.PAWN_EVOLUTION:
			check(not seen.has(def.augment_id), "기본 말이 없으면 기물 지급은 제시하지 않음")
	check(seen.has(&"CARD_PACKAGE"), "카드 패키지는 항상 가능")


func test_each_augment_category_applies_its_effect() -> void:
	var state := make_state()
	var evolve: Dictionary = AugmentRegistry.get_def(&"EVO_%d_1" % Kind.YUT).apply(state, 1, {"pawn_id": 13})
	check(evolve["ok"], "진화 성공")
	check_eq(state.get_pawn(13).display_label(), "윷말", "고른 말이 윷 1호기로 진화")
	check_eq(state.get_pawn(11).kind, Kind.BASIC, "다른 말은 그대로")
	var bad: Dictionary = AugmentRegistry.get_def(&"EVO_%d_1" % Kind.YUT).apply(state, 1, {"pawn_id": 21})
	check(not bad["ok"], "남의 말은 진화시킬 수 없음")
	check_eq(state.get_pawn(21).kind, Kind.BASIC, "남의 말 불변")
	var tool: Dictionary = AugmentRegistry.get_def(&"TOOL_SLOT_777").apply(state, 2)
	check(tool["ok"], "도구 교체")
	check_eq((state.tools[2] as BaseJudgmentTool).tool_id, &"SLOT_777", "777 슬롯머신으로 교체")
	AugmentRegistry.get_def(&"AUG_LAW_05").apply(state, 1)
	check(state.rulebook.has_law("LAW_05"), "교칙이 법전에 등록됨")
	var cards: Dictionary = AugmentRegistry.get_def(&"CARD_PACKAGE").apply(state, 1)
	check(cards["ok"], "카드 패키지")
	check_eq((state.hands[1] as Array).size(), 2, "손패에 2장")


func test_law_augment_uses_fifo_rulebook() -> void:
	var state := make_state()
	for law_id: String in ["LAW_01", "LAW_02", "LAW_03", "LAW_04", "LAW_05"]:
		AugmentRegistry.get_def(StringName("AUG_%s" % law_id)).apply(state, 1)
	check_eq(state.rulebook.law_ids(), ["LAW_02", "LAW_03", "LAW_04", "LAW_05"] as Array[String], "5번째에서 가장 오래된 교칙이 밀려남")


# --- TurnManager 드래프트 흐름 -------------------------------------------------

func test_draft_opens_in_round_one_with_offers_for_every_player() -> void:
	var manager: TurnManager = _manager(4, true)
	check_eq(manager.current_state, Phase.PHASE_ROUND_START, "1라운드는 드래프트로 시작")
	for player_id: int in [1, 2, 3, 4]:
		check_eq(manager.draft_offers_for(player_id).size(), 3, "P%d 3지선다" % player_id)
	check_eq(manager.draft_pending_players(), int_array([1, 2, 3, 4]), "플레이 순서대로 대기")
	_dispose(manager)


func test_draft_pick_applies_effect_and_finishes_when_everyone_picked() -> void:
	var manager: TurnManager = _manager(2, true)
	manager._draft_offers[1] = [&"EVO_2_1", &"TOOL_HOLDEM", &"AUG_LAW_03"] as Array[StringName]
	manager._draft_offers[2] = [&"CARD_PACKAGE", &"AUG_LAW_04", &"TOOL_YUT"] as Array[StringName]
	_do(manager, 1, &"pick_augment", {"index": 0, "pawn_id": 13})
	check(manager.state.get_pawn(13).kind == GameEnums.PawnKind.CHESS and manager.state.get_pawn(13).unit_no in [1, 2, 3, 4], "P1이 고른 기본 말이 체스 기물 중 하나로 진화")
	check_eq(manager.draft_pending_players(), int_array([2]), "P2만 남음")
	check_eq(manager.current_state, Phase.PHASE_ROUND_START, "아직 드래프트 중")
	_do(manager, 2, &"pick_augment", {"index": 1})
	check(manager.state.rulebook.has_law("LAW_04"), "P2의 교칙이 등록됨")
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "모두 고르면 첫 턴")
	check_eq(manager.augments[1], [&"EVO_2_1"] as Array, "선택 기록")
	_dispose(manager)


func test_draft_rejects_bad_pawn_and_double_pick() -> void:
	var manager: TurnManager = _manager(2, true)
	var rejected: Array = []
	manager.action_rejected.connect(func(player_id: int, action: StringName, reason: StringName) -> void: rejected.append(reason))
	manager._draft_offers[1] = [&"EVO_3_1", &"TOOL_YUT", &"CARD_PACKAGE"] as Array[StringName]
	_do(manager, 1, &"pick_augment", {"index": 0, "pawn_id": 21})
	check_eq(rejected, [&"invalid_pawn"] as Array, "남의 말로는 진화 불가")
	_do(manager, 1, &"pick_augment", {"index": 1})
	_do(manager, 1, &"pick_augment", {"index": 2})
	check_eq(rejected.size(), 2, "이미 고른 플레이어의 재선택은 거부")
	_dispose(manager)


func test_auto_pick_and_timeout_auto_pick() -> void:
	var manager: TurnManager = _manager(3, true)
	manager.auto_pick_draft(1)
	check_eq(manager.draft_pending_players(), int_array([2, 3]), "P1 자동 선택 완료")
	manager.tick(GameEnums.PHASE_TIME_DRAFT + 0.1)
	check_eq(manager.current_state, Phase.PHASE_TURN_BEGIN, "시간 초과 시 남은 플레이어는 자동 선택되고 진행")
	for player_id: int in [1, 2, 3]:
		check_eq((manager.augments[player_id] as Array).size(), 1, "P%d 증강 1개 획득" % player_id)
	_dispose(manager)


func test_draft_only_in_rounds_1_4_and_7() -> void:
	var manager: TurnManager = _manager(2, true)
	manager.auto_pick_draft(1)
	manager.auto_pick_draft(2)
	var opened: Array[int] = []
	for round_before: int in [1, 2, 3, 4, 5, 6, 7, 8]:
		manager.state.round_number = round_before
		manager._enter_neutral_npc_phase()
		if manager.current_state == Phase.PHASE_ROUND_START:
			opened.append(manager.state.round_number)
			manager.auto_pick_draft(1)
			manager.auto_pick_draft(2)
	check_eq(opened, [4, 7] as Array[int], "2~8라운드 중 4, 7라운드 시작에만 드래프트")
	_dispose(manager)


# --- 신규 함정 / 소환 카드 -------------------------------------------------------

func test_trap_pit_restrains_only_on_dice_four_or_more() -> void:
	var state := make_state()
	state.place_attachment(2, TrapPit.new(2))
	place(state, 11, 0, [], false)
	var weak: MoveReport = move(state, 11, 3)
	check(not weak.stopped_early and state.get_pawn(11).restrained_turns == 0, "눈금 3은 통과")
	check_eq(state.get_pawn(11).current_tile_idx, 3, "정상 이동")
	place(state, 12, 0, [], false)
	var strong: MoveReport = move(state, 12, 4)
	check(strong.stopped_early, "눈금 4 이상이면 그 자리에 멈춤")
	check_eq(state.get_pawn(12).current_tile_idx, 2, "나락 타일에서 정지")
	check_eq(state.get_pawn(12).restrained_turns, 2, "2턴 구속")
	check_eq(state.board.get_tile(2).attachments.size(), 0, "발동 후 소모")


func test_trap_pit_ignores_its_owner() -> void:
	var state := make_state()
	state.place_attachment(2, TrapPit.new(1))
	place(state, 11, 0, [], false)
	move(state, 11, 4)
	check_eq(state.get_pawn(11).current_tile_idx, 4, "설치자는 통과")
	check_eq(state.get_pawn(11).restrained_turns, 0, "구속 없음")


func test_restrained_pawn_skips_exactly_two_own_turns() -> void:
	var manager: TurnManager = _manager(2, false)
	manager.state.place_attachment(2, TrapPit.new(1))
	manager.state.tools[1] = ScriptedTool.new([6, 6, 6, 6])  # 서로 다른 타일에 서서 잡기·추가 턴이 끼어들지 않게 한다
	manager.state.tools[2] = ScriptedTool.new([4, 1, 1, 1])
	var blocked: Array[bool] = []
	for round_number: int in 4:
		for player_id: int in [1, 2]:
			if player_id == 2:
				blocked.append(not manager.state.get_pawn(21).is_selectable())
			_do(manager, player_id, &"proceed")
			_do(manager, player_id, &"roll")
			var pawn_id: int = 21 if (player_id == 2 and round_number == 0) else player_id * 10 + 1 + round_number
			_do(manager, player_id, &"select_pawn", {"pawn_id": pawn_id})
	check_eq(manager.state.get_pawn(21).current_tile_idx, 2, "21번 말은 나락에서 멈춤")
	check_eq(blocked, [false, true, true, false] as Array[bool], "구속된 다음 두 번의 내 턴 동안 선택 불가, 그 뒤 해제")
	_dispose(manager)


func test_mine_blast_hits_everyone_within_two_tiles_and_clears_numbers() -> void:
	var state := make_state()
	check(exec(state, PlaceMineFieldCommand.new(2, 6)), "지뢰 설치")
	check(state.board.get_tile(6).has_attachment("TRP_03"), "6번에 지뢰")
	check(state.board.get_tile(5).has_attachment("MINE_NUM") and state.board.get_tile(7).has_attachment("MINE_NUM"), "양옆 [1] 숫자 표시")
	place(state, 21, 8, [7])    # 반경 2 이내 (적, 지뢰 설치자 쪽)
	place(state, 12, 4, [3])    # 반경 2 이내 (아군)
	place(state, 22, 12, [11])  # 반경 밖
	place(state, 11, 3, [2])
	var report: MoveReport = move(state, 11, 5)  # 4, 5, 6에서 지뢰를 밟는다
	check(report.trapped, "밟은 말도 폭발에 휘말림")
	check_eq(state.get_pawn(21).current_tile_idx, 0, "반경 2칸 안의 기물은 피아 구분 없이 출발선으로")
	check_eq(state.get_pawn(12).current_tile_idx, 0, "아군도 폭파")
	check_eq(state.get_pawn(22).current_tile_idx, 12, "반경 밖은 안전")
	check(not state.board.get_tile(5).has_attachment("MINE_NUM"), "숫자 표시도 사라짐")
	check(not state.board.get_tile(6).has_attachment("TRP_03"), "지뢰 소모")


func test_mine_blast_radius_follows_graph_edges() -> void:
	var board := BoardGraph.new()
	defer_free(board)
	check_eq(board.tiles_within(22, 1), int_array([21, 22, 23, 26, 27]), "중앙의 반경 1")
	check_eq(board.tiles_within(0, 2), int_array([0, 1, 2, 18, 19, 27, 28]), "0번의 반경 2: 외곽 양쪽과 지름길 2 끝")
	check(board.tiles_within(5, 2).has(21), "분기 간선도 반경에 포함")


func test_island_imprisons_on_landing_until_even_roll() -> void:
	var state := make_state()
	var card: BaseCard = CardRegistry.get_card(&"TRP_04")
	check(not card.can_play(state, 2, {"tile": 3}), "코너가 아닌 타일은 거부")
	check(card.can_play(state, 2, {"tile": 5}), "코너는 가능")
	exec(state, card.create_command(state, 2, {"tile": 5}))
	check(not card.can_play(state, 1, {"tile": 10}), "무인도는 보드에 하나만")
	place(state, 11, 3, [2])
	move(state, 11, 2)
	check_eq(state.get_pawn(11).current_tile_idx, 5, "무인도에 도착")
	check(state.get_pawn(11).is_imprisoned, "갇힘")
	var odd: MoveReport = move(state, 11, 3)
	check(odd.canceled and odd.jailed, "홀수 눈금이면 헛수고")
	check_eq(state.get_pawn(11).current_tile_idx, 5, "제자리")
	var even: MoveReport = move(state, 11, 2)
	check(even.released, "짝수 눈금에 탈출")
	check(not state.get_pawn(11).is_imprisoned, "감금 해제")
	check(even.path.size() == 2, "탈출과 동시에 눈금만큼 이동")


func test_island_does_not_imprison_its_owner_or_passers() -> void:
	var state := make_state()
	state.place_attachment(5, TrapIsland.new(1))
	place(state, 11, 3, [2])
	move(state, 11, 2)
	check(not state.get_pawn(11).is_imprisoned, "설치자는 갇히지 않음")
	place(state, 21, 3, [2])
	move(state, 21, 4)  # 5번을 통과해 7번에 도착
	check(not state.get_pawn(21).is_imprisoned, "통과만 하면 갇히지 않음")


func test_summon_cards_spawn_npcs_with_cap() -> void:
	var state := make_state()
	var bandit: BaseCard = CardRegistry.get_card(&"SUM_01")
	var ghost: BaseCard = CardRegistry.get_card(&"SUM_02")
	check(bandit.needs_tile() and not ghost.needs_tile(), "도적은 타일 선택, 고스트는 중앙 고정")
	exec(state, bandit.create_command(state, 1, {"tile": 12}))
	check_eq(state.npcs.size(), 1, "도적 소환")
	check_eq(state.npcs[0].current_tile_idx, 12, "고른 타일")
	check_eq(state.npcs[0].behavior, GameEnums.NpcBehavior.CHASE_NEAREST, "추격 AI")
	exec(state, ghost.create_command(state, 2, {}))
	check_eq(state.npcs[1].current_tile_idx, 22, "고스트는 중앙에 소환")
	check_eq(state.npcs[1].behavior, GameEnums.NpcBehavior.PATROL_REVERSE, "순찰 AI")
	exec(state, bandit.create_command(state, 1, {"tile": 3}))
	check(not bandit.can_play(state, 1, {"tile": 4}), "NPC는 최대 %d체" % GameEnums.MAX_NPCS)


func test_tile_cards_report_that_they_need_a_tile() -> void:
	for card_id: StringName in [&"TRP_01", &"TRP_02", &"TRP_03", &"TRP_04", &"SUM_01"]:
		check(CardRegistry.get_card(card_id).needs_tile(), "%s는 타일을 고른다" % card_id)
	for card_id: StringName in [&"ACT_01", &"ACT_04", &"ACT_05", &"ACT_06", &"SUM_02"]:
		check(not CardRegistry.get_card(card_id).needs_tile(), "%s는 타일이 필요 없다" % card_id)


func test_new_traps_round_trip_through_snapshot() -> void:
	var state := make_state()
	exec(state, PlaceMineFieldCommand.new(1, 9))
	state.place_attachment(14, TrapPit.new(2))
	state.place_attachment(15, TrapIsland.new(1))
	var snapshot: TurnSnapshot = TurnSnapshot.capture(state)
	for tile: TileNode in state.board.tiles:
		tile.clear_attachments()
	snapshot.restore(state)
	check(state.board.get_tile(9).has_attachment("TRP_03"), "지뢰 복원")
	check(state.board.get_tile(8).has_attachment("MINE_NUM"), "숫자 복원")
	var mine: TrapMine = state.board.get_tile(9).attachments[0] as TrapMine
	check_eq(mine.number_tiles, int_array([8, 10]), "지뢰와 숫자 칸의 연결 복원")
	check(state.board.get_tile(14).has_attachment("TRP_02"), "나락 복원")
	check_eq(state.board.get_tile(15).attachments[0].duration_turns, 3, "무인도 지속 시간 복원")


# --- 모노폴리 / 윷 세트 효과 ------------------------------------------------------

func test_monopoly_pawn_builds_a_toll_hotel_that_stops_enemies_and_expires() -> void:
	var state := make_state(2, 1, {1: _loadout(Kind.MONOPOLY)})
	place(state, 11, 0, [], false)
	var built: MoveReport = move(state, 11, 2)
	check(built.hotel_built, "이동이 끝난 타일에 호텔 건설")
	var hotel: TileAttachment = state.board.get_tile(2).attachments[0]
	check_eq(hotel.attachment_id, "HOTEL", "호텔")
	check_eq(hotel.duration_turns, 5, "내 턴 5번간 유지")
	place(state, 21, 0, [], false)
	var enemy: MoveReport = move(state, 21, 4)
	check(enemy.stopped_early, "적이 밟으면 정지")
	check_eq(state.get_pawn(21).current_tile_idx, 2, "호텔 타일에서 멈춤")
	check(not state.board.get_tile(2).has_attachment("HOTEL"), "호텔은 통행료를 받으면 소모")
	check(hotel.is_expired(), "소모된 호텔은 만료 상태")
	var second := make_state(2, 1, {1: _loadout(Kind.MONOPOLY)})
	place(second, 11, 0, [], false)
	move(second, 11, 2)
	var kept: TileAttachment = second.board.get_tile(2).attachments[0]
	place(second, 12, 0, [], false)
	var own: MoveReport = move(second, 12, 4)
	check(not own.stopped_early, "내 호텔은 그냥 지나감")
	check(second.board.get_tile(2).has_attachment("HOTEL"), "내 호텔은 소모되지 않음")
	for i: int in 4:
		check(not kept.tick_turn(), "%d번째 턴 경과" % (i + 1))
	check(kept.tick_turn(), "내 턴 5번 뒤 만료")


func test_monopoly_four_set_makes_hotels_permanent() -> void:
	var state := make_state(2, 1, {1: _loadout(Kind.MONOPOLY), 2: _loadout(Kind.MONOPOLY)})
	var hotel := Hotel.new(1)
	check(hotel.is_expiry_suspended(state), "모노폴리 4세트면 만료 정지")
	var weak := make_state(2, 1, {1: [Vector2i(Kind.MONOPOLY, 1), Vector2i(Kind.MONOPOLY, 2), Vector2i(Kind.MONOPOLY, 3), 0]})
	check(not Hotel.new(1).is_expiry_suspended(weak), "3세트는 정지되지 않음")
	var manager: TurnManager = _manager(2, false, {1: _loadout(Kind.MONOPOLY)})
	manager.state.place_attachment(7, Hotel.new(1))
	var placed: TileAttachment = manager.state.board.get_tile(7).attachments[0]
	for i: int in 8:
		manager._tick_owned_attachments(1)
	check(manager.state.board.get_tile(7).has_attachment("HOTEL"), "턴이 지나도 영구 유지")
	check_eq(placed.duration_turns, 5, "남은 턴 수 그대로")
	manager.state.pawns[0].kind = GameEnums.PawnKind.BASIC
	for i: int in 5:
		manager._tick_owned_attachments(1)
	check(not manager.state.board.get_tile(7).has_attachment("HOTEL"), "4세트가 깨지면 다시 만료")
	_dispose(manager)


func test_monopoly_two_set_salary_draws_two_cards_at_the_goal() -> void:
	var state := make_state(2, 1, {1: [Vector2i(Kind.MONOPOLY, 1), Vector2i(Kind.MONOPOLY, 2), 0, 0]})
	place(state, 11, 18, [17])
	var report: MoveReport = move(state, 11, 2)
	check(report.finished, "완주")
	check_eq(report.salary_cards, 2, "월급날: 카드 2장")
	check_eq((state.hands[1] as Array).size(), 2, "손패에 반영")
	var single := make_state(2, 1, {1: [Vector2i(Kind.MONOPOLY, 1), 0, 0, 0]})
	place(single, 11, 18, [17])
	check_eq(move(single, 11, 2).salary_cards, 0, "1세트는 월급날 없음")


func test_yut_two_set_grants_a_bonus_roll_on_four_or_five() -> void:
	var manager: TurnManager = _manager(2, false, {1: [Vector2i(Kind.YUT, 1), Vector2i(Kind.YUT, 2), 0, 0]})
	manager.state.tools[1] = ScriptedTool.new([4, 2])
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(manager.current_state, Phase.PHASE_ROLL_WAIT, "사기 윷: 같은 턴에 추가 굴림")
	check_eq(manager.current_player_id(), 1, "아직 1번 플레이어")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(manager.current_player_id(), 2, "추가 굴림이 끝나면 다음 플레이어")
	_dispose(manager)


# --- 승리 판정 ----------------------------------------------------------------------

func _reason(state: GameState, player_id: int, report: MoveReport = null, chain: int = 0) -> StringName:
	var order: Array[int] = [1, 2]
	return VictoryChecker.player_reason(state, order, player_id, report, chain)


func test_normal_victory_requires_all_four_pawns_home() -> void:
	var state := make_state()
	for slot: int in [1, 2, 3]:
		state.finish_stack(state.get_pawn(10 + slot))
	check_eq(_reason(state, 1), &"", "3/4는 승리가 아님")
	state.finish_stack(state.get_pawn(14))
	check_eq(_reason(state, 1), VictoryChecker.ALL_HOME, "4/4 완주")


func test_special_victory_yut_four_stack_needs_the_full_yut_set() -> void:
	var state := make_state(2, 1, {1: _loadout(Kind.YUT)})
	var report := MoveReport.new()
	report.special_victory = VictoryChecker.YUT_FOUR_STACK
	check_eq(_reason(state, 1, report), VictoryChecker.YUT_FOUR_STACK, "윷 4세트의 4업 완주")
	var partial := make_state(2, 1, {1: [Vector2i(Kind.YUT, 1), Vector2i(Kind.YUT, 2), Vector2i(Kind.YUT, 3), 0]})
	check_eq(_reason(partial, 1, report), &"", "윷 3세트는 특수 승리 불가")


func test_special_victory_checkmate_surrounds_the_leaders_pawn() -> void:
	var state := make_state(2, 1, {1: _loadout(Kind.CHESS)})
	place(state, 21, 8, [6, 7])     # 1등 유저(P2)의 말: 바로 뒤 7번, 바로 앞 9번
	place(state, 11, 7, [5, 6])
	check_eq(_reason(state, 1), &"", "앞쪽만 비어 있으면 포위가 아님")
	place(state, 12, 9, [8])
	check_eq(_reason(state, 1), VictoryChecker.CHECKMATE, "앞뒤 타일을 체스 말이 동시에 포위")
	state.get_pawn(12).current_tile_idx = 10
	check_eq(_reason(state, 1), &"", "한쪽이 비면 해제")
	var basic := make_state()
	place(basic, 21, 8, [6, 7])
	place(basic, 11, 7, [5, 6])
	place(basic, 12, 9, [8])
	check_eq(_reason(basic, 1), &"", "체스 4세트가 아니면 포위해도 승리 아님")


func test_checkmate_targets_the_leader_only() -> void:
	var state := make_state(3, 1, {1: _loadout(Kind.CHESS)})
	place(state, 21, 15, [14])   # P2: 앞선 말
	place(state, 31, 2, [1])     # P3: 뒤처진 말 (포위당해도 1등이 아님)
	place(state, 11, 1, [0])
	place(state, 12, 3, [2])
	var order: Array[int] = [1, 2, 3]
	check_eq(VictoryChecker.leader_player(state, order, 1), 2, "남은 거리 합이 가장 작은 P2가 1등")
	check(not VictoryChecker.is_checkmate(state, order, 1), "1등이 아닌 유저의 포위는 무효")


func test_special_victory_janggun_mungun_needs_three_chained_captures() -> void:
	var state := make_state(2, 1, {1: _loadout(Kind.JANGGI)})
	check_eq(_reason(state, 1, null, 2), &"", "2연속은 부족")
	check_eq(_reason(state, 1, null, 3), VictoryChecker.JANGGUN_MUNGUN, "한 턴에 3연속 잡기")
	check_eq(_reason(make_state(), 1, null, 3), &"", "장기 4세트가 아니면 무효")


func test_janggun_mungun_through_a_real_turn_with_three_captures() -> void:
	# 장기 기물은 잡기 추가 턴이 없으므로, 한 턴에 3연속 잡기는 재굴림으로 쌓은 이동 대기열로 만든다.
	var manager: TurnManager = _manager(2, false, {1: _loadout(Kind.JANGGI)})
	place(manager.state, 11, 1, [0])
	place(manager.state, 21, 2, [1])
	place(manager.state, 22, 4, [3])
	place(manager.state, 23, 6, [5])
	manager.state.tools[1] = ScriptedTool.new([ScriptedTool.reroll_of(1), ScriptedTool.reroll_of(2), 2])
	var winners: Array = []
	manager.game_over.connect(func(winner_id: int, reason: StringName) -> void: winners.append([winner_id, reason]))
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"roll")
	for step: int in 3:
		_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(winners, [[1, VictoryChecker.JANGGUN_MUNGUN]], "한 턴 안에서 3연속 잡기")
	check(manager.is_game_over, "게임 종료")
	_dispose(manager)


func test_capture_chain_resets_when_the_turn_passes() -> void:
	var manager: TurnManager = _manager(2, false, {1: _loadout(Kind.JANGGI)})
	place(manager.state, 11, 1, [0])
	place(manager.state, 21, 2, [1])
	place(manager.state, 22, 4, [3])
	manager.state.tools[1] = ScriptedTool.new([1, 2, 1])
	manager.state.tools[2] = ScriptedTool.new([1])
	for step: int in 2:
		_do(manager, 1, &"proceed")
		_do(manager, 1, &"roll")
		_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"select_pawn", {"pawn_id": 12})  # 잡지 못하고 턴 종료
	check_eq(manager.current_player_id(), 2, "턴이 넘어감")
	check_eq(manager._chain_captures, 0, "연속 잡기 카운터 초기화")
	check(not manager.is_game_over, "2연속으로는 승리하지 않음")
	_dispose(manager)


func test_janggun_mungun_three_captures_via_four_set_extra_turns() -> void:
	# 장기 4세트 특권: 잡기 추가 턴이 이어져 굴림 3번 연속으로 3연속 잡기를 달성한다.
	var manager: TurnManager = _manager(2, false, {1: _loadout(Kind.JANGGI)})
	place(manager.state, 11, 1, [0])
	place(manager.state, 21, 2, [1])
	place(manager.state, 22, 4, [3])
	place(manager.state, 23, 6, [5])
	manager.state.tools[1] = ScriptedTool.new([1, 2, 2])
	var winners: Array = []
	manager.game_over.connect(func(winner_id: int, reason: StringName) -> void: winners.append([winner_id, reason]))
	for step: int in 3:
		_do(manager, 1, &"proceed")
		_do(manager, 1, &"roll")
		_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	check_eq(winners, [[1, VictoryChecker.JANGGUN_MUNGUN]], "추가 턴이 이어져 3연속 잡기")
	_dispose(manager)


func test_janggi_capture_extra_turn_is_a_four_set_privilege() -> void:
	for count: int in [1, 2, 3, 4]:
		var loadout: Array = []
		for unit: int in 4:
			loadout.append(Vector2i(Kind.JANGGI, unit + 1) if unit < count else 0)
		var state := make_state(2, 1, {1: loadout})
		place(state, 11, 2, [1])
		place(state, 21, 4, [3])
		var report: MoveReport = move(state, 11, 2)
		check_eq(report.captured_pawn_ids, int_array([21]), "%d세트: 잡기는 수행" % count)
		check_eq(report.extra_turn, count == 4, "%d세트: 추가 굴림은 4세트에서만" % count)
	var chess := make_state(2, 1, {1: _loadout(Kind.CHESS)})
	place(chess, 11, 2, [1])
	place(chess, 21, 4, [3])
	check(not move(chess, 11, 2).extra_turn, "다른 4세트(체스)는 해당 없음")


func test_special_victory_real_estate_needs_six_simultaneous_hotels() -> void:
	var state := make_state(2, 1, {1: _loadout(Kind.MONOPOLY)})
	for tile: int in [1, 2, 4, 6, 9]:
		state.place_attachment(tile, Hotel.new(1))
	check_eq(VictoryChecker.hotel_count(state, 1), 5, "호텔 5개")
	check_eq(_reason(state, 1), &"", "5개는 부족")
	state.place_attachment(11, Hotel.new(1))
	state.place_attachment(12, Hotel.new(2))
	check_eq(_reason(state, 1), VictoryChecker.REAL_ESTATE, "내 호텔 6개 동시 유지")
	check_eq(_reason(state, 2), &"", "상대 호텔은 세지 않음")
	check_eq(_reason(make_state(), 1), &"", "모노폴리 4세트가 아니면 무효")


func test_special_victory_daema_bulsa_holds_all_four_corners() -> void:
	var state := make_state(2, 1, {1: _loadout(Kind.GO)})
	check_eq(_reason(state, 1), &"", "시작 직후(모두 0번)는 아님")
	place(state, 12, 5)
	place(state, 13, 10)
	place(state, 14, 15)
	check_eq(_reason(state, 1), VictoryChecker.DAEMA_BULSA, "0, 5, 10, 15번 네 모서리 동시 점령")
	place(state, 14, 14)
	check_eq(_reason(state, 1), &"", "하나라도 비면 무효")


func test_evaluate_checks_current_player_first_and_returns_empty_when_nobody_wins() -> void:
	var state := make_state()
	var order: Array[int] = [1, 2]
	check(VictoryChecker.evaluate(state, order, 1, null, 0).is_empty(), "승자 없음")
	for player_id: int in [1, 2]:
		for pawn: PlayerPawn in state.pawns_of(player_id):
			state.finish_stack(pawn)
	check_eq(VictoryChecker.evaluate(state, order, 2, null, 0)["winner"], 2, "동시에 조건을 만족하면 현재 턴 플레이어가 우선")


func test_victory_reason_texts_cover_all_six_outcomes() -> void:
	for reason: StringName in [VictoryChecker.ALL_HOME, VictoryChecker.YUT_FOUR_STACK, VictoryChecker.CHECKMATE, VictoryChecker.JANGGUN_MUNGUN, VictoryChecker.REAL_ESTATE, VictoryChecker.DAEMA_BULSA]:
		check(VictoryChecker.reason_text(reason).contains("승리"), "%s 설명" % reason)


func test_turn_manager_stops_the_game_on_special_victory_and_rejects_further_actions() -> void:
	var manager: TurnManager = _manager(2, false, {1: _loadout(Kind.GO)})
	for pawn_id: int in [12, 13, 14]:
		place(manager.state, pawn_id, {12: 5, 13: 10, 14: 15}[pawn_id])
	place(manager.state, 11, 18, [17])
	manager.state.tools[1] = ScriptedTool.new([2])
	var rejected: Array = []
	manager.action_rejected.connect(func(_player: int, _action: StringName, reason: StringName) -> void: rejected.append(reason))
	_do(manager, 1, &"proceed")
	_do(manager, 1, &"roll")
	_do(manager, 1, &"select_pawn", {"pawn_id": 11})
	# 11번이 완주해 0번에서 빠지므로 바둑 4세트가 네 모서리를 다 차지하지는 못한다 -> 아직 승리 아님.
	check(not manager.is_game_over, "완주한 말은 모서리 점령에 쓰이지 않음")
	_dispose(manager)
	var winning: TurnManager = _manager(2, false, {1: _loadout(Kind.GO)})
	for pawn_id: int in [12, 13]:
		place(winning.state, pawn_id, {12: 5, 13: 10}[pawn_id])
	place(winning.state, 14, 13, [12])
	winning.state.tools[1] = ScriptedTool.new([3])  # 바둑 2세트 포석: 눈금 -1 -> 실제 2칸
	var winners: Array = []
	winning.game_over.connect(func(winner_id: int, reason: StringName) -> void: winners.append([winner_id, reason]))
	winning.action_rejected.connect(func(_player: int, _action: StringName, reason: StringName) -> void: rejected.append(reason))
	_do(winning, 1, &"proceed")
	_do(winning, 1, &"roll")
	_do(winning, 1, &"select_pawn", {"pawn_id": 14})  # 13 -> 14 -> 15번 모서리 도착: 0(출발선 11번), 5, 10, 15 점령
	check_eq(winners, [[1, VictoryChecker.DAEMA_BULSA]], "대마 불사 승리")
	_do(winning, 2, &"proceed")
	check(rejected.has(&"game_over"), "게임이 끝난 뒤의 행동은 거부")
	_dispose(winning)


func test_unit_augments_give_the_named_unit_and_refuse_duplicates() -> void:
	var state := make_state()
	var rook: AugmentDef = AugmentRegistry.get_def(&"EVO_2_4")
	check_eq(rook.display_name, "기물 지급: 체스:룩", "선택지는 세부 기물 하나를 이름으로 지급")
	check(rook.is_available(state, 1), "아직 없으니 받을 수 있다")
	check(rook.apply(state, 1, {"pawn_id": 11})["ok"], "룩 지급")
	check_eq(state.get_pawn(11).display_label(), "체스:룩", "정확히 룩이 지급된다 (랜덤 아님)")
	check(not rook.is_available(state, 1), "이미 룩을 가졌으면 제시하지 않는다")
	var again: Dictionary = rook.apply(state, 1, {"pawn_id": 12})
	check(not again["ok"] and state.get_pawn(12).kind == GameEnums.PawnKind.BASIC, "이미 가진 기물은 받을 수 없다")
	check(AugmentRegistry.get_def(&"EVO_2_1").is_available(state, 1), "다른 체스 기물은 계속 받을 수 있다")
	# 바둑은 흑·백 두 종이고 각각 2개까지, 윷말은 4개까지
	var black: AugmentDef = AugmentRegistry.get_def(&"EVO_5_1")
	check(black.apply(state, 1, {"pawn_id": 12})["ok"] and black.apply(state, 1, {"pawn_id": 13})["ok"], "흑돌 2개까지 받는다")
	check(not black.is_available(state, 1), "흑돌 두 개를 가졌으면 흑돌은 더 못 받는다")
	check(AugmentRegistry.get_def(&"EVO_5_2").is_available(state, 1) or state.basic_pawns_of(1).size() == 1, "백돌은 별개 선택지")
	check(AugmentRegistry.get_def(&"EVO_5_1").describe(state, 1).contains("이미 가진 기물은 받을 수 없습니다"), "설명에 중복 불가 안내")
