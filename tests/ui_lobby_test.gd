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
		GameSession.nickname = "테스터"
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
	_expect(_lobby.mode == Lobby.Mode.CHOOSE, "처음에는 멀티플레이 선택 화면")
	for node_name: String in ["RoomCodeInput", "JoinRoom", "HostCard"]:
		_expect(_lobby.find_child(node_name, true, false) != null, "비밀 결투 화면 요소: %s" % node_name)
	_expect((_lobby.find_child("HostCard", true, false) as Button).text == "새 방 만들기" and (_lobby.find_child("JoinRoom", true, false) as Button).text == "입장하기", "방 코드 입력 + [새 방 만들기]")
	_expect((_lobby._top["title"] as Label).text == "친선 줘팸터" and (_lobby._bottom["name"] as Label).text.contains("테스터"), "위 띠 제목과 아래 띠 이름")
	_lobby.start_hosting()
	await process_frame
	var service: LobbyService = _lobby.service
	_expect(_lobby.mode == Lobby.Mode.HOST and service.in_room() and service.is_host, "방 만들기를 누르면 방장이 된다")
	_expect(RoomCode.is_valid(service.room_code), "5자리 방 코드가 만들어진다: %s" % service.room_code)
	var badge: Label = _lobby.find_child("RoomCode", true, false)
	_expect(badge != null and badge.text == "[ 방 코드: %s ]" % service.room_code, "상단에 방 코드 배지")
	_expect(_lobby.find_child("CopyRoomCode", true, false) != null, "코드 복사 버튼")
	_expect(_lobby._seat_box.get_child_count() == 4, "좌석 행 4개")
	var rules_line: Label = _lobby.find_child("RoomRulesLine", true, false)
	_expect(rules_line != null and rules_line.text.begins_with("[방 규칙]") and rules_line.text.contains("빈자리 컴퓨터"), "대기실에 방 규칙 한 줄 (%s)" % (rules_line.text if rules_line != null else "없음"))
	GameSession.apply_preset(MatchRules.PRESET_CLASSIC)
	service.broadcast_rules()
	await process_frame
	_expect(rules_line.text.contains("클래식 완주전") and rules_line.text.contains("법전 끄기"), "프리셋을 바꾸면 대기실 줄도 바뀐다 (%s)" % rules_line.text)
	GameSession.reset_rules()
	service.broadcast_rules()
	_expect(service.model.state_of(1) == LobbyModel.SeatState.HUMAN and service.model.name_of(1) == "테스터", "1번 좌석은 내 닉네임의 방장")
	var title1: Label = _lobby._seat_box.find_child("SeatTitle1", true, false)
	_expect(title1 != null and title1.text.begins_with("방장"), "P1은 방장으로 표시")
	var title2: Label = _lobby._seat_box.find_child("SeatTitle2", true, false)
	_expect(title2 != null and title2.text == "빈 자리", "자동 초대가 꺼진 테스트 환경에서는 빈 자리")
	_expect(_lobby._start_button != null and not _lobby._start_button.disabled, "방장 혼자(나머지는 AI)면 시작할 수 있다")
	_expect(_lobby.find_child("ManualToggle", true, false) == null and _lobby.find_child("InviteCode2", true, false) == null, "수동 코드 연결 UI는 없다 (긴 코드는 화면에 나오지 않는다)")
	_lobby.copy_room_code()
	if DisplayServer.get_name() != "headless":
		_expect(DisplayServer.clipboard_get() == service.room_code, "복사 버튼이 방 코드를 클립보드에 넣는다")
	# 시작 시 자동으로 초대를 올리는 방(자리가 INVITED)의 표시
	_expect(service.model.invite(2), "2번 좌석 초대")
	service.roster_changed.emit()
	await process_frame
	title2 = _lobby._seat_box.find_child("SeatTitle2", true, false)
	_expect(title2 != null and title2.text == "입장 대기 중...", "P2는 입장 대기 중...")
	_expect(_lobby._seat_box.find_child("FillBot2", true, false) != null, "대기 중인 자리에 AI 봇으로 채우기 버튼")
	# 친구 입장
	service.model.guest_joined(2, "친구")
	service.roster_changed.emit()
	await process_frame
	title2 = _lobby._seat_box.find_child("SeatTitle2", true, false)
	_expect(title2 != null and title2.text.begins_with("입장 완료!") and title2.text.contains("친구"), "P2: 입장 완료!")
	_expect(service.model.can_start(), "초대가 끝나면 시작 조건 충족")
	_expect(not _lobby._start_button.disabled and _lobby._start_button.text.contains("사람 2명") and _lobby._start_button.text.contains("AI 없음"), "친구가 들어오면 사람끼리(AI 없음) 시작할 수 있다: %s" % _lobby._start_button.text)
	_lobby.start_game()
	_expect(_lobby.game_started and GameSession.net_active and GameSession.net_is_host, "시작하면 온라인 설정이 세션에 들어간다")
	_expect(str(GameSession.net_players) == "[1, 2]" and GameSession.net_bots.is_empty(), "2인 대전: 비어 있는 자리는 빠지고 AI도 없다 (%s)" % str(GameSession.net_players))
	_expect(GameSession.net_names.get(2, "") == "친구" and GameSession.net_seed > 0, "이름과 시드가 전달된다")
	GameSession.clear_net()
	_lobby.game_started = false
	# 봇 채우기 / 비우기 (초대 중인 자리도 바로 봇으로)
	_expect(service.model.invite(3), "3번 좌석 초대")
	service.set_bot(3, true)
	await process_frame
	_expect(service.model.state_of(3) == LobbyModel.SeatState.BOT, "초대 중인 자리도 AI 봇으로 채울 수 있다")
	var title3: Label = _lobby._seat_box.find_child("SeatTitle3", true, false)
	_expect(title3 != null and title3.text == "AI 봇", "P3: AI 봇")
	service.set_bot(3, false)
	_expect(service.model.state_of(3) == LobbyModel.SeatState.OPEN, "비우면 다시 열린 좌석")
	# 릴레이 장애 안내
	service.relay_status_changed.emit(false)
	await process_frame
	_expect(_lobby._status.text.contains("연결 서버") and not _lobby._status.text.contains("수동"), "릴레이가 막히면 안내가 나온다 (수동 연결 안내는 없다)")
	# 나가기
	_lobby.leave_room()
	await process_frame
	_expect(_lobby.mode == Lobby.Mode.CHOOSE and not service.in_room(), "방을 닫으면 선택 화면으로 돌아간다")
	# 빠른 랜덤 매칭: 열린 방이 없으면 내가 방장이 되어 기다리고, 15초가 지나면 AI로 채워 시작한다
	var broker := MemoryBroker.new()
	MemoryBroker.reset_all()
	_lobby.add_child(broker)
	service.broker = broker
	_lobby.quick.auto_tick = false
	_lobby.quick.set_process(false)
	_lobby.start_quick_match()
	await process_frame
	_expect(_lobby.mode == Lobby.Mode.QUICK and _lobby.quick.state == QuickMatch.State.HOSTING, "열린 방이 없으면 빠른 매칭은 방장으로 기다린다")
	_expect(_lobby._quick_status.text.contains("매칭 중... 다른 교주님을 찾고 있습니다 (경과 시간: 0초)"), "대기 문구: %s" % _lobby._quick_status.text)
	_lobby.quick.tick(4.0)
	_lobby._refresh_quick()
	_expect(_lobby._quick_status.text.contains("경과 시간: 4초"), "경과 시간이 올라간다")
	_expect(_lobby._quick_count.text.contains("11초") and _lobby._quick_count.text.contains("1/4"), "남은 시간·인원 표시: %s" % _lobby._quick_count.text)
	_expect(_lobby._seat_box.get_child_count() == 4 and not _lobby._quick_now_button.disabled, "자리 4개와 [지금 바로 시작] 버튼")
	_lobby.quick.tick(11.0)
	_expect(_lobby.game_started, "15초가 지나면 빈자리를 AI로 채우고 게임을 시작한다")
	_expect(service.model.state_of(2) == LobbyModel.SeatState.BOT and service.model.state_of(4) == LobbyModel.SeatState.BOT, "빈자리는 AI 봇")
	_expect(GameSession.mode == GameSession.MODE_AI, "게임 모드는 AI 대전으로 넘어간다")
	_lobby.game_started = false
	_lobby.leave_room()
	_expect(_lobby.quick.state == QuickMatch.State.IDLE and not service.in_room(), "취소하면 대기열에서 빠진다")
	_lobby.start_quick_match()
	await process_frame
	_lobby._quick_now_button.pressed.emit()
	_expect(_lobby.game_started, "[지금 바로 시작]은 기다리지 않고 시작한다")
	_lobby.game_started = false
	_lobby.leave_room()
	# 친선전 방: 혼자 시작 버튼
	_lobby.start_hosting()
	await process_frame
	_lobby._start_button.pressed.emit()
	_expect(_lobby.game_started and service.model.state_of(3) == LobbyModel.SeatState.BOT, "친선전 방도 혼자면 AI와 시작")
	_lobby.game_started = false
	_lobby.leave_room()
	# 참가자 화면: 방 코드 입력 하나
	_lobby.start_guest()
	await process_frame
	_expect(_lobby.mode == Lobby.Mode.CHOOSE, "방 코드 입력 화면")
	var input: LineEdit = _lobby._guest_box.find_child("RoomCodeInput", true, false)
	_expect(input != null and input.max_length == 5, "방 코드 5자리 입력창")
	_expect(_lobby._guest_box.find_child("JoinRoom", true, false) != null, "방 입장하기 버튼")
	_expect(_lobby.find_child("InviteInput", true, false) == null, "긴 초대 코드 입력창은 없다")
	input.text = "7k9m2"
	input.text_changed.emit("7k9m2")
	_expect(input.text == "7K9M2", "입력은 대문자로 정리된다")
	input.text = "7K9"
	input.text_changed.emit("7K9")
	_lobby.join_with_room_code()
	_expect(_lobby._status.text.contains("5자리") and not _lobby._guest_busy, "5자리가 아니면 안내만 하고 시작하지 않는다")
	# 존재하지 않는 방
	input.text = "7K9M2"
	input.text_changed.emit("7K9M2")
	_lobby.join_with_room_code()
	await process_frame
	_expect(_lobby._status.text.contains("찾지 못했습니다") and not _lobby._guest_busy, "없는 방: 안내 후 다시 입력 가능")
	# 릴레이 불통
	broker.offline = true
	input = _lobby._guest_box.find_child("RoomCodeInput", true, false)
	input.text = "7K9M2"
	input.text_changed.emit("7K9M2")
	_lobby.join_with_room_code()
	await process_frame
	_expect(_lobby._status.text.contains("중계 서버") and not _lobby._status.text.contains("수동"), "릴레이 불통: 안내만 나온다")
	broker.offline = false
	# 방은 있는데 이 환경에서 WebRTC를 못 쓰는 경우 - 후보를 모두 시도해 본 뒤 실패를 알린다
	var code: String = LobbyCode.encode(LobbyCode.KIND_OFFER, 2, "v=0\r\ns=x\r\n", [{"media": "0", "index": 0, "name": "candidate:1 1 UDP 1 1.1.1.1 1 typ host"}])
	var host_side := RoomSignaling.new(broker, "7K9M2")
	host_side.post_offer(2, "AAAAAA", code, Callable())
	host_side.post_offer(3, "BBBBBB", code, Callable())
	input = _lobby._guest_box.find_child("RoomCodeInput", true, false)
	input.text = "7K9M2"
	input.text_changed.emit("7K9M2")
	_lobby.join_with_room_code()
	await process_frame
	_expect(_lobby._status.text != "" and not _lobby._guest_busy and not service.in_room(), "연결을 못 맺으면 실패를 알리고 방에서 빠진다")
	_expect(_lobby.mode == Lobby.Mode.CHOOSE and _lobby.find_child("JoinFailedPopup", false, false) != null, "입장 실패는 팝업으로 알리고 로비(코드 입력) 화면으로 돌아간다")
	(_lobby.find_child("JoinFailedPopup", false, false).find_child("Confirm", true, false) as Button).pressed.emit()
	await process_frame
	_expect(_lobby.find_child("JoinFailedPopup", false, false) == null, "[확인]으로 팝업을 닫는다")
	# 응답 없는 릴레이: "방장과 연결하는 중..."에서 무한 대기하지 않고 감시 타임아웃으로 돌려보낸다
	MemoryBroker.reset_all()
	broker.silent = true
	input = _lobby._guest_box.find_child("RoomCodeInput", true, false)
	input.text = "7K9M2"
	input.text_changed.emit("7K9M2")
	_lobby.join_with_room_code()
	await process_frame
	_expect(_lobby._guest_busy and _lobby.find_child("JoinFailedPopup", false, false) == null, "응답을 기다리는 동안은 연결 중")
	service.check_join_watchdog(Time.get_ticks_msec() + int(service.signaling_timeout_seconds * 1000.0) + 500)
	await process_frame
	var popup: Node = _lobby.find_child("JoinFailedPopup", false, false)
	_expect(popup != null and (popup.find_child("Message", true, false) as Label).text == LobbyService.JOIN_TIMEOUT_MESSAGE, "타임아웃 안내 팝업: 방 연결에 실패했습니다...")
	_expect(_lobby.mode == Lobby.Mode.CHOOSE and not _lobby._guest_busy and not service.in_room(), "타임아웃 뒤 로비 화면으로 돌아가 다시 입력할 수 있다")
	_expect((_lobby._guest_box.find_child("RoomCodeInput", true, false) as LineEdit).text == "7K9M2", "입력한 방 코드는 남겨 둔다")
	broker.silent = false
	popup.queue_free()
	_lobby.start_guest()
	await process_frame
	service.joined.emit()
	service.model.setup_host("방장")
	service.model.guest_joined(2, "테스터")
	await process_frame
	_expect(_lobby._guest_connected and _lobby._guest_box.find_child("SeatTitle4", true, false) != null and _lobby._guest_box.find_child("SeatTitle2", true, false).text.contains("테스터"), "입장하면 좌석 카드 4장 명단이 보인다")
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
