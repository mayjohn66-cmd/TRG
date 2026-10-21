# File: res://scenes/feedback_modal.gd
# Class: class_name FeedbackModal
# Role: 인게임 피드백 창 (하이브리드 전송). 유형(버그 / 밸런스 / 재미·기타) + 닉네임(선택) + 내용(5~5000자) + 게임 스냅샷 첨부 여부를 받아
#       [개발자에게 바로 전송] = 디스코드 웹후크(실시간 알림, 전문은 txt 첨부) + 구글 폼(장문·시트 보관)에 동시에 보내고(60초 쿨타임),
#       보낼 곳이 없거나 모두 실패하면 클립보드 복사 + 미리 채운 구글 폼 열기로 넘어간다. 또는
#       [리포트+로그 복사하기](클립보드)로 내보낸다. 스냅샷은 여는 쪽(MainBoard)이 넘긴 snapshot_source를 보낼 때마다 불러 최신 상태로 만든다.
#       창과 HTTPRequest는 쓰고 나면 queue_free된다 (요청은 창을 닫아도 끝까지 가고, 끝나면 스스로 지워진다).
class_name FeedbackModal
extends Control

# --- 보낼 곳 설정 (개발자가 URL·항목 ID만 채워 넣는다. 비어 있는 곳은 건너뛴다) ---------------------------
# 1) 디스코드 웹후크 URL (실시간 푸시 알림용). 짧은 미리보기는 메시지로, 전체 내용·스냅샷은 txt 첨부 파일로 보내 장문도 잘리지 않는다.
#    주의: 웹 빌드는 누구나 내려받아 볼 수 있으므로 이 주소도 공개된다 (악용되면 디스코드에서 웹후크를 다시 만들어 바꿔 끼운다).
const DISCORD_WEBHOOK_URL: String = "https://discord.com/api/webhooks/1562298513155686430/FLqE6H-njP7u0Cq6m4xbVsId7TRdC9Vz9L2jrVQewhqq9qrCHG49GuvgMtLXju0Q44fF"

# 2) 구글 폼 연동 설정 (장문 무제한 수집 & 스프레드시트 자동 저장용)
# 예: "https://docs.google.com/forms/d/e/1FAIpQLSe.../viewform"
const GOOGLE_FORM_VIEW_URL: String = ""
# 예: "https://docs.google.com/forms/d/e/1FAIpQLSe.../formResponse"
const GOOGLE_FORM_ACTION_URL: String = ""
const GFORM_ENTRY_CATEGORY: String = "entry.111111111" # 유형 항목 ID
const GFORM_ENTRY_NICKNAME: String = "entry.222222222" # 닉네임 항목 ID
const GFORM_ENTRY_MESSAGE: String  = "entry.333333333" # 피드백 본문 항목 ID
const GFORM_ENTRY_SNAPSHOT: String = "entry.444444444" # 자동 게임 로그 항목 ID

const MIN_LENGTH: int = 5
## 장문 밸런스 피드백도 받도록 넉넉하게 (디스코드는 첨부 파일, 구글 폼은 항목 값으로 전부 간다).
const MAX_LENGTH: int = 5000
const NAME_MAX_LENGTH: int = 30
## 도배 방지: 한 번 보내면 이 시간 동안 다시 보낼 수 없다 (창을 다시 열어도 유지).
const COOLDOWN_SECONDS: int = 60
const REQUEST_TIMEOUT_SECONDS: float = 15.0
## 디스코드 메시지·embed 한도 안의 미리보기 길이 (전체 내용은 첨부 파일에 있다).
const PREVIEW_LIMIT: int = 1500
const SNAPSHOT_PREVIEW_LIMIT: int = 3500
## 구글 폼 미리 채우기 링크(viewform?...)는 주소 길이 한도가 있어 본문을 이만큼만 담는다 (전체는 클립보드).
const PREFILL_LIMIT: int = 1500
const RECENT_LOG_LINES: int = 15

enum Kind { BUG, BALANCE, FUN }
const KIND_KEYS: Array[String] = ["feedback.kind_bug", "feedback.kind_balance", "feedback.kind_fun"]
const KIND_COLORS: Array[Color] = [Color("e03131"), Color("f08c00"), Color("2f9e44")]
const INK: Color = Color("1b4d3e")

## 마지막으로 보낸 시각 (Time.get_ticks_msec). 모든 창이 같이 쓴다.
static var _last_sent_msec: int = -1

