# File: res://tests/test_rules_and_cards.gd
# Class: class_name TestRulesAndCards
# Role: 법전 FIFO 4슬롯·인터셉터 파이프라인, 커맨드 스택 LIFO, 카드 ACT_01/04/06 및 법전 우선 원칙(명세 4·6) 검증
class_name TestRulesAndCards
extends TestCase


class RecordingCommand extends GameCommand:
	var log: Array[StringName]
	var label: StringName

	func _init(target_log: Array[StringName], id: StringName) -> void:
		log = target_log
		label = id
		command_name = id

	func _run(_state: GameState) -> void:
		log.append(label)


func _make_book() -> RuleBookManager:
	return RuleBookManager.new()


func test_rulebook_is_fifo_with_four_slots_and_reports_evictions() -> void:
	var book: RuleBookManager = _make_book()
	var added: Array = []
	book.law_added.connect(func(new_law: LawResource, removed_law: LawResource) -> void: added.append([new_law.law_id, removed_law.law_id if removed_law != null else ""]))
	for law_id: String in ["LAW_01", "LAW_02", "LAW_03", "LAW_04"]:
		book.enqueue_law(LawRegistry.create(law_id))
	check_eq(book.active_laws_queue.size(), 4, "4슬롯 가득 참")
	check_eq(added[3], ["LAW_04", ""], "밀려난 교칙이 없으면 removed_law는 null")
	book.enqueue_law(LawRegistry.create("LAW_05"))
	check_eq(added[4], ["LAW_05", "LAW_01"], "5번째는 가장 오래된 교칙을 pop_front로 밀어냄")
	check_eq(book.law_ids(), ["LAW_02", "LAW_03", "LAW_04", "LAW_05"] as Array[String], "슬롯 순서 (오래된 것이 앞)")
	check_eq(book.active_laws_queue.size(), MAX_SLOTS_FOR_TEST, "슬롯 수 유지")
	book.free()


const MAX_SLOTS_FOR_TEST: int = 4


func test_remove_law_by_id_for_act_06() -> void:
	var book: RuleBookManager = _make_book()
	var removed: Array = []
	book.law_removed.connect(func(law: LawResource) -> void: removed.append(law.law_id))
	book.enqueue_law(LawRegistry.create("LAW_01"))
	book.enqueue_law(LawRegistry.create("LAW_02"))
	check(book.remove_law_by_id("LAW_01"), "존재하는 교칙은 파기 성공")
	check_eq(removed, ["LAW_01"], "law_removed 시그널")
	check_eq(book.law_ids(), ["LAW_02"] as Array[String], "남은 교칙")
	check(not book.remove_law_by_id("LAW_01"), "이미 없는 교칙은 false")
	check(not book.remove_law_by_id("NOPE"), "알 수 없는 ID는 false")
	check_eq(removed.size(), 1, "실패 시 시그널 없음")
	book.free()


func test_process_context_only_runs_laws_matching_trigger_timing() -> void:
	var state := make_state()
	add_law(state, "LAW_01")  # ON_MOVE_CALC
	add_law(state, "LAW_04")  # ON_DICE_ROLL
	var ctx: RuleContext = make_ctx(state, 3)
	ctx = run_timing(state, ctx, RuleContext.ON_DICE_ROLL)
	check_eq(ctx.dice_value, -3, "ON_DICE_ROLL 교칙(LAW_04)만 적용: 홀수는 후퇴")
	check(ctx.allow_shortcut, "ON_MOVE_CALC 교칙(LAW_01)은 아직 미적용")
	ctx = run_timing(state, ctx, RuleContext.ON_MOVE_CALC)
	check(not ctx.allow_shortcut, "ON_MOVE_CALC 시점에 LAW_01 적용")
	check_eq(ctx.dice_value, -3, "눈금은 다시 바뀌지 않음")
	var untouched: RuleContext = run_timing(state, make_ctx(state, 3), RuleContext.ON_CAPTURE)
	check_eq(untouched.dice_value, 3, "일치하는 교칙이 없으면 ctx 그대로")


