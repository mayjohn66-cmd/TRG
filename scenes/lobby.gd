# File: res://scenes/lobby.gd
# Class: class_name Lobby
# Role: 멀티플레이 로비 화면. 메뉴는 [빠른 랜덤 매칭] / [친선전 방 만들기] / [방 코드로 입장] 세 카드이며, 빠른 매칭은 공용 대기열(QuickMatch)이 방을 찾거나 열고 15초 안에 안 차면 AI로 채워 시작한다. 방장은 5자리 방 코드와 P1~P4 좌석 상태만 보고, 참가자는 방 코드만 입력하면 공개 릴레이를 통해 백그라운드에서 WebRTC 연결이 자동으로 맺어진다. 긴 초대/응답 코드는 [고급: 수동 코드 연결] 접이식 메뉴에만 숨어 있다
class_name Lobby
extends Control

const START_MENU_SCENE: String = "res://scenes/start_menu.tscn"
const BOARD_SCENE: String = "res://scenes/main_board.tscn"
const COLOR_BG: Color = Color("0d1018")
const COLOR_GOLD: Color = Color("ffd43b")
const SEAT_COLORS: Array[Color] = [Color("e03131"), Color("1c7ed6"), Color("2f9e44"), Color("f08c00")]

enum Mode { CHOOSE, HOST, GUEST, QUICK }

## 테스트에서 씬 전환을 막기 위한 스위치.
var change_scene_enabled: bool = true
var mode: Mode = Mode.CHOOSE
var service: LobbyService = null
var quick: QuickMatch = null
## 게임 시작을 눌러 장면 전환까지 마쳤다 (테스트 확인용).
var game_started: bool = false

var _panel_box: VBoxContainer = null
var _status: Label = null
var _seat_box: VBoxContainer = null
var _start_button: Button = null
var _guest_box: VBoxContainer = null
var _manual_box: VBoxContainer = null   # [고급: 수동 코드 연결] 내용 (접혀 있으면 숨김)
var _room_label: Label = null
var _quick_status: Label = null
var _quick_count: Label = null
var _quick_now_button: Button = null
var _quick_ui_left: float = 0.0
var _join_input: LineEdit = null
var _join_button: Button = null
var _invite_codes: Dictionary = {}   # 좌석 -> 방장이 만든 초대 코드 (고급 메뉴용)
var _answer_texts: Dictionary = {}   # 좌석 -> 방장이 붙여 넣은 응답 코드 (다시 그려도 유지)
var _seat_errors: Dictionary = {}    # 좌석 -> 안내/오류 문구
var _guest_room_text: String = ""
var _guest_invite_text: String = ""
var _guest_answer_code: String = ""
var _guest_connected: bool = false
var _guest_busy: bool = false
var _manual_open: bool = false
var _relay_ok: bool = true


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
	service.room_ready.connect(_on_room_ready)
	service.relay_status_changed.connect(_on_relay_status)
	service.join_progress.connect(_on_join_progress)
	service.join_failed.connect(_on_join_failed)
	quick = QuickMatch.new()
	quick.name = "QuickMatch"
	quick.service = service
	add_child(quick)
	quick.start_requested.connect(_on_quick_start_requested)
	quick.failed.connect(_on_quick_failed)
	quick.state_changed.connect(func(_state: int) -> void: _refresh_quick())
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
	_manual_box = null
	_room_label = null
	_quick_status = null
	_quick_count = null
	_quick_now_button = null
	_join_input = null
	_join_button = null
	_start_button = null
	_status = null


