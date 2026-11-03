# File: res://tests/test_haunt.gd
# Class: class_name TestHaunt
# Role: 방해령 삼총사(베루·사리·메죵) 카드 3종과 특수 승리 LAW_09 [방해령 허리케인 포스!!] 검증 - 카드 효과·대상 규칙, 법전 진행도(손패 종류 수), 내 차례 끝에만 달성, 증강 보정(카드 지급·드로우 가중치)
class_name TestHaunt
extends TestCase


func _new_manager(seed_value: int = 4242) -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	manager.start_game([1, 2], seed_value)
	return manager


func _dispose(manager: TurnManager) -> void:
	tree.root.remove_child(manager)
	manager.free()


func _events(manager: TurnManager) -> Array:
	var events: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void: events.append({"kind": kind, "data": data}))
	return events


func _place(pawn: PlayerPawn, tile: int) -> void:
	pawn.has_left_start = true
	pawn.is_finished = false
	pawn.current_tile_idx = tile


func _hand_all(state: GameState, player: int) -> void:
	state.hands[player] = [&"ACT_18", &"ACT_19", &"ACT_20"]


# ---- 카드 등록·데이터 ----

func test_three_haunt_cards_are_registered_with_names_and_table_text() -> void:
	for id: StringName in HauntCommand.IDS:
		var card: BaseCard = CardRegistry.get_card(id)
		check(card is CardHaunt and card.category == GameEnums.CardCategory.INSTANT, "%s 즉발 카드" % id)
		check_eq(CardRegistry.deck_copies(id), 2, "%s 덱 2장" % id)
		check(CardRegistry.type_of(id) == "INSTANT", "%s 표의 종류" % id)
		check(GameData.text("cards", id, "desc") != "" and GameData.text("cards", id, "name_ja") != "" and GameData.text("cards", id, "name_en") != "", "%s 표에 한국어·영어·일본어 이름과 설명" % id)
	check_eq([CardRegistry.get_card(&"ACT_18").display_name, CardRegistry.get_card(&"ACT_19").display_name, CardRegistry.get_card(&"ACT_20").display_name],
		["방해령 베루", "방해령 사리", "방해령 메죵"], "카드 이름")
	check(MainBoard.HAUNT_HINT.contains("베루·사리·메죵을 모두 손패에 모으면 무언가 일어날지도"), "툴팁 하단 힌트 문구")
	check(L10n.has_hangul(MainBoard.HAUNT_HINT), "힌트 원문은 한국어 (번역은 translations.csv)")


# ---- 베루: 적 말 뒤로 1칸 ----

func test_beru_pushes_an_enemy_pawn_back_one_tile() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var me: int = manager.current_player_id()
	var enemy_pawn: PlayerPawn = state.get_pawn(21)
	_place(enemy_pawn, 10)
	state.hands[me] = [&"ACT_18"]
	var card: BaseCard = CardRegistry.get_card(&"ACT_18")
	check(card.could_play(state, me) and card.is_legal(state, me, {"pawn_id": 21}), "보드 위 적 말이 있으면 쓸 수 있다")
	check(not card.is_legal(state, me, {"pawn_id": 11}), "내 말은 고를 수 없다")
	check(not card.is_legal(state, me, {"pawn_id": 22}), "출발선에서 기다리는 적 말은 고를 수 없다")
	manager.act(&"play_card", {"player_id": me, "card_id": &"ACT_18", "pawn_id": 21})
	check_eq(enemy_pawn.current_tile_idx, 9, "적 말이 10번 → 9번 칸")
	check(not state.has_card(me, &"ACT_18"), "카드는 쓰면 사라진다")
	_dispose(manager)


func test_beru_needs_an_empty_track_tile_behind_the_pawn() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var me: int = manager.current_player_id()
	var card: BaseCard = CardRegistry.get_card(&"ACT_18")
	_place(state.get_pawn(21), 1)
	check(not card.is_legal(state, me, {"pawn_id": 21}), "1번 칸에서는 출발선으로 밀 수 없다")
	_place(state.get_pawn(21), 10)
	_place(state.get_pawn(22), 9)
	check(not card.is_legal(state, me, {"pawn_id": 21}), "뒤 칸에 다른 말이 있으면 밀 수 없다 (잡기·업기가 생기지 않게)")
	check(card.is_legal(state, me, {"pawn_id": 22}), "22번 말은 뒤 칸(8번)이 비어 있어 밀 수 있다")
	_dispose(manager)


# ---- 사리: 내 말 앞으로 1칸 ----

