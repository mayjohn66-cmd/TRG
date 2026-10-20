# File: res://tests/test_rules_and_cards.gd
# Class: class_name TestRulesAndCards
# Role: 법전 FIFO 4슬롯·인터셉터 파이프라인, 커맨드 스택 LIFO, 카드 ACT_01/04/06 및 법전 우선 원칙(명세 4·6) 검증
class_name TestRulesAndCards
extends TestCase


class RecordingCommand extends GameCommand:
	var log: Array[String]
	var label: String
	var allowed: bool = true

	func _init(target_log: Array[String], id: String, can_run: bool = true) -> void:
		super()
		log = target_log
		label = id
		command_name = id
		allowed = can_run

	func can_execute(_ctx: RuleContext) -> bool:
		return allowed and state != null

	func _run() -> void:
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

func test_personal_passives_only_run_at_their_timing_and_for_their_owner() -> void:
	var state := make_state()
	state.rulebook.add_personal("SUPER_10", 1)  # ON_DICE_ROLL: 짝수 또는 5 이상 +3
	state.rulebook.add_personal("SUPER_11", 1)  # ON_CAPTURE
	check(not state.rulebook.add_personal("SUPER_10", 1), "같은 패시브는 한 번만")
	check(state.rulebook.law_ids().is_empty(), "개인 패시브는 법전 슬롯을 차지하지 않는다")
	var ctx: RuleContext = run_timing(state, make_ctx(state, 4), RuleContext.ON_DICE_ROLL)
	check_eq(ctx.dice_value, 7, "짝수 4 -> 니트로 +3")
	check_eq(ctx.capture_charge_steps, 0, "ON_CAPTURE 패시브는 아직 미적용")
	check_eq(run_timing(state, make_ctx(state, 5), RuleContext.ON_DICE_ROLL).dice_value, 8, "홀수라도 5 이상이면 +3")
	check_eq(run_timing(state, make_ctx(state, 3), RuleContext.ON_DICE_ROLL).dice_value, 3, "홀수 3은 그대로")
	check_eq(run_timing(state, make_ctx(state, 4, 2), RuleContext.ON_DICE_ROLL).dice_value, 4, "주인이 아니면 작동하지 않는다")
	var captured: RuleContext = run_timing(state, make_ctx(state, 4), RuleContext.ON_CAPTURE)
	check_eq(captured.capture_charge_steps, LawRunawayTrain.charge_steps(), "ON_CAPTURE 시점에 폭주 기관차")
	check_eq(captured.dice_value, 4, "눈금은 다시 바뀌지 않음")


func test_process_context_orders_by_priority_then_queue_order() -> void:
	var state := make_state()
	var script := GDScript.new()
	script.source_code = "extends LawResource\nvar factor: int = 1\nvar add: int = 0\nfunc intercept(ctx: RuleContext) -> RuleContext:\n\tctx.dice_value = ctx.dice_value * factor + add\n\treturn ctx\n"
	script.reload()
	var double_it: LawResource = script.new()
	double_it.set("factor", 2)
	double_it.law_id = "TEST_DOUBLE"
	double_it.trigger_timing = RuleContext.ON_DICE_ROLL
	var plus_one: LawResource = script.new()
	plus_one.set("add", 1)
	plus_one.law_id = "TEST_PLUS"
	plus_one.trigger_timing = RuleContext.ON_DICE_ROLL
	state.rulebook.enqueue_law(double_it)
	state.rulebook.enqueue_law(plus_one)
	check_eq(run_timing(state, make_ctx(state, 3), RuleContext.ON_DICE_ROLL).dice_value, 7, "같은 priority면 큐 순서: 3*2+1")
	plus_one.priority = -1
	check_eq(run_timing(state, make_ctx(state, 3), RuleContext.ON_DICE_ROLL).dice_value, 8, "priority가 낮으면 먼저: (3+1)*2")


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
	check_eq(state.get_pawn(11).current_tile_idx, 4, "말은 움직이지 않음")


func test_move_calc_flags_and_path_nodes() -> void:
	var state := make_state()
	var pawn: PlayerPawn = place(state, 11, 0, [], false)
	var move_ctx: RuleContext = make_ctx(state, 3)
	MoveExecutor.execute(state, pawn, move_ctx)
	check_eq(move_ctx.path_nodes, int_array([1, 2, 3]), "이동 실행기가 path_nodes를 채움")


func test_game_command_fields_and_defaults() -> void:
	var state := make_state()
	var command := ExpelPawnCommand.new(2, 21)
	check_eq(command.sender_id, 2, "sender_id")
	check_eq(command.command_name, "ExpelPawn", "command_name")
	check(command.timestamp >= 0, "timestamp는 생성 시각")
	check(not command.can_execute(make_ctx(state, 0)), "상태가 주입되기 전에는 실행 불가")
	command.bind_state(state)
	check(command.can_execute(make_ctx(state, 0)), "주입 후 실행 가능")
	var later := ExpelPawnCommand.new(2, 21)
	check(later.timestamp >= command.timestamp, "나중에 만든 커맨드의 timestamp는 크거나 같음")


