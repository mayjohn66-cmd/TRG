## 증강 선택 창이 떠 있는 동안 뒤의 보드·말 그림은 보내지 않는다 (30프레임 기기에서 창이 뜰 때 버벅이던 문제), 창이 닫히면 그대로 돌아온다.
extends "res://tests/ui_fx_test.gd"
var checks := 0


func _expect(ok: bool, message: String) -> void:
	checks += 1
	super._expect(ok, message)


func settle(n: int = 4) -> void:
	for i: int in n:
		await process_frame


func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	_board._announcer.cancel()
	_board._reset_presentation()
	_board._close_opening()
	_board._close_draft_overlay()
	_board._close_augment_review()
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)
	_board.pacing_enabled = false
	await settle(6)
	_expect(_board._board_layer.visible and _board._pawn_layer.visible, "증강 창이 없으면 보드·말이 보인다")
	_board.manager.change_state(TurnManager.State.PHASE_ROUND_START)
	_board._build_draft_overlay(1, 2)
	await settle()
	_expect(_board._draft_overlay != null and not _board._board_layer.visible and not _board._pawn_layer.visible, "증강 창이 떠 있으면 뒤의 보드·말은 그리지 않는다")
	# 다음 사람의 창으로 바뀌어도 (닫았다 다시 만들어도) 숨김이 유지된다
	_board._build_draft_overlay(2, 1)
	await settle()
	_expect(not _board._board_layer.visible and not _board._pawn_layer.visible, "창을 다시 만들어도 숨김 유지")
	_board._close_draft_overlay()
	await settle()
	_expect(_board._board_layer.visible and _board._pawn_layer.visible, "창이 닫히면 보드·말이 그대로 돌아온다")
	# 증강 확인 창(라운드 시작 요약)도 같다: 떠 있는 동안 숨기고, 닫으면 돌아온다
	var ids: Array = [AugmentRegistry.all()[0].augment_id]
	_board._draft_summary.clear()
	_board._draft_summary.append({"player": 1, "augment": ids[0], "text": ""})
	_board._show_augment_review([1, 2])
	await settle()
	_expect(_board._review_overlay != null and not _board._board_layer.visible, "증강 확인 창이 떠 있으면 보드는 그리지 않는다")
	_board._close_augment_review()
	await settle()
	_expect(_board._board_layer.visible and _board._pawn_layer.visible, "증강 확인 창이 닫히면 보드가 돌아온다")
	# 이미 닫힌 상태에서 또 닫아도 안전
	_board._close_draft_overlay()
	_expect(_board._board_layer.visible and _board._pawn_layer.visible, "중복 닫기도 안전")
	MatchTelemetry.test_sender = Callable()
	var board: MainBoard = _board
	_board = null
	board.queue_free()
	await settle()
	for failure: String in _failures:
		printerr("DRAFT_BACKDROP_FAIL ", failure)
	print("DRAFT_BACKDROP ", checks, " assertions; ", _failures.size(), " failures")
	quit(0 if _failures.is_empty() else 1)
