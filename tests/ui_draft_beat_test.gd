# Role: 증강 창이 열리기 전 여운 박자 동안 화면 갱신이 계속 와도 증강 창이 결국 열리는지 검사.
#       (박자를 "움직임 대기"로 착각해 박자를 끝없이 다시 걸던 문제: 느린 기기·웹에서 드래프트에서 판이 멈췄다, 1.2.0 제보 "가마솥 들어가면 겜 멈춤")
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
	# 움직임이 끝나 여운 박자를 거는 상황을 만든 뒤, 박자 동안·박자 뒤로 매 프레임 화면을 갱신한다 (다른 연출·봇이 갱신을 부르는 것과 같다).
	board._close_draft_overlay()
	board._draft_wait_motion = true
	board._refresh_all()
	_expect(board._draft_overlay == null, "박자 동안에는 증강 창을 잠깐 닫는다")
	var start: int = Time.get_ticks_msec()
	var opened: bool = false
	while Time.get_ticks_msec() - start < 4000:
		board._refresh_all()
		await process_frame
		if board._draft_overlay != null and board._draft_overlay.visible:
			opened = true
			break
	_expect(opened, "갱신이 계속 와도 박자가 끝나면 증강 창이 다시 열린다 (%d ms)" % (Time.get_ticks_msec() - start))
	GameEnums.draft_start = saved_start
	board.queue_free()
	await process_frame
	if _failures.is_empty():
		print("UI_DRAFT_BEAT_OK")
		quit(0)
	else:
		for failure: String in _failures:
			print("UI_DRAFT_BEAT_FAIL: " + failure)
		quit(1)


func _expect(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