var kind: Kind = Kind.BUG
## 보낼 때마다 불러 최신 게임 스냅샷 문자열을 받는다. 비어 있으면 스냅샷 없이 보낸다.
var snapshot_source: Callable = Callable()
## 어디서 열었는지 (상단 버튼 / 결과 화면) - 리포트 머리말에 붙는다.
var context: String = ""
## 테스트가 바꿔 끼우는 주소 (기본은 위 상수).
var webhook_url: String = DISCORD_WEBHOOK_URL
var form_action_url: String = GOOGLE_FORM_ACTION_URL
var form_view_url: String = GOOGLE_FORM_VIEW_URL
## 이번 전송에서 아직 끝나지 않은 요청 수와 성공한 곳들.
var _pending_requests: int = 0
var _delivered: Array[String] = []

var _kind_buttons: Array[Button] = []
var _name_edit: LineEdit = null
var _body_edit: TextEdit = null
var _count_label: Label = null
var _attach_check: CheckBox = null
var _status_label: Label = null
var _send_button: Button = null
var _copy_button: Button = null


## parent 위에 창을 연다. 반환한 창은 닫으면 queue_free된다.
static func open(parent: Node, source: Callable = Callable(), from: String = "", initial_kind: Kind = Kind.BUG) -> FeedbackModal:
	var modal := FeedbackModal.new()
	modal.snapshot_source = source
	modal.context = from
	modal.kind = initial_kind
	parent.add_child(modal)
	return modal


func _ready() -> void:
	name = "FeedbackModal"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 260
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0.08, 0.06, 0.66)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	panel.add_theme_stylebox_override("panel", UiSkin.panel("panel", 22.0))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(_label(L10n.tr_ui("feedback.title"), 24, Color("0b7285")))
	# 유형: 셋 중 하나 (라디오처럼 하나만 눌린다)
	var kinds := HBoxContainer.new()
	kinds.add_theme_constant_override("separation", 8)
	box.add_child(kinds)
	var group := ButtonGroup.new()
	for index: int in KIND_KEYS.size():
		var button := Button.new()
		button.name = "Kind%d" % index
		button.toggle_mode = true
		button.button_group = group
		button.text = L10n.tr_ui(KIND_KEYS[index])
		button.custom_minimum_size = Vector2(0, 40)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 15)
		button.toggled.connect(_on_kind_toggled.bind(index))
		kinds.add_child(button)
		_kind_buttons.append(button)
	_kind_buttons[int(kind)].button_pressed = true
	_refresh_kind_buttons()
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	box.add_child(name_row)
	var name_title: Label = _label(L10n.tr_ui("feedback.name"), 15, INK)
	name_title.custom_minimum_size = Vector2(170, 0)
	name_row.add_child(name_title)
	_name_edit = LineEdit.new()
	_name_edit.name = "NameEdit"
	_name_edit.placeholder_text = L10n.tr_ui("feedback.name_hint")
	_name_edit.max_length = NAME_MAX_LENGTH
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text = GameSession.display_nickname() if GameSession.nickname != "" else ""
	_style_input(_name_edit)
	name_row.add_child(_name_edit)
	_body_edit = TextEdit.new()
	_body_edit.name = "BodyEdit"
	_body_edit.placeholder_text = L10n.tr_ui("feedback.body_hint")
	_body_edit.custom_minimum_size = Vector2(0, 150)
	_body_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_body_edit.text_changed.connect(_on_body_changed)
	_style_input(_body_edit)
	box.add_child(_body_edit)
	_count_label = _label("", 13, Color("6c757d"))
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_count_label)
	_attach_check = CheckBox.new()
	_attach_check.name = "AttachCheck"
	_attach_check.text = L10n.tr_ui("feedback.attach")
	_attach_check.button_pressed = true
	_attach_check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_attach_check.custom_minimum_size = Vector2(580, 0)
	_attach_check.add_theme_font_size_override("font_size", 14)
	for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		_attach_check.add_theme_color_override(key, INK)
	box.add_child(_attach_check)
	_status_label = _label("", 14, Color("0b7285"))
	_status_label.name = "Status"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size = Vector2(580, 0)
	box.add_child(_status_label)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	box.add_child(buttons)
	_send_button = LobbyTheme.big_button(L10n.tr_ui("feedback.send"), send, 18, Color("1c7ed6"))
	_send_button.name = "SendButton"
	_send_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_send_button)
	_copy_button = LobbyTheme.big_button(L10n.tr_ui("feedback.copy"), copy_report, 18, Color("2b8a3e"))
	_copy_button.name = "CopyButton"
	_copy_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(_copy_button)
	var close := LobbyTheme.big_button(L10n.tr_ui("feedback.close"), close_modal, 18, Color("6c757d"))
	close.name = "CloseButton"
	buttons.add_child(close)
	_on_body_changed()


