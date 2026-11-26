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
	check_eq(ToolPick.sanitize(&"DICE_HWATU", [4, 0]), [4, 0] as Array[int], "화투 2장 (고른 순서 유지)")
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
