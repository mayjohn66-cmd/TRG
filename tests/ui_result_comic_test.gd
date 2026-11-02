## 1.01 결과창 만화 컷: 사선 분할선 → 1위 칸 → Result·2nd·3rd·4th 0.08초 간격 탄성 슬라이드 → 1st 도장 impact, [Next Page]로 상세 결과표 넘김.
extends "res://tests/ui_fx_test.gd"
var checks := 0


func _expect(ok: bool, message: String) -> void:
	checks += 1
	super._expect(ok, message)


func settle(n: int = 4) -> void:
	for i: int in n:
		await process_frame


func _entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for rank: int in range(1, 5):
		var face := ColorRect.new()
		face.color = Color.BLACK
		out.append({"rank": rank, "name": "닉네임%d" % rank, "color": Color("ff6b6b"), "avatar": face, "art": null})
	return out


func _page_alone() -> void:
	var page := ResultComicPage.new()
	root.add_child(page)
	page.setup(_entries(), "카이지의 한방 역전법", "한 턴에 18칸 폭발 전진 성공!")
	await settle()
	var lines: Control = page.find_child("ComicLines", true, false)
	page.set_time(0.0)
	_expect(lines.get("progress") == 0.0 and not page.panels[0].visible and page.stamp.modulate.a == 0.0, "처음에는 분할선·패널·도장 모두 없음")
	page.set_time(ResultComicPage.LINES_END * 0.5)
	_expect(lines.get("progress") > 0.0 and lines.get("progress") < 1.0 and not page.panels[0].visible, "분할선이 패널보다 먼저 그어진다")
	page.set_time(ResultComicPage.LINES_END)
	_expect(is_equal_approx(float(lines.get("progress")), 1.0), "분할선이 다 그어진 뒤")
	# 패널 순서: Result → 2nd → 3rd → 4th, 0.08초 간격
	for index: int in range(1, 4):
		_expect(is_equal_approx(ResultComicPage.panel_start(index) - ResultComicPage.panel_start(index - 1), 0.08), "패널 %d은 앞 패널 0.08초 뒤" % index)
	_expect(ResultComicPage.PANEL_START >= ResultComicPage.LEFT_START, "1위 칸이 먼저 자리를 잡기 시작한 뒤 오른쪽 패널")
	page.set_time(ResultComicPage.panel_start(1) + 0.01)
	_expect(page.panels[0].visible and page.panels[1].visible and not page.panels[3].visible, "Result·2nd가 들어올 때 4th는 아직")
	page.set_time(ResultComicPage.panel_start(3) + 0.005)
	var start_offset: Vector2 = page.panels[3].position
	_expect(start_offset.x > 300.0 and start_offset.y > 0.0, "오른쪽 아래(사선 방향)에서 들어온다 (%s)" % start_offset)
	# 탄성(overshoot): 제자리를 살짝 지나쳤다가 돌아온다
	var overshoot: bool = false
	var t: float = ResultComicPage.panel_start(3)
	while t < ResultComicPage.panel_start(3) + ResultComicPage.PANEL_LEN:
		page.set_time(t)
		overshoot = overshoot or page.panels[3].position.x < -1.0
		t += 0.01
	_expect(overshoot, "cubic-bezier overshoot로 제자리를 지나쳤다가 돌아온다")
	page.set_time(ResultComicPage.panel_start(3) + ResultComicPage.PANEL_LEN)
	_expect(page.panels[3].position.length() < 0.5, "끝나면 제자리")
	_expect(ResultComicPage.panel_start(3) + ResultComicPage.PANEL_LEN * 0.55 <= ResultComicPage.STAMP_AT, "1st 도장은 마지막 패널이 닿은 뒤")
	page.set_time(ResultComicPage.STAMP_AT)
	_expect(page.stamp.modulate.a > 0.99 and page.stamp.scale.is_equal_approx(Vector2.ONE), "1st 도장 쾅")
	_expect(page.next_button.disabled, "등장 중에는 [Next Page]를 누를 수 없다")
	# 재생: impact 한 번, 패널 착지 4번(순서대로), 끝나면 [Next Page]
	var landed: Array[int] = []
	var impacts: Array[int] = [0]
	page.panel_landed.connect(func(index: int) -> void: landed.append(index))
	page.impact.connect(func() -> void: impacts[0] += 1)
	page.play(1.0)
	await create_timer(ResultComicPage.DURATION + 0.3).timeout
	_expect(landed == [0, 1, 2, 3], "탁! 탁! 탁! 착지 순서 (%s)" % [landed])
	_expect(impacts[0] == 1, "도장 impact는 한 번 (%d)" % impacts[0])
	_expect(not page.active and not page.next_button.disabled and page.next_button.modulate.a > 0.99, "등장이 끝나면 [Next Page]")
	var nexts: Array[int] = [0]
	page.next_pressed.connect(func() -> void: nexts[0] += 1)
	page.next_button.pressed.emit()
	_expect(nexts[0] == 1, "[Next Page]를 누르면 다음 쪽")
	# 누르면 건너뛴다
	var page2 := ResultComicPage.new()
	root.add_child(page2)
	page2.setup(_entries().slice(0, 2), "완주 피니시", "")
	var impacts2: Array[int] = [0]
	page2.impact.connect(func() -> void: impacts2[0] += 1)
	page2.play(1.0)
	await settle(2)
	page2.skip()
	_expect(impacts2[0] == 1 and not page2.active and page2.panels[1].position.length() < 0.5, "건너뛰기: impact 한 번 + 제자리 (2명 판도 동작)")
	page.queue_free()
	page2.queue_free()
	await settle()


