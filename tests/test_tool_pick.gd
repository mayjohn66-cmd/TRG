# File: res://tests/test_tool_pick.gd
# Class: class_name TestToolPick
# Role: 판정 도구 터치로 고르기 (1.3.1). 고른 자리가 결과에 실리고(타로는 뒤집히는 자리도), 확률·눈금·난수 순서는 고르지 않았을 때와 같다.
class_name TestToolPick
extends TestCase


func _manager(tool: BaseJudgmentTool, seed_value: int) -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	manager.start_game([1, 2] as Array[int], seed_value, {})
	manager.state.tools[1] = tool
	return manager


func _dispose(manager: TurnManager) -> void:
	tree.root.remove_child(manager)
	manager.free()


## 같은 시드로 굴린 첫 결과 (pick을 줄 수 있다).
func _first_roll(tool_id: StringName, seed_value: int, params: Dictionary) -> Dictionary:
	var manager := _manager(ToolRegistry.create(tool_id), seed_value)
	var seen: Array[Dictionary] = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"roll_resolved" and int(data["player_id"]) == 1:
			seen.append(data["result"]))
	manager.act(&"proceed", {"player_id": 1})
	var payload: Dictionary = params.duplicate()
	payload["player_id"] = 1
	manager.act(&"roll", payload)
	var after: int = manager.state.rng.randi()
	_dispose(manager)
	return {"result": seen[0] if not seen.is_empty() else {}, "rng_after": after}


func test_sanitize_accepts_only_exact_distinct_picks() -> void:
	check_eq(ToolPick.sanitize(&"DICE_TAROT", [2]), [2] as Array[int], "타로 1장")
	check(ToolPick.sanitize(&"DICE_TAROT", [5]).is_empty(), "범위 밖")
	check(ToolPick.sanitize(&"DICE_TAROT", [0, 1]).is_empty(), "고를 수보다 많다")
	check(ToolPick.sanitize(&"DICE_HWATU", [1, 1]).is_empty(), "같은 자리 두 번")
	check_eq(ToolPick.sanitize(&"DICE_HWATU", [2, 0]), [2, 0] as Array[int], "화투 3장 중 2장 (고른 순서 유지)")
	check(ToolPick.sanitize(&"DICE_HWATU", [4, 0]).is_empty(), "화투는 3장뿐 (1.3.1)")
	for moved: StringName in [&"HOLDEM", &"DICE_MAHJONG", &"DICE_OMIKUJI", &"DICE_COOKIE", &"DICE_ICECREAM", &"DICE_CAPSULE"]:
		check(not ToolPick.supports(moved), "%s는 고르기 창 대신 교환·손으로 꺼내기 (1.3.1)" % moved)
	check(ToolPick.sanitize(&"D6", [0]).is_empty(), "고르기 없는 도구")
	check(ToolPick.sanitize(&"DICE_COOKIE", "0").is_empty(), "배열이 아닌 값")
	for tool_id: StringName in ToolPick.SPECS:
		check(ToolRegistry.ALL_IDS.has(tool_id), "%s는 실제 도구" % tool_id)
		check(ToolPick.choose_of(tool_id) >= 1 and ToolPick.choose_of(tool_id) <= ToolPick.count_of(tool_id), "%s 고를 수가 놓인 수 안" % tool_id)


func test_pick_changes_nothing_but_the_shown_position() -> void:
	for tool_id: StringName in ToolPick.SPECS:
		for seed_value: int in [11, 222, 3333]:
			var picks: Array[int] = []
			for index: int in ToolPick.choose_of(tool_id):
				picks.append(ToolPick.count_of(tool_id) - 1 - index)
			var plain: Dictionary = _first_roll(tool_id, seed_value, {})
			var chosen: Dictionary = _first_roll(tool_id, seed_value, {"pick": picks})
			var a: Dictionary = plain["result"]
			var b: Dictionary = chosen["result"]
			check(not a.is_empty() and not b.is_empty(), "%s 굴림 결과" % tool_id)
			if a.is_empty() or b.is_empty():
				continue
			check_eq(int(b["steps"]), int(a["steps"]), "%s 눈금은 그대로 (시드 %d)" % [tool_id, seed_value])
			check_eq(bool(b["ends_turn"]), bool(a["ends_turn"]), "%s 턴 종료 여부 그대로" % tool_id)
			check_eq(bool(b["reroll"]), bool(a["reroll"]), "%s 한 번 더 그대로" % tool_id)
			check_eq(int(chosen["rng_after"]), int(plain["rng_after"]), "%s 난수 순서 그대로 (락스텝 안전)" % tool_id)
			check_eq((b["details"] as Dictionary).get("picked", []), picks, "%s 고른 자리가 결과에 실린다" % tool_id)
			check(not (a["details"] as Dictionary).has("picked"), "%s 고르지 않으면 picked 없음" % tool_id)
			if tool_id == &"DICE_TAROT":
				check_eq(int(b["details"]["flipped"]), picks[0], "타로는 고른 자리가 뒤집힌다")
				check_eq(str(b["details"]["fate"]), str(a["details"]["fate"]), "타로 운명은 그대로")


