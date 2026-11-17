# Role: 전문적 해킹 창이 굴림 연출(야추 다이스 등 보드 한가운데 판)을 가리지 않는지 검사 - 연출이 떠 있는 동안은 숨고, 끝나면 다시 보인다
extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	GameSession.mode = GameSession.MODE_AI
	var board: MainBoard = (load("res://scenes/main_board.tscn") as PackedScene).instantiate()
	root.add_child(board)
	var guard: int = 0
	while board._intro_blocks() and guard < 2400:
		guard += 1
		await process_frame
	board._bot.set_enabled(false)
	board.manager.set_process(false)
	var me: int = board.local_player_id
	board.manager.state.current_player = me
	board.manager._hack_turn_player = me
	board._refresh_hack_window()
	await process_frame
	var layer := board.get_node_or_null("HackWindow") as CanvasLayer
	_expect(layer != null, "해킹 턴이면 해킹 창이 뜬다")
	if layer != null:
		_expect(layer.visible, "굴림 연출이 없으면 해킹 창이 보인다")
		board._presenter.active = true
		await process_frame
		_expect(not layer.visible, "굴림 연출이 떠 있는 동안 해킹 창은 숨는다")
		board._presenter.active = false
		await process_frame
		_expect(layer.visible, "굴림 연출이 끝나면 해킹 창이 다시 보인다")
	board.queue_free()
	await process_frame
	if _failures.is_empty():
		print("UI_HACK_WINDOW_OK")
		quit(0)
	else:
		for failure: String in _failures:
			print("UI_HACK_WINDOW_FAIL: " + failure)
		quit(1)


func _expect(ok: bool, message: String) -> void:
	if not ok:
		_failures.append(message)
