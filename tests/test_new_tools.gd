# File: res://tests/test_new_tools.gd
# Class: class_name TestNewTools
# Role: 새 판정 도구 3종(야추 다이스·블랙잭 21 딜러·클래식 구슬 핀볼)의 판정 공식과 TurnManager 연동을 검사한다
class_name TestNewTools
extends TestCase


func _rng(seed_value: int = 4242) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _new_manager() -> TurnManager:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	manager.start_game([1, 2], 4242, {})
	return manager


func _dispose(manager: TurnManager) -> void:
	tree.root.remove_child(manager)
	manager.free()


# --- 야추 다이스 ---------------------------------------------------------------

func test_yacht_hand_table() -> void:
	var cases: Array = [
		[[1, 1, 1, 1, 1], &"yacht", 12],
		[[6, 6, 6, 6, 6], &"yacht", 12],
		[[2, 2, 2, 2, 5], &"four", 9],
		[[1, 2, 3, 4, 5], &"large_straight", 9],
		[[2, 3, 4, 5, 6], &"large_straight", 9],
		[[3, 3, 5, 5, 5], &"full_house", 7],
		[[1, 2, 3, 4, 6], &"small_straight", 7],
		[[2, 3, 4, 5, 5], &"small_straight", 7],
		[[4, 4, 4, 1, 6], &"triple", 5],
		[[1, 1, 2, 3, 6], &"chance", 3],
		[[1, 1, 2, 2, 1], &"full_house", 7],
		[[1, 1, 3, 3, 4], &"chance", 2],
		[[1, 1, 1, 2, 2], &"full_house", 7],
		[[2, 2, 3, 3, 1], &"chance", 2],
		[[1, 2, 2, 1, 1], &"full_house", 7],
		[[1, 1, 2, 4, 5], &"chance", 3],
		[[1, 1, 1, 2, 4], &"triple", 5],
	]
	for entry: Array in cases:
		var hand: Dictionary = ToolYacht.evaluate(entry[0])
		check_eq(hand["hand"], entry[1], "%s 족보" % str(entry[0]))
		check_eq(int(hand["steps"]), int(entry[2]), "%s 칸수" % str(entry[0]))
	check_eq(int(ToolYacht.evaluate([1, 1, 1, 1, 6])["steps"]), 9, "포카드가 눈금 6을 끼고 있어도 9칸")
	check_eq(int(ToolYacht.evaluate([1, 1, 2, 3, 5])["steps"]), 3, "노페어는 가장 높은 눈금 5의 절반 올림 3칸")
	check_eq(int(ToolYacht.evaluate([1, 1, 2, 2, 3])["steps"]), 2, "노페어(투페어 모양)는 최고 눈금 3의 절반 올림 2칸")


func test_yacht_flow_keep_reroll_and_cash_out() -> void:
	var tool := ToolYacht.new()
	var rng: RandomNumberGenerator = _rng()
	check(not tool.has_pending_state(), "처음엔 진행 중이 아니다")
	check(tool.cash_out() == null, "굴리기 전에는 확정할 것이 없다")
	var first: RollResult = tool.roll(rng)
	check(first.can_continue and tool.has_pending_state(), "첫 굴림은 확정 전")
	check_eq((first.details["dice"] as Array).size(), 5, "주사위 5개")
	check_eq(int(first.details["rerolls_left"]), 2, "남은 다시 굴리기 2회")
	var before: Array = (first.details["dice"] as Array).duplicate()
	tool.set_keep([true, false, true, false, true])
	var second: RollResult = tool.roll(rng)
	var after: Array = second.details["dice"]
	check(after[0] == before[0] and after[2] == before[2] and after[4] == before[4], "고정한 주사위는 그대로")
	check_eq(int(second.details["rerolls_left"]), 1, "다시 굴리기 1회 남음")
	check_eq(second.details["rolled"], [1, 3], "고정하지 않은 주사위만 굴렸다")
	tool.set_keep([false, false, false, false, false])
	var third: RollResult = tool.roll(rng)
	check_eq(int(third.details["rerolls_left"]), 0, "다시 굴리기를 모두 썼다")
	check(third.can_continue, "다 써도 확정 전이다 (확정 버튼을 눌러야 이동)")
	var done: RollResult = tool.roll(rng)
	check(not done.can_continue and not tool.has_pending_state(), "다시 굴릴 횟수가 없는데 굴리면 현재 족보로 확정")
	check_eq(done.steps, int(ToolYacht.evaluate(done.details["dice"])["steps"]), "확정 칸수는 족보 공식")


