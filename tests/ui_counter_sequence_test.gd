extends SceneTree
# File: tests/ui_counter_sequence_test.gd
# Role: 처치 확정형 연출 순서 검증 - 잡기 뒤 방어 카드가 개입할 때 [대치 -> 방어 결정 -> 확정된 결과 한 번만] 순서를 지키는지 실제 판(봇 방어)으로 본다.
#       방어 성공(감나빗!): 처치 컷인·장외 사출 없이 말이 제자리, 처치 기록 없음.
#       반사(거울의 힘): 공격한 말이 역으로 컷인을 맞고 날아간다, 맞은 말은 제자리.
#       방어 없음: 그때 비로소 처치 컷인과 사출, 처치 기록.

var board: MainBoard = null
var failures: Array[String] = []
var _started: bool = false


func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run()
	return false


func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("UI_COUNTER_FAIL: " + message)


func _run() -> void:
	await _scenario(&"CNT_04")
	await _scenario(&"CNT_02")
	await _scenario(&"")
	if failures.is_empty():
		print("UI_COUNTER_SEQUENCE_OK: dodge keeps the pawn without a kill scene, mirror kills the attacker once, no counter plays the kill after the decision")
	quit(0 if failures.is_empty() else 1)


func _fresh_board() -> void:
	if board != null:
		board.queue_free()
		await process_frame
	board = load("res://scenes/main_board.tscn").instantiate()
	board.instant_roll_for_test = true
	root.add_child(board)
	await process_frame
	await process_frame
	board._bot.set_enabled(false)
	board.manager._draft_offers.clear()
	board.manager._draft_picks.clear()
	board.manager.review_enabled = false
	board.manager._begin_turn()
	board._close_draft_overlay()
	board._close_opening()
	board._intro_pending = false
	board._announcer.cancel()
	board._announced_round = board.state.round_number
	board._reset_presentation()
	board._fx_until_msec = 0


func _scenario(counter_card: StringName) -> void:
	await _fresh_board()
	var label: String = String(counter_card) if counter_card != &"" else "방어 없음"
	var manager: TurnManager = board.manager
	var state: GameState = board.state
	expect(manager.current_player_id() == 1 and manager.current_state == TurnManager.State.PHASE_TURN_BEGIN, "%s: P1 차례로 시작" % label)
	for player_id: int in [1, 2, 3, 4]:
		(state.hands[player_id] as Array).clear()
	if counter_card != &"":
		state.give_card(2, counter_card)
	var mine: PlayerPawn = state.get_pawn(11)
	var enemy: PlayerPawn = state.get_pawn(21)
	mine.current_tile_idx = 1
	mine.has_left_start = true
	mine.step_history.assign([1])
	enemy.current_tile_idx = 2
	enemy.has_left_start = true
	enemy.step_history.assign([2])
	state.tools[1] = ScriptedTool.new([1])
	board.instant_roll_for_test = false
	board._bot.bot_players.assign([2, 3, 4] as Array[int])
	board._bot.set_enabled(true)
	board._refresh_all()
	board._announcer.cancel()
	var enemy_home: Vector2 = (board._pawn_views[21] as Node2D).position
	var events: Array[StringName] = []
	manager.event_received.connect(func(kind: StringName, _data: Dictionary) -> void:
		if kind in [&"counter_offer", &"counter_resolved", &"counter_passed", &"move_resolved"]:
			events.append(kind))
	board._action_log.clear_entries()
	# 내 차례 배너가 끝나면 굴린다
	var waited: float = 0.0
	while board._ui_busy() and waited < 6.0:
		waited += 1.0 / 60.0
		await process_frame
	manager.act(&"proceed", {"player_id": 1})
	manager.act(&"roll", {"player_id": 1})
	if manager.current_state == TurnManager.State.PHASE_SELECT_PAWN:
		manager.act(&"select_pawn", {"player_id": 1, "pawn_id": 11})
	var victim_cutin: bool = false
	var reverse_cutin: bool = false
	var moved_while_pending: bool = false
	var cutin_while_pending: bool = false
	var enemy_flew: bool = false
	var settled: bool = false
	var deadline: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var cutin: CaptureCutin = board._capture_cutin
		if cutin.active:
			if cutin.attacker_avatar == board._avatar_for(1) and cutin.defender_avatar == board._avatar_for(2):
				victim_cutin = true
			if cutin.attacker_avatar == board._avatar_for(2) and cutin.defender_avatar == board._avatar_for(1):
				reverse_cutin = true
		var enemy_view: Node2D = board._pawn_views.get(21)
		if enemy_view != null and enemy_view.position.distance_to(enemy_home) > 40.0:
			enemy_flew = true
		if manager.counter_pending():
			cutin_while_pending = cutin_while_pending or cutin.active
			moved_while_pending = moved_while_pending or enemy_flew
		if events.has(&"move_resolved") and not manager.counter_pending() and not board._presentation_active() and not cutin.busy() and manager.current_player_id() != 1:
			settled = true
			break
	expect(settled, "%s: 판이 다음 차례로 넘어가고 연출이 끝난다 (events=%s)" % [label, str(events)])
	var log_text: String = "\n".join(PackedStringArray(board._action_log.lines()))
	expect(not cutin_while_pending and not moved_while_pending, "%s: 방어 결정 전에는 처치 컷인도 사출도 없다 (대치만)" % label)
	match counter_card:
		&"CNT_04":
			expect(events.has(&"counter_offer") and events.has(&"counter_resolved"), "감나빗: 방어 대기 -> 방어 발동 %s" % str(events))
			expect(not victim_cutin and not enemy_flew, "감나빗: 처치 컷인·장외 사출 없이 제자리 (컷인 %s, 날아감 %s)" % [victim_cutin, enemy_flew])
			expect(state.get_pawn(21).has_left_start and state.get_pawn(21).current_tile_idx == 2, "감나빗: 맞을 뻔한 말은 2번 칸에 그대로")
			expect(not log_text.contains("처치!"), "감나빗: 처치 기록이 없다")
		&"CNT_02":
			expect(events.has(&"counter_resolved"), "거울의 힘 발동")
			expect(not victim_cutin and not enemy_flew, "거울의 힘: 맞은 말에게는 처치 장면이 없다")
			expect(reverse_cutin, "거울의 힘: 공격한 쪽이 역으로 처치 컷인을 맞는다")
			expect(not state.get_pawn(11).has_left_start, "거울의 힘: 공격한 말은 출발선으로")
			expect(log_text.contains("1번 말") and log_text.contains("처치!"), "거울의 힘: 반격 처치가 기록된다")
		_:
			expect(not events.has(&"counter_offer"), "방어 카드가 없으면 방어 대기가 없다")
			expect(victim_cutin and enemy_flew, "방어 없음: 처치 컷인과 사출이 나온다")
			expect(log_text.contains("처치!"), "방어 없음: 처치 기록")
	board._bot.set_enabled(false)
