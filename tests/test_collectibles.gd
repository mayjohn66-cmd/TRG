# File: res://tests/test_collectibles.gd
# Class: class_name TestCollectibles
# Role: 수집품 기물 세트(코롯토·치비구루미) - 완주해야 버프가 생기고, 코롯토는 주사위 결과 +1, 치비구루미는 턴 종료 눈금이 나와도 절반 확률로 다시 굴리는지 검증
class_name TestCollectibles
extends TestCase


func _find(sub: GameEnums.PawnSubType) -> Array:
	for kind: GameEnums.PawnKind in PawnCatalog.SUB_TYPES.keys():
		var list: Array = PawnCatalog.SUB_TYPES[kind]
		for index: int in list.size():
			if list[index] == sub:
				return [kind, index + 1]
	return [GameEnums.PawnKind.BASIC, 0]


func _state_with(sub: GameEnums.PawnSubType, finished: bool) -> GameState:
	var state := GameState.new()
	state.setup([1, 2] as Array[int], 31)
	var pawn: PlayerPawn = state.get_pawn(11)
	var ku: Array = _find(sub)
	pawn.kind = ku[0]
	pawn.unit_no = ku[1]
	pawn.is_finished = finished
	return state


func test_set_is_registered_with_two_collectibles_and_art() -> void:
	check(PawnCatalog.EVOLVABLE_SETS.has(GameEnums.PawnKind.COLLECTIBLE), "지급 가능한 세트")
	check_eq(PawnCatalog.display_set_name(GameEnums.PawnKind.COLLECTIBLE), "수집품", "세트 이름")
	check_eq(PawnCatalog.unit_label(GameEnums.PawnKind.COLLECTIBLE, 1), "수집품:코롯토", "1호기 코롯토")
	check_eq(PawnCatalog.unit_label(GameEnums.PawnKind.COLLECTIBLE, 2), "수집품:치비구루미", "2호기 치비구루미")
	check(AugmentRegistry.get_def(&"EVO_9_1") != null and AugmentRegistry.get_def(&"EVO_9_2") != null, "기물 지급 증강 2종")
	for key: String in ["COLLECT_COROTTO", "COLLECT_CHIBI"]:
		check(ResourceLoader.exists("res://content_trickcal/illustrations/pawns/%s.png" % key), key + " 그림")


func test_corotto_gives_roll_plus_one_only_after_finishing() -> void:
	var racing: GameState = _state_with(GameEnums.PawnSubType.COLLECT_COROTTO, false)
	check_eq(CollectibleBuffs.roll_bonus(racing, 1), 0, "아직 달리는 중이면 버프가 없다")
	var done: GameState = _state_with(GameEnums.PawnSubType.COLLECT_COROTTO, true)
	check_eq(CollectibleBuffs.roll_bonus(done, 1), 1, "완주하면 주사위 +1")
	check_eq(CollectibleBuffs.roll_bonus(done, 2), 0, "다른 사람에게는 없다")


func test_chibigurumi_rerolls_turn_end_half_the_time_after_finishing() -> void:
	var tool: BaseJudgmentTool = ToolRegistry.create(&"D6")
	var ending: RollResult = RollResult.make(&"D6", 0, {})
	ending.ends_turn = true
	var racing: GameState = _state_with(GameEnums.PawnSubType.COLLECT_CHIBI, false)
	check(not CollectibleBuffs.chibi_active(racing, 1), "달리는 중에는 버프가 없다")
	check(CollectibleBuffs.save_from_turn_end(racing, 1, tool, ending).ends_turn, "버프가 없으면 그대로 턴 종료")
	var done: GameState = _state_with(GameEnums.PawnSubType.COLLECT_CHIBI, true)
	check(CollectibleBuffs.chibi_active(done, 1), "완주하면 버프가 켜진다")
	var saved: int = 0
	for seed_value: int in 400:
		done.rng.seed = seed_value
		var info: Dictionary = {}
		var out: RollResult = CollectibleBuffs.save_from_turn_end(done, 1, tool, ending, info)
		if bool(info.get("saved", false)):
			saved += 1
			check(not out.ends_turn, "다시 굴린 주사위는 턴 종료가 아니다")
	check(saved > 140 and saved < 260, "약 절반(%d/400)" % saved)
	var plain: RollResult = RollResult.make(&"D6", 3, {})
	check_eq(CollectibleBuffs.save_from_turn_end(done, 1, tool, plain), plain, "턴 종료가 아닌 굴림은 건드리지 않는다")
	var revolver: BaseJudgmentTool = ToolRegistry.create(&"REVOLVER")
	var shot: RollResult = RollResult.make(&"REVOLVER", 0, {})
	shot.ends_turn = true
	check_eq(CollectibleBuffs.save_from_turn_end(done, 1, revolver, shot), shot, "상태가 있는 도구(러시안 룰렛)는 다시 굴리지 않는다")


## 실제 턴 흐름: 코롯토를 완주시킨 사람의 굴림은 눈금 +1이 붙고, 보너스 이유에 수집품이 실린다.
func test_corotto_bonus_applies_to_a_real_roll() -> void:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	manager.set_process(false)
	manager.start_game([1, 2] as Array[int], 4242)
	var events: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void: events.append({"kind": kind, "data": data}))
	var pawn: PlayerPawn = manager.state.get_pawn(11)
	var ku: Array = _find(GameEnums.PawnSubType.COLLECT_COROTTO)
	pawn.kind = ku[0]
	pawn.unit_no = ku[1]
	pawn.is_finished = true
	manager.state.tools[1] = ScriptedTool.new([2])
	manager.act(&"proceed", {"player_id": 1})
	manager.act(&"roll", {"player_id": 1})
	check_eq(manager.move_queue, int_array([3]), "눈금 2 + 코롯토 1 = 3칸")
	var boosted: Array = events.filter(func(e: Dictionary) -> bool: return e["kind"] == &"roll_boosted")
	check(not boosted.is_empty() and int(boosted[0]["data"]["collect"]) == 1, "보너스 이유에 수집품 +1")
	tree.root.remove_child(manager)
	manager.free()
