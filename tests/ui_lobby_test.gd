# File: res://tests/ui_lobby_test.gd
# Class: (SceneTree 스크립트, class_name 없음)
# Role: 로비 화면 흐름 검증(헤드리스, 실제 WebRTC 없이 서비스 신호를 직접 흘려 넣는다) - 방 만들기 -> 좌석 행 4개 -> 초대 코드 표시/응답 붙여넣기 -> 사람 입장/봇/내보내기, 참가 화면 입력/응답 코드/입장 후 명단
extends SceneTree

var _lobby: Lobby = null
var _frames: int = 0
var _failures: Array[String] = []
var _started: bool = false


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 1:
		_lobby = load("res://scenes/lobby.tscn").instantiate()
		_lobby.change_scene_enabled = false
		root.add_child(_lobby)
		_lobby.service.offline_for_test = true
	if _frames == 3 and not _started:
		_started = true
		_run()
	return false


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _run() -> void:
	GameSession.nickname = "테스터"
	_expect(_lobby.mode == Lobby.Mode.CHOOSE, "처음에는 방 만들기/참가 선택 화면")
	_lobby.start_hosting()
	await process_frame
	var service: LobbyService = _lobby.service
	_expect(_lobby.mode == Lobby.Mode.HOST and service.in_room() and service.is_host, "방 만들기를 누르면 방장이 된다")
	_expect(_lobby._seat_box.get_child_count() == 4, "좌석 행 4개")
	_expect(service.model.state_of(1) == LobbyModel.SeatState.HUMAN and service.model.name_of(1) == "테스터", "1번 좌석은 내 닉네임의 방장")
	_expect(_lobby._start_button != null and _lobby._start_button.disabled, "게임 화면 연동 전까지 시작 버튼은 잠겨 있다")
	# 초대 코드: 만드는 중 -> 코드 표시
	_expect(service.model.invite(2), "2번 좌석 초대")
	service.roster_changed.emit()
	await process_frame
	_expect(_lobby._seat_box.find_child("InviteCode2", true, false) == null, "코드가 오기 전에는 코드 상자가 없다")
	var code: String = LobbyCode.encode(LobbyCode.KIND_OFFER, 2, "v=0\r\ns=x\r\n", [{"media": "0", "index": 0, "name": "candidate:1 1 UDP 1 1.1.1.1 1 typ host"}])
	service.invite_ready.emit(2, code)
	await process_frame
	var invite_box: TextEdit = _lobby._seat_box.find_child("InviteCode2", true, false)
	_expect(invite_box != null and invite_box.text == code and not invite_box.editable, "초대 코드가 읽기 전용 상자에 보인다")
	var answer_box: TextEdit = _lobby._seat_box.find_child("AnswerCode2", true, false)
	_expect(answer_box != null and answer_box.editable, "응답 코드를 붙여 넣을 상자가 있다")
	answer_box.text = "붙여넣은 내용"
	answer_box.text_changed.emit()
	service.roster_changed.emit()  # 다시 그려도 입력 내용이 유지된다
	await process_frame
	answer_box = _lobby._seat_box.find_child("AnswerCode2", true, false)
	_expect(answer_box != null and answer_box.text == "붙여넣은 내용", "다시 그려도 붙여 넣은 응답 코드가 남는다")
	_lobby.copy_text(code)
	if DisplayServer.get_name() != "headless":
		_expect(DisplayServer.clipboard_get() == code, "복사 버튼이 클립보드에 코드를 넣는다")
	_lobby.submit_answer(2)
	# 오류 문구
	service.link_failed.emit(2, "잘못된 코드입니다")
	await process_frame
	_expect(str(_lobby._seat_errors.get(2, "")) == "잘못된 코드입니다", "좌석 오류 문구가 저장된다")
	# 친구 입장
	service.model.guest_joined(2, "친구")
	service.roster_changed.emit()
	await process_frame
	_expect(service.model.can_start(), "초대가 끝나면 시작 조건 충족")
	_lobby._seat_errors.clear()
	# 봇 채우기 / 비우기
	service.set_bot(3, true)
	await process_frame
	_expect(service.model.state_of(3) == LobbyModel.SeatState.BOT, "컴퓨터로 채우면 봇 좌석")
	service.set_bot(3, false)
	_expect(service.model.state_of(3) == LobbyModel.SeatState.OPEN, "비우면 다시 열린 좌석")
	# 나가기
	_lobby.leave_room()
	await process_frame
	_expect(_lobby.mode == Lobby.Mode.CHOOSE and not service.in_room(), "방을 닫으면 선택 화면으로 돌아간다")
	# 참가자 화면
	_lobby.start_guest()
	await process_frame
	_expect(_lobby.mode == Lobby.Mode.GUEST and _lobby._guest_box.find_child("InviteInput", true, false) != null, "참가 화면에 초대 코드 입력 상자")
	_lobby._guest_invite_text = "엉터리"
	_lobby.join_with_code()
	await process_frame
	_expect(_lobby._status.text != "", "잘못된 초대 코드는 안내 문구가 나온다")
	service.answer_ready.emit("TRG1-응답코드")
	await process_frame
	var output: TextEdit = _lobby._guest_box.find_child("AnswerOutput", true, false)
	_expect(output != null and output.text == "TRG1-응답코드" and not output.editable, "응답 코드가 읽기 전용으로 보인다")
	service.joined.emit()
	service.model.setup_host("방장")
	service.model.guest_joined(2, "테스터")
	await process_frame
	_expect(_lobby._guest_connected and _lobby._guest_box.get_child_count() >= 4, "입장하면 좌석 명단이 보인다")
	service.left_room.emit("방장과의 연결이 끊어졌습니다.")
	await process_frame
	_expect(_lobby.mode == Lobby.Mode.CHOOSE, "연결이 끊기면 선택 화면으로 돌아간다")
	if _failures.is_empty():
		print("UI_LOBBY_OK")
		quit(0)
	else:
		for message: String in _failures:
			printerr("UI_LOBBY_FAIL: " + message)
		quit(1)
