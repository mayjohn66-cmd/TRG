# Role: 보드 위 함정 설명을 읽는 중에 증강 선택 창이 뜨면 설명이 닫히는지 검사.
#       (설명 패널이 z 90이라 증강 창 위에 계속 남아 보이던 문제, 1.2.0 제보 "罠の説明を読んでいる時に増強選択の時間になったら、罠の説明がずっと出ていました")
#       프로필·[내 증강] 같은 버튼 설명은 증강 창이 떠 있어도 볼 수 있어야 한다.
extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var saved_start: int = GameEnums.draft_start
	GameEnums.draft_start = 1
	GameSession.mode = GameSession.MODE_AI
	var board: MainBoard = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	board._bot.set_enabled(false)
	var guard: int = 0
	while (not board._draft_open or board._draft_overlay == null or not board._draft_overlay.visible) and guard < 3600:
		guard += 1
		await process_frame
	_expect(board._draft_overlay != null and board._draft_overlay.visible, "첫 증강 창이 열린다")
	# 증강 창이 뜨기 직전 상황: 창을 잠깐 닫고, 보드의 코너 함정(우이의 소원빌기) 칸에 커서를 올려 설명을 연다.
	board._close_draft_overlay()
	var tile: int = 5
	var trap := TileAttachment.new()
	trap.attachment_id = "TRP_C02"
	trap.owner_id = 2
	board.state.board.get_tile(tile).add_attachment(trap)
	var pointer: Vector2 = board._tile_center(tile) + board._pawn_layer.position
	board._hover_attachment_tip(pointer)
	await process_frame
	await process_frame
	_expect(board._tip_panel.visible and str(board._tip_source) == "tile:%d" % tile, "함정 칸에 커서를 올리면 설명이 뜬다 (source=%s)" % str(board._tip_source))
	# 증강 선택 시간이 되어 창이 다시 뜬다 (커서는 그대로 함정 칸 위)
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 4000 and (board._draft_overlay == null or not board._draft_overlay.visible):
		board._refresh_all()
		board._hover_attachment_tip(pointer)
		await process_frame
	_expect(board._draft_overlay != null and board._draft_overlay.visible, "증강 창이 다시 뜬다")
	await process_frame
	await process_frame
	board._hover_attachment_tip(pointer)
	await process_frame
	_expect(not board._tip_panel.visible, "증강 창이 뜨면 보드 함정 설명이 닫힌다")
	# 눌러서 고정한 보드 설명도 창이 덮으면 닫힌다
	board._tip_toggle("tile:%d" % tile, board._fill_attachment_tip.bind(tile))
	await process_frame
	await process_frame
	_expect(not board._tip_panel.visible, "눌러서 고정한 보드 설명도 증강 창 위에 남지 않는다")
	# 버튼 설명(Control source)은 증강 창이 떠 있어도 볼 수 있다
	var button: Control = board.find_child("MyAugmentsButton", true, false) as Control
	_expect(button != null, "[내 증강] 버튼이 있다")
	if button != null:
		board._tip_toggle(button, func() -> void: board._fill_profile_tip(board.local_player_id))
		await process_frame
		await process_frame
		_expect(board._tip_panel.visible, "[내 증강] 설명은 증강 창이 떠 있어도 열린다")
	# 증강 창을 닫은 보드에서 함정 설명을 눌러 고정한 채 [내 증강]을 눌러도 설명이 바뀐다 (문자열·버튼 출처 비교 오류가 없어야 한다)
	board._close_draft_overlay()
	board._tip_end()
	board._tip_toggle("tile:%d" % tile, board._fill_attachment_tip.bind(tile))
	await process_frame
	_expect(board._tip_panel.visible and board._tip_pinned, "증강 창이 없으면 함정 설명을 눌러 고정할 수 있다")
	if button != null:
		board._tip_toggle(button, func() -> void: board._fill_profile_tip(board.local_player_id))
		await process_frame
		_expect(board._tip_source == button and board._tip_panel.visible, "고정한 함정 설명이 떠 있어도 [내 증강]을 누르면 그 설명으로 바뀐다")
	GameEnums.draft_start = saved_start
	board.queue_free()
	await process_frame
	if _failures.is_empty():
		print("UI_TRAP_TIP_DRAFT_OK")
		quit(0)
	else:
		for failure: String in _failures:
			print("UI_TRAP_TIP_DRAFT_FAIL: " + failure)
		quit(1)


func _expect(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
