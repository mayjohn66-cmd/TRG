# File: res://tests/test_lobby.gd
# Class: class_name TestLobby
# Role: 멀티플레이 로비의 순수 계층 검증 - 초대/응답 코드 형식(LobbyCode), 좌석 모델(LobbyModel), 수동 시그널링 흐름(RtcLink, 가짜 연결 사용)
class_name TestLobby
extends TestCase


# --- LobbyCode -------------------------------------------------------------

func _sample_candidates() -> Array:
	return [{"media": "0", "index": 0, "name": "candidate:1 1 UDP 2122252543 192.168.0.5 50000 typ host"}, {"media": "0", "index": 0, "name": "candidate:2 1 UDP 1686052607 1.2.3.4 50001 typ srflx raddr 0.0.0.0 rport 0"}]


func test_code_round_trip_keeps_every_field() -> void:
	var sdp: String = "v=0\r\no=- 1 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\na=group:BUNDLE 0\r\nm=application 9 UDP/DTLS/SCTP webrtc-datachannel\r\n한글도 있어요\r\n"
	var code: String = LobbyCode.encode(LobbyCode.KIND_OFFER, 3, sdp, _sample_candidates())
	check(code.begins_with(LobbyCode.PREFIX), "접두어")
	check(not code.contains("+") and not code.contains("/") and not code.contains("="), "복사·붙여넣기에 안전한 문자만 쓴다")
	var decoded: Dictionary = LobbyCode.decode(code)
	check(bool(decoded["ok"]), "해석 성공: %s" % str(decoded["error"]))
	check_eq(decoded["kind"], LobbyCode.KIND_OFFER, "종류")
	check_eq(decoded["peer_id"], 3, "좌석 번호")
	check_eq(decoded["sdp"], sdp, "SDP가 그대로")
	check_eq(decoded["candidates"], _sample_candidates(), "후보가 그대로")


func test_code_tolerates_whitespace_and_line_breaks_from_messengers() -> void:
	var code: String = LobbyCode.encode(LobbyCode.KIND_ANSWER, 2, "v=0\r\ns=x\r\n", _sample_candidates())
	var wrapped: String = "  " + code.substr(0, 30) + "\n" + code.substr(30, 40) + "\r\n " + code.substr(70) + "  \n"
	var decoded: Dictionary = LobbyCode.decode(wrapped)
	check(bool(decoded["ok"]), "줄바꿈·공백이 섞여도 읽는다")
	check_eq(decoded["kind"], LobbyCode.KIND_ANSWER, "종류 유지")


func test_code_rejects_garbage_with_friendly_messages() -> void:
	for bad: String in ["", "hello", "TRG1-", "TRG1-abcd", "TRG1-" + "A".repeat(40), "XXXX-abc"]:
		var decoded: Dictionary = LobbyCode.decode(bad)
		check(not bool(decoded["ok"]) and str(decoded["error"]) != "", "잘못된 코드는 거부: '%s'" % bad)
	var good: String = LobbyCode.encode(LobbyCode.KIND_OFFER, 2, "v=0\r\n", [])
	var truncated: Dictionary = LobbyCode.decode(good.substr(0, good.length() - 6))
	check(not bool(truncated["ok"]), "끝이 잘린 코드는 거부")
	var bad_seat: Dictionary = LobbyCode.decode(LobbyCode.encode(LobbyCode.KIND_OFFER, 9, "v=0\r\n", []))
	check(not bool(bad_seat["ok"]), "좌석 번호가 범위 밖이면 거부")
	var bad_sdp: Dictionary = LobbyCode.decode(LobbyCode.encode(LobbyCode.KIND_OFFER, 2, "not sdp", []))
	check(not bool(bad_sdp["ok"]), "SDP가 아니면 거부")


func test_realistic_sized_code_stays_reasonably_short() -> void:
	var lines: Array[String] = ["v=0", "o=- 4611731400430051336 2 IN IP4 127.0.0.1", "s=-", "t=0 0", "a=group:BUNDLE 0", "a=extmap-allow-mixed", "a=msid-semantic: WMS",
		"m=application 9 UDP/DTLS/SCTP webrtc-datachannel", "c=IN IP4 0.0.0.0", "a=ice-ufrag:abcd", "a=ice-pwd:0123456789abcdef0123456789", "a=ice-options:trickle",
		"a=fingerprint:sha-256 " + ":".join(PackedStringArray(["AB", "CD", "EF", "01", "23", "45", "67", "89", "AB", "CD", "EF", "01", "23", "45", "67", "89", "AB", "CD", "EF", "01", "23", "45", "67", "89", "AB", "CD", "EF", "01", "23", "45", "67", "89"])),
		"a=setup:actpass", "a=mid:0", "a=sctp-port:5000", "a=max-message-size:262144"]
	var sdp: String = "\r\n".join(PackedStringArray(lines)) + "\r\n"
	var code: String = LobbyCode.encode(LobbyCode.KIND_OFFER, 2, sdp, _sample_candidates())
	check(code.length() < 1100, "일반적인 코드는 메신저로 보내기 쉬운 길이 (%d자)" % code.length())