func test_command_stack_resolves_interrupts_lifo() -> void:
	var state := make_state()
	var stack: CommandStack = new_stack()
	var ctx: RuleContext = make_ctx(state, 0)
	var log: Array[String] = []
	check(stack.push_interrupt(RecordingCommand.new(log, "first"), ctx), "쌓기")
	check(stack.push_interrupt(RecordingCommand.new(log, "second"), ctx), "쌓기")
	check(stack.push_interrupt(RecordingCommand.new(log, "third"), ctx), "쌓기")
	check_eq(stack.interrupt_count(), 3, "대기열")
	var resolved: Array[GameCommand] = stack.resolve_interrupts(ctx)
	check_eq(log, ["third", "second", "first"] as Array[String], "후입선출")
	check_eq(resolved.size(), 3, "실행된 커맨드 목록")
	check_eq(stack.interrupt_count(), 0, "대기열 비움")
	check_eq(stack.history_count(), 3, "실행 이력")


func test_command_stack_skips_commands_that_became_invalid_before_resolution() -> void:
	var state := make_state()
	add_law(state, "LAW_02")
	var stack: CommandStack = new_stack()
	var ctx: RuleContext = make_ctx(state, 0)
	var first := RepealLawCommand.new(1, "LAW_02")
	var second := RepealLawCommand.new(2, "LAW_02")
	check(stack.push_interrupt(first, ctx), "첫 번째 쌓기")
	check(stack.push_interrupt(second, ctx), "쌓는 시점에는 둘 다 유효")
	var resolved: Array[GameCommand] = stack.resolve_interrupts(ctx)
	check_eq(resolved.size(), 1, "LIFO로 먼저 실행된 쪽이 교칙을 파기하고, 나머지는 can_execute 실패로 건너뜀")
	check(resolved[0] == second, "나중에 낸 커맨드가 먼저 실행")
	check_eq(stack.history_count(), 1, "건너뛴 커맨드는 이력에 남지 않음")
	check(not stack.push_interrupt(RepealLawCommand.new(1, "LAW_02"), ctx), "이미 없는 교칙은 쌓기 단계에서 거부")


func test_command_stack_execute_and_undo_last() -> void:
	var state := make_state()
	var stack: CommandStack = new_stack()
	place(state, 11, 4, [3])
	check(exec(state, ExpelPawnCommand.new(1, 11), stack), "실행")
	check_eq(state.get_pawn(11).current_tile_idx, 0, "추방됨")
	check(stack.undo_last(), "undo 성공")
	check_eq(state.get_pawn(11).current_tile_idx, 4, "되돌림")
	check_eq(state.get_pawn(11).step_history, int_array([3, 4]), "이력도 복원")
	check(not stack.undo_last(), "이력 없음")


func test_undo_turn_history_reverses_in_time_order() -> void:
	var state := make_state()
	var stack: CommandStack = new_stack()
	var undone_order: Array[String] = []
	stack.command_undone.connect(func(command: GameCommand) -> void: undone_order.append(command.command_name))
	place(state, 11, 4, [3])
	place(state, 12, 9, [8])
	add_law(state, "LAW_02")
	exec(state, ExpelPawnCommand.new(1, 11), stack)
	exec(state, RepealLawCommand.new(1, "LAW_02"), stack)
	exec(state, ExpelPawnCommand.new(1, 12), stack)
	check_eq(stack.history_count(), 3, "세 번 실행")
	check_eq(stack.undo_turn_history(), 3, "세 개 모두 취소")
	check_eq(undone_order, ["ExpelPawn", "RepealLaw", "ExpelPawn"] as Array[String], "가장 최근 것부터 역순")
	check_eq(state.get_pawn(11).current_tile_idx, 4, "첫 번째 추방 복원")
	check_eq(state.get_pawn(12).current_tile_idx, 9, "두 번째 추방 복원")
	check(state.rulebook.has_law("LAW_02"), "파기된 교칙 복원")
	check_eq(stack.history_count(), 0, "이력 비움")


