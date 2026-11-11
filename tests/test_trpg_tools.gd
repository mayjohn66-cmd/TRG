# File: res://tests/test_trpg_tools.gd
# Class: class_name TestTrpgTools
# Role: TRPG 확장 판정 도구 2종 - 오미쿠지 뽑기통(DICE_OMIKUJI)·아이스크림(DICE_ICECREAM) 규칙·레지스트리·표 데이터 검증
class_name TestTrpgTools
extends TestCase


func test_registered_and_table_rows() -> void:
	for id: StringName in [&"DICE_OMIKUJI", &"DICE_ICECREAM"]:
		check(ToolRegistry.ALL_IDS.has(id), "ALL_IDS: %s" % id)
		var tool: BaseJudgmentTool = ToolRegistry.create(id)
		check(tool != null and tool.tool_id == id, "create: %s" % id)
		check(not GameData.text("dice", id, "name_en").is_empty() and not GameData.text("dice", id, "name_ja").is_empty(), "localized: %s" % id)
		check(AugmentRegistry.SWAPPABLE_TOOLS.has(id), "swappable: %s" % id)
		check(AugmentRegistry.get_def(StringName("TOOL_" + str(id))) != null, "tool-swap augment: %s" % id)
		check(ResourceLoader.exists("res://content_trickcal/illustrations/dice/%s.png" % id), "placeholder art: %s" % id)
	check(ToolRegistry.create(&"DICE_OMIKUJI") is ToolOmikuji, "omikuji class")
	check(ToolRegistry.create(&"DICE_ICECREAM") is ToolIceCream, "icecream class")


func test_omikuji_fortunes() -> void:
	var total: int = 0
	for entry: Array in ToolOmikuji.FORTUNES:
		total += int(entry[3])
	check_eq(total, 100, "weights sum to 100")
	var great: RollResult = ToolOmikuji.of_fortune(&"great")
	check(great.reroll and not great.ends_turn and great.steps == 8, "great blessing = 8 + extra throw")
	var worst: RollResult = ToolOmikuji.of_fortune(&"worst")
	check(worst.ends_turn and not worst.reroll and worst.steps == 0, "worst = forced end")
	var plain: RollResult = ToolOmikuji.of_fortune(&"mid")
	check(plain.steps == 6 and not plain.reroll and not plain.ends_turn, "mid = 6 steps")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var tool := ToolOmikuji.new()
	var seen: Dictionary = {}
	for i: int in 800:
		var r: RollResult = tool.roll(rng)
		seen[StringName(r.details["fortune"])] = true
		check(r.steps >= 0 and r.steps <= 8, "steps in range")
		check(r.reroll == (r.details["fortune"] == &"great") and r.ends_turn == (r.details["fortune"] == &"worst"), "flags match fortune")
	check_eq(seen.size(), ToolOmikuji.FORTUNES.size(), "every fortune appears")


func test_icecream_bar() -> void:
	var again: RollResult = ToolIceCream.of_again()
	check(again.reroll and again.steps == 3 and bool(again.details["again"]), "one more! = refill + extra throw")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var tool := ToolIceCream.new()
	var spaces: Dictionary = {}
	var refills: int = 0
	for i: int in 900:
		var r: RollResult = tool.roll(rng)
		if bool(r.details["again"]):
			refills += 1
			check(r.reroll, "refill throws again")
		else:
			spaces[r.steps] = true
			check(r.steps >= 1 and r.steps <= 6 and not r.reroll, "plain bite 1~6")
	check_eq(spaces.size(), 6, "all stick lengths appear")
	check(refills > 60 and refills < 220, "refill about 15%%: %d" % refills)


func test_turn_manager_applies_results() -> void:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.draft_enabled = false
	manager.hotseat_mode = true
	tree.root.add_child(manager)
	defer_free(manager)
	manager.start_game([1, 2], 77)
	manager.set_process(false)
	manager.state.tools[1] = ToolRegistry.create(&"DICE_OMIKUJI")
	var r: RollResult = manager.state.tools[1].roll(manager.rng) if "rng" in manager else null
	check(r == null or r.tool_id == &"DICE_OMIKUJI", "tool rolls through the shared rng")
	var indices: Array[int] = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"roll_resolved":
			indices.append(int(data.get("chain_index", -1))))
	manager._apply_roll_result(ToolOmikuji.of_fortune(&"great"))
	manager.move_queue.clear()
	manager._close_resolution_window()
	check_eq(manager.current_state, TurnManager.State.PHASE_TURN_BEGIN, "extra roll reopens the card phase")
	manager._apply_roll_result(ToolOmikuji.of_fortune(&"great"))
	manager.advance_to_next_player()
	manager._apply_roll_result(ToolIceCream.of_again())
	check_eq(indices, [0, 1, 0], "roll event keeps the chain across card phases and resets on the next turn")