func test_sari_pulls_my_pawn_forward_one_tile() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var me: int = manager.current_player_id()
	var mine: PlayerPawn = state.get_pawn(me * 10 + 1)
	_place(mine, 5)
	state.hands[me] = [&"ACT_19"]
	var card: BaseCard = CardRegistry.get_card(&"ACT_19")
	check(card.could_play(state, me) and card.is_legal(state, me, {"pawn_id": mine.entity_id}), "보드 위 내 말이 있으면 쓸 수 있다")
	check(not card.is_legal(state, me, {"pawn_id": 21}), "적 말은 고를 수 없다")
	manager.act(&"play_card", {"player_id": me, "card_id": &"ACT_19", "pawn_id": mine.entity_id})
	check_eq(mine.current_tile_idx, 6, "내 말이 5번 → 6번 칸")
	_dispose(manager)


func test_sari_cannot_enter_the_finish_or_an_occupied_tile() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var me: int = manager.current_player_id()
	var card: BaseCard = CardRegistry.get_card(&"ACT_19")
	var mine: PlayerPawn = state.get_pawn(me * 10 + 1)
	_place(mine, BoardSpec.tile_count - 1)
	check(not card.is_legal(state, me, {"pawn_id": mine.entity_id}), "마지막 칸에서는 결승선으로 당길 수 없다")
	_place(mine, 5)
	_place(state.get_pawn(21), 6)
	check(not card.is_legal(state, me, {"pawn_id": mine.entity_id}), "앞 칸에 말이 있으면 당길 수 없다")
	_dispose(manager)


# ---- 메죵: 적의 다음 눈금 -1 ----

func test_mejong_reduces_the_enemy_next_roll_once() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var me: int = manager.current_player_id()
	var foe: int = 2 if me == 1 else 1
	state.hands[me] = [&"ACT_20"]
	var card: BaseCard = CardRegistry.get_card(&"ACT_20")
	check(card.is_legal(state, me, {"target_player": foe}) and not card.is_legal(state, me, {"target_player": me}), "상대만 고를 수 있다")
	manager.act(&"play_card", {"player_id": me, "card_id": &"ACT_20", "target_player": foe})
	check_eq(int(state.roll_penalty.get(foe, 0)), 1, "상대에게 눈금 -1이 걸린다")
	# 그 사람의 다음 굴림에 한 번만 적용된다 (눈금 5 → 4)
	var events := _events(manager)
	state.roll_penalty[me] = 1
	state.forced_roll[me] = 5
	manager.act(&"proceed", {"player_id": me})
	manager.act(&"roll", {"player_id": me})
	var penalized: Array = events.filter(func(event: Dictionary) -> bool: return event["kind"] == &"roll_penalized")
	check(penalized.size() == 1 and int(penalized[0]["data"]["from"]) == 5 and int(penalized[0]["data"]["to"]) == 4, "눈금 5 → 4")
	check(not state.roll_penalty.has(me), "한 번 쓰면 사라진다")
	_dispose(manager)


func test_mejong_never_turns_a_roll_into_zero() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var me: int = manager.current_player_id()
	var events := _events(manager)
	state.roll_penalty[me] = 3
	state.forced_roll[me] = 2
	manager.act(&"proceed", {"player_id": me})
	manager.act(&"roll", {"player_id": me})
	var penalized: Array = events.filter(func(event: Dictionary) -> bool: return event["kind"] == &"roll_penalized")
	check(penalized.size() == 1 and int(penalized[0]["data"]["to"]) == 1, "눈금은 최소 1칸 (2 - 3 → 1)")
	_dispose(manager)


# ---- 법전 LAW_09: 진행도 · 달성 시점 ----

func test_hurricane_law_progress_counts_kinds_in_hand_in_real_time() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var law: VictoryLaw = LawRegistry.create("LAW_09") as VictoryLaw
	check(law != null and law.law_name == "방해령 허리케인 포스!!" and law.goal() == 3 and law.unit() == "종", "법전 이름·목표 3종")
	state.hands[1] = []
	check_eq(law.progress(state, 1), 0, "손패에 없으면 0/3")
	state.hands[1] = [&"ACT_18"]
	check_eq(law.progress(state, 1), 1, "베루만 있으면 1/3")
	state.hands[1] = [&"ACT_18", &"ACT_18", &"ACT_19", &"JNK_CUKE"]
	check_eq(law.progress(state, 1), 2, "같은 종류 여러 장은 1종으로 센다 (2/3)")
	_hand_all(state, 1)
	check_eq(law.progress(state, 1), 3, "세 종류가 다 있으면 3/3")
	check(law.achieved(state, 1) and not law.achieved(state, 2), "달성 여부는 사람별로")
	check(law.is_danger(state, 1) or law.achieved(state, 1), "2~3종이면 위험 표시 대상")
	_dispose(manager)