func _title(text: String) -> void:
	var title := _label(text, 30, COLOR_GOLD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_box.add_child(title)


func _show_choose() -> void:
	if quick != null:
		quick.stop()
	mode = Mode.CHOOSE
	_clear_panel()
	_title("멀티플레이")
	var hello := _label("%s 님, 어떻게 플레이할까요?" % GameSession.display_nickname(), 16, Color("ced4da"))
	hello.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_box.add_child(hello)
	_panel_box.add_child(_card("QuickMatchCard", "빠른 랜덤 매칭", "버튼 하나로 바로 매칭  (15초 안에 AI가 빈자리를 채워 시작)", start_quick_match, Color("c2410c")))
	_panel_box.add_child(_card("HostCard", "친선전 방 만들기", "5자리 방 코드를 만들어 친구를 초대", start_hosting, Color("2b8a3e")))
	_panel_box.add_child(_card("JoinCard", "방 코드로 입장", "친구에게 받은 5자리 코드로 바로 합류", start_guest, Color("1c6dd0")))
	_panel_box.add_child(_button("뒤로", go_back, 14, Color("4a3a66")))


## 큼직한 카드형 버튼 (제목 + 한 줄 설명).
func _card(node_name: String, title: String, subtitle: String, callback: Callable, base: Color) -> Button:
	var card := _button("", callback, 22, base)
	card.name = node_name
	card.custom_minimum_size = Vector2(0, 92)
	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(column)
	var head := _label(title, 26, Color.WHITE)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(head)
	var sub := _label(subtitle, 13, Color("ffe8cc") if base == Color("c2410c") else Color("e9ecef"))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(sub)
	return card


## [빠른 랜덤 매칭]: 대기열에 들어간다 (열린 방이 있으면 합류, 없으면 방장이 되어 기다림).
func start_quick_match() -> void:
	mode = Mode.QUICK
	_manual_open = false
	_clear_panel()
	_title("빠른 랜덤 매칭")
	_quick_status = _label("", 20, COLOR_GOLD)
	_quick_status.name = "QuickStatus"
	_quick_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quick_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quick_status.custom_minimum_size = Vector2(820, 0)
	_panel_box.add_child(_quick_status)
	_quick_count = _label("", 14, Color("adb5bd"))
	_quick_count.name = "QuickCountdown"
	_quick_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_box.add_child(_quick_count)
	_seat_box = VBoxContainer.new()
	_seat_box.add_theme_constant_override("separation", 8)
	_panel_box.add_child(_seat_box)
	_status = _label("", 14, Color("ffe066"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_box.add_child(_status)
	_quick_now_button = _button("지금 바로 시작  (빈자리 AI 채우기)", quick.start_now, 18, Color("2b8a3e"))
	_quick_now_button.name = "QuickStartNow"
	_panel_box.add_child(_quick_now_button)
	_panel_box.add_child(_button("매칭 취소", leave_room, 14, Color("7a2a2a")))
	quick.start()
	_refresh_quick()


## 대기 화면의 문구·자리 목록을 현재 상태로 맞춘다.
func _refresh_quick() -> void:
	if mode != Mode.QUICK or _quick_status == null:
		return
	var seconds: int = int(quick.elapsed)
	match quick.state:
		QuickMatch.State.SEARCHING, QuickMatch.State.HOSTING, QuickMatch.State.IDLE:
			_quick_status.text = "매칭 중... 다른 교주님을 찾고 있습니다 (경과 시간: %d초)" % seconds
		QuickMatch.State.JOINING:
			_quick_status.text = "방을 찾았습니다! 입장하는 중... (경과 시간: %d초)" % seconds
		QuickMatch.State.GUEST:
			_quick_status.text = "매칭 완료! 방장이 곧 게임을 시작합니다."
		QuickMatch.State.STARTING:
			_quick_status.text = "게임을 시작합니다..."
	if quick.state == QuickMatch.State.HOSTING:
		_quick_count.text = "%d초 뒤에 빈자리를 AI가 채우고 시작합니다  (현재 %d/%d명)" % [quick.seconds_left(), service.model.human_count(), LobbyModel.SEAT_COUNT]
	else:
		_quick_count.text = ""
	if _quick_now_button != null:
		_quick_now_button.disabled = quick.state != QuickMatch.State.HOSTING
	_rebuild_quick_rows()


func _rebuild_quick_rows() -> void:
	if _seat_box == null:
		return
	for child: Node in _seat_box.get_children():
		_seat_box.remove_child(child)
		child.queue_free()
	for seat: int in range(1, LobbyModel.SEAT_COUNT + 1):
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _style(Color("131826"), SEAT_COLORS[seat - 1].darkened(0.2), 2, 12, 0, 10))
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 10)
		row.add_child(line)
		line.add_child(_badge(seat))
		var seat_state: LobbyModel.SeatState = service.model.state_of(seat)
		var text: String = _seat_title(seat, seat_state)
		if seat_state == LobbyModel.SeatState.OPEN or seat_state == LobbyModel.SeatState.INVITED:
			text = "대기 중..."
		if service.in_room() and seat == service.my_seat():
			text += "  (나)"
		line.add_child(_label(text, 17, Color("f1f3f5")))
		_seat_box.add_child(row)


func _process(delta: float) -> void:
	if mode != Mode.QUICK:
		return
	_quick_ui_left -= delta
	if _quick_ui_left <= 0.0:
		_quick_ui_left = 0.25
		_refresh_quick()


func _on_quick_start_requested() -> void:
	start_game()


func _on_quick_failed(message: String) -> void:
	_show_choose()
	_panel_box.add_child(_label(message, 14, Color("ff8787")))


## 게임을 시작한다: 빈자리는 AI 봇으로 채운다. 지금은 사람이 방장 혼자일 때만 시작할 수 있다 (참가자와 함께하는 게임 화면 동기화는 다음 단계).
func start_game() -> void:
	if service.model.human_count() > 1:
		_set_status("참가자와 함께하는 온라인 게임 화면은 아직 연결되지 않았습니다 (다음 단계). 방은 그대로 유지됩니다.", true)
		return
	service.fill_with_bots()
	GameSession.mode = GameSession.MODE_AI
	game_started = true
	if change_scene_enabled:
		get_tree().change_scene_to_file(BOARD_SCENE)


## [방 만들기]: 방장이 되어 방 코드와 좌석 화면으로 간다.
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
	_manual_open = false
	_relay_ok = true
	_clear_panel()
	_title("친선전 방")
	_panel_box.add_child(_make_code_badge())
	var help := _label("친구에게 이 방 코드를 알려 주세요. 친구가 코드를 입력하면 자동으로 연결됩니다. 빈 자리는 시작할 때 컴퓨터가 채웁니다.", 13, Color("adb5bd"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.custom_minimum_size = Vector2(820, 0)
	_panel_box.add_child(help)
	_seat_box = VBoxContainer.new()
	_seat_box.add_theme_constant_override("separation", 8)
	_panel_box.add_child(_seat_box)
	_status = _label("", 14, Color("ffe066"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_box.add_child(_status)
	_add_manual_fold()
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	_panel_box.add_child(footer)
	_start_button = _button("게임 시작  (빈자리는 AI)", _on_start_pressed, 18, Color("2b8a3e"))
	_start_button.name = "StartGame"
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_start_button)
	footer.add_child(_button("방 닫고 나가기", leave_room, 14, Color("7a2a2a")))
	_rebuild()


## 상단 중앙의 황금색 방 코드 배지 + 코드 복사 버튼.
func _make_code_badge() -> Control:
	var center := CenterContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	center.add_child(row)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", _style(Color("3d2f06"), COLOR_GOLD, 3, 16, 6, 14))
	row.add_child(badge)
	_room_label = _label(_room_text(), 40, COLOR_GOLD)
	_room_label.name = "RoomCode"
	badge.add_child(_room_label)
	var copy := _button("코드 복사", copy_room_code, 16, Color("495a85"))
	copy.name = "CopyRoomCode"
	copy.custom_minimum_size = Vector2(130, 56)
	row.add_child(copy)
	return center


func _room_text() -> String:
	return "[ 방 코드: %s ]" % (service.room_code if service.room_code != "" else "-----")


## [고급: 수동 코드 연결] 접이식 메뉴. 자동 연결이 막힌 네트워크에서만 쓰는 비상용이라 처음엔 접혀 있다.
func _add_manual_fold() -> void:
	var toggle := _button("고급: 수동 코드 연결  %s" % ("▼" if _manual_open else "▶"), toggle_manual, 12, Color("2a3147"))
	toggle.name = "ManualToggle"
	toggle.custom_minimum_size = Vector2(0, 28)
	_panel_box.add_child(toggle)
	_manual_box = VBoxContainer.new()
	_manual_box.name = "ManualBox"
	_manual_box.add_theme_constant_override("separation", 8)
	_manual_box.visible = _manual_open
	_panel_box.add_child(_manual_box)


func toggle_manual() -> void:
	_manual_open = not _manual_open
	var toggle: Button = _panel_box.find_child("ManualToggle", true, false)
	if toggle != null:
		toggle.text = "고급: 수동 코드 연결  %s" % ("▼" if _manual_open else "▶")
	if _manual_box != null:
		_manual_box.visible = _manual_open


## [방 입장]: 방 코드 5자리를 입력하는 화면으로 간다.
func start_guest() -> void:
	mode = Mode.GUEST
	_guest_room_text = ""
	_guest_invite_text = ""
	_guest_answer_code = ""
	_guest_connected = false
	_guest_busy = false
	_manual_open = false
	_clear_panel()
	_title("방 입장")
	_guest_box = VBoxContainer.new()
	_guest_box.add_theme_constant_override("separation", 10)
	_panel_box.add_child(_guest_box)
	_status = _label("", 15, Color("ffe066"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_box.add_child(_status)
	_add_manual_fold()
	_panel_box.add_child(_button("나가기", leave_room, 14, Color("7a2a2a")))
	_rebuild()


func _rebuild() -> void:
	match mode:
		Mode.HOST: _rebuild_host()
		Mode.GUEST: _rebuild_guest()
		Mode.QUICK: _refresh_quick()


func _rebuild_host() -> void:
	if _seat_box == null:
		return
	for child: Node in _seat_box.get_children():
		_seat_box.remove_child(child)
		child.queue_free()
	for seat: int in range(1, LobbyModel.SEAT_COUNT + 1):
		_seat_box.add_child(_make_host_row(seat))
	_rebuild_manual_host()
	if _room_label != null:
		_room_label.text = _room_text()
	if _start_button != null:
		# 지금은 방장 혼자(나머지는 AI)일 때만 시작할 수 있다. 참가자가 있으면 온라인 게임 화면 연동(다음 단계)을 기다린다.
		var alone: bool = service.model.human_count() <= 1
		_start_button.disabled = not alone
		_start_button.text = "게임 시작  (빈자리는 AI)" if alone else "게임 시작  (참가자와의 게임 화면은 다음 단계)"
	if _status != null and not _seat_errors.has(0):
		if not _relay_ok:
			_status.text = "자동 연결 서버에 닿지 못했습니다. 아래 [고급: 수동 코드 연결]을 열어 코드를 직접 주고받을 수 있습니다."
		else:
			_status.text = "친구의 입장을 기다리는 중입니다. 방 코드를 알려 주세요."


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
	title.name = "SeatTitle%d" % seat
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	match state:
		LobbyModel.SeatState.OPEN, LobbyModel.SeatState.INVITED:
			var fill := _button("AI 봇으로 채우기", service.set_bot.bind(seat, true), 14, Color("495a85"))
			fill.name = "FillBot%d" % seat
			head.add_child(fill)
		LobbyModel.SeatState.HUMAN:
			if seat != LobbyModel.HOST_SEAT:
				head.add_child(_button("내보내기", service.kick.bind(seat), 13, Color("7a2a2a")))
		LobbyModel.SeatState.BOT:
			head.add_child(_button("비우기", service.set_bot.bind(seat, false), 13, Color("495a85")))
	return row


func _seat_title(seat: int, state: LobbyModel.SeatState) -> String:
	match state:
		LobbyModel.SeatState.OPEN: return "빈 자리"
		LobbyModel.SeatState.INVITED: return "입장 대기 중..."
		LobbyModel.SeatState.BOT: return "AI 봇"
	if seat == LobbyModel.HOST_SEAT:
		return "방장  %s" % service.model.name_of(seat)
	return "입장 완료!  %s" % service.model.name_of(seat)


## 고급 메뉴 속 방장용 수동 연결 줄: 열린 자리는 초대 코드 만들기, 초대 중인 자리는 코드 표시 + 응답 붙여넣기.
func _rebuild_manual_host() -> void:
	if _manual_box == null:
		return
	for child: Node in _manual_box.get_children():
		_manual_box.remove_child(child)
		child.queue_free()
	var note := _label("자동 연결이 안 될 때만 쓰세요. 초대 코드를 친구에게 보내고, 친구가 돌려준 응답 코드를 붙여 넣어 [연결]을 누릅니다.", 12, Color("868e96"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(800, 0)
	_manual_box.add_child(note)
	for seat: int in range(2, LobbyModel.SEAT_COUNT + 1):
		var state: LobbyModel.SeatState = service.model.state_of(seat)
		if state != LobbyModel.SeatState.OPEN and state != LobbyModel.SeatState.INVITED:
			continue
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 6)
		_manual_box.add_child(column)
		var head := HBoxContainer.new()
		head.add_theme_constant_override("separation", 10)
		column.add_child(head)
		head.add_child(_badge(seat))
		if state == LobbyModel.SeatState.OPEN:
			head.add_child(_button("수동 초대 코드 만들기", create_invite.bind(seat), 13, Color("1c6dd0")))
		else:
			head.add_child(_button("초대 취소", cancel_invite.bind(seat), 13, Color("7a2a2a")))
			column.add_child(_make_invite_panel(seat))
		if _seat_errors.has(seat):
			var error := _label(str(_seat_errors[seat]), 13, Color("ff8787"))
			error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			column.add_child(error)


func _make_invite_panel(seat: int) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	if not _invite_codes.has(seat):
		box.add_child(_label("연결 후보를 모으는 중입니다 (몇 초 걸립니다)...", 13, Color("adb5bd")))
		return box
	box.add_child(_label("1) 초대 코드를 친구에게 보내세요", 12, Color("adb5bd")))
	var code_row := HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	box.add_child(code_row)
	var code_edit := _code_box(str(_invite_codes[seat]), false)
	code_edit.name = "InviteCode%d" % seat
	code_row.add_child(code_edit)
	code_row.add_child(_button("복사", copy_text.bind(str(_invite_codes[seat])), 13, Color("495a85")))
	box.add_child(_label("2) 친구가 돌려준 응답 코드를 붙여 넣고 [연결]", 12, Color("adb5bd")))
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
	_join_input = null
	_join_button = null
	if _manual_box != null:
		for child: Node in _manual_box.get_children():
			_manual_box.remove_child(child)
			child.queue_free()
	if _guest_connected:
		_guest_box.add_child(_label("입장 완료! 방장이 게임을 시작하기를 기다리는 중...", 17, Color("8ce99a")))
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
	var prompt := _label("방장에게 받은 방 코드 5자리를 입력하세요.", 15, Color("adb5bd"))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guest_box.add_child(prompt)
	var center := CenterContainer.new()
	_guest_box.add_child(center)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	center.add_child(row)
	_join_input = LineEdit.new()
	_join_input.name = "RoomCodeInput"
	_join_input.max_length = RoomCode.LENGTH
	_join_input.placeholder_text = "_ _ _ _ _"
	_join_input.text = _guest_room_text
	_join_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_input.custom_minimum_size = Vector2(260, 64)
	_join_input.editable = not _guest_busy
	_join_input.add_theme_font_size_override("font_size", 36)
	_join_input.add_theme_color_override("font_color", COLOR_GOLD)
	_join_input.text_changed.connect(_on_room_input_changed)
	_join_input.text_submitted.connect(func(_text: String) -> void: join_with_room_code())
	row.add_child(_join_input)
	_join_button = _button("방 입장하기", join_with_room_code, 20, Color("2b8a3e"))
	_join_button.name = "JoinRoom"
	_join_button.custom_minimum_size = Vector2(190, 64)
	_join_button.disabled = _guest_busy
	row.add_child(_join_button)
	_rebuild_manual_guest()


## 고급 메뉴 속 참가자용 수동 연결: 초대 코드를 붙여 넣으면 응답 코드가 나온다.
func _rebuild_manual_guest() -> void:
	if _manual_box == null:
		return
	if _guest_answer_code == "":
		var note := _label("자동 입장이 안 될 때만 쓰세요. 방장에게 받은 초대 코드를 붙여 넣고 [참가하기]를 누른 뒤, 나온 응답 코드를 방장에게 보내세요.", 12, Color("868e96"))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(800, 0)
		_manual_box.add_child(note)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_manual_box.add_child(row)
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
		_manual_box.add_child(_label("이 응답 코드를 방장에게 보내세요. 방장이 [연결]을 누르면 자동으로 입장합니다.", 12, Color("adb5bd")))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		_manual_box.add_child(row)
		var code_edit := _code_box(_guest_answer_code, false)
		code_edit.name = "AnswerOutput"
		row.add_child(code_edit)
		row.add_child(_button("복사", copy_text.bind(_guest_answer_code), 13, Color("495a85")))


# ---------------------------------------------------------------------------
# 동작
# ---------------------------------------------------------------------------

func copy_room_code() -> void:
	if service.room_code == "":
		return
	DisplayServer.clipboard_set(service.room_code)
	if _status != null:
		_status.text = "방 코드 %s 를 복사했습니다. 친구에게 붙여 넣어 보내 주세요." % service.room_code


func _on_room_input_changed(text: String) -> void:
	var cleaned: String = RoomCode.normalize(text)
	_guest_room_text = cleaned
	if _join_input != null and _join_input.text != cleaned:
		_join_input.text = cleaned
		_join_input.caret_column = cleaned.length()


## [방 입장하기]: 방 코드만으로 자동 연결을 시작한다.
func join_with_room_code() -> void:
	if _guest_busy:
		return
	if not RoomCode.is_valid(RoomCode.normalize(_guest_room_text)):
		_set_status("방 코드는 영문 대문자와 숫자 %d자리입니다." % RoomCode.LENGTH, true)
		return
	_guest_busy = true
	_set_status("연결 중...", false)
	if _join_input != null:
		_join_input.editable = false
	if _join_button != null:
		_join_button.disabled = true
	if not service.join_by_room_code(GameSession.display_nickname(), _guest_room_text):
		_guest_busy = false
		_rebuild()


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


## 고급: 붙여 넣은 초대 코드로 수동 입장.
func join_with_code() -> void:
	if service.join_room(GameSession.display_nickname(), _guest_invite_text):
		_set_status("응답 코드를 만드는 중입니다...", false)


func copy_text(text: String) -> void:
	DisplayServer.clipboard_set(text)
	_set_status("코드를 복사했습니다. 친구에게 붙여 넣어 보내 주세요.", false)


func _set_status(text: String, is_error: bool) -> void:
	if _status != null:
		_status.text = text
		_status.add_theme_color_override("font_color", Color("ff8787") if is_error else Color("ffe066"))


func leave_room() -> void:
	service.leave()
	_invite_codes.clear()
	_answer_texts.clear()
	_seat_errors.clear()
	_guest_busy = false
	_show_choose()


func go_back() -> void:
	if change_scene_enabled:
		get_tree().change_scene_to_file(START_MENU_SCENE)


func _on_start_pressed() -> void:
	start_game()


func _on_room_ready(_code: String) -> void:
	if _room_label != null:
		_room_label.text = _room_text()


func _on_relay_status(ok: bool) -> void:
	_relay_ok = ok
	if mode == Mode.HOST:
		_rebuild()
		if not ok and not _manual_open:
			toggle_manual()


func _on_join_progress(message: String) -> void:
	_set_status(message, false)


func _on_join_failed(message: String) -> void:
	_guest_busy = false
	_guest_answer_code = ""
	_rebuild()
	_set_status(message, true)
	if mode == Mode.GUEST and not _manual_open and message.contains("고급"):
		toggle_manual()


func _on_invite_ready(seat: int, code: String) -> void:
	_invite_codes[seat] = code
	_rebuild()


func _on_link_failed(seat: int, message: String) -> void:
	if seat == 0:
		_set_status(message, true)
	else:
		_seat_errors[seat] = message
	_rebuild()


func _on_answer_ready(code: String) -> void:
	_guest_answer_code = code
	_rebuild()


func _on_joined() -> void:
	if mode == Mode.QUICK:
		_refresh_quick()
		return
	_guest_connected = true
	_guest_busy = false
	_set_status("", false)
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