func test_process_context_orders_by_priority_then_queue_order() -> void:
	var state := make_state()
	# 같은 priority면 큐 순서: LAW_06(5 -> 1) 다음 LAW_04(홀수 -> 후퇴) = -1
	add_law(state, "LAW_06")
	add_law(state, "LAW_04")
	check_eq(run_timing(state, make_ctx(state, 5), RuleContext.ON_DICE_ROLL).dice_value, -1, "LAW_06 -> LAW_04")
	var reversed_state := make_state()
	add_law(reversed_state, "LAW_04")
	add_law(reversed_state, "LAW_06")
	check_eq(run_timing(reversed_state, make_ctx(reversed_state, 5), RuleContext.ON_DICE_ROLL).dice_value, -1, "LAW_04 -> LAW_06")
	# priority가 낮을수록 먼저: 큐에는 LAW_06이 앞이지만 LAW_04의 priority를 -1로 주면 LAW_04가 먼저.
	var priority_state := make_state()
	var camera: LawResource = LawRegistry.create("LAW_06")
	var frog: LawResource = LawRegistry.create("LAW_04")
	frog.priority = -1
	priority_state.rulebook.enqueue_law(camera)
	priority_state.rulebook.enqueue_law(frog)
	var out: RuleContext = run_timing(priority_state, make_ctx(priority_state, 6), RuleContext.ON_DICE_ROLL)
	check_eq(out.dice_value, 1, "6 -> (LAW_04) 6 전진 -> (LAW_06) 1")
	var odd: RuleContext = run_timing(priority_state, make_ctx(priority_state, 5), RuleContext.ON_DICE_ROLL)
	check_eq(odd.dice_value, -1, "5 -> (LAW_04) -5 -> (LAW_06) -1")
	var even: RuleContext = run_timing(state, make_ctx(state, 4), RuleContext.ON_DICE_ROLL)
	check_eq(even.dice_value, 4, "짝수 4는 전진 4")


func test_law_may_replace_context_or_cancel() -> void:
	var state := make_state()
	var canceler := LawResource.new()
	canceler.law_id = "TEST_CANCEL"
	canceler.trigger_timing = RuleContext.ON_MOVE_CALC
	state.rulebook.enqueue_law(canceler)
	var base_ctx: RuleContext = run_timing(state, make_ctx(state, 2), RuleContext.ON_MOVE_CALC)
	check(not base_ctx.is_canceled, "기본 intercept는 ctx를 그대로 반환")
	check_eq(base_ctx.dice_value, 2, "기본 intercept는 변조하지 않음")
	var script := GDScript.new()
	script.source_code = "extends LawResource\nfunc intercept(ctx: RuleContext) -> RuleContext:\n\tctx.is_canceled = true\n\tctx.metadata[\"by\"] = law_id\n\treturn ctx\n"
	script.reload()
	var cancel_law: LawResource = script.new()
	cancel_law.law_id = "TEST_CANCEL_2"
	cancel_law.trigger_timing = RuleContext.ON_MOVE_CALC
	state.rulebook.enqueue_law(cancel_law)
	var result: RuleContext = run_timing(state, make_ctx(state, 2), RuleContext.ON_MOVE_CALC)
	check(result.is_canceled, "교칙이 is_canceled를 세울 수 있음")
	check_eq(result.metadata["by"], "TEST_CANCEL_2", "metadata 전달")


func test_canceled_move_does_not_move_the_pawn() -> void:
	var state := make_state()
	var script := GDScript.new()
	script.source_code = "extends LawResource\nfunc intercept(ctx: RuleContext) -> RuleContext:\n\tctx.is_canceled = true\n\treturn ctx\n"
	script.reload()
	var law: LawResource = script.new()
	law.law_id = "TEST_FREEZE"
	law.trigger_timing = RuleContext.ON_MOVE_CALC
	state.rulebook.enqueue_law(law)
	place(state, 11, 4, [3])
	var report: MoveReport = move(state, 11, 3)
	check(report.canceled, "이동 취소")
	check_eq(state.get_pawn(11).tile_index, 4, "말은 움직이지 않음")


