## 도장 알림(카드 발동!·공격!·함정 발동! 등)의 1배속 최소 표시 시간: 1.8초 아래로 줄지 않고(컴퓨터 차례 터보 포함), 라운드 표지 같은 짧은 알림은 제외한다.
extends "res://tests/ui_fx_test.gd"
var checks := 0


func _expect(ok: bool, message: String) -> void:
	checks += 1
	super._expect(ok, message)


func _first_queued() -> Dictionary:
	if not _board._announcer._current.is_empty():
		return _board._announcer._current
	var queue: Array = _board._announcer._queue
	return queue[0] if not queue.is_empty() else {}


func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	_expect(MainBoard.STAMP_MIN_SECONDS >= 1.7, "1배속 최소 시간은 1.7초 이상")
	for key: String in ["card", "attack", "defense", "trap", "trap_set", "skill", "tarot", "npc", "extra_turn"]:
		_expect(MainBoard.stamp_min_hold({"key": key, "sub": "P1"}) == MainBoard.STAMP_MIN_SECONDS, "%s 도장은 최소 시간이 있다" % key)
	_expect(MainBoard.stamp_min_hold({"key": "round"}) == 0.0 and MainBoard.stamp_min_hold({}) == 0.0, "라운드 표지·도장이 아닌 알림은 대상이 아니다")
	_board.pacing_enabled = true
	_board.instant_roll_for_test = false
	_board._announcer.cancel()
	_board._announce_now("카드 발동", "카드 발동!", "", Color.WHITE, null, 1.1, true, {"key": "card", "sub": "P1"})
	var shown: Dictionary = _first_queued()
	_expect(not shown.is_empty() and float(shown["duration"]) >= MainBoard.STAMP_MIN_SECONDS, "카드 발동! 알림은 1배속에서 1.8초 이상 (%s)" % str(shown.get("duration", "-")))
	_board._announcer.cancel()
	_board._announce_now("라운드", "ROUND 3", "", Color.WHITE, null, 1.0, true, {"key": "round"})
	shown = _first_queued()
	_expect(not shown.is_empty() and float(shown["duration"]) < MainBoard.STAMP_MIN_SECONDS, "라운드 표지는 짧게 그대로")
	_board._announcer.cancel()
	_board.pacing_enabled = false
	_board.instant_roll_for_test = true
	MatchTelemetry.test_sender = Callable()
	var board: MainBoard = _board
	_board = null
	board.queue_free()
	await process_frame
	for failure: String in _failures:
		printerr("STAMP_HOLD_FAIL ", failure)
	print("STAMP_HOLD ", checks, " assertions; ", _failures.size(), " failures")
	quit(0 if _failures.is_empty() else 1)