func test_yacht_cash_out_and_yacht_grants_reroll() -> void:
	var tool := ToolYacht.new()
	tool.roll(_rng(11))
	tool.dice = [4, 4, 4, 4, 4]
	var yacht: RollResult = tool.cash_out()
	check_eq(yacht.steps, 12, "야추는 12칸")
	check(yacht.reroll, "야추는 한 번 더")
	check(not tool.has_pending_state(), "확정하면 초기화")
	var plain := ToolYacht.new()
	plain.roll(_rng(12))
	plain.dice = [1, 1, 2, 3, 6]
	var none: RollResult = plain.cash_out()
	check(not none.reroll and none.steps == 3, "노페어는 한 번 더가 없고 최고 6의 절반 3칸")


func test_yacht_keep_mask_ignores_bad_input() -> void:
	var tool := ToolYacht.new()
	tool.roll(_rng(5))
	tool.set_keep([true])
	var result: RollResult = tool.roll(_rng(6))
	check_eq((result.details["rolled"] as Array).size(), 4, "길이가 모자라면 첫 주사위만 고정")


# --- 블랙잭 --------------------------------------------------------------------

func test_blackjack_totals() -> void:
	check_eq(ToolBlackjack.total_of([1, 13]), 21, "A+K = 21")
	check_eq(ToolBlackjack.total_of([1, 1]), 12, "A+A = 12 (하나는 1)")
	check_eq(ToolBlackjack.total_of([1, 5, 8]), 14, "A는 21을 넘으면 1")
	check_eq(ToolBlackjack.total_of([12, 11, 5]), 25, "10+10+5 = 25")
	check_eq(ToolBlackjack.total_of([9, 7]), 16, "9+7")
	check_eq(ToolBlackjack.total_of([1, 1, 1, 8]), 21, "A 셋은 11+1+1+8 = 21")
	check_eq(ToolBlackjack.total_of([1, 1, 1, 7]), 20, "A 셋과 7은 20")


func test_blackjack_opening_total_is_always_between_eleven_and_twenty_one() -> void:
	for seed_value: int in 300:
		var tool := ToolBlackjack.new()
		var result: RollResult = tool.roll(_rng(seed_value))
		var total: int = int(result.details["total"])
		check(total >= 11 and total <= 21, "시작 합계 11~21 (%d)" % total)
		if total == 21:
			check(result.steps == 11 and result.reroll and not result.can_continue, "시작부터 21이면 11칸 + 한 번 더")
		else:
			check(result.can_continue and result.steps == total - 10, "11~20이면 확정 전 (예상 %d칸)" % (total - 10))
			check(tool.has_pending_state(), "진행 중")


func test_blackjack_stand_moves_total_minus_ten() -> void:
	for seed_value: int in 120:
		var tool := ToolBlackjack.new()
		var first: RollResult = tool.roll(_rng(seed_value))
		if not first.can_continue:
			continue
		var stand: RollResult = tool.cash_out()
		check_eq(stand.steps, int(first.details["total"]) - 10, "스탠드는 합계-10칸")
		check(stand.steps >= 1 and stand.steps <= 10 and not stand.reroll and not stand.ends_turn, "1~10칸, 한 번 더 없음")
		check(not tool.has_pending_state(), "확정하면 끝")


