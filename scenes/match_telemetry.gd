# File: res://scenes/match_telemetry.gd
# Class: class_name MatchTelemetry
# Role: 플레이 통계를 디스코드 웹후크로 조용히 보낸다 (방문자 수·판 수·같은 사람이 여러 판 했는지·누가 이겼는지 보는 용도).
#       세 가지 순간에 한 줄씩 보낸다: 로비 입장(타이틀의 [입장하기], 세션당 1회) / 매치 시작(보드 진입) / 매치 완료(결과 화면).
#       사람마다 브라우저에 저장한 익명 태그(#4자리)와 누적 판 수를 붙여 [닉네임(#A7B2)]으로 구분한다 (GameSession.player_tag).
#       웹 빌드에서만 보낸다 (에디터·데스크톱·테스트에서는 아무것도 보내지 않는다). 끄려면 ENABLE_MATCH_TELEMETRY를 false로.
#       웹 페이지에 애널리틱스 슬롯(web/shell.html의 TRG_GA_ID)이 켜져 있으면 같은 순간을 window.trgTrack으로도 알린다.
class_name MatchTelemetry
extends RefCounted

## 통계 알림 켜기/끄기.
const ENABLE_MATCH_TELEMETRY: bool = true
## 알림을 보낼 웹후크. 비워 두면 피드백 웹후크(FeedbackModal.DISCORD_WEBHOOK_URL)를 쓴다 (통계 전용 채널을 따로 쓰고 싶을 때 채운다).
const TELEMETRY_WEBHOOK_URL: String = ""
const REQUEST_TIMEOUT_SECONDS: float = 10.0
## 증강 요약이 너무 길면 자른다 (디스코드 메시지는 2000자 한도).
const AUGMENT_SUMMARY_LIMIT: int = 300

## 테스트가 바꿔 끼우는 전송 함수: (url: String, body: PackedByteArray, content_type: String) -> void. 비어 있으면 실제로 보낸다.
static var test_sender: Callable = Callable()
## 테스트에서 웹 빌드인 척하게 한다.
static var test_force_enabled: bool = false
## 이번 접속(세션)에서 로비 입장을 이미 알렸다.
static var _lobby_reported: bool = false


static func webhook_url() -> String:
	return TELEMETRY_WEBHOOK_URL if TELEMETRY_WEBHOOK_URL != "" else FeedbackModal.DISCORD_WEBHOOK_URL


## 이 환경에서 알림을 보내는가: 설정이 켜져 있고, 웹후크 주소가 있고, 실제 웹 빌드(또는 테스트가 켠 경우)일 때만.
static func is_active() -> bool:
	return ENABLE_MATCH_TELEMETRY and webhook_url() != "" and (OS.has_feature("web") or test_force_enabled)


# --- 문구 ---------------------------------------------------------------------------------------
# 이모지는 게임 글꼴에 없어서 글자 코드로 만든다 (디스코드로만 가고 게임 화면에는 나오지 않는다).

static func lobby_tag() -> String:
	return "[%s 로비 입장]" % String.chr(0x1F44B)  # 👋


static func start_tag() -> String:
	return "[%s 매치 시작]" % String.chr(0x1F3AE)  # 🎮


static func tag() -> String:
	return "[%s 매치 완료]" % String.chr(0x1F4CA)  # 📊


## 모드 이름: 놀이터(컴퓨터와 대전) / 친선(방 코드로 만든 방) / 익명(빠른 매칭) / 4인 수동(한 화면 핫시트).
static func mode_label(online: bool, vs_computer: bool, quick_match: bool = false) -> String:
	if online:
		return "익명" if quick_match else "친선"
	return "놀이터" if vs_computer else "4인 수동"


## 1위의 우승 방식: 말 4개 완주면 [일반], 중앙 법전의 특수 승리면 [특수승리(교칙 이름)].
static func win_label(reason: StringName) -> String:
	if not VictoryLaw.is_victory_id(String(reason)):
		return "일반"
	var law: LawResource = LawRegistry.create(String(reason))
	return "특수승리(%s)" % law.law_name if law != null else "특수승리"