func _run() -> void:
	MatchTelemetry.test_sender = func(_url: String, _body: PackedByteArray, _type: String) -> void: pass
	await _page_alone()
	_board._on_draft_auto_pressed()
	await settle(10)
	_board._announcer.cancel()
	_board._reset_presentation()
	_board._close_opening()
	_board._close_draft_overlay()
	_board._close_augment_review()
	_board._bot.set_enabled(false)
	_board.manager.set_process(false)
	var state: GameState = _board.state
	state.rankings = [1, 3, 2, 4] as Array[int]
	state.winner = 1
	state.rank_reasons[1] = VictoryChecker.ALL_HOME
	_board.instant_roll_for_test = false  # 연출을 켠다: 결과 1쪽(만화 컷)부터
	_board._show_result_overlay()
	var comic: ResultComicPage = _board._result_overlay.find_child("ResultComicPage", true, false) as ResultComicPage
	_expect(comic != null, "연출이 켜져 있으면 결과 1쪽 만화 컷부터")
	var restart: Button = _board._result_overlay.find_child("LobbyButton", true, false) as Button
	_expect(restart != null and not restart.is_visible_in_tree(), "상세 결과표는 [Next Page] 전까지 숨김")
	_expect(_board.result_comic_texts(1) == (["완주 피니시", "말 4개 모두 완주"] as Array[String]), "완주 우승의 승리 이름·조건")
	var frames: int = 0
	while comic != null and (not comic.visible or comic.active) and frames < 600:
		frames += 1
		await process_frame
	_expect(comic.visible and not comic.active and comic.stamp.modulate.a > 0.99, "등장이 끝나 1st 도장까지")
	var names: Array[String] = []
	for index: int in range(1, 4):
		names.append((comic.panels[index].get_node("Name") as Label).text)
	_expect(names == ([_board._player_name(3), _board._player_name(2), _board._player_name(4)] as Array[String]), "2nd·3rd·4th 패널 이름 (%s)" % [names])
	comic.next_button.pressed.emit()
	await create_timer(_board.RESULT_PAGE_IN + 0.25).timeout
	_expect(not is_instance_valid(comic) or comic.is_queued_for_deletion(), "넘긴 만화 컷은 치운다")
	_expect(restart.is_visible_in_tree(), "상세 결과표가 펼쳐진다")
	var detail: Control = restart
	while detail.get_parent() != _board._result_overlay:
		detail = detail.get_parent()
	_expect(absf(detail.position.x) < 1.0 and absf(detail.rotation) < 0.001, "상세 결과표가 제자리에 (x=%.1f)" % detail.position.x)
	_board._close_result_overlay()
	_board.instant_roll_for_test = true
	MatchTelemetry.test_sender = Callable()
	var board: MainBoard = _board
	_board = null
	board.queue_free()
	await settle()
	for failure: String in _failures:
		printerr("RESULT_COMIC_FAIL ", failure)
	print("RESULT_COMIC ", checks, " assertions; ", _failures.size(), " failures")
	quit(0 if _failures.is_empty() else 1)