func test_blackjack_hit_busts_or_continues_and_21_ends_with_bonus() -> void:
	var saw_bust: bool = false
	var saw_blackjack: bool = false
	var saw_continue: bool = false
	for seed_value: int in 400:
		var tool := ToolBlackjack.new()
		var rng: RandomNumberGenerator = _rng(seed_value + 1000)
		var result: RollResult = tool.roll(rng)
		var guard: int = 0
		while result.can_continue and guard < 20:
			guard += 1
			result = tool.roll(rng)  # 계속 히트
			saw_continue = saw_continue or result.can_continue
		if bool(result.details["bust"]):
			saw_bust = true
			check(result.ends_turn and result.steps == 0 and not result.reroll and int(result.details["total"]) >= 22, "버스트는 0칸·턴 종료")
		elif bool(result.details["blackjack"]):
			saw_blackjack = true
			check(result.steps == 11 and result.reroll and not result.ends_turn and int(result.details["total"]) == 21, "21은 11칸+한 번더")
		check(not tool.has_pending_state(), "결과가 나오면 초기화")
	check(saw_bust and saw_blackjack and saw_continue, "버스트·블랙잭·계속 모두 관측")


func test_blackjack_forced_totals() -> void:
	var tool := ToolBlackjack.new()
	tool.cards = [10, 6]
	tool._started = true
	var rng: RandomNumberGenerator = _rng(3)
	# 16에서 히트: 다음 카드가 무엇이든 합계는 17~26 (에이스면 17)
	var result: RollResult = tool.roll(rng)
	var total: int = int(result.details["total"])
	check(total >= 17 and total <= 26, "16에서 히트하면 17~26")
	check_eq(bool(result.details["bust"]), total >= 22, "22 이상이면 버스트")
	var stood := ToolBlackjack.new()
	stood.cards = [10, 9]
	stood._started = true
	var stand: RollResult = stood.cash_out()
	check_eq(stand.steps, 9, "19에서 스탠드는 9칸")


# --- 핀볼 ----------------------------------------------------------------------

func test_pinball_holes_and_weights() -> void:
	var weight_sum: int = 0
	for weight: int in ToolPinball.WEIGHTS:
		weight_sum += weight
	check_eq(weight_sum, 100, "가중치 합 100")
	check_eq(ToolPinball.HOLES, [2, 4, 6, 10, 5, 3, 1] as Array[int], "구멍 숫자 배열 [2,4,6,★10,5,3,1]")
	check_eq(ToolPinball.HOLES.size(), ToolPinball.WEIGHTS.size(), "구멍과 가중치 개수 일치")
	var seen: Dictionary = {}
	for roll_value: int in 100:
		seen[ToolPinball.pick_hole(roll_value)] = true
	check_eq(seen.size(), 7, "100개 값이 7개 구멍을 모두 가리킨다")


func test_pinball_roll_lands_in_a_hole_with_matching_steps() -> void:
	var tool := ToolPinball.new()
	var rng: RandomNumberGenerator = _rng(9)
	var seen: Dictionary = {}
	for i: int in 700:
		var result: RollResult = tool.roll(rng)
		var hole: int = int(result.details["hole"])
		seen[hole] = true
		check(hole >= 0 and hole <= 6, "구멍 번호 0~6")
		check_eq(result.steps, ToolPinball.HOLES[hole], "이동 칸수는 구멍의 숫자")
		check(result.steps >= 1 and result.steps <= 10 and not result.can_continue and not result.ends_turn and not result.reroll, "1~10칸, 단일 굴림")
		check_eq((result.details["bounces"] as Array).size(), 6, "못 튕김 연출 정보 6개")
	check_eq(seen.size(), 7, "7개 구멍 모두 관측")


func test_pinball_is_deterministic_for_the_same_seed() -> void:
	var a := ToolPinball.new().roll(_rng(31))
	var b := ToolPinball.new().roll(_rng(31))
	check(a.steps == b.steps and a.details["bounces"] == b.details["bounces"], "같은 시드는 같은 결과 (모든 화면이 같게 보인다)")


# --- 등록·턴 매니저 연동 --------------------------------------------------------

