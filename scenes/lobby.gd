# File: res://scenes/lobby.gd
# Class: class_name Lobby
# Role: 멀티플레이 로비 화면. [방 만들기]/[방 참가] -> 방장은 좌석마다 초대 코드를 만들어 보내고 응답 코드를 붙여 넣어 연결하며, 참가자는 초대 코드를 붙여 넣어 응답 코드를 돌려준다. WebRTC 직접 연결이라 서버가 필요 없다
class_name Lobby
extends Control

const START_MENU_SCENE: String = "res://scenes/start_menu.tscn"
const COLOR_BG: Color = Color("0d1018")
const COLOR_GOLD: Color = Color("ffd43b")
const SEAT_COLORS: Array[Color] = [Color("e03131"), Color("1c7ed6"), Color("2f9e44"), Color("f08c00")]

enum Mode { CHOOSE, HOST, GUEST }

## 테스트에서 씬 전환을 막기 위한 스위치.
var change_scene_enabled: bool = true
var mode: Mode = Mode.CHOOSE
var service: LobbyService = null

var _panel_box: VBoxContainer = null
var _status: Label = null
var _seat_box: VBoxContainer = null
var _start_button: Button = null
var _guest_box: VBoxContainer = null
var _invite_codes: Dictionary = {}   # 좌석 -> 방장이 만든 초대 코드
var _answer_texts: Dictionary = {}   # 좌석 -> 방장이 붙여 넣은 응답 코드 (다시 그려도 유지)
var _seat_errors: Dictionary = {}    # 좌석 -> 안내/오류 문구
var _guest_invite_text: String = ""
var _guest_answer_code: String = ""
var _guest_connected: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	name = "Lobby"
	service = LobbyService.new()
	service.name = "LobbyService"
	add_child(service)
	service.invite_ready.connect(_on_invite_ready)
	service.link_failed.connect(_on_link_failed)
	service.answer_ready.connect(_on_answer_ready)
	service.joined.connect(_on_joined)
	service.left_room.connect(_on_left_room)
	service.roster_changed.connect(_rebuild)
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(880, 0)
	panel.add_theme_stylebox_override("panel", _style(Color("1a2030"), Color("39435c"), 3, 22, 24, 24))
	center.add_child(panel)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 12)
	panel.add_child(_panel_box)
	_show_choose()
	add_child(MobileSupport.new())


# ---------------------------------------------------------------------------
# 화면 구성
# ---------------------------------------------------------------------------

func _clear_panel() -> void:
	for child: Node in _panel_box.get_children():
		_panel_box.remove_child(child)
		child.queue_free()
	_seat_box = null
	_guest_box = null
	_start_button = null
	_status = null