func test_rollback_command_undoes_turn_history_and_is_not_recorded() -> void:
	var state := make_state()
	var stack: CommandStack = new_stack()
	place(state, 11, 4, [3])
	add_law(state, "LAW_02")
	state.turn_snapshot = TurnSnapshot.capture(state)
	exec(state, ExpelPawnCommand.new(1, 11), stack)
	exec(state, RepealLawCommand.new(1, "LAW_02"), stack)
	var rolled_back: Array[int] = []
	stack.turn_rolled_back.connect(func(count: int) -> void: rolled_back.append(count))
	check(exec(state, RollbackCommand.new(2), stack), "ACT_05 실행")
	check_eq(rolled_back, [2] as Array[int], "이전 두 개를 되감음")
	check_eq(stack.history_count(), 0, "롤백 커맨드 자체는 이력에 남지 않음")
	check(state.rollback_requested, "TurnManager에 알리는 플래그")
	check_eq(TurnSnapshot.capture(state).data, state.turn_snapshot.data, "역순 undo 결과는 턴 시작 TurnSnapshot과 정확히 같다")

func test_act_04_rocket_reserves_plus_four_for_the_next_roll() -> void:
	var state := make_state()
	var card: BaseCard = CardRegistry.get_card(&"ACT_04")
	check_eq(card.display_name, "로켓", "카드 이름")
	check(card.can_play(state, 1, {}), "조건 없이 사용 가능")
	exec(state, card.create_command(state, 1, {}))
	check_eq(state.roll_bonus, 4, "+4 예약")
	var snapshot: Dictionary = TurnSnapshot.capture(state).to_dict()
	state.roll_bonus = 0
	TurnSnapshot.from_dict(snapshot).restore(state, true)
	check_eq(state.roll_bonus, 4, "스냅샷에 보너스가 담긴다")


func test_card_registry_has_thirty_two_cards_and_the_default_deck() -> void:
	var counts: Dictionary = {}
	for card_id: StringName in CardRegistry.DECK_COMPOSITION.keys():
		var card: BaseCard = CardRegistry.get_card(card_id)
		check(card != null and card.card_id == card_id, "카드 %s 등록" % card_id)
		var key: String = "corner" if card.corner_only else str(card.category)
		counts[key] = int(counts.get(key, 0)) + 1
	check_eq(CardRegistry.DECK_COMPOSITION.size(), 32, "카드 32종")
	check_eq([counts.get(str(GameEnums.CardCategory.COUNTER)), counts.get(str(GameEnums.CardCategory.INSTANT)), counts.get(str(GameEnums.CardCategory.TRAP)), counts.get("corner"), counts.get(str(GameEnums.CardCategory.SUMMON))], [7, 13, 6, 4, 2], "반격 7 · 즉발 13 · 함정 6 · 코너 함정 4 · 소환 2")
	check_eq(CardRegistry.default_deck().size(), 50, "기본 덱 50장 (cards_table.csv param_2)")


func test_act_06_objection_resets_one_victory_record() -> void:
	var state := make_state()
	add_law(state, "LAW_01")
	add_law(state, "LAW_05")
	state.law_stats[2] = {VictoryLaw.KILLS: 4}
	var card: BaseCard = CardRegistry.get_card(&"ACT_06")
	check(card.can_play(state, 1, {"target_player": 2, "law_id": "LAW_01"}), "처치 기록은 지울 수 있다")
	check(not card.can_play(state, 1, {"target_player": 1, "law_id": "LAW_01"}), "0인 기록은 지울 게 없다")
	check(not card.can_play(state, 1, {"target_player": 2, "law_id": "LAW_05"}), "포위망(지금 보드 상태)은 기록이 아니다")
	exec(state, card.create_command(state, 1, {"target_player": 2, "law_id": "LAW_01"}))
	check_eq(state.stat(2, VictoryLaw.KILLS), 0, "0으로 초기화")

func test_neutral_npc_bandit_chases_with_bfs_and_steals_card() -> void:
	var state := make_state()
	place(state, 21, 3, [2])
	state.give_card(2, &"ACT_06")
	var npc: NeutralNPC = state.spawn_npc(1, GameEnums.NpcBehavior.CHASE_NEAREST, 1, &"SUM_01")
	var reports: Array[Dictionary] = []
	for i: int in 6:
		reports.append(npc.run_ai(state))
		if state.get_pawn(21).current_tile_idx == 0:
			break
	check_eq(state.get_pawn(21).current_tile_idx, 0, "도적에게 잡혀 출발선으로")
	check((state.hands[2] as Array).is_empty(), "생떼 카드 1장 강탈")


func test_neutral_npc_ghost_patrols_reverse_and_drags_pawns_to_halfway() -> void:
	var state := make_state()
	place(state, 21, 10, [9])
	var ghost: NeutralNPC = state.spawn_npc(12, GameEnums.NpcBehavior.PATROL_REVERSE, 1, &"SUM_02")
	var report: Dictionary = ghost.run_ai(state)
	check_eq(report["path"], int_array([11, 10]), "12번에서 역주행하다 말을 만나면 그 자리에서 멈춘다")
	check_eq(report["vanished"], true, "한 번 잡으면 소멸")
	check_eq(state.get_pawn(21).current_tile_idx, 12, "마주친 말은 12번으로 연행")


