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


func test_rulebook_is_fifo_with_four_slots() -> void:
	var book := RuleBookManager.new()
	var evicted: Array[StringName] = []
	book.law_evicted.connect(func(law_id: StringName) -> void: evicted.append(law_id))
	for law_id: StringName in [&"LAW_01", &"LAW_02", &"LAW_03", &"LAW_04"]:
		check_eq(book.add_law(LawRegistry.create(law_id)), GameEnums.AddLawResult.ADDED, "빈 슬롯 추가")
	check_eq(book.add_law(LawRegistry.create(&"LAW_05")), GameEnums.AddLawResult.ADDED_EVICTED, "5번째는 밀어내기")
	check_eq(evicted, [&"LAW_01"] as Array[StringName], "가장 오래된 교칙이 밀려남")
	check_eq(book.law_ids(), [&"LAW_02", &"LAW_03", &"LAW_04", &"LAW_05"] as Array[StringName], "슬롯 순서")
	check_eq(book.add_law(LawRegistry.create(&"LAW_03")), GameEnums.AddLawResult.REJECTED_DUPLICATE, "중복 거부")
	check_eq(book.laws.size(), 4, "슬롯 수 유지")


func test_repeal_slot_removes_law() -> void:
	var book := RuleBookManager.new()
	book.add_law(LawRegistry.create(&"LAW_01"))
	book.add_law(LawRegistry.create(&"LAW_02"))
	check_eq(book.repeal_slot(0).law_id, &"LAW_01", "삭제된 교칙")
	check_eq(book.law_ids(), [&"LAW_02"] as Array[StringName], "남은 교칙")
	check(book.repeal_slot(5) == null, "잘못된 슬롯")


func test_roll_modify_pipeline_runs_in_slot_order() -> void:
	var state := make_state()
	# LAW_06(4 초과 -> 1) 다음 LAW_04(홀수 후퇴): 5 -> 1 -> -1
	add_law(state, &"LAW_06")
	add_law(state, &"LAW_04")
	var ctx: RuleContext = make_ctx(state, 5)
	state.rulebook.run_stage(GameEnums.HookStage.ROLL_MODIFY, ctx)
	check_eq(ctx.steps, -1, "LAW_06 -> LAW_04 순서")
	# 반대 순서: LAW_04(5 -> -5) 다음 LAW_06(|5| > 4 -> -1)
	var reversed_state := make_state()
	add_law(reversed_state, &"LAW_04")
	add_law(reversed_state, &"LAW_06")
	var ctx2: RuleContext = make_ctx(reversed_state, 5)
	reversed_state.rulebook.run_stage(GameEnums.HookStage.ROLL_MODIFY, ctx2)
	check_eq(ctx2.steps, -1, "LAW_04 -> LAW_06 순서")
	var even: RuleContext = make_ctx(state, 4)
	state.rulebook.run_stage(GameEnums.HookStage.ROLL_MODIFY, even)
	check_eq(even.steps, 4, "짝수 4는 전진 4")


func test_law_04_negative_yut_face() -> void:
	var state := make_state()
	add_law(state, &"LAW_04")
	var ctx: RuleContext = make_ctx(state, -1)
	state.rulebook.run_stage(GameEnums.HookStage.ROLL_MODIFY, ctx)
	check_eq(ctx.steps, -1, "빽도(홀수)는 계속 후퇴")


func test_path_prepare_flags() -> void:
	var state := make_state()
	add_law(state, &"LAW_01")
	add_law(state, &"LAW_02")
	add_law(state, &"LAW_08")
	var ctx: RuleContext = make_ctx(state, 3)
	state.rulebook.run_stage(GameEnums.HookStage.PATH_PREPARE, ctx)
	check(not ctx.shortcuts_enabled, "LAW_01")
	check(not ctx.stacking_allowed, "LAW_02")
	check(ctx.goal_bounce, "LAW_08")


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
	check(not card.can_play(state, 1, {"slot_index": 2}), "빈 슬롯 지정 불가")
	check(card.can_play(state, 1, {"slot_index": 0}), "유효 슬롯")
	CommandStack.new().execute(card.create_command(state, 1, {"slot_index": 0}), state)
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
