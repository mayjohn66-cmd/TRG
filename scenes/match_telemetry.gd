# File: res://scenes/match_telemetry.gd
# Class: class_name MatchTelemetry
# Role: 플레이 통계를 디스코드 웹후크로 조용히 보낸다 (방문자 수·판 수·같은 사람이 여러 판 했는지·누가 이겼는지 보는 용도).
#       세 가지 순간에 한 줄씩 보낸다: 로비 입장(타이틀의 [입장하기], 세션당 1회) / 매치 시작(보드 진입) / 매치 완료(내 순위가 확정된 즉시, 4인 수동은 결과 화면).
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


static func vote_tag() -> String:
	return "[%s%s 유저 미니투표]" % [String.chr(0x1F5F3), String.chr(0xFE0F)]  # 🗳️


## 결과 화면의 원클릭 소감 투표: [id, 디스코드에 보낼 글(이모지 포함), 화면에 쓸 글]. 게임 글꼴에는 이모지가 없어 화면 글자에서는 뺀다.
static func vote_choices() -> Array:
	return [
		[&"fun", "%s 딱 재밌어요!" % String.chr(0x1F525), "딱 재밌어요!"],  # 🔥
		[&"spicy", "%s AI/억까가 너무 매워요" % String.chr(0x1F608), "AI/억까가 너무 매워요"],  # 😈
		[&"confusing", "%s 룰·효과 파악이 어려워요" % String.chr(0x1F92F), "룰·효과 파악이 어려워요"],  # 🤯
		[&"long", "%s 한 판이 너무 길어요" % String.chr(0x1F422), "한 판이 너무 길어요"],  # 🐢
	]


## 한줄평 길이 제한과 정리 (줄바꿈 제거).
const VOTE_COMMENT_LIMIT: int = 120


## mode(선택): 이 판의 모드 이름 (놀이터면 난이도 태그 포함, 예: "놀이터 [Lv.5 핵불닭]"). 있으면 이름 뒤에 붙는다.
static func vote_line(who: String, choice: String, comment: String, my_rank: int, rounds: int, mode: String = "") -> String:
	var note: String = comment.replace("\n", " ").replace("\r", " ").strip_edges()
	if note.length() > VOTE_COMMENT_LIMIT:
		note = note.substr(0, VOTE_COMMENT_LIMIT) + "…"
	return "%s %s | %s | %s | (%s · %d라운드)" % [vote_tag(), who + (" | " + mode if mode != "" else ""), choice, note if note != "" else "-", "%d위" % my_rank if my_rank > 0 else "순위 -", rounds]


## 모드 이름: 놀이터(컴퓨터와 대전) / 친선(방 코드로 만든 방) / 익명(빠른 매칭) / 4인 수동(한 화면 핫시트).
static func mode_label(online: bool, vs_computer: bool, quick_match: bool = false) -> String:
	if online:
		return "익명" if quick_match else "친선"
	return "놀이터" if vs_computer else "4인 수동"


## 친선전 프리셋의 통계 표기 (한국어).
const PRESET_TAGS: Dictionary = {&"classic": "클래식 완주전", &"standard": "오리지널 표준", &"mind_games": "우정파괴 심리전"}


## 디스코드 통계용 친선전 옵션 표기 (한국어): 프리셋과 꼭 맞으면 그 이름, 아니면 기본과 다른 값을 짧게.
## 예: "클래식 완주전" / "법전OFF/함정비공개" / "오리지널 표준/스피드전". 빈자리 컴퓨터가 있으면 "봇Lv.3"을 붙인다.
static func rules_label(rules: Dictionary, has_bots: bool = false) -> String:
	var parts: PackedStringArray = []
	var preset: StringName = MatchRules.preset_of(rules)
	if preset != &"":
		parts.append(str(PRESET_TAGS.get(preset, "")))
	else:
		if not bool(rules.get("laws", true)):
			parts.append("법전OFF")
		if not bool(rules.get("trap_reveal", true)):
			parts.append("함정비공개")
		match int(rules.get("super_freq", 1)):
			0: parts.append("초증강OFF")
			2: parts.append("초증강2배")
			3: parts.append("초증강3배")
	if StringName(rules.get("speed", MatchRules.SPEED_NORMAL)) == MatchRules.SPEED_FAST:
		parts.append("스피드전")
	if has_bots:
		parts.append("봇Lv.%d" % BotTemper.sanitize(rules.get("bot_level", BotTemper.DEFAULT_LEVEL)))
	return "/".join(parts)