func _title(text: String) -> void:
	var title := _label(text, 30, COLOR_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_box.add_child(title)


func _show_choose() -> void:
	mode = Mode.CHOOSE
	_clear_panel()
	_title("멀티플레이")
	var hello := _label("%s 님, 방을 만들거나 친구의 방에 참가하세요." % GameSession.display_nickname(), 16, Color("ced4da"))
	hello.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_box.add_child(hello)
	_panel_box.add_child(_button("방 만들기  (내가 방장)", start_hosting, 22, Color("2b8a3e")))
	_panel_box.add_child(_button("방 참가  (초대 코드 입력)", start_guest, 22, Color("1c6dd0")))
	_panel_box.add_child(_button("뒤로", go_back, 14, Color("4a3a66")))
	var note := _label("서버 없이 친구와 직접 연결(WebRTC)합니다. 코드는 메신저 등으로 주고받으세요.", 12, Color("868e96"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_box.add_child(note)


## [방 만들기]: 방장이 되어 좌석 화면으로 간다.
func start_hosting() -> void:
	if not service.host_room(GameSession.display_nickname()):
		_show_choose()
		var warning := _label("방을 만들 수 없습니다. 웹 브라우저(Chrome·Edge·Safari 등)에서 열어 주세요.", 13, Color("ff8787"))
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_panel_box.add_child(warning)
		return
	mode = Mode.HOST
	_invite_codes.clear()
	_answer_texts.clear()
	_seat_errors.clear()
	_clear_panel()
	_title("내 방  (방장: %s)" % GameSession.display_nickname())
	var help := _label("① 빈 자리의 [초대 코드 만들기]를 눌러 코드를 친구에게 보냅니다.  ② 친구가 돌려준 응답 코드를 붙여 넣고 [연결]을 누릅니다.  빈 자리는 시작할 때 컴퓨터가 채웁니다.", 13, Color("adb5bd"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(820, 0)
	_panel_box.add_child(help)
	_seat_box = VBoxContainer.new()
	_seat_box.add_theme_constant_override("separation", 8)
	_panel_box.add_child(_seat_box)
	_status = _label("", 14, Color("ffe066"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_box.add_child(_status)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	_panel_box.add_child(footer)
	_start_button = _button("게임 시작  (다음 단계에서 연결)", _on_start_pressed, 18, Color("2b8a3e"))
	_start_button.disabled = true
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_start_button)
	footer.add_child(_button("방 닫고 나가기", leave_room, 14, Color("7a2a2a")))
	_rebuild()


## [방 참가]: 초대 코드를 붙여 넣는 화면으로 간다.
func start_guest() -> void:
	mode = Mode.GUEST
	_guest_invite_text = ""
	_guest_answer_code = ""
	_guest_connected = false
	_clear_panel()
	_title("방 참가")
	_guest_box = VBoxContainer.new()
	_guest_box.add_theme_constant_override("separation", 10)
	_panel_box.add_child(_guest_box)
	_status = _label("", 14, Color("ffe066"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_box.add_child(_status)
	_panel_box.add_child(_button("나가기", leave_room, 14, Color("7a2a2a")))
	_rebuild()


func _rebuild() -> void:
	match mode:
		Mode.HOST: _rebuild_host()
		Mode.GUEST: _rebuild_guest()


func _rebuild_host() -> void:
	if _seat_box == null:
		return
	for child: Node in _seat_box.get_children():
		_seat_box.remove_child(child)
		child.queue_free()
	for seat: int in range(1, LobbyModel.SEAT_COUNT + 1):
		_seat_box.add_child(_make_host_row(seat))
	if _start_button != null:
		_start_button.disabled = true  # 게임 화면 연동 전까지는 눌러서 시작할 수 없다
		_start_button.tooltip_text = "멀티플레이 게임 화면은 다음 단계에서 연결됩니다."
	if _status != null and not _seat_errors.has(0):
		_status.text = "모든 자리가 정리되었습니다. 열린 자리는 컴퓨터가 채웁니다." if service.model.can_start() else "초대한 친구의 연결을 기다리는 중입니다."


func _make_host_row(seat: int) -> Control:
	var row := PanelContainer.new()
	row.add_theme_stylebox_override("panel", _style(Color("131826"), SEAT_COLORS[seat - 1].darkened(0.2), 2, 12, 0, 10))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	row.add_child(column)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	column.add_child(head)
	head.add_child(_badge(seat))
	var state: LobbyModel.SeatState = service.model.state_of(seat)
	var title := _label(_seat_title(seat, state), 17, Color("f1f3f5"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	match state:
		LobbyModel.SeatState.OPEN:
			head.add_child(_button("초대 코드 만들기", create_invite.bind(seat), 14, Color("1c6dd0")))
			head.add_child(_button("컴퓨터로 채우기", service.set_bot.bind(seat, true), 14, Color("495a85")))
		LobbyModel.SeatState.INVITED:
			head.add_child(_button("취소", cancel_invite.bind(seat), 13, Color("7a2a2a")))
			column.add_child(_make_invite_panel(seat))
		LobbyModel.SeatState.HUMAN:
			if seat != LobbyModel.HOST_SEAT:
				head.add_child(_button("내보내기", service.kick.bind(seat), 13, Color("7a2a2a")))
		LobbyModel.SeatState.BOT:
			head.add_child(_button("비우기", service.set_bot.bind(seat, false), 13, Color("495a85")))
	if _seat_errors.has(seat):
		var error := _label(str(_seat_errors[seat]), 13, Color("ff8787"))
		error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		column.add_child(error)
	return row


func _seat_title(seat: int, state: LobbyModel.SeatState) -> String:
	match state:
		LobbyModel.SeatState.OPEN: return "빈 자리"
		LobbyModel.SeatState.INVITED: return "초대 중" if _invite_codes.has(seat) else "초대 코드 만드는 중..."
		LobbyModel.SeatState.BOT: return service.model.name_of(seat)
	return "%s%s" % [service.model.name_of(seat), "  (방장)" if seat == LobbyModel.HOST_SEAT else ""]


func _make_invite_panel(seat: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	if not _invite_codes.has(seat):
		box.add_child(_label("연결 후보를 모으는 중입니다 (몇 초 걸립니다)...", 13, Color("adb5bd")))
		return box
	box.add_child(_label("1) 이 초대 코드를 친구에게 보내세요", 13, Color("adb5bd")))
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	box.add_child(code_row)
	var code_edit := _code_box(str(_invite_codes[seat]), false)
	code_edit.name = "InviteCode%d" % seat
	code_row.add_child(code_edit)
	code_row.add_child(_button("복사", copy_text.bind(str(_invite_codes[seat])), 13, Color("495a85")))
	box.add_child(_label("2) 친구가 돌려준 응답 코드를 붙여 넣고 [연결]", 13, Color("adb5bd")))
	var answer_row := HBoxContainer.new()
	answer_row.add_theme_constant_override("separation", 8)
	box.add_child(answer_row)
	var answer_edit := _code_box(str(_answer_texts.get(seat, "")), true)
	answer_edit.name = "AnswerCode%d" % seat
	answer_edit.text_changed.connect(func() -> void: _answer_texts[seat] = answer_edit.text)
	answer_row.add_child(answer_edit)
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 6)
	answer_row.add_child(buttons)
	buttons.add_child(_button("붙여넣기", paste_answer.bind(seat, answer_edit), 13, Color("495a85")))
	buttons.add_child(_button("연결", submit_answer.bind(seat), 14, Color("2b8a3e")))
	return box


func _rebuild_guest() -> void:
	if _guest_box == null:
		return
	for child: Node in _guest_box.get_children():
		_guest_box.remove_child(child)
		child.queue_free()
	if _guest_connected:
		_guest_box.add_child(_label("방에 입장했습니다! 방장이 게임을 시작하기를 기다리는 중...", 17, Color("8ce99a")))
		for seat: int in range(1, LobbyModel.SEAT_COUNT + 1):
			var row := PanelContainer.new()
			row.add_theme_stylebox_override("panel", _style(Color("131826"), SEAT_COLORS[seat - 1].darkened(0.2), 2, 12, 0, 10))
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 10)
			row.add_child(line)
			line.add_child(_badge(seat))
			var state: LobbyModel.SeatState = service.model.state_of(seat)
			var text: String = _seat_title(seat, state)
			if seat == service.my_seat():
				text += "  (나)"
			line.add_child(_label(text, 17, Color("f1f3f5")))
			_guest_box.add_child(row)
		return
	if _guest_answer_code == "":
		_guest_box.add_child(_label("방장에게 받은 초대 코드를 붙여 넣고 [참가하기]를 누르세요.", 14, Color("adb5bd")))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_guest_box.add_child(row)
		var edit := _code_box(_guest_invite_text, true)
		edit.name = "InviteInput"
		edit.text_changed.connect(func() -> void: _guest_invite_text = edit.text)
		row.add_child(edit)
		var buttons := VBoxContainer.new()
		buttons.add_theme_constant_override("separation", 6)
		row.add_child(buttons)
		buttons.add_child(_button("붙여넣기", paste_invite.bind(edit), 13, Color("495a85")))
		buttons.add_child(_button("참가하기", join_with_code, 14, Color("2b8a3e")))
	else:
		_guest_box.add_child(_label("이 응답 코드를 방장에게 보내세요. 방장이 [연결]을 누르면 자동으로 입장합니다.", 14, Color("adb5bd")))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_guest_box.add_child(row)
		var code_edit := _code_box(_guest_answer_code, false)
		code_edit.name = "AnswerOutput"
		row.add_child(code_edit)
		row.add_child(_button("복사", copy_text.bind(_guest_answer_code), 13, Color("495a85")))


# ---------------------------------------------------------------------------
# 동작
# ---------------------------------------------------------------------------

func create_invite(seat: int) -> void:
	_seat_errors.erase(seat)
	_invite_codes.erase(seat)
	_answer_texts.erase(seat)
	if not service.create_invite(seat):
		_seat_errors[seat] = "초대 코드를 만들 수 없습니다."
		_rebuild()


func cancel_invite(seat: int) -> void:
	_invite_codes.erase(seat)
	_answer_texts.erase(seat)
	_seat_errors.erase(seat)
	service.cancel_invite(seat)


func submit_answer(seat: int) -> void:
	_seat_errors.erase(seat)
	if service.submit_answer(seat, str(_answer_texts.get(seat, ""))):
		_seat_errors[seat] = "연결하는 중입니다... 잠시만 기다려 주세요."
	_rebuild()


func paste_answer(seat: int, edit: TextEdit) -> void:
	edit.text = DisplayServer.clipboard_get()
	_answer_texts[seat] = edit.text


func paste_invite(edit: TextEdit) -> void:
	edit.text = DisplayServer.clipboard_get()
	_guest_invite_text = edit.text


func join_with_code() -> void:
	if service.join_room(GameSession.display_nickname(), _guest_invite_text):
		_status.text = "응답 코드를 만드는 중입니다..."


func copy_text(text: String) -> void:
	DisplayServer.clipboard_set(text)
	if _status != null:
		_status.text = "코드를 복사했습니다. 친구에게 붙여 넣어 보내 주세요."


func leave_room() -> void:
	service.leave()
	_invite_codes.clear()
	_answer_texts.clear()
	_seat_errors.clear()
	_show_choose()


func go_back() -> void:
	if change_scene_enabled:
		get_tree().change_scene_to_file(START_MENU_SCENE)


func _on_start_pressed() -> void:
	if _status != null:
		_status.text = "멀티플레이 게임 화면은 다음 단계에서 연결됩니다."


func _on_invite_ready(seat: int, code: String) -> void:
	_invite_codes[seat] = code
	_rebuild()


func _on_link_failed(seat: int, message: String) -> void:
	if seat == 0:
		if _status != null:
			_status.text = message
	else:
		_seat_errors[seat] = message
	_rebuild()


func _on_answer_ready(code: String) -> void:
	_guest_answer_code = code
	if _status != null:
		_status.text = ""
	_rebuild()


func _on_joined() -> void:
	_guest_connected = true
	_rebuild()


func _on_left_room(reason: String) -> void:
	_show_choose()
	var message := _label(reason, 14, Color("ff8787"))
	_panel_box.add_child(message)


# ---------------------------------------------------------------------------
# 위젯 도우미
# ---------------------------------------------------------------------------

func _code_box(text: String, editable: bool) -> TextEdit:
	var edit := TextEdit.new()
	edit.text = text
	edit.editable = editable
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.custom_minimum_size = Vector2(600, 64)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 12)
	edit.placeholder_text = "여기에 코드를 붙여 넣으세요"
	return edit


func _badge(seat: int) -> Label:
	var badge := _label("P%d" % seat, 17, Color.WHITE)
	badge.custom_minimum_size = Vector2(44, 32)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_stylebox_override("normal", _style(SEAT_COLORS[seat - 1], SEAT_COLORS[seat - 1].lightened(0.3), 2, 8, 0, 2))
	return badge


func _label(text: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	return label


func _style(bg: Color, border: Color, border_width: int, radius: int, shadow: int, margin: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = shadow
	style.set_content_margin_all(margin)
	return style


func _button(text: String, callback: Callable, size_px: int, base: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 56 if size_px >= 20 else 34)
	button.add_theme_font_size_override("font_size", size_px)
	button.add_theme_stylebox_override("normal", _style(base, base.lightened(0.3), 2, 12, 4, 8))
	button.add_theme_stylebox_override("hover", _style(base.lightened(0.15), COLOR_GOLD, 2, 12, 6, 8))
	button.add_theme_stylebox_override("pressed", _style(base.darkened(0.2), COLOR_GOLD, 2, 12, 0, 8))
	button.add_theme_stylebox_override("disabled", _style(base.darkened(0.5), base.darkened(0.2), 2, 12, 0, 8))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if callback.is_valid():
		button.pressed.connect(callback)
	return button