func test_move_calc_flags_and_path_nodes() -> void:
	var state := make_state()
	add_law(state, "LAW_01")
	add_law(state, "LAW_02")
	add_law(state, "LAW_08")
	var ctx: RuleContext = run_timing(state, make_ctx(state, 3), RuleContext.ON_MOVE_CALC)
	check(not ctx.allow_shortcut, "LAW_01")
	check(not ctx.allow_stacking, "LAW_02")
	check(ctx.exact_goal_required, "LAW_08")
	var pawn: PlayerPawn = place(state, 11, 0, [], false)
	var move_ctx: RuleContext = make_ctx(state, 3)
	MoveExecutor.execute(state, pawn, move_ctx)
	check_eq(move_ctx.path_nodes, int_array([1, 2, 3]), "이동 실행기가 path_nodes를 채움")


func test_command_stack_resolves_interrupts_lifo_and_undoes() -> void:
	var state := make_state()
	var stack := CommandStack.new()
	var log: Array[StringName] = []
	stack.queue_interrupt(RecordingCommand.new(log, &"first"))
	stack.queue_interrupt(RecordingCommand.new(log, &"second"))
	stack.queue_interrupt(RecordingCommand.new(log, &"third"))
	check_eq(stack.interrupt_count(), 3, "대기열")
	stack.resolve_interrupts(state)
	check_eq(log, [&"third", &"second", &"first"] as Array[StringName], "후입선출")
	check_eq(stack.interrupt_count(), 0, "대기열 비움")
	check_eq(stack.history_count(), 3, "실행 이력")


func test_command_undo_restores_board() -> void:
	var state := make_state()
	var stack := CommandStack.new()
	place(state, 11, 4, [3])
	stack.execute(ExpelPawnCommand.new(1, 11), state)
	check_eq(state.get_pawn(11).tile_index, 0, "추방됨")
	check(stack.undo_last(state), "undo 성공")
	check_eq(state.get_pawn(11).tile_index, 4, "되돌림")
	check(not stack.undo_last(state), "이력 없음")


func test_act_06_repeals_chosen_slot() -> void:
	var state := make_state()
	add_law(state, &"LAW_02")
	add_law(state, &"LAW_05")
	var card: BaseCard = CardRegistry.get_card(&"ACT_06")
	check(not card.can_play(state, 1, {"law_id": "LAW_07"}), "법전에 없는 교칙은 지정 불가")
	check(card.can_play(state, 1, {"law_id": "LAW_02"}), "법전에 있는 교칙")
	CommandStack.new().execute(card.create_command(state, 1, {"law_id": "LAW_02"}), state)
	check(not state.rulebook.has_law(&"LAW_02"), "법전 파기")
	check(state.rulebook.has_law(&"LAW_05"), "다른 교칙 유지")


func test_act_01_reverses_order_and_movement_for_one_round() -> void:
	var state := make_state(3)
	var card: BaseCard = CardRegistry.get_card(&"ACT_01")
	CommandStack.new().execute(card.create_command(state, 1, {}), state)
	check_eq(state.turn_direction, -1, "턴 순서 반전")
	check_eq(state.movement_direction(), -1, "이동 역주행")
	check_eq(state.next_player_after(1), 3, "역순 진행")
	var pawn: PlayerPawn = place(state, 11, 4, [3])
	var ctx: RuleContext = make_ctx(state, 2)
	ctx.direction = state.movement_direction()
	var report: MoveReport = MoveExecutor.execute(state, pawn, ctx)
	check_eq(report.path, int_array([3, 2]), "양수 눈금도 후진")


