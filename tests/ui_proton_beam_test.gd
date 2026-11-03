## SUM_03 롤링 양성자빔 화면 점검: 소환하면 [소환] 알림 뒤에 빛 기둥이 하늘에서 내려앉고, 라운드 끝에는 통통 튀지 않고 스르륵 미끄러진다.
## 태울 말은 빔이 그 칸에 닿을 때까지 제자리에 보이다가 불타 날아가고, 함정 그림도 빔이 닿을 때 부서진다. 수명이 다하면 걷히며 사라진다.
extends "res://tests/ui_fx_test.gd"
var checks := 0


func _expect(ok: bool, message: String) -> void:
	checks += 1
	super._expect(ok, message)


func settle(n: int = 4) -> void:
	for i: int in n:
		await process_frame


func quiet() -> void:
	_board._announcer.cancel()
	_board._reset_presentation()
	_board._close_opening()
	_board._close_draft_overlay()
	_board._close_augment_review()
	_board._announced_round = _board.state.round_number
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)
	_board.pacing_enabled = true


func _beam_view(npc_id: int) -> ProtonBeamView:
	var view: Variant = _board._npc_views.get(npc_id)
	return view as ProtonBeamView if view != null and is_instance_valid(view) else null


## 눈으로 확인용: BEAM_CAPTURE_DIR이 있으면 장면을 PNG로 남긴다 (CI는 쓰지 않는다).
func _capture(title: String) -> void:
	var directory := OS.get_environment("BEAM_CAPTURE_DIR")
	if directory == "":
		return
	await process_frame
	root.get_texture().get_image().save_png(directory.path_join(title + ".png"))