func test_registry_and_augment_pool_include_new_tools() -> void:
	for id: StringName in [&"DICE_YACHT", &"DICE_BLACKJACK", &"DICE_PINBALL"]:
		check(ToolRegistry.ALL_IDS.has(id) and ToolRegistry.create(id) != null, "%s 등록" % id)
		check(AugmentRegistry.SWAPPABLE_TOOLS.has(id), "%s 판정 도구 교체 증강 풀" % id)
		check(AugmentRegistry.get_def(StringName("TOOL_%s" % id)) != null, "%s 증강 정의" % id)
	check_eq(ToolRegistry.create(&"DICE_YACHT").display_name, "야추 다이스", "야추 이름")
	check_eq(ToolRegistry.create(&"DICE_BLACKJACK").display_name, "블랙잭 21 딜러", "블랙잭 이름")
	check_eq(ToolRegistry.create(&"DICE_PINBALL").display_name, "클래식 구슬 핀볼", "핀볼 이름")


# --- 봇 판단 --------------------------------------------------------------------

func test_bot_yacht_keeps_most_frequent_face() -> void:
	check_eq(BotBrain.yacht_keep_mask([3, 3, 5, 3, 1]), [true, true, false, true, false] as Array[bool], "가장 많이 겹친 3을 고정")
	check_eq(BotBrain.yacht_keep_mask([2, 2, 6, 6, 1]), [false, false, true, true, false] as Array[bool], "겹침이 같으면 높은 눈금(6)을 고정")
	check_eq(BotBrain.yacht_keep_mask([1, 2, 3, 6, 6]), [false, false, false, true, true] as Array[bool], "더 많이 겹친 6이 우선")
	check_eq(BotBrain.yacht_keep_mask([1, 2, 3, 4, 6]), [true, true, true, true, false] as Array[bool], "겹침이 없으면 가장 긴 연속 숫자를 고정")
	check_eq(BotBrain.yacht_keep_mask([1, 3, 5, 6, 4]), [false, true, true, true, true] as Array[bool], "겹침 없음: 3,4,5,6 연속")
	var scattered: Array[bool] = BotBrain.yacht_keep_mask([1, 3, 6, 1, 3])
	check_eq(scattered, [false, true, false, false, true] as Array[bool], "투페어는 높은 쪽(3 vs 1 → 3) 하나")


func test_bot_yacht_stop_conditions() -> void:
	var tool := ToolYacht.new()
	check(not BotBrain.should_stop_yacht(tool), "굴리기 전에는 멈출 게 없다")
	tool.roll(_rng(1))
	tool.dice = [1, 1, 2, 3, 5]
	check(not BotBrain.should_stop_yacht(tool), "노페어에 다시 굴릴 기회가 있으면 계속")
	tool.dice = [2, 2, 2, 2, 6]
	check(BotBrain.should_stop_yacht(tool), "포카드(9칸)는 확정")
	tool.dice = [1, 2, 3, 4, 6]
	check(BotBrain.should_stop_yacht(tool), "스몰 스트레이트(7칸)는 확정")
	tool.dice = [1, 1, 2, 3, 5]
	tool.rerolls_left = 0
	check(BotBrain.should_stop_yacht(tool), "다시 굴릴 횟수가 없으면 확정")


func test_bot_blackjack_hits_up_to_sixteen() -> void:
	var tool := ToolBlackjack.new()
	check(not BotBrain.should_hit_blackjack(tool), "시작 전에는 히트할 게 없다")
	tool.roll(_rng(2))
	tool.cards = [10, 6]
	check(BotBrain.should_hit_blackjack(tool), "16은 히트")
	tool.cards = [10, 7]
	check(not BotBrain.should_hit_blackjack(tool), "17은 스탠드")
	tool.cards = [5, 4, 3]
	check(BotBrain.should_hit_blackjack(tool), "12는 히트")
	tool.cards = [1, 6]
	check(not BotBrain.should_hit_blackjack(tool), "에이스 포함 17은 스탠드")