# --- LobbyModel ------------------------------------------------------------

func test_model_starts_with_host_only() -> void:
	var model := LobbyModel.new()
	model.setup_host("방장")
	check_eq(model.state_of(1), LobbyModel.SeatState.HUMAN, "1번은 방장")
	check_eq(model.name_of(1), "방장", "방장 이름")
	for seat: int in [2, 3, 4]:
		check_eq(model.state_of(seat), LobbyModel.SeatState.OPEN, "나머지는 비어 있다")
	check_eq(model.human_count(), 1, "사람 1명")
	check(model.can_start(), "초대 중인 사람이 없으면 시작할 수 있다 (빈 자리는 봇)")


func test_model_invite_join_leave_flow() -> void:
	var model := LobbyModel.new()
	model.setup_host("방장")
	check(model.invite(2), "열린 자리에 초대")
	check(not model.invite(2), "이미 초대 중인 자리에는 다시 초대할 수 없다")
	check(not model.invite(1), "방장 자리는 초대할 수 없다")
	check(model.has_pending_invite() and not model.can_start(), "초대 중에는 시작할 수 없다")
	check(model.guest_joined(2, "친구"), "연결되면 사람이 된다")
	check_eq(model.name_of(2), "친구", "이름")
	check_eq(model.human_count(), 2, "사람 2명")
	check(model.can_start(), "연결이 끝나면 시작할 수 있다")
	model.rename_guest(2, "새이름")
	check_eq(model.name_of(2), "새이름", "이름 갱신")
	check(model.guest_left(2), "나가면 빈 자리")
	check_eq(model.state_of(2), LobbyModel.SeatState.OPEN, "다시 열림")
	check(not model.guest_left(2), "빈 자리는 나갈 수 없다")


func test_model_bots_and_cancel() -> void:
	var model := LobbyModel.new()
	model.setup_host("방장")
	check(model.set_bot(3, true), "봇으로 채우기")
	check_eq(model.name_of(3), "컴퓨터 3", "봇 이름")
	check(not model.invite(3), "봇 자리는 초대할 수 없다")
	check(model.set_bot(3, false), "비우기")
	check(not model.set_bot(3, false), "빈 자리를 또 비울 수 없다")
	check(model.invite(4) and model.cancel_invite(4), "초대 취소")
	check_eq(model.state_of(4), LobbyModel.SeatState.OPEN, "취소하면 열림")
	check(model.invite(2) and model.guest_joined(2, "친구"), "한 명 입장")
	model.fill_open_with_bots()
	check_eq(model.state_of(3), LobbyModel.SeatState.BOT, "시작 시 빈 자리는 봇")
	check_eq(model.state_of(4), LobbyModel.SeatState.BOT, "시작 시 빈 자리는 봇")
	check_eq(model.state_of(2), LobbyModel.SeatState.HUMAN, "사람은 그대로")
	check_eq(model.first_open_seat(), -1, "열린 자리 없음")


func test_model_serializes_for_guests_and_rejects_bad_data() -> void:
	var host := LobbyModel.new()
	host.setup_host("방장")
	host.invite(2)
	host.guest_joined(2, "친구")
	host.set_bot(4, true)
	var guest := LobbyModel.new()
	var signalled: Array = []
	guest.changed.connect(func() -> void: signalled.append(true))
	check(guest.from_array(host.to_array()), "방장 명단을 받는다")
	check_eq(guest.to_array(), host.to_array(), "참가자 모델이 같아진다")
	check(not signalled.is_empty(), "변경 신호")
	check(not guest.from_array([]), "크기가 틀리면 거부")
	check(not guest.from_array([[0, "a"], [0, "a"], [0, "a"], [9, "a"]]), "상태값이 범위 밖이면 거부")
	check(not guest.from_array([[0, "a"], [0, "a"], [0, "a"], "x"]), "항목 형식이 틀리면 거부")
	check_eq(guest.to_array(), host.to_array(), "거부된 데이터는 기존 상태를 건드리지 않는다")


# --- RtcLink (가짜 연결) -----------------------------------------------------

