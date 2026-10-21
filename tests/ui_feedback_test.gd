# File: res://tests/ui_feedback_test.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 인게임 피드백 창 검증 - 상단 [피드백] / 결과 화면 [후기] 버튼, 글자 수 제한, 게임 스냅샷(진행·사람별 상태·법전·최근 로그 15줄),
#       복사 폴백, 로컬 가짜 웹후크 서버로 실제 POST(디스코드 형식) · 60초 쿨타임 · 실패 처리, 창과 HTTPRequest가 남지 않고 해제되는지, 언어 버튼(KO/EN/JA 폴백)
extends SceneTree

var board: MainBoard
var failures: Array[String] = []
var frames: int = 0


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 1:
		board = load("res://scenes/main_board.tscn").instantiate()
		board.instant_roll_for_test = true
		root.add_child(board)
	if frames == 3:
		_run()
	return false


func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _run() -> void:
	board._bot.set_enabled(false)
	board.ai_mode = false
	board.manager._draft_offers.clear()
	board.manager._draft_picks.clear()
	board.manager._begin_turn()
	board._close_draft_overlay()
	board._close_opening()
	board._announcer.cancel()
	board._record(1, "[color=#ffd43b]테스트 기록[/color] [lb]R1] 한 줄")
	FeedbackModal.reset_cooldown()
	# 상단 버튼
	var feedback_button: Button = board.find_child("FeedbackButton", true, false)
	var language_button: Button = board.find_child("LanguageButton", true, false)
	expect(feedback_button != null and feedback_button.text == L10n.tr_ui("btn.feedback"), "상단에 피드백 버튼")
	expect(language_button != null and language_button.text == "KO" and language_button.get_child_count() >= 1, "상단에 지구본 + KO 언어 버튼")
	feedback_button.pressed.emit()
	var modal: FeedbackModal = board.find_child("FeedbackModal", false, false)
	expect(modal != null, "피드백 버튼이 창을 연다")
	if modal == null:
		_finish()
		return
	expect(board._open_feedback() == modal, "이미 열려 있으면 새 창을 만들지 않는다")
	expect(modal.kind == FeedbackModal.Kind.BUG and (modal.find_child("Kind0", true, false) as Button).button_pressed, "기본 유형: 버그 제보")
	(modal.find_child("Kind1", true, false) as Button).button_pressed = true
	expect(modal.kind == FeedbackModal.Kind.BALANCE, "유형 버튼은 하나만 눌린다 (밸런스)")
	expect((modal.find_child("AttachCheck", true, false) as CheckBox).button_pressed, "스냅샷 첨부는 기본으로 켜져 있다")
	expect(modal.author() == L10n.tr_ui("feedback.anonymous") or modal.author() == GameSession.display_nickname(), "이름을 비우면 익명 교주")
	(modal.find_child("NameEdit", true, false) as LineEdit).text = ""
	expect(modal.author() == "익명 교주", "빈 이름 -> 익명 교주")
	# 글자 수
	modal.set_message("짧음")
	expect(modal.send() == &"too_short", "5자 미만은 보내지 않는다")
	modal.set_message("가".repeat(700))
	expect(modal.message().length() == FeedbackModal.MAX_LENGTH, "500자에서 잘린다 (%d)" % modal.message().length())
	modal.set_message("3라운드에 변이 물약을 골랐더니 말이 사라졌어요")
	# 스냅샷
	var snapshot: String = modal.snapshot()
	for part: String in ["[게임 스냅샷]", "라운드 1", "-- 플레이어 --", "P1 ", "기물:", "증강:", "-- 중앙 법전 --", "-- 최근 액션 로그", "테스트 기록 [R1] 한 줄"]:
		expect(snapshot.contains(part), "스냅샷에 '%s'" % part)
	expect(not snapshot.contains("[color"), "스냅샷의 로그는 꾸밈(BBCode)을 지운 글자")
	var report: String = modal.copy_report()
	expect(report.contains("밸런스") and report.contains("변이 물약") and report.contains("[게임 스냅샷]"), "복사 리포트 = 유형 + 내용 + 스냅샷")
	expect(modal.find_child("FeedbackToast", true, false) != null, "복사하면 토스트 알림")
	expect((modal.find_child("Status", true, false) as Label).text == L10n.tr_ui("feedback.copied"), "복사 완료 문구")
	(modal.find_child("AttachCheck", true, false) as CheckBox).button_pressed = false
	expect(not modal.build_report().contains("[게임 스냅샷]"), "첨부를 끄면 스냅샷이 빠진다")
	(modal.find_child("AttachCheck", true, false) as CheckBox).button_pressed = true
	# 주소가 없으면 복사로 안내
	modal.webhook_url = ""
	modal.form_url = ""
	expect(modal.send() == &"no_target", "웹후크·설문 주소가 없으면 복사로 안내")
	# 가짜 웹후크 서버로 실제 POST
	var server := TCPServer.new()
	var port: int = 18765
	while server.listen(port, "127.0.0.1") != OK and port < 18800:
		port += 1
	modal.webhook_url = "http://127.0.0.1:%d/hook" % port
	expect(modal.send() == &"webhook", "웹후크로 보낸다")
	expect(root.find_child("FeedbackRequest", true, false) != null, "요청 노드는 루트에 붙어 창을 닫아도 끝까지 간다")
	var body: String = await _serve_once(server, 204)
	await _wait_until(func() -> bool: return root.find_child("FeedbackRequest", true, false) == null, 5000)
	expect(root.find_child("FeedbackRequest", true, false) == null, "보낸 뒤 HTTPRequest가 해제된다")
	var payload: Variant = JSON.parse_string(body)
	expect(payload is Dictionary, "디스코드 웹후크 JSON 본문 (%s)" % body.substr(0, 80))
	if payload is Dictionary:
		expect(str(payload.get("content", "")).contains("변이 물약") and str(payload.get("content", "")).contains("익명 교주"), "content = 유형·작성자·내용")
		var embeds: Array = payload.get("embeds", [])
		expect(embeds.size() == 1 and str((embeds[0] as Dictionary).get("description", "")).begins_with("```") and str((embeds[0] as Dictionary).get("description", "")).contains("[게임 스냅샷]"), "embeds = 스냅샷 코드 블록")
	expect((modal.find_child("Status", true, false) as Label).text == L10n.tr_ui("feedback.sent"), "전송 완료 문구")
	expect(FeedbackModal.cooldown_left() > 50, "보내면 60초 쿨타임")
	modal.set_message("한 번 더 보내 봅니다")
	expect(modal.send() == &"cooldown", "쿨타임 중에는 다시 보내지 않는다")
	server.stop()
	# 실패: 닫힌 포트
	FeedbackModal.reset_cooldown()
	modal.webhook_url = "http://127.0.0.1:%d/hook" % port
	expect(modal.send() == &"webhook", "닫힌 주소로 보내 본다")
	await _wait_until(func() -> bool: return root.find_child("FeedbackRequest", true, false) == null, 8000)
	expect(root.find_child("FeedbackRequest", true, false) == null, "실패해도 HTTPRequest가 해제된다")
	expect((modal.find_child("Status", true, false) as Label).text == L10n.tr_ui("feedback.send_failed"), "실패 안내 (복사 폴백)")
	expect(FeedbackModal.cooldown_left() == 0, "실패는 쿨타임을 걸지 않는다")
	# 닫기 -> 해제
	(modal.find_child("CloseButton", true, false) as Button).pressed.emit()
	await process_frame
	await process_frame
	expect(board.find_child("FeedbackModal", false, false) == null, "닫으면 창이 해제된다")
	# 결과 화면의 후기 버튼
	board._show_result_overlay()
	var review: Button = board._result_overlay.find_child("ReviewFeedbackButton", true, false)
	expect(review != null, "결과 화면에 후기·밸런스 피드백 버튼")
	if review != null:
		review.pressed.emit()
		var from_result: FeedbackModal = board.find_child("FeedbackModal", false, false)
		expect(from_result != null and from_result.kind == FeedbackModal.Kind.BALANCE and from_result.context == "결과 화면", "결과 화면에서 열면 밸런스 의견으로 시작")
		if from_result != null:
			from_result.close_modal()
	board._close_result_overlay()
	# 언어 버튼: KO -> EN -> JA -> KO. 번역이 비어 있으면 한국어로 나온다.
	var saved_lang: String = L10n.current_lang
	language_button.pressed.emit()
	expect(L10n.current_lang == "en" and language_button.text == "EN", "언어 버튼: EN")
	expect(L10n.tr_ui("btn.roll") == "굴리기", "번역이 비어 있으면 한국어 폴백")
	language_button.pressed.emit()
	expect(L10n.current_lang == "ja" and language_button.text == "JA", "언어 버튼: JA")
	language_button.pressed.emit()
	expect(L10n.current_lang == "ko" and language_button.text == "KO", "언어 버튼: 다시 KO")
	L10n.set_language(saved_lang)
	GameSession.language = saved_lang
	GameSession.save_settings()
	FeedbackModal.reset_cooldown()
	_finish()