## 1위의 우승 방식: 말 4개 완주면 [일반], 중앙 법전의 특수 승리면 [특수승리(교칙 이름)].
static func win_label(reason: StringName) -> String:
	if String(reason) == "" or not VictoryLaw.is_victory_id(String(reason)):
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
## difficulty(선택): 체감 난이도 지표 {"winner": 1위 이름, "kills", "deaths", "played": 끝까지 마친 판 수, "wins": 그중 1위 횟수}. 있는 항목만 붙인다.
static func end_line(who: String, nth: int, mode: String, rounds: int, seconds: int, my_rank: int, win: String, augments: Array[String], difficulty: Dictionary = {}) -> String:
	var summary: String = ", ".join(PackedStringArray(augments)) if not augments.is_empty() else "없음"
	if summary.length() > AUGMENT_SUMMARY_LIMIT:
		summary = summary.substr(0, AUGMENT_SUMMARY_LIMIT) + "…"
	var rank_text: String = "%d위" % my_rank if my_rank > 0 else "-"
	if str(difficulty.get("winner", "")) != "":
		rank_text += " / 우승자: %s" % str(difficulty["winner"])
	var extra: String = ""
	if difficulty.has("kills") or difficulty.has("deaths"):
		extra += " | 킬/데스: %d킬 %d데스" % [int(difficulty.get("kills", 0)), int(difficulty.get("deaths", 0))]
	if int(difficulty.get("played", 0)) > 0:
		extra += " | 누적: %d판 중 1위 %d회" % [int(difficulty["played"]), int(difficulty.get("wins", 0))]
	return "%s %s (%d번째 판) | %s | %d라운드(소요시간 %s) | 내 최종 순위: %s | 1위 우승방식: %s%s | 고른 증강: %s" % [
		tag(), str(who) if str(who) != "" else "이름 없음", nth, str(mode) if str(mode) != "" else "-", rounds, duration_text(seconds), rank_text, str(win) if str(win) != "" else "일반", extra, summary]


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


## 내 순위가 확정됐다(또는 결과 화면에 닿았다).
static func report_match_end(host: Node, nth: int, mode: String, rounds: int, seconds: int, my_rank: int, reason: StringName, augments: Array[String], difficulty: Dictionary = {}) -> bool:
	if not is_active():
		return false
	var win: String = win_label(reason)
	_notify_page("match_complete", {"mode": mode, "rounds": rounds, "win": win, "rank": my_rank, "seconds": seconds, "kills": int(difficulty.get("kills", 0)), "deaths": int(difficulty.get("deaths", 0))})
	return send_line(host, end_line(GameSession.tagged_name(), nth, mode, rounds, seconds, my_rank, win, augments, difficulty))


## 결과 화면의 원클릭 소감 투표를 보낸다.
static func report_vote(host: Node, choice: String, comment: String, my_rank: int, rounds: int, mode: String = "") -> bool:
	if not is_active():
		return false
	_notify_page("match_vote", {"choice": choice, "rank": my_rank, "mode": mode})
	return send_line(host, vote_line(GameSession.tagged_name(), choice, comment, my_rank, rounds, mode))


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
	# 요청 노드는 보드판이 아니라 트리 루트에 붙인다: 로비로 씬을 바꿔도 보드판과 함께 지워지지 않고, 응답을 받은 뒤 스스로 정리된다.
	var tree: SceneTree = host.get_tree() if host != null and host.is_inside_tree() else Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return false
	var request := HTTPRequest.new()
	request.name = "MatchTelemetryRequest"
	request.timeout = REQUEST_TIMEOUT_SECONDS
	tree.root.add_child(request)
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