func test_hurricane_is_judged_only_at_the_end_of_my_own_turn() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var events := _events(manager)
	state.rulebook.enqueue_law(LawRegistry.create("LAW_09"))
	_hand_all(state, 1)
	check(not manager._judge_special_victory(2), "남(2번)의 차례가 끝나도 1번의 허리케인은 판정하지 않는다")
	check(not manager._judge_special_victory(-1), "라운드 끝 판정에서도 세지 않는다")
	check(not state.is_graduated(1), "아직 졸업하지 않았다")
	manager._judge_special_victory(1)
	check(state.is_graduated(1) and state.rank_reasons.get(1, &"") == &"LAW_09", "내 차례를 끝내는 순간 특수 승리로 졸업")
	check(not state.rulebook.has_law("LAW_09"), "달성한 법전은 법전에서 지워진다")
	var judged: Array = events.filter(func(event: Dictionary) -> bool: return event["kind"] == &"special_victory_judgement")
	check(judged.size() == 1 and (judged[0]["data"]["laws"] as Array).has("LAW_09"), "판정 사건에 LAW_09")
	_dispose(manager)


func test_hurricane_needs_all_three_at_turn_end() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	state.rulebook.enqueue_law(LawRegistry.create("LAW_09"))
	state.hands[1] = [&"ACT_18", &"ACT_19"]
	manager._judge_special_victory(1)
	check(not state.is_graduated(1), "2종만으로는 달성하지 못한다")
	state.hands[1] = [&"ACT_18", &"ACT_19", &"ACT_19"]
	manager._judge_special_victory(1)
	check(not state.is_graduated(1), "같은 종류를 겹쳐 가져도 3종이 아니다")
	_dispose(manager)


# ---- 증강 보정: 카드 1장 지급 + 드로우 가중치 ----

func test_choosing_the_hurricane_law_gifts_a_haunt_card_and_boosts_draws() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var augment: AugmentDef = AugmentRegistry.get_def(&"AUG_LAW_09")
	state.round_number = augment.min_round
	check(augment != null and augment.category == GameEnums.AugmentCategory.LAW_ENACT and augment.is_available(state, 1), "법전 증강으로 나온다 (7라운드부터)")
	check(augment.describe(state, 1).contains("방해령 카드 1장 지급"), "증강 설명에 지급 보정")
	state.hands[1] = []
	var result: Dictionary = augment.apply(state, 1)
	check(bool(result["ok"]) and state.rulebook.has_law("LAW_09"), "교칙 제정")
	check((state.hands[1] as Array).size() == 1 and HauntCommand.is_haunt((state.hands[1] as Array)[0]), "무작위 방해령 1장 지급")
	check(state.haunt_boost.has(1) and not state.haunt_boost.has(2), "고른 사람만 드로우 가중치")
	check(not augment.is_available(state, 2), "이미 법전에 있으면 다시 나오지 않는다")
	_dispose(manager)


func test_boosted_draws_favor_missing_haunt_kinds_and_stay_deterministic() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	var haunts_boosted: int = 0
	var haunts_plain: int = 0
	for trial: int in 300:
		for who: int in [1, 2]:
			state.hands[who] = []
			state.card_deck = [] as Array[StringName]
			for i: int in 40:
				state.card_deck.append(&"ACT_04")
			state.card_deck.append_array([&"ACT_18", &"ACT_19", &"ACT_20"])
			state._shuffle(state.card_deck)  # 방해령이 덱 맨 위에만 있지 않게 섞는다
			if who == 1:
				state.haunt_boost[1] = true
			else:
				state.haunt_boost.erase(2)
			var drawn: StringName = state.draw_card(who)
			if HauntCommand.is_haunt(drawn):
				if who == 1:
					haunts_boosted += 1
				else:
					haunts_plain += 1
	check(haunts_boosted > 3 * haunts_plain and haunts_boosted > 60, "가중치가 붙은 사람이 방해령을 훨씬 자주 뽑는다 (%d vs %d / 300)" % [haunts_boosted, haunts_plain])
	# 이미 손패에 있는 종류는 보통 확률: 세 종류를 다 가졌으면 균등
	state.haunt_boost[1] = true
	state.hands[1] = [&"ACT_18", &"ACT_19", &"ACT_20"]
	state.card_deck = [&"ACT_18", &"ACT_04"] as Array[StringName]
	var kept: int = 0
	for trial: int in 200:
		state.hands[1] = [&"ACT_18", &"ACT_19", &"ACT_20"]
		state.card_deck = [&"ACT_18", &"ACT_04"] as Array[StringName]
		state._shuffle(state.card_deck)
		if state.draw_card(1) == &"ACT_18":
			kept += 1
	check(kept > 60 and kept < 140, "이미 가진 종류는 가중치가 없다 (%d/200)" % kept)
	# 같은 시드 → 같은 카드 (락스텝)
	var a := _new_manager(777)
	var b := _new_manager(777)
	a.state.haunt_boost[1] = true
	b.state.haunt_boost[1] = true
	var seq_a: Array = []
	var seq_b: Array = []
	for i: int in 8:
		a.state.hands[1] = []
		b.state.hands[1] = []
		seq_a.append(a.state.draw_card(1))
		seq_b.append(b.state.draw_card(1))
	check_eq(seq_a, seq_b, "같은 시드와 같은 행동이면 같은 카드를 뽑는다")
	_dispose(a)
	_dispose(b)
	_dispose(manager)