func _link(tag: String = "fake") -> RtcLink:
	var connection := FakeRtcConnection.new()
	connection.tag = tag
	var link := RtcLink.new(connection)
	link.quiet_seconds = 0.05
	link.max_seconds = 0.5
	return link


func _wait_code(link: RtcLink) -> String:
	var result: Array = []
	link.code_ready.connect(func(code: String) -> void: result.append(code))
	var guard: int = 0
	while result.is_empty() and guard < 120:
		guard += 1
		await tree.process_frame
	return str(result[0]) if not result.is_empty() else ""


func test_manual_signaling_handshake_between_host_and_guest_links() -> void:
	var host: RtcLink = _link("host")
	var guest: RtcLink = _link("guest")
	check(host.setup() and guest.setup(), "연결 객체 초기화")
	host.start_offer(3)
	var invite: String = await _wait_code(host)
	check(invite.begins_with(LobbyCode.PREFIX), "초대 코드가 만들어진다")
	var offer: Dictionary = LobbyCode.decode(invite)
	check_eq(offer["kind"], LobbyCode.KIND_OFFER, "초대 코드 종류")
	check_eq(offer["peer_id"], 3, "초대 코드의 좌석")
	check_eq((offer["candidates"] as Array).size(), 2, "ICE 후보가 모두 담긴다")
	guest.accept_offer(invite)
	var answer: String = await _wait_code(guest)
	var answer_data: Dictionary = LobbyCode.decode(answer)
	check_eq(answer_data["kind"], LobbyCode.KIND_ANSWER, "응답 코드 종류")
	check_eq(answer_data["peer_id"], 3, "응답 코드도 같은 좌석")
	var guest_connection: FakeRtcConnection = guest.connection
	check_eq(guest_connection.remote[0], "offer", "참가자는 초대 SDP를 원격 설명으로 적용")
	check_eq(guest_connection.added_candidates.size(), 2, "참가자가 방장의 후보를 추가")
	check(host.accept_answer(answer), "방장이 응답 코드를 적용")
	var host_connection: FakeRtcConnection = host.connection
	check_eq(host_connection.remote[0], "answer", "방장은 응답 SDP를 원격 설명으로 적용")
	check_eq(host_connection.added_candidates.size(), 2, "방장이 참가자의 후보를 추가")


func test_link_rejects_wrong_kind_wrong_seat_and_garbage() -> void:
	var host: RtcLink = _link("host")
	host.setup()
	host.start_offer(2)
	var invite: String = await _wait_code(host)
	var errors: Array[String] = []
	host.failed.connect(func(message: String) -> void: errors.append(message))
	check(not host.accept_answer(invite), "초대 코드를 응답 코드 자리에 넣으면 거부")
	check(not host.accept_answer("엉터리"), "엉터리 코드는 거부")
	var other_seat: String = LobbyCode.encode(LobbyCode.KIND_ANSWER, 4, "v=0\r\n", _sample_candidates())
	check(not host.accept_answer(other_seat), "다른 좌석의 응답 코드는 거부")
	check_eq(errors.size(), 3, "거부할 때마다 안내 문구가 나온다")
	var guest: RtcLink = _link("guest")
	guest.setup()
	var guest_errors: Array[String] = []
	guest.failed.connect(func(message: String) -> void: guest_errors.append(message))
	guest.accept_offer(LobbyCode.encode(LobbyCode.KIND_ANSWER, 2, "v=0\r\n", []))
	check_eq(guest_errors.size(), 1, "참가자가 응답 코드를 초대 칸에 넣으면 안내")


func test_link_reports_failure_when_webrtc_is_unavailable_or_no_candidates() -> void:
	var broken := FakeRtcConnection.new()
	broken.initialize_result = ERR_UNAVAILABLE
	var link := RtcLink.new(broken)
	var errors: Array[String] = []
	link.failed.connect(func(message: String) -> void: errors.append(message))
	check(not link.setup(), "초기화 실패")
	check(errors.size() == 1 and errors[0].contains("WebRTC"), "WebRTC를 쓸 수 없다는 안내")
	var silent := FakeRtcConnection.new()
	silent.candidate_names = []
	var quiet_link := RtcLink.new(silent)
	quiet_link.quiet_seconds = 0.05
	quiet_link.max_seconds = 0.2
	quiet_link.setup()
	var failures: Array[String] = []
	quiet_link.failed.connect(func(message: String) -> void: failures.append(message))
	quiet_link.start_offer(2)
	var guard: int = 0
	while failures.is_empty() and guard < 120:
		guard += 1
		await tree.process_frame
	check_eq(failures.size(), 1, "후보가 하나도 없으면 실패를 알린다")