func _finish() -> void:
	board.queue_free()
	await process_frame
	if failures.is_empty():
		print("UI_FEEDBACK_OK: buttons, limits, snapshot, copy, webhook POST, cooldown, failure, cleanup, language")
	else:
		for failure: String in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)


## 가짜 웹후크: 연결 하나를 받아 요청 본문을 읽고 status로 답한다. 반환: 본문.
func _serve_once(server: TCPServer, status: int) -> String:
	var until: int = Time.get_ticks_msec() + 5000
	var peer: StreamPeerTCP = null
	while Time.get_ticks_msec() < until and peer == null:
		if server.is_connection_available():
			peer = server.take_connection()
		await process_frame
	if peer == null:
		failures.append("가짜 웹후크 서버에 연결이 오지 않았다")
		return ""
	var raw: PackedByteArray = PackedByteArray()
	var body_length: int = -1
	var header_end: int = -1
	while Time.get_ticks_msec() < until:
		peer.poll()
		var available: int = peer.get_available_bytes()
		if available > 0:
			raw.append_array(peer.get_data(available)[1])
			var text: String = raw.get_string_from_utf8()
			header_end = text.find("\r\n\r\n")
			if header_end != -1 and body_length == -1:
				for line: String in text.substr(0, header_end).split("\r\n"):
					if line.to_lower().begins_with("content-length:"):
						body_length = int(line.split(":")[1].strip_edges())
			if header_end != -1 and body_length != -1 and raw.size() >= _byte_offset(raw, header_end) + body_length:
				break
		await process_frame
	var reason: String = "No Content" if status == 204 else "OK"
	peer.put_data(("HTTP/1.1 %d %s\r\nContent-Length: 0\r\nConnection: close\r\n\r\n" % [status, reason]).to_utf8_buffer())
	peer.poll()
	await process_frame
	peer.disconnect_from_host()
	var full: String = raw.get_string_from_utf8()
	return full.substr(full.find("\r\n\r\n") + 4)


## 글자 위치 header_end(헤더는 ASCII)의 바이트 위치 + 빈 줄 4바이트.
func _byte_offset(_raw: PackedByteArray, header_end: int) -> int:
	return header_end + 4


func _wait_until(condition: Callable, timeout_msec: int) -> void:
	var until: int = Time.get_ticks_msec() + timeout_msec
	while not condition.call() and Time.get_ticks_msec() < until:
		await process_frame