# --- Dry-Run(미리보기)와 법전 변조 추적 ------------------------------------------

func test_preview_context_computes_values_without_emitting_law_signals() -> void:
	var state := make_state()
	state.rulebook.add_personal("SUPER_10", 1)  # 눈금이 짝수이거나 5 이상이면 +3칸
	var events: Array = []
	state.rulebook.law_applied.connect(func(law: LawResource, _timing: String, before: int, after: int, modified: bool) -> void: events.append([law.law_id, before, after, modified]))
	var preview: RuleContext = make_ctx(state, 5)
	preview.is_preview = true
	preview = run_timing(state, preview, RuleContext.ON_DICE_ROLL)
	check_eq(preview.dice_value, 8, "미리보기도 수치는 똑같이 계산")
	check_eq(events.size(), 0, "미리보기는 law_applied를 내지 않음")
	var real: RuleContext = run_timing(state, make_ctx(state, 5), RuleContext.ON_DICE_ROLL)
	check_eq(real.dice_value, 8, "실제 처리")
	check_eq(events, [["SUPER_10", 5, 8, true]], "실제 처리는 변조 여부와 함께 시그널")


func test_law_applied_reports_unmodified_laws_and_tracks_modified_ids() -> void:
	var state := make_state()
	state.rulebook.add_personal("SUPER_10", 1)
	var flags: Array = []
	state.rulebook.law_applied.connect(func(_law: LawResource, _timing: String, _b: int, _a: int, modified: bool) -> void: flags.append(modified))
	run_timing(state, make_ctx(state, 3), RuleContext.ON_DICE_ROLL)
	check_eq(flags, [false], "눈금이 그대로면 modified=false")
	check_eq(state.rulebook.last_modified_law_ids.size(), 0, "변조 기록 없음")
	run_timing(state, make_ctx(state, 6), RuleContext.ON_DICE_ROLL)
	check_eq(state.rulebook.last_modified_law_ids, ["SUPER_10"] as Array[String], "변조한 교칙 ID 기록")


func _law_notes_for_move(start_tile: int, roll: int) -> Array:
	var manager := TurnManager.new()
	manager.boost_gimmicks = false
	manager.hotseat_mode = true
	manager.draft_enabled = false
	tree.root.add_child(manager)
	manager.start_game([1, 2] as Array[int], 777)
	var notes: Array = []
	manager.event_received.connect(func(kind: StringName, data: Dictionary) -> void:
		if kind == &"move_resolved":
			notes.append(data["law_notes"]))
	place(manager.state, 11, start_tile)
	manager.state.tools[1] = ScriptedTool.new([roll])
	manager.act(&"proceed", {"player_id": 1})
	manager.act(&"roll", {"player_id": 1})
	manager.act(&"select_pawn", {"player_id": 1, "pawn_id": 11})
	tree.root.remove_child(manager)
	manager.free()
	return notes


func test_move_report_notes_laws_only_when_the_path_really_changes() -> void:
	check_eq(_law_notes_for_move(2, 2), [[]], "경로가 같으면 법전 요약 없음")


func test_neutral_npc_vanishes_after_first_catch() -> void:
	var state := make_state()
	place(state, 21, 3, [2])
	var bandit: NeutralNPC = state.spawn_npc(3, GameEnums.NpcBehavior.CHASE_NEAREST, 1, &"SUM_01")
	var vanished_ids: Array = []
	state.npc_vanished.connect(func(npc_id: int, _tile: int) -> void: vanished_ids.append(npc_id))
	var report: Dictionary = bandit.run_ai(state)
	check_eq(report["vanished"], true, "잡은 NPC는 소멸 표시")
	var npc_id: int = bandit.entity_id
	state.remove_npc(bandit)
	check_eq(state.npcs.size(), 0, "판에서 제거")
	check_eq(vanished_ids, [npc_id], "npc_vanished 시그널")
	var ghost: NeutralNPC = state.spawn_npc(0, GameEnums.NpcBehavior.PATROL_REVERSE, 1, &"SUM_02")
	var idle: Dictionary = ghost.run_ai(state)
	check_eq(idle["vanished"], false, "아무도 못 잡으면 계속 순찰")


func test_game_session_validates_nicknames() -> void:
	check_eq(GameSession.validate_nickname(""), "닉네임을 입력해 주세요.", "빈 값")
	check_eq(GameSession.validate_nickname("   "), "닉네임을 입력해 주세요.", "공백만")
	check(GameSession.validate_nickname("12345678901") != "", "11자는 너무 길다")
	check_eq(GameSession.validate_nickname("에르핀"), "", "정상")
	check_eq(GameSession.validate_nickname("  열자짜리닉네임입니다 "), "", "공백을 뺀 10자는 통과")
