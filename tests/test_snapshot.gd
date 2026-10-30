# File: res://tests/test_snapshot.gd
# Class: class_name TestSnapshot
# Role: 명세 5 검증 - TurnSnapshot 직렬화/복원 범위(기물·업기·완주·설치물·법전 복원, 손패 미복원)
class_name TestSnapshot
extends TestCase


func test_snapshot_restores_positions_stacks_attachments_and_laws() -> void:
	var state := make_state()
	place(state, 11, 8, [7])
	place(state, 12, 8, [7])
	state.stack_pawns(state.get_pawn(11), state.get_pawn(12))
	place(state, 21, 14, [13])
	state.place_attachment(3, TrapMirrorForce.new(2))
	add_law(state, &"LAW_01")
	add_law(state, &"LAW_03")
	state.spawn_npc(5, GameEnums.NpcBehavior.CHASE_NEAREST, 1, &"SUM_01")
	var snapshot: TurnSnapshot = TurnSnapshot.capture(state)

	# 턴 도중 벌어지는 변화들
	move(state, 11, 4)
	state.send_to_start(state.get_pawn(21), 1)
	state.finish_stack(state.get_pawn(11))
	state.board.get_tile(3).clear_attachments()
	state.rulebook.remove_law_by_id("LAW_01")
	state.rulebook.enqueue_law(LawRegistry.create("LAW_08"))
	state.clear_npcs()

	snapshot.restore(state)
	var leader: PlayerPawn = state.get_pawn(11)
	check_eq(leader.current_tile_idx, 8, "기물 위치 복원")
	check(not leader.is_finished and not state.get_pawn(12).is_finished, "완주 상태 복원")
	check_eq(state.get_pawn(12).carrier, leader, "업기 관계 복원")
	check_eq(leader.carried.size(), 1, "업은 말 목록 복원")
	check_eq(state.get_pawn(21).current_tile_idx, 14, "추방된 말 복원")
	check_eq(state.get_pawn(21).step_history, int_array([13, 14]), "step_history 복원")
	check(state.board.get_tile(3).has_attachment(&"TRP_01"), "설치물 복원")
	check_eq(state.board.get_tile(3).attachments[0].owner_id, 2, "설치물 소유자 복원")
	check_eq(state.rulebook.law_ids(), ["LAW_01", "LAW_03"] as Array[String], "법전 큐 복원")
	check_eq(state.npcs.size(), 1, "NPC 복원")
	check_eq(state.npcs[0].current_tile_idx, 5, "NPC 위치 복원")


func test_snapshot_is_deep_copy() -> void:
	var state := make_state()
	place(state, 11, 8, [7])
	var snapshot: TurnSnapshot = TurnSnapshot.capture(state)
	state.get_pawn(11).step_history.append(99)
	state.get_pawn(11).current_tile_idx = 12
	snapshot.restore(state)
	check_eq(state.get_pawn(11).step_history, int_array([7, 8]), "깊은 복사라 이후 변경에 영향받지 않음")


func test_snapshot_dict_roundtrip_for_network() -> void:
	var state := make_state()
	place(state, 11, 8, [7])
	state.place_attachment(4, TrapMirrorForce.new(1))
	add_law(state, &"LAW_02")
	var payload: Dictionary = TurnSnapshot.capture(state).to_dict()
	var other := make_state()
	TurnSnapshot.from_dict(payload).restore(other, true)
	check_eq(other.get_pawn(11).current_tile_idx, 8, "다른 인스턴스에 복원")
	check(other.board.get_tile(4).has_attachment(&"TRP_01"), "설치물 재생성")
	check(other.rulebook.has_law(&"LAW_02"), "법전 재생성")


func test_hands_are_not_restored_by_snapshot() -> void:
	var state := make_state()
	state.give_card(2, &"ACT_06")
	state.give_card(1, &"CNT_01")
	var snapshot: TurnSnapshot = TurnSnapshot.capture(state)
	state.consume_card(2, &"ACT_06")
	state.consume_card(1, &"CNT_01")
	snapshot.restore(state)
	check((state.hands[2] as Array).is_empty(), "소모된 개입 카드는 복구되지 않음")
	check((state.hands[1] as Array).is_empty(), "발동한 바이츠 더 더스트 자체도 소모된 채 유지")


func test_bites_the_dust_rollback_via_command_history_restores_turn_start_but_keeps_consumed_cards() -> void:
	var state := make_state()
	var stack: CommandStack = new_stack()
	place(state, 11, 2, [1])
	place(state, 21, 4, [3])
	state.give_card(2, &"CNT_01")
	state.turn_snapshot = TurnSnapshot.capture(state)
	var move_ctx: RuleContext = make_ctx(state, 2)
	var move_command := MoveCommand.new(1, 11, move_ctx)
	check(stack.execute_command(move_command, move_ctx), "이동도 커맨드로 이력에 남는다")
	check(move_command.report.captured_pawn_ids.has(21), "잡기 발생")
	var card: BaseCard = CardRegistry.get_card(&"CNT_01")
	var attack: int = int(state.attack_log[0]["id"])
	check(card.can_play(state, 2, {"attack": attack}), "피해자는 바이츠 더 더스트 사용 가능")
	check(not card.can_play(state, 1, {"attack": attack}), "가해자는 사용 불가")
	state.consume_card(2, &"CNT_01")
	check(exec(state, card.create_command(state, 2, {"attack": attack}), stack), "바이츠 더 더스트 실행")
	check_eq(state.get_pawn(11).current_tile_idx, 2, "이동한 말 복귀")
	check_eq(state.get_pawn(21).current_tile_idx, 4, "잡힌 말 복귀")
	check_eq(TurnSnapshot.capture(state).data, state.turn_snapshot.data, "턴 시작 시점과 동일")
	check(state.rollback_requested, "롤백 플래그")
	check((state.hands[2] as Array).is_empty(), "방어 카드는 소모된 채")
