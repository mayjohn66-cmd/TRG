# File: res://tests/test_match_telemetry.gd
# Class: class_name TestMatchTelemetry
# Role: 매치 완료 알림 - 한 줄 문구·모드·우승 방식 이름, 테스트·데스크톱에서는 보내지 않음, 켜졌을 때 웹후크 본문(조용한 알림·멘션 차단·개인정보 없음)
class_name TestMatchTelemetry
extends TestCase


func _tag() -> String:
	return "[%s 매치 완료 알림]" % String.chr(0x1F4CA)


func cleanup() -> void:
	MatchTelemetry.test_force_enabled = false
	MatchTelemetry.test_sender = Callable()
	super()


func test_line_has_mode_rounds_and_win_kind() -> void:
	check_eq(MatchTelemetry.build_line("놀이터", 13, "특수승리"), _tag() + " 놀이터 | 13라운드 | 특수승리", "한 줄 문구")
	check_eq(MatchTelemetry.build_line("온라인", 8, "일반", "0.9.0+abc1234"), _tag() + " 온라인 | 8라운드 | 일반 | v0.9.0+abc1234", "버전이 붙는다")
	check_eq(MatchTelemetry.mode_label(false, true), "놀이터", "컴퓨터와 대전")
	check_eq(MatchTelemetry.mode_label(true, true), "온라인", "온라인")
	check_eq(MatchTelemetry.mode_label(false, false), "4인 수동", "4인 수동")
	check_eq(MatchTelemetry.win_label(VictoryChecker.ALL_HOME), "일반", "말 4개 완주")
	check_eq(MatchTelemetry.win_label(&"LAW_01"), "특수승리", "특수 승리 교칙")


func test_nothing_is_sent_outside_a_web_build() -> void:
	var sent: Array = []
	MatchTelemetry.test_sender = func(url: String, _body: PackedByteArray, _type: String) -> void: sent.append(url)
	check(not MatchTelemetry.is_active(), "에디터·테스트에서는 꺼져 있다")
	check(not MatchTelemetry.report_match(null, false, true, 5, VictoryChecker.ALL_HOME), "보내지 않았다")
	check(sent.is_empty(), "전송 함수도 불리지 않는다")


func test_enabled_report_is_a_quiet_one_line_without_personal_data() -> void:
	var sent: Array = []
	MatchTelemetry.test_force_enabled = true
	MatchTelemetry.test_sender = func(url: String, body: PackedByteArray, content_type: String) -> void: sent.append([url, body.get_string_from_utf8(), content_type])
	check(MatchTelemetry.report_match(null, false, true, 13, &"LAW_01"), "보냈다")
	check_eq(sent.size(), 1, "한 번")
	check_eq(sent[0][0], FeedbackModal.DISCORD_WEBHOOK_URL, "전용 주소가 없으면 피드백 웹후크를 쓴다")
	var text: String = sent[0][1]
	check(text.contains(_tag() + " 놀이터 | 13라운드 | 특수승리"), "본문에 한 줄 로그")
	check(text.contains("\"flags\":4096"), "알림음 없이 조용히")
	check(text.contains("\"allowed_mentions\":{\"parse\":[]}"), "멘션은 막는다")
	check(not text.contains(GameSession.display_nickname()) or GameSession.display_nickname() == "", "닉네임은 보내지 않는다")
	check((sent[0][2] as String).begins_with("multipart/form-data; boundary="), "사전 확인 없이 가는 multipart")
