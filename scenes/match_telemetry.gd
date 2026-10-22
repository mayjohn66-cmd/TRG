# File: res://scenes/match_telemetry.gd
# Class: class_name MatchTelemetry
# Role: 한 판이 결과 화면까지 끝났을 때 📊 매치 완료 알림 한 줄을 디스코드 웹후크로 조용히 보낸다 (하루·시간당 몇 판이 플레이되는지 보는 용도).
#       개인 정보는 보내지 않는다: 닉네임·방 코드·접속 정보 없이 모드·진행 라운드·우승 방식·버전만 간다.
#       웹 빌드에서만 보낸다 (에디터·데스크톱·테스트에서는 아무것도 보내지 않는다). 끄려면 ENABLE_MATCH_TELEMETRY를 false로.
#       웹 페이지에 구글 애널리틱스 슬롯(web/shell.html의 TRG_GA_ID)이 켜져 있으면 같은 내용을 window.trgTrack으로도 알린다.
class_name MatchTelemetry
extends RefCounted

## 매치 완료 알림 켜기/끄기.
const ENABLE_MATCH_TELEMETRY: bool = true
## 알림을 보낼 웹후크. 비워 두면 피드백 웹후크(FeedbackModal.DISCORD_WEBHOOK_URL)를 쓴다 (통계 전용 채널을 따로 쓰고 싶을 때 채운다).
const TELEMETRY_WEBHOOK_URL: String = ""
const REQUEST_TIMEOUT_SECONDS: float = 10.0
## 📊 이모지는 게임 글꼴에 없어서 글자 코드로 만든다 (디스코드로만 가고 게임 화면에는 나오지 않는다).
static func tag() -> String:
	return "[%s 매치 완료 알림]" % String.chr(0x1F4CA)

## 테스트가 바꿔 끼우는 전송 함수: (url: String, body: PackedByteArray, content_type: String) -> void. 비어 있으면 실제로 보낸다.
static var test_sender: Callable = Callable()
## 테스트에서 웹 빌드인 척하게 한다.
static var test_force_enabled: bool = false


static func webhook_url() -> String:
	return TELEMETRY_WEBHOOK_URL if TELEMETRY_WEBHOOK_URL != "" else FeedbackModal.DISCORD_WEBHOOK_URL


## 이 환경에서 알림을 보내는가: 설정이 켜져 있고, 웹후크 주소가 있고, 실제 웹 빌드(또는 테스트가 켠 경우)일 때만.
static func is_active() -> bool:
	return ENABLE_MATCH_TELEMETRY and webhook_url() != "" and (OS.has_feature("web") or test_force_enabled)


## 모드 이름: 온라인 방 / 놀이터(컴퓨터와 대전) / 4인 수동 조작.
static func mode_label(online: bool, vs_computer: bool) -> String:
	if online:
		return "온라인"
	return "놀이터" if vs_computer else "4인 수동"


## 우승 방식: 말 4개 완주면 [일반], 중앙 법전의 특수 승리면 [특수승리].
static func win_label(reason: StringName) -> String:
	return "특수승리" if VictoryLaw.is_victory_id(String(reason)) else "일반"


static func build_line(mode: String, rounds: int, win: String, version: String = "") -> String:
	var line: String = "%s %s | %d라운드 | %s" % [tag(), mode, rounds, win]
	return line + " | v%s" % version if version != "" else line


## 판이 끝났다. host는 요청 노드를 붙일 곳(트리 안의 아무 노드). 보냈으면 true.
static func report_match(host: Node, online: bool, vs_computer: bool, rounds: int, reason: StringName) -> bool:
	if not is_active():
		return false
	var mode: String = mode_label(online, vs_computer)
	var win: String = win_label(reason)
	_notify_page(mode, rounds, win)
	var boundary: String = "----TRGStats%d" % Time.get_ticks_usec()
	var payload: Dictionary = {
		"username": "TRG 통계",
		"content": build_line(mode, rounds, win, GameSession.version()),
		"allowed_mentions": {"parse": []},
		"flags": 4096,  # 알림음 없이 조용히 (SUPPRESS_NOTIFICATIONS)
	}
	# JSON 대신 multipart로 보낸다: 브라우저가 사전 확인(preflight) 요청 없이 한 번에 보낸다 (피드백 창과 같은 방식).
	var body := PackedByteArray()
	body.append_array(("--%s\r\nContent-Disposition: form-data; name=\"payload_json\"\r\nContent-Type: application/json\r\n\r\n" % boundary).to_utf8_buffer())
	body.append_array(JSON.stringify(payload).to_utf8_buffer())
	body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())
	var content_type: String = "multipart/form-data; boundary=%s" % boundary
	if test_sender.is_valid():
		test_sender.call(webhook_url(), body, content_type)
		return true
	if host == null or not host.is_inside_tree():
		return false
	var request := HTTPRequest.new()
	request.name = "MatchTelemetryRequest"
	request.timeout = REQUEST_TIMEOUT_SECONDS
	host.get_tree().root.add_child(request)
	request.request_completed.connect(func(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		request.queue_free())  # 성공·실패와 상관없이 조용히 정리한다 (통계라서 게임에는 아무 영향이 없다)
	if request.request_raw(webhook_url(), PackedStringArray(["Content-Type: %s" % content_type]), HTTPClient.METHOD_POST, body) != OK:
		request.queue_free()
		return false
	return true


## 웹 페이지의 애널리틱스 슬롯으로도 알린다 (측정 ID가 없으면 페이지의 trgTrack이 빈 함수라 아무 일도 없다).
static func _notify_page(mode: String, rounds: int, win: String) -> void:
	if not OS.has_feature("web"):
		return
	var params: String = JSON.stringify({"mode": mode, "rounds": rounds, "win": win})
	JavaScriptBridge.eval("window.trgTrack && window.trgTrack('match_complete', %s)" % params, true)