## 밝은 창에 맞춘 입력칸: 흰 바탕 + 진한 글자 + 회색 안내문.
func _style_input(input: Control) -> void:
	for state_name: String in ["normal", "focus", "read_only"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color.WHITE
		style.border_color = Color("0b7285") if state_name == "focus" else Color("adb5bd")
		style.set_border_width_all(2)
		style.set_corner_radius_all(10)
		style.set_content_margin_all(8)
		input.add_theme_stylebox_override(state_name, style)
	input.add_theme_color_override("font_color", INK)
	input.add_theme_color_override("font_placeholder_color", Color("868e96"))
	input.add_theme_color_override("caret_color", INK)
	input.add_theme_font_size_override("font_size", 15)


func _label(text: String, size_px: int, color: Color) -> Label:
	var item := Label.new()
	item.text = text
	item.add_theme_font_size_override("font_size", size_px)
	item.add_theme_color_override("font_color", color)
	return item


func _on_kind_toggled(pressed: bool, index: int) -> void:
	if pressed:
		kind = index as Kind
	_refresh_kind_buttons()


func _refresh_kind_buttons() -> void:
	for index: int in _kind_buttons.size():
		var on: bool = index == int(kind)
		var fill: Color = KIND_COLORS[index] if on else Color("dee2e6")
		var style := StyleBoxFlat.new()
		style.bg_color = fill
		style.set_corner_radius_all(12)
		style.set_border_width_all(2)
		style.border_color = KIND_COLORS[index]
		for state_name: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			_kind_buttons[index].add_theme_stylebox_override(state_name, style)
		for key: String in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
			_kind_buttons[index].add_theme_color_override(key, Color.WHITE if on else Color("495057"))


## 500자를 넘기면 잘라 내고 글자 수를 보여 준다.
func _on_body_changed() -> void:
	if _body_edit.text.length() > MAX_LENGTH:
		_body_edit.text = _body_edit.text.substr(0, MAX_LENGTH)
		_body_edit.set_caret_column(_body_edit.get_line(_body_edit.get_line_count() - 1).length())
		_body_edit.set_caret_line(_body_edit.get_line_count() - 1)
	_count_label.text = L10n.tr_ui("feedback.count", [message().length(), MAX_LENGTH])


func message() -> String:
	return _body_edit.text.strip_edges() if _body_edit != null else ""


func author() -> String:
	var typed: String = _name_edit.text.strip_edges() if _name_edit != null else ""
	return typed if typed != "" else L10n.tr_ui("feedback.anonymous")


func set_message(text: String) -> void:
	_body_edit.text = text
	_on_body_changed()


## 스냅샷을 붙일지 (체크박스) 고려한 스냅샷 문자열. 끌 수 있다.
func snapshot() -> String:
	if _attach_check != null and not _attach_check.button_pressed:
		return ""
	if not snapshot_source.is_valid():
		return ""
	return str(snapshot_source.call())


## 클립보드·설문용 전체 리포트: 유형·작성자·내용 + 스냅샷(최근 로그 포함).
func build_report() -> String:
	var lines: PackedStringArray = []
	lines.append("[TRG 피드백] %s" % L10n.tr_ui(KIND_KEYS[int(kind)]))
	lines.append("작성자: %s" % author())
	if context != "":
		lines.append("보낸 곳: %s" % context)
	lines.append("")
	lines.append(message())
	var snap: String = snapshot()
	if snap != "":
		lines.append("")
		lines.append(snap)
	return "\n".join(lines)


## 디스코드 웹후크 JSON(payload_json): content = 유형·작성자·내용 미리보기, embeds = 스냅샷 미리보기. 전체는 첨부 파일(report_file_text).
func build_webhook_payload() -> Dictionary:
	var body: String = message()
	var preview: String = body if body.length() <= PREVIEW_LIMIT else body.substr(0, PREVIEW_LIMIT) + "\n... (전체 %d자는 첨부 파일 feedback.txt)" % body.length()
	var payload: Dictionary = {
		"username": "TRG 피드백",
		"content": "**[%s]** %s\n%s" % [L10n.tr_ui(KIND_KEYS[int(kind)]), author(), preview],
		"attachments": [{"id": 0, "filename": "feedback.txt", "description": "피드백 전문 + 게임 스냅샷"}],
	}
	var snap: String = snapshot()
	if snap != "":
		payload["embeds"] = [{
			"title": "게임 스냅샷" + (" (%s)" % context if context != "" else ""),
			"description": "```\n%s\n```" % snap.replace("```", "\'\'\'").substr(0, SNAPSHOT_PREVIEW_LIMIT),
			"color": KIND_COLORS[int(kind)].to_rgba32() >> 8,
		}]
	return payload


## 첨부 파일 feedback.txt: 잘리지 않은 전체 리포트 (UTF-8).
func report_file_text() -> String:
	return build_report()


## 디스코드로 보내는 multipart/form-data 본문 (payload_json + files[0]). 반환: [본문 바이트, Content-Type 헤더 값].
func build_webhook_multipart() -> Array:
	var boundary: String = "----TRGFeedback%d" % Time.get_ticks_usec()
	var body := PackedByteArray()
	body.append_array(("--%s\r\nContent-Disposition: form-data; name=\"payload_json\"\r\nContent-Type: application/json\r\n\r\n" % boundary).to_utf8_buffer())
	body.append_array(JSON.stringify(build_webhook_payload()).to_utf8_buffer())
	body.append_array(("\r\n--%s\r\nContent-Disposition: form-data; name=\"files[0]\"; filename=\"feedback.txt\"\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n" % boundary).to_utf8_buffer())
	body.append_array(report_file_text().to_utf8_buffer())
	body.append_array(("\r\n--%s--\r\n" % boundary).to_utf8_buffer())
	return [body, "multipart/form-data; boundary=%s" % boundary]


## 구글 폼 formResponse로 보내는 항목 (전부 잘리지 않은 값). 스냅샷 첨부를 끄면 스냅샷 항목은 비운다.
func build_form_fields() -> Dictionary:
	var fields: Dictionary = {}
	fields[GFORM_ENTRY_CATEGORY] = L10n.tr_ui(KIND_KEYS[int(kind)])
	fields[GFORM_ENTRY_NICKNAME] = author()
	fields[GFORM_ENTRY_MESSAGE] = message()
	fields[GFORM_ENTRY_SNAPSHOT] = ("보낸 곳: %s\n" % context if context != "" else "") + snapshot()
	return fields


static func _urlencode(fields: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key: Variant in fields:
		parts.append("%s=%s" % [str(key).uri_encode(), str(fields[key]).uri_encode()])
	return "&".join(parts)


## 구글 폼 미리 채우기 링크 (보낼 곳이 모두 막혔을 때 사용자가 직접 제출하게 연다). 주소 길이 때문에 본문은 앞부분만 담는다.
func build_prefill_url() -> String:
	if form_view_url == "":
		return ""
	var fields: Dictionary = {}
	fields[GFORM_ENTRY_CATEGORY] = L10n.tr_ui(KIND_KEYS[int(kind)])
	fields[GFORM_ENTRY_NICKNAME] = author()
	fields[GFORM_ENTRY_MESSAGE] = message().substr(0, PREFILL_LIMIT)
	return "%s%susp=pp_url&%s" % [form_view_url, "&" if form_view_url.contains("?") else "?", _urlencode(fields)]


## 남은 쿨타임(초). 0이면 보낼 수 있다.
static func cooldown_left() -> int:
	if _last_sent_msec < 0:
		return 0
	var elapsed: int = Time.get_ticks_msec() - _last_sent_msec
	return maxi(int(ceil((COOLDOWN_SECONDS * 1000 - elapsed) / 1000.0)), 0)


## 테스트용: 쿨타임을 지운다.
static func reset_cooldown() -> void:
	_last_sent_msec = -1


## [개발자에게 바로 전송]: 디스코드(실시간 알림)와 구글 폼(장문 보관) 중 설정된 곳 모두에 동시에 보낸다.
## 반환: &"too_short" / &"cooldown" / &"busy" / &"sent"(요청 시작) / &"form_link"(미리 채운 폼 열기) / &"no_target"(복사만).
func send() -> StringName:
	if message().length() < MIN_LENGTH:
		_set_status(L10n.tr_ui("feedback.too_short", [MIN_LENGTH]), false)
		return &"too_short"
	if _pending_requests > 0:
		return &"busy"
	if webhook_url != "" or form_action_url != "":
		if cooldown_left() > 0:
			_set_status(L10n.tr_ui("feedback.cooldown", [cooldown_left()]), false)
			return &"cooldown"
		_last_sent_msec = Time.get_ticks_msec()
		_delivered.clear()
		if webhook_url != "":
			var multipart: Array = build_webhook_multipart()
			_post("discord", webhook_url, PackedStringArray(["Content-Type: %s" % multipart[1]]), multipart[0])
		if form_action_url != "":
			_post("form", form_action_url, PackedStringArray(["Content-Type: application/x-www-form-urlencoded"]), _urlencode(build_form_fields()).to_utf8_buffer())
		if _pending_requests > 0:
			_set_status(L10n.tr_ui("feedback.sending"), true)
			_send_button.disabled = true
		return &"sent"
	return _fallback()


## 보낼 곳이 없거나 모두 실패했을 때: 리포트를 클립보드에 복사하고, 구글 폼 주소가 있으면 미리 채운 폼을 연다.
func _fallback() -> StringName:
	_copy_text(build_report())
	var prefill: String = build_prefill_url()
	if prefill != "":
		OS.shell_open(prefill)
		_set_status(L10n.tr_ui("feedback.form_opened"), true)
		return &"form_link"
	_set_status(L10n.tr_ui("feedback.no_target"), false)
	return &"no_target"


## 비동기 POST 한 건. 요청 노드는 트리 루트에 붙어 창을 닫아도 끝까지 가고, 끝나면(성공·실패·시간 초과) 스스로 지워진다.
func _post(channel: String, url: String, headers: PackedStringArray, body: PackedByteArray) -> void:
	var request := HTTPRequest.new()
	request.name = "FeedbackRequest_%s" % channel
	request.timeout = REQUEST_TIMEOUT_SECONDS
	var host: Node = get_tree().root if is_inside_tree() else self
	host.add_child(request)
	_pending_requests += 1
	var modal_ref: WeakRef = weakref(self)
	request.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
		var ok: bool = result == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 400
		# 웹 빌드에서 구글 폼은 응답을 읽을 수 없다(CORS). 제출 자체는 서버에 들어가므로 보낸 것으로 친다.
		if channel == "form" and OS.has_feature("web") and code == 0:
			ok = true
		var modal: FeedbackModal = modal_ref.get_ref() as FeedbackModal
		if modal != null:
			modal._on_request_done(channel, ok)
		request.queue_free())
	var error: Error = request.request_raw(url, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		request.queue_free()
		_on_request_done(channel, false)


func _on_request_done(channel: String, ok: bool) -> void:
	_pending_requests = maxi(_pending_requests - 1, 0)
	if ok:
		_delivered.append(channel)
	if _pending_requests > 0:
		return
	_send_button.disabled = false
	if _delivered.is_empty():
		_last_sent_msec = -1  # 실패는 쿨타임을 걸지 않는다
		_fallback()
		_set_status(L10n.tr_ui("feedback.send_failed"), false)
		return
	_set_status(L10n.tr_ui("feedback.sent"), true)
	_toast(L10n.tr_ui("feedback.sent"))
	_body_edit.text = ""
	_on_body_changed()


## [리포트+로그 복사하기]: 내용이 비어 있어도 스냅샷만이라도 복사한다.
func copy_report() -> String:
	var report: String = build_report()
	_copy_text(report)
	_set_status(L10n.tr_ui("feedback.copied"), true)
	_toast(L10n.tr_ui("feedback.copied"))
	return report


## 클립보드에 복사한다. 웹에서는 브라우저 클립보드 API도 함께 부른다 (DisplayServer 클립보드가 막힌 브라우저 대비).
static func _copy_text(text: String) -> void:
	DisplayServer.clipboard_set(text)
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try { navigator.clipboard.writeText(%s); } catch (e) {}" % JSON.stringify(text), true)


func _set_status(text: String, good: bool) -> void:
	if _status_label != null:
		_status_label.text = text
		_status_label.add_theme_color_override("font_color", Color("2b8a3e") if good else Color("c92a2a"))


## 화면 아래쪽에 잠깐 떴다 사라지는 알림 (창 위).
func _toast(text: String) -> void:
	var toast := Label.new()
	toast.name = "FeedbackToast"
	toast.text = text
	toast.add_theme_font_size_override("font_size", 17)
	toast.add_theme_color_override("font_color", Color.WHITE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.45, 0.25, 0.95)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(12)
	toast.add_theme_stylebox_override("normal", style)
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(toast)
	toast.reset_size()
	var view: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1366, 768)
	toast.position = Vector2((view.x - toast.size.x) / 2.0, view.y - toast.size.y - 40.0)
	var tween: Tween = toast.create_tween()
	tween.tween_interval(2.4)
	tween.tween_property(toast, "modulate:a", 0.0, 0.4)
	tween.tween_callback(toast.queue_free)


func close_modal() -> void:
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_modal()