func test_turn_manager_runs_yacht_reroll_and_stop_with_keep_mask() -> void:
	var manager: TurnManager = _new_manager()
	var player: int = manager.current_player_id()
	manager.state.tools[player] = ToolYacht.new()
	manager.act(&"proceed", {"player_id": player})
	manager.act(&"roll", {"player_id": player})
	var yacht: ToolYacht = manager.state.tools[player]
	check(yacht.has_pending_state() and manager.current_state == TurnManager.State.PHASE_ROLL_WAIT, "첫 굴림 뒤 확정 전 (ROLL_WAIT 유지)")
	var before: Array[int] = yacht.dice.duplicate()
	manager.act(&"roll", {"player_id": player, "keep": [true, true, false, false, true]})
	check(yacht.dice[0] == before[0] and yacht.dice[1] == before[1] and yacht.dice[4] == before[4], "행동에 실어 보낸 고정 표시가 엔진에 적용된다")
	check_eq(yacht.rerolls_left, 1, "다시 굴리기 1회 남음")
	manager.act(&"stop", {"player_id": player})
	check(not yacht.has_pending_state() and manager.current_state != TurnManager.State.PHASE_ROLL_WAIT, "확정하면 이동 단계로")
	_dispose(manager)


func test_turn_manager_blackjack_bust_ends_the_turn() -> void:
	var manager: TurnManager = _new_manager()
	var player: int = manager.current_player_id()
	var tool := ToolBlackjack.new()
	manager.state.tools[player] = tool
	manager.act(&"proceed", {"player_id": player})
	tool.cards = [10, 10]  # 합계 20: 다음 히트는 에이스가 아니면 버스트
	tool._started = true
	var guard: int = 0
	while tool.has_pending_state() and guard < 30:
		guard += 1
		manager.act(&"roll", {"player_id": player})
	check(manager.current_player_id() != player or manager.current_state != TurnManager.State.PHASE_ROLL_WAIT, "버스트나 21이면 굴림이 끝난다")
	_dispose(manager)


## 네 봇이 새 도구 3종만 쓰고도(턴마다 야추·블랙잭·핀볼을 돌려가며) 한 판을 끝까지 진행한다 (고정·히트·스탠드·버스트에서 멈추지 않는다).
func test_four_bots_finish_a_game_using_only_the_new_tools() -> void:
	for seed_value: int in [1, 2, 3]:
		var manager := TurnManager.new()
		manager.boost_gimmicks = false
		manager.hotseat_mode = true
		manager.draft_enabled = false
		tree.root.add_child(manager)
		manager.set_process(false)
		manager.start_game([1, 2, 3, 4] as Array[int], seed_value * 1000 + 3)
		var order: Array[StringName] = [&"DICE_YACHT", &"DICE_BLACKJACK", &"DICE_PINBALL", &"DICE_YACHT"]
		for index: int in 4:
			manager.state.tools[index + 1] = ToolRegistry.create(order[(index + seed_value) % 4])
		var controller := BotController.new()
		controller.manager = manager
		controller.bot_players = [1, 2, 3, 4] as Array[int]
		controller.instant = true
		controller.enabled = true
		controller.rng.seed = seed_value
		var ticks: int = 0
		var busts: int = 0
		manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
			if kind == &"roll_resolved" and bool(((data["result"] as Dictionary)["details"] as Dictionary).get("bust", false)):
				busts += 1)
		while not manager.is_game_over and ticks < 80000:
			controller.tick(0.0)
			ticks += 1
		check(manager.is_game_over and manager.state.winner != -1, "시드 %d: 새 도구만으로도 판이 끝난다 (%d틱, 라운드 %d, 버스트 %d회)" % [seed_value, ticks, manager.state.round_number, busts])
		controller.free()
		_dispose(manager)


# --- 증강 선택 카드의 족보·눈금표 ------------------------------------------------