# ---- 스냅샷(되감기)·기록 코드 ----

func test_new_state_survives_a_turn_snapshot_round_trip() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	state.roll_penalty[2] = 2
	state.haunt_boost[1] = true
	var snapshot: TurnSnapshot = TurnSnapshot.capture(state)
	state.roll_penalty.clear()
	state.haunt_boost.clear()
	snapshot.restore(state, true)
	check_eq(int(state.roll_penalty.get(2, 0)), 2, "눈금 깎기 복원")
	check(state.haunt_boost.has(1), "드로우 가중치 복원")
	_dispose(manager)


## 중반 법전 보장(자동 제정)은 방해령 허리케인 포스!!를 뽑지 않는다: 증강 보정(카드 1장·드로우 가중치) 없이는 사실상 달성할 수 없다.
func test_auto_enact_never_picks_the_hurricane_law() -> void:
	for seed_value: int in range(100, 160):
		var manager := _new_manager(seed_value)
		manager.state.round_number = 8
		manager._enter_round_start()
		var ids: Array = manager.state.rulebook.law_ids()
		check(not ids.has("LAW_09"), "시드 %d: 자동 제정에 LAW_09가 없다 (%s)" % [seed_value, str(ids)])
		_dispose(manager)


## 히든 보정: 방해령 3종이 우연히 손패에 모이면 방해령 허리케인 포스!! 증강이 그 사람의 드래프트에 훨씬 자주 나온다.
func test_collecting_all_three_by_chance_boosts_the_hurricane_offer() -> void:
	var manager := _new_manager()
	var state: GameState = manager.state
	state.round_number = 7  # 법전 증강은 7라운드부터
	var def: AugmentDef = AugmentRegistry.get_def(&"AUG_LAW_09")
	state.hands[1] = []
	var base: float = AugmentRegistry.effective_weight(def, state, 1)
	state.hands[1] = [&"ACT_18", &"ACT_19"]
	check_eq(AugmentRegistry.effective_weight(def, state, 1), base, "2종만으로는 보정이 없다")
	_hand_all(state, 1)
	check_eq(AugmentRegistry.effective_weight(def, state, 1), base * AugmentRegistry.HAUNT_COLLECTED_OFFER_FACTOR, "3종이 모이면 가중치 x%d" % int(AugmentRegistry.HAUNT_COLLECTED_OFFER_FACTOR))
	check_eq(AugmentRegistry.effective_weight(def, state, 2), base, "다른 사람은 그대로 (손패 기준)")
	var other: AugmentDef = AugmentRegistry.get_def(&"AUG_LAW_01")
	state.hands[1] = []
	var plain_other: float = AugmentRegistry.effective_weight(other, state, 1)
	_hand_all(state, 1)
	check_eq(AugmentRegistry.effective_weight(other, state, 1), plain_other, "다른 법전 증강은 영향이 없다")
	# 실제 드래프트: 보정이 붙은 사람이 이 증강을 훨씬 자주 본다
	var seen_plain: int = 0
	var seen_boosted: int = 0
	for trial: int in 300:
		state.hands[2] = []
		if AugmentRegistry.generate_offers(state, 2).has(&"AUG_LAW_09"):
			seen_plain += 1
		if AugmentRegistry.generate_offers(state, 1).has(&"AUG_LAW_09"):
			seen_boosted += 1
	check(seen_boosted > 2 * seen_plain and seen_boosted > 20, "손패에 3종이 있는 사람이 훨씬 자주 본다 (%d vs %d / 300)" % [seen_boosted, seen_plain])
	# 이미 법전에 있으면 더는 나오지 않는다
	state.rulebook.enqueue_law(LawRegistry.create("LAW_09"))
	check(not AugmentRegistry.generate_offers(state, 1).has(&"AUG_LAW_09"), "법전에 이미 있으면 제시하지 않는다")
	_dispose(manager)