func test_act_04_works_at_19_and_28_after_retreating_from_start() -> void:
	var state := make_state()
	var card: BaseCard = CardRegistry.get_card(&"ACT_04")
	place(state, 11, 0, [], false)
	check(not card.can_play(state, 1, {"pawn_id": 11}), "후퇴 전에는 사용 불가")
	var report: MoveReport = move(state, 11, -1)
	check_eq(report.path, int_array([19]), "0번에서 후퇴하면 19번")
	check(card.can_play(state, 1, {"pawn_id": 11}), "19번 도착 직후 발동 가능")
	check(not card.can_play(state, 2, {"pawn_id": 11}), "남의 말에는 사용 불가")
	CommandStack.new().execute(card.create_command(state, 1, {"pawn_id": 11}), state)
	check(state.get_pawn(11).is_finished, "즉시 완주")

	place(state, 12, 0, [27, 28], true)
	var report28: MoveReport = move(state, 12, -1)
	check_eq(report28.path, int_array([28]), "history 직전이 28이면 28번으로 후퇴")
	check(card.can_play(state, 1, {"pawn_id": 12}), "28번 도착 직후에도 발동 가능")


func test_act_04_not_playable_for_pawn_that_merely_walked_to_19() -> void:
	var state := make_state()
	var card: BaseCard = CardRegistry.get_card(&"ACT_04")
	place(state, 11, 17, [16])
	move(state, 11, 2)
	check_eq(state.get_pawn(11).tile_index, 19, "19번 도착")
	check(not card.can_play(state, 1, {"pawn_id": 11}), "0번에서 후퇴한 경우에만 사용 가능")


func test_card_registry_and_default_deck() -> void:
	for card_id: StringName in [&"ACT_01", &"ACT_04", &"ACT_05", &"ACT_06", &"TRP_01"]:
		check(CardRegistry.get_card(card_id) != null, "카드 %s 등록" % card_id)
	check_eq(CardRegistry.default_deck().size(), 12, "기본 덱 12장")


func test_mirror_force_card_validates_tile() -> void:
	var state := make_state()
	var card: BaseCard = CardRegistry.get_card(&"TRP_01")
	check(not card.can_play(state, 1, {"tile": 0}), "출발선 설치 불가")
	check(not card.can_play(state, 1, {"tile": 22}), "중앙 설치 불가")
	check(card.can_play(state, 1, {"tile": 9}), "일반 타일")
	CommandStack.new().execute(card.create_command(state, 1, {"tile": 9}), state)
	check(state.board.get_tile(9).has_attachment(&"TRP_01"), "설치됨")
	check_eq(state.board.get_tile(9).attachments[0].owner_id, 1, "설치자 기록")
	check(not card.can_play(state, 2, {"tile": 9}), "같은 설치물 중복 불가")


func test_neutral_npc_bandit_chases_with_bfs_and_steals_card() -> void:
	var state := make_state()
	place(state, 21, 3, [2])
	state.give_card(2, &"ACT_06")
	var npc: NeutralNPC = state.spawn_npc(1, GameEnums.NpcBehavior.CHASE_NEAREST, 1, &"SUM_01")
	var reports: Array[Dictionary] = []
	for i: int in 6:
		reports.append(npc.run_ai(state))
		if state.get_pawn(21).tile_index == 0:
			break
	check_eq(state.get_pawn(21).tile_index, 0, "도적에게 잡혀 출발선으로")
	check((state.hands[2] as Array).is_empty(), "생떼 카드 1장 강탈")


func test_neutral_npc_ghost_patrols_reverse_and_drags_pawns_to_center() -> void:
	var state := make_state()
	place(state, 21, 18, [17])
	var ghost: NeutralNPC = state.spawn_npc(0, GameEnums.NpcBehavior.PATROL_REVERSE, 1, &"SUM_02")
	var report: Dictionary = ghost.run_ai(state)
	check_eq(report["path"], int_array([19, 18, 17]), "외곽 트랙 역주행 3칸")
	check_eq(state.get_pawn(21).tile_index, 22, "마주친 말은 중앙으로 연행")