func test_every_tool_has_a_payout_table_for_the_augment_card() -> void:
	for tool_id: StringName in ToolRegistry.ALL_IDS:
		var line: String = ToolRegistry.table_line(tool_id)
		check(ToolRegistry.TABLES.has(tool_id) and line.begins_with("• "), "%s 족보표가 있다" % tool_id)
		check(line.contains("칸") or line.contains("1~6") or line.contains("1~10") or line.contains("("), "%s 표에 구체적인 칸수가 적혀 있다" % tool_id)
	check_eq(ToolRegistry.table_line(&"HOLDEM"), "• 족보표: 노페어(1) / 원페어(3) / 투페어(5) / 트리플(7) / 스트레이트(10) / 플러시+(15칸)", "홀덤 표")
	check_eq(ToolRegistry.table_line(&"DICE_YACHT"), "• 족보표: 찬스(1~3) / 트리플(5) / 풀하·4연속(7) / 포카드·5연속(9) / ★야추(12칸+한번더)", "야추 표")
	check_eq(ToolRegistry.table_line(&"DICE_BLACKJACK"), "• 족보표: 11~20 스탠드 시 (합계-10)칸 / ★21 달성(11칸+한번더) / 22↑ 버스트(0칸)", "블랙잭 표")
	check_eq(ToolRegistry.table_line(&"SLOT_777"), "• 족보표: 꽝(1) / 2일치(4) / 3일치(8) / ★777 잭팟(20칸!)", "슬롯 표")


func test_tool_swap_augment_description_lists_the_table() -> void:
	var state := GameState.new()
	state.setup([1, 2] as Array[int], 1)
	for tool_id: StringName in AugmentRegistry.SWAPPABLE_TOOLS:
		var definition: AugmentDef = AugmentRegistry.get_def(StringName("TOOL_%s" % tool_id))
		var text: String = definition.describe(state, 1)
		check(text.contains(ToolRegistry.table_line(tool_id)), "%s 증강 카드에 족보표가 함께 나온다" % tool_id)


# --- 중립 NPC 위험 예고 ----------------------------------------------------------

func _npc_state() -> GameState:
	var state := GameState.new()
	state.setup([1, 2] as Array[int], 5)
	return state


func test_ghost_danger_preview_is_the_next_six_tiles_backward() -> void:
	var state: GameState = _npc_state()
	var ghost: NeutralNPC = state.spawn_npc(12, GameEnums.NpcBehavior.PATROL_REVERSE, 1, &"SUM_02")
	var preview: Dictionary = ghost.danger_preview(state)
	check_eq(preview["direction"], -1, "팩맨은 역방향")
	check_eq(preview["tiles"], [11, 10, 9, 8, 7, 6] as Array[int], "12번에서 역방향으로 최대 6칸")
	check_eq(preview["catch_tiles"], [11, 10, 9, 8, 7, 6] as Array[int], "지나는 타일에 서 있으면 잡힌다")
	check_eq(float(preview["chance"]), 0.0, "지금은 아무도 없다")
	var before: int = ghost.current_tile_idx
	ghost.danger_preview(state)
	check_eq(ghost.current_tile_idx, before, "미리보기는 NPC를 움직이지 않는다")


func test_robber_danger_preview_stops_at_the_first_pawn_ahead() -> void:
	var state: GameState = _npc_state()
	var pawn: PlayerPawn = state.get_pawn(11)
	pawn.has_left_start = true
	pawn.current_tile_idx = 12
	var robber: NeutralNPC = state.spawn_npc(10, GameEnums.NpcBehavior.CHASE_NEAREST, 1, &"SUM_01")
	var preview: Dictionary = robber.danger_preview(state)
	check_eq(preview["direction"], 1, "도적떼는 정방향")
	check_eq(preview["tiles"], [11, 12] as Array[int], "말을 만나는 칸에서 멈춘다")
	check_eq(float(preview["chance"]), 1.0, "3칸 안의 말은 반드시 잡힌다")
	pawn.current_tile_idx = 15
	check(absf(float(robber.danger_preview(state)["chance"]) - 0.5) < 0.001, "5칸 앞이면 5·6칸이 나올 때만 (2/4)")
	pawn.current_tile_idx = 20
	var far: Dictionary = robber.danger_preview(state)
	check_eq((far["tiles"] as Array).size(), 6, "최대 6칸까지만 간다")
	check_eq(float(far["chance"]), 0.0, "6칸보다 멀면 이번 라운드에는 못 잡는다")