func test_invalid_pick_is_ignored() -> void:
	var result: Dictionary = _first_roll(&"DICE_TAROT", 5, {"pick": [9]})["result"]
	check(not result.is_empty() and not (result["details"] as Dictionary).has("picked"), "잘못된 pick은 무시하고 평소처럼 굴린다")


# --- 텍사스 홀덤 교환 (1.3.1) ---------------------------------------------------------

func test_holdem_deals_five_then_exchanges_once() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var tool := ToolHoldem.new()
	var deal: RollResult = tool.roll(rng)
	check(deal.can_continue and tool.has_pending_state(), "처음에는 5장을 받고 교환을 기다린다")
	var dealt: Array = deal.details["cards"]
	check_eq(dealt.size(), 5, "5장")
	check_eq(int(deal.details["preview_steps"]), ToolHoldem.steps_for(ToolHoldem.evaluate(tool.cards)), "받은 패의 족보 미리보기")
	tool.set_keep([true, false, true, false, true])
	var final: RollResult = tool.roll(rng)
	check(not final.can_continue and not tool.has_pending_state(), "교환하면 확정")
	var cards: Array = final.details["cards"]
	check_eq(final.details["exchanged"], [1, 3], "남기지 않은 자리만 바꾼다")
	check(cards[0] == dealt[0] and cards[2] == dealt[2] and cards[4] == dealt[4], "남긴 카드는 그대로")
	for index: int in [1, 3]:
		check(not dealt.has(cards[index]), "새 카드는 버린 카드·손패와 겹치지 않는다")
	var unique: Dictionary = {}
	for card: Variant in cards:
		unique[int(card)] = true
	check_eq(unique.size(), 5, "다섯 장 모두 다른 카드")
	check_eq(final.steps, ToolHoldem.steps_for(ToolHoldem.evaluate(cards as Array[int] if cards is Array[int] else _ints(cards))), "최종 족보만큼 전진")


func test_holdem_stand_keeps_the_dealt_hand() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var tool := ToolHoldem.new()
	check(tool.cash_out() == null, "받기 전에는 확정할 것이 없다")
	var deal: RollResult = tool.roll(rng)
	var final: RollResult = tool.cash_out()
	check_eq(final.details["cards"], deal.details["cards"], "그대로 확정하면 받은 5장")
	check_eq((final.details["exchanged"] as Array).size(), 0, "바꾼 카드 없음")
	check(not tool.has_pending_state(), "확정 뒤에는 새 판")


func test_holdem_turn_flow_keep_param_and_timeout() -> void:
	var manager := _manager(ToolHoldem.new(), 99)
	var seen: Array[Dictionary] = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"roll_resolved":
			seen.append(data["result"]))
	manager.act(&"proceed", {"player_id": 1})
	manager.act(&"roll", {"player_id": 1})
	check(seen.size() == 1 and bool(seen[0]["can_continue"]), "첫 굴림은 교환 대기")
	check(manager.current_state == TurnManager.State.PHASE_ROLL_WAIT, "교환을 기다리는 동안 굴림 단계")
	manager.act(&"roll", {"player_id": 1, "keep": [true, true, true, true, false]})
	check(seen.size() == 2 and not bool(seen[1]["can_continue"]), "keep을 실어 교환하면 확정")
	if seen.size() == 2:
		check_eq(seen[1]["details"]["exchanged"], [4], "마지막 한 장만 바꿨다")
	_dispose(manager)
	var idle := _manager(ToolHoldem.new(), 100)
	idle.act(&"proceed", {"player_id": 1})
	idle.act(&"roll", {"player_id": 1})
	idle.force_timeout()
	check(not (idle.state.tools[1] as BaseJudgmentTool).has_pending_state(), "시간이 다 되면 받은 그대로 확정")
	_dispose(idle)


func test_bot_holdem_keeps_pairs_and_stands_on_strong_hands() -> void:
	var pair: Array[int] = [0, 13, 5, 20, 37]  # 2♣ 2♦ 7♣ 9♦ Q♥: 2 한 쌍
	check_eq(BotBrain.holdem_keep_mask(pair), [true, true, false, false, false] as Array[bool], "겹친 숫자만 남긴다")
	var flush_draw: Array[int] = [0, 3, 7, 9, 40]  # 클럽 4장 + 하트
	check_eq(BotBrain.holdem_keep_mask(flush_draw), [true, true, true, true, false] as Array[bool], "같은 문양 4장이면 플러시를 노린다")
	var high: Array[int] = [0, 15, 30, 45, 12]  # 2 4 6 8 A, 문양 섞임
	check_eq(BotBrain.holdem_keep_mask(high), [false, false, false, true, true] as Array[bool], "아무것도 없으면 높은 카드 2장")
	var tool := ToolHoldem.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	tool.roll(rng)
	tool.cards = [0, 1, 2, 3, 4] as Array[int]  # 클럽 2~6 스트레이트 플러시
	check(BotBrain.should_stand_holdem(tool), "스트레이트 이상이면 교환하지 않는다")


func _ints(values: Array) -> Array[int]:
	var result: Array[int] = []
	for value: Variant in values:
		result.append(int(value))
	return result