func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	_board._on_draft_auto_pressed()
	await settle(10)
	quiet()
	var manager: TurnManager = _board.manager
	var state: GameState = _board.state
	manager.current_turn_index = manager.player_order.find(_board.local_player_id)
	manager.change_state(TurnManager.State.PHASE_TURN_BEGIN)
	quiet()
	var me: int = manager.current_player_id()
	for pawn: PlayerPawn in state.pawns:
		pawn.reset_to_start()
	_board._refresh_all()
	await settle()

	# 1) 소환: 빛 기둥 그림이 생기고, 알림이 지나간 뒤 하늘에서 내려앉는다
	state.hands[me] = [NpcSweep.BEAM_ID]
	manager.act(&"play_card", {"player_id": me, "card_id": NpcSweep.BEAM_ID, "tile": BoardSpec.halfway_tile})
	_expect(not state.npcs.is_empty() and state.npcs[0].is_beam(), "엔진: 롤링 양성자빔 소환")
	var beam_id: int = state.npcs[0].entity_id if not state.npcs.is_empty() else -1
	_board._refresh_all()
	await settle(2)
	var view: ProtonBeamView = _beam_view(beam_id)
	_expect(view != null, "판 위 그림이 빛 기둥(ProtonBeamView)")
	var landed: bool = false
	var saw_partial: bool = false
	var deadline: int = Time.get_ticks_msec() + 8000
	while Time.get_ticks_msec() < deadline:
		view = _beam_view(beam_id)
		if view != null and view.visible and view.drop > 0.0 and view.drop < 0.98:
			saw_partial = true
		if view != null and view.visible and view.drop >= 1.0 and saw_partial:
			landed = true
			break
		await process_frame
	await _capture("beam_landed")
	_expect(saw_partial, "기둥이 위에서부터 내려오는 중간 모습이 보인다 (강림)")
	_expect(landed, "강림이 끝나면 기둥이 땅에 닿아 서 있다")
	quiet()

	# 2) 라운드 끝 이동: 양쪽 바로 옆 칸에 말을 두면 어느 방향이든 하나는 탄다. 함정도 양쪽에 깐다
	var start: int = BoardSpec.halfway_tile
	var left: PlayerPawn = state.pawns_of(2 if me != 2 else 3)[0] if state.pawns_of(2 if me != 2 else 3).size() > 0 else null
	var right: PlayerPawn = state.pawns_of(me)[0]
	left.has_left_start = true
	left.current_tile_idx = start - 1
	right.has_left_start = true
	right.current_tile_idx = start + 1
	state.place_attachment(start - 2, TrapPit.new(me))
	state.place_attachment(start + 2, TrapPit.new(me))
	_board._refresh_all()
	await settle(6)
	quiet()
	manager._enter_neutral_npc_phase()
	var held_ids: Array = _board._beam_victims.keys()
	_expect(held_ids.size() == 1, "엔진이 태운 말 1개를 화면이 붙잡아 둔다 (%d개)" % held_ids.size())
	var burned_id: int = int(held_ids[0]) if not held_ids.is_empty() else -1
	var burned: PlayerPawn = state.get_pawn(burned_id)
	_expect(burned != null and not burned.has_left_start, "엔진에서는 이미 출발선으로 갔다")
	var burned_view: Node2D = _board._pawn_views.get(burned_id)
	var held_pos: Vector2 = burned_view.position if burned_view != null else Vector2.ZERO
	_expect(burned_view != null and burned_view.visible, "빔이 닿기 전에는 태워질 말이 제자리에 보인다")
	_expect(not _board._train_trap_hold.is_empty(), "빔이 닿기 전에는 지나갈 칸의 함정 그림도 남아 있다")
	var positions: Array[Vector2] = []
	var hidden_frames: int = 0
	var visible_before_contact: int = 0
	var run_frames: int = 0
	deadline = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		run_frames += 1
		view = _beam_view(beam_id)
		if view == null:
			break
		if not view.visible:
			hidden_frames += 1
		if positions.is_empty() or positions[-1].distance_to(view.position) > 0.01:
			positions.append(view.position)
			if positions.size() == 10 or positions.size() == 30:
				await _capture("beam_glide_%d" % positions.size())
		if _board._beam_victims.has(burned_id) and burned_view.visible and burned_view.position == held_pos:
			visible_before_contact += 1
		if not view.has_meta("npc_run") and run_frames > 10:
			break
		await process_frame
	var steps: int = (state.npcs[0].step_history.size() if not state.npcs.is_empty() else 0)
	_expect(positions.size() >= 12, "빛 기둥이 여러 프레임에 걸쳐 스르륵 움직였다 (%d개 위치)" % positions.size())
	_expect(hidden_frames == 0, "미끄러지는 동안 기둥이 사라지는 프레임이 없다 (%d프레임)" % hidden_frames)
	_expect(visible_before_contact > 0, "태워질 말은 빔이 닿을 때까지 제자리에 보였다")
	_expect(not _board._beam_victims.has(burned_id), "빔이 닿은 뒤에는 말을 놓아준다")
	_expect(_board._train_trap_hold.is_empty(), "지나간 칸의 함정 그림은 빔이 닿을 때 부서졌다")
	await create_timer(1.5).timeout
	_expect(burned_view != null and not burned_view.visible, "탄 말은 날아가고 보드에서 사라진다 (출발선)")
	var still: NeutralNPC = state.get_npc(beam_id)
	_expect(still != null and still.rounds_left == NpcSweep.BEAM_ROUNDS - 1, "잡아도 사라지지 않고 남은 수명 2")
	view = _beam_view(beam_id)
	_expect(view != null and view.rounds_left == NpcSweep.BEAM_ROUNDS - 1 and view.visible, "기둥 라벨이 남은 2라운드를 보인다")
	_expect(steps >= 0, "이동 기록 %d" % steps)
	quiet()

	# 3) 마지막 라운드: 수명이 다하면 걷히며 사라지고 그림도 치워진다
	still.rounds_left = 1
	manager._enter_neutral_npc_phase()
	_expect(state.get_npc(beam_id) == null, "엔진: 세 번째 이동 뒤 소멸")
	var gone: bool = false
	deadline = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if not _board._npc_views.has(beam_id):
			gone = true
			break
		await process_frame
	_expect(gone, "다 미끄러진 뒤 기둥 그림이 치워진다")
	await create_timer(1.5).timeout
	var leftover: int = 0
	for child: Node in _board._pawn_layer.get_children():
		if child is ProtonBeamView:
			leftover += 1
	_expect(leftover == 0, "걷히는 연출이 끝나면 빛 기둥 노드가 남지 않는다 (%d개)" % leftover)

	_board._reset_presentation()
	MatchTelemetry.test_sender = Callable()
	var board: MainBoard = _board
	_board = null
	board.queue_free()
	await settle()
	for failure: String in _failures:
		printerr("PROTON_BEAM_FAIL ", failure)
	print("PROTON_BEAM ", checks, " assertions; ", _failures.size(), " failures")
	quit(0 if _failures.is_empty() else 1)