## 기기: 휴대폰·태블릿 브라우저면 Mobile, 아니면 PC.
static func device_label() -> String:
	if OS.has_feature("web_android") or OS.has_feature("web_ios") or OS.has_feature("mobile"):
		return "Mobile"
	if OS.has_feature("web"):
		var agent: String = str(JavaScriptBridge.eval("navigator.userAgent", true))
		if RegEx.create_from_string("(?i)mobi|android|iphone|ipad|ipod").search(agent) != null:
			return "Mobile"
	return "PC"


## 걸린 시간 [M분 S초].
static func duration_text(seconds: int) -> String:
	seconds = maxi(seconds, 0)
	return "%d분 %d초" % [seconds / 60, seconds % 60]


static func lobby_line(who: String, device: String, version: String) -> String:
	return "%s %s | %s | v%s" % [lobby_tag(), who, device, version]


static func start_line(who: String, mode: String, nth: int) -> String:
	return "%s %s | %s | %d번째 판 시작" % [start_tag(), who, mode, nth]


## my_rank가 0 이하면(한 화면 4인 수동처럼 '나'가 없으면) 순위 칸에 [-]를 적는다.
static func end_line(who: String, nth: int, mode: String, rounds: int, seconds: int, my_rank: int, win: String, augments: Array[String]) -> String:
	var summary: String = ", ".join(PackedStringArray(augments)) if not augments.is_empty() else "없음"
	if summary.length() > AUGMENT_SUMMARY_LIMIT:
		summary = summary.substr(0, AUGMENT_SUMMARY_LIMIT) + "…"
	return "%s %s (%d번째 판) | %s | %d라운드(소요시간 %s) | 내 최종 순위: %s | 1위 우승방식: %s | 고른 증강: %s" % [
		tag(), who, nth, mode, rounds, duration_text(seconds), "%d위" % my_rank if my_rank > 0 else "-", win, summary]


# --- 보내기 -------------------------------------------------------------------------------------

## 타이틀에서 [입장하기]를 눌렀다 (이번 접속에서 처음일 때만 보낸다). 보냈으면 true.
static func report_lobby_entry(host: Node) -> bool:
	if _lobby_reported or not is_active():
		return false
	_lobby_reported = true
	_notify_page("lobby_enter", {"device": device_label()})
	return send_line(host, lobby_line(GameSession.tagged_name(), device_label(), GameSession.version()))


## 보드판에 들어와 한 판이 시작됐다. nth는 이 사람의 누적 판 번호.
static func report_match_start(host: Node, mode: String, nth: int) -> bool:
	if not is_active():
		return false
	_notify_page("match_start", {"mode": mode, "nth": nth})
	return send_line(host, start_line(GameSession.tagged_name(), mode, nth))


## 결과 화면에 닿았다.
static func report_match_end(host: Node, nth: int, mode: String, rounds: int, seconds: int, my_rank: int, reason: StringName, augments: Array[String]) -> bool:
	if not is_active():
		return false
	var win: String = win_label(reason)
	_notify_page("match_complete", {"mode": mode, "rounds": rounds, "win": win, "rank": my_rank, "seconds": seconds})
	return send_line(host, end_line(GameSession.tagged_name(), nth, mode, rounds, seconds, my_rank, win, augments))


## 한 줄을 웹후크로 보낸다. host는 요청 노드를 붙일 곳(트리 안의 아무 노드).
static func send_line(host: Node, text: String) -> bool:
	var boundary: String = "----TRGStats%d" % Time.get_ticks_usec()
	var payload: Dictionary = {
		"username": "TRG 통계",
		"content": text,
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
static func _notify_page(event: String, params: Dictionary) -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("window.trgTrack && window.trgTrack(%s, %s)" % [JSON.stringify(event), JSON.stringify(params)], true)
