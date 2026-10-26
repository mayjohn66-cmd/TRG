# File: res://scenes/lobby.gd
# Class: class_name Lobby
# Role: 멀티플레이 로비 화면(밝은 민트/청록 테마, 위·아래 띠). 시작 메뉴의 [친선 줘팸터]는 방 코드 입력 + [새 방 만들기], [익명 줘팸터]는 곧바로 빠른 랜덤 매칭이다. 빠른 매칭은 공용 대기열(QuickMatch)이 방을 찾거나 열고 15초 안에 안 차면 AI로 채워 시작한다. 방장은 5자리 방 코드와 P1~P4 좌석 상태만 보고, 참가자는 방 코드만 입력하면 공개 릴레이를 통해 백그라운드에서 WebRTC 연결이 자동으로 맺어진다.
class_name Lobby
extends Control

const START_MENU_SCENE: String = "res://scenes/start_menu.tscn"
const BOARD_SCENE: String = "res://scenes/main_board.tscn"
const COLOR_GOLD: Color = Color("8a6a1a")  ## 방 코드 배지 글자색 (크림색 배지 위의 진한 금갈색)
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
var _top: Dictionary = {}
var _bottom: Dictionary = {}
var _status: Label = null
var _seat_box: BoxContainer = null
var _start_button: Button = null
var _guest_box: VBoxContainer = null
var _room_label: Label = null
var _quick_status: Label = null
var _quick_count: Label = null
var _quick_now_button: Button = null
var _quick_ui_left: float = 0.0
var _join_input: LineEdit = null
var _join_button: Button = null
var _guest_room_text: String = ""
var _guest_connected: bool = false
var _guest_busy: bool = false
var _relay_ok: bool = true


func _ready() -> void:
	Sfx.unlock()
	Sfx.bgm_play.call_deferred(Sfx.LOBBY_TRACK)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	name = "Lobby"
	service = LobbyService.new()
	service.name = "LobbyService"
	add_child(service)
	service.link_failed.connect(_on_link_failed)
	service.joined.connect(_on_joined)
	service.left_room.connect(_on_left_room)
	service.roster_changed.connect(_rebuild)
	service.room_ready.connect(_on_room_ready)
	service.relay_status_changed.connect(_on_relay_status)
	service.join_progress.connect(_on_join_progress)
	service.join_failed.connect(_on_join_failed)
	service.game_starting.connect(_on_game_starting)
	quick = QuickMatch.new()
	quick.name = "QuickMatch"
	quick.service = service
	add_child(quick)
	quick.start_requested.connect(_on_quick_start_requested)
	quick.failed.connect(_on_quick_failed)
	quick.state_changed.connect(func(_state: int) -> void: _refresh_quick())
	LobbyTheme.add_background(self)
	_top = LobbyTheme.add_top_bar(self, "친선 줘팸터", _on_back_pressed, "규칙", func() -> void: LobbyTheme.show_rules(self))
	_bottom = LobbyTheme.add_bottom_bar(self, "%s 교주님" % GameSession.display_nickname(), "설정", func() -> void: LobbyTheme.show_settings(self))
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_top = LobbyTheme.BAR_HEIGHT
	scroll.offset_bottom = -LobbyTheme.BAR_HEIGHT
	add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	panel.add_theme_stylebox_override("panel", LobbyTheme.style(Color(LobbyTheme.MINT, 0.93), LobbyTheme.MINT_EDGE, 3, 30, 12, 22))
	center.add_child(panel)
	_panel_box = VBoxContainer.new()
	_panel_box.add_theme_constant_override("separation", 12)
	panel.add_child(_panel_box)
	if GameSession.lobby_intent == &"quick":
		start_quick_match()
	else:
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
	_room_label = null
	_quick_status = null
	_quick_count = null
	_quick_now_button = null
	_join_input = null
	_join_button = null
	_start_button = null
	_status = null


## 위쪽 띠의 제목을 바꾼다.
func _title(text: String) -> void:
	if _top.has("title"):
		(_top["title"] as Label).text = text


## 위쪽 띠의 [뒤로가기]: 방 안이면 방을 나가고(코드 입력 화면으로), 코드 입력 화면과 빠른 매칭이면 시작 메뉴로 돌아간다.
func _on_back_pressed() -> void:
	if mode == Mode.HOST or (mode == Mode.GUEST):
		leave_room()
	else:
		if quick != null:
			quick.stop()
		go_back()


## [친선 줘팸터]: 방 코드 5자리를 입력해 들어가거나 [새 방 만들기]로 내가 방장이 된다.
func _show_choose() -> void:
	if quick != null:
		quick.stop()
	mode = Mode.CHOOSE
	_guest_room_text = ""
	_guest_connected = false
	_guest_busy = false
	_clear_panel()
	_title("친선 줘팸터")
	_guest_box = VBoxContainer.new()
	_guest_box.add_theme_constant_override("separation", 12)
	_panel_box.add_child(_guest_box)
	_status = _label("", 16, Color("c47f00"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_box.add_child(_status)
	_rebuild()


func start_guest() -> void:
	_show_choose()


## [빠른 랜덤 매칭]: 대기열에 들어간다 (열린 방이 있으면 합류, 없으면 방장이 되어 기다림).
func start_quick_match() -> void:
	mode = Mode.QUICK
	_clear_panel()
	_title("익명 줘팸터")
	_quick_status = _label("", 24, LobbyTheme.TEAL_DARK)
	_quick_status.name = "QuickStatus"
	_quick_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quick_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quick_status.custom_minimum_size = Vector2(700, 0)
	_panel_box.add_child(_quick_status)
	_quick_count = _label("", 14, Color("3d6b5c"))
	_quick_count.name = "QuickCountdown"
	_quick_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_box.add_child(_quick_count)
	_seat_box = _new_seat_box()
	_panel_box.add_child(_seat_box)
	_status = _label("", 14, Color("c47f00"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_box.add_child(_status)
	_quick_now_button = LobbyTheme.cream_button("지금 바로 시작  (빈자리 AI 채우기)", quick.start_now, 24)
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
		var seat_state: LobbyModel.SeatState = service.model.state_of(seat)
		var title: String = _seat_title(seat, seat_state)
		if seat_state == LobbyModel.SeatState.OPEN or seat_state == LobbyModel.SeatState.INVITED:
			title = "대기 중..."
		_seat_box.add_child(_make_seat_card(seat, title, service.in_room() and seat == service.my_seat())["root"])


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
	_panel_box.add_child(_label(message, 14, Color("d6336c")))


## 게임을 시작한다. 방장 혼자면 컴퓨터 대전(빈자리 전부 AI), 사람이 둘 이상이면 온라인 대전: 사람 + 방장이 채운 AI만 참여하고 비어 있는 자리는 빠진다 (2인 대전 가능).
func start_game() -> void:
	if service.model.human_count() <= 1:
		service.fill_with_bots()
		GameSession.clear_net()
		GameSession.mode = GameSession.MODE_AI
		game_started = true
		if change_scene_enabled:
			get_tree().change_scene_to_file(BOARD_SCENE)
		return
	if not service.begin_online_game():
		_set_status("게임을 시작할 수 없습니다. 방을 다시 만들어 주세요.", true)


## 방장이 시작했다 (방장·참가자 모두): 온라인 설정을 세션에 넣고 게임 화면으로 간다.
func _on_game_starting(config: Dictionary) -> void:
	GameSession.set_net(service.is_host, service.my_seat(), config)
	game_started = true
	if change_scene_enabled:
		get_tree().change_scene_to_file(BOARD_SCENE)


## [방 만들기]: 방장이 되어 방 코드와 좌석 화면으로 간다.
func start_hosting() -> void:
	if not service.host_room(GameSession.display_nickname()):
		_show_choose()
		var warning := _label("방을 만들 수 없습니다. 웹 브라우저(Chrome·Edge·Safari 등)에서 열어 주세요.", 13, Color("d6336c"))
		warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_panel_box.add_child(warning)
		return
	mode = Mode.HOST
	_relay_ok = true
	_clear_panel()
	_title("친선 줘팸터")
	_panel_box.add_child(_make_code_badge())
	var help := _label("친구에게 이 방 코드를 알려 주세요. 친구가 코드를 입력하면 자동으로 연결됩니다. 혼자면 AI 3명과, 친구가 있으면 사람끼리(2~4인) 시작하며 비워 둔 자리는 빠지고 AI는 [AI 봇으로 채우기]를 누른 자리만 참여합니다.", 13, Color("3d6b5c"))
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.custom_minimum_size = Vector2(700, 0)
	_panel_box.add_child(help)
	_seat_box = _new_seat_box()
	_panel_box.add_child(_seat_box)
	_status = _label("", 14, Color("c47f00"))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_box.add_child(_status)
	var test_tip := _label("혼자 테스트하려면 브라우저 창을 두 개 나란히 띄우세요 (탭 전환은 안 됩니다: 가려진 탭은 브라우저가 멈춥니다).", 11, Color("5a8070"))
	test_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	test_tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel_box.add_child(test_tip)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	_panel_box.add_child(footer)
	_start_button = LobbyTheme.cream_button("게임 시작  (빈자리는 AI)", _on_start_pressed, 26)
	_start_button.name = "StartGame"
	_start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_start_button)
	var rules_button := LobbyTheme.small_button("방 규칙 설정", func() -> void: RoomRulesPanel.open(self, true), &"blue", 16)
	rules_button.name = "OpenRoomRules"
	rules_button.custom_minimum_size = Vector2(150, 0)
	footer.add_child(rules_button)
	footer.add_child(_button("방 닫고 나가기", leave_room, 14, Color("7a2a2a")))
	_rebuild()


## 상단 중앙의 황금색 방 코드 배지 + 코드 복사 버튼.
func _make_code_badge() -> Control:
	var center := CenterContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	center.add_child(row)
	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", LobbyTheme.style(LobbyTheme.CREAM, LobbyTheme.CREAM_EDGE, 4, 22, 4, 14))
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


func _rebuild() -> void:
	match mode:
		Mode.HOST: _rebuild_host()
		Mode.GUEST, Mode.CHOOSE: _rebuild_guest()
		Mode.QUICK: _refresh_quick()


func _rebuild_host() -> void:
	if _seat_box == null:
		return
	for child: Node in _seat_box.get_children():
		_seat_box.remove_child(child)
		child.queue_free()
	for seat: int in range(1, LobbyModel.SEAT_COUNT + 1):
		_seat_box.add_child(_make_host_row(seat))
	if _room_label != null:
		_room_label.text = _room_text()
	if _start_button != null:
		# 혼자면 AI와 대결(빈자리 전부 AI), 사람이 둘 이상이면 지금 명단 그대로 시작한다 (비어 있는 자리는 빠져 2인 대전도 된다).
		_start_button.disabled = false
		_start_button.text = _start_label()
	if _status != null:
		if not _relay_ok:
			_status.text = "연결 서버에 닿지 못했습니다. 인터넷 연결을 확인해 주세요 (친구가 방에 들어오지 못할 수 있습니다)."
		else:
			_status.text = "친구의 입장을 기다리는 중입니다. 방 코드를 알려 주세요."


## 시작 버튼 문구: 지금 명단으로 몇 명이 어떻게 겨루는지 보여 준다.
func _start_label() -> String:
	var humans: int = service.model.human_count()
	if humans <= 1:
		return "게임 시작  (AI 3명과 대결)"
	var bots: int = 0
	for seat: int in range(2, LobbyModel.SEAT_COUNT + 1):
		if service.model.state_of(seat) == LobbyModel.SeatState.BOT:
			bots += 1
	return "게임 시작  (사람 %d명%s)" % [humans, " + AI %d명" % bots if bots > 0 else ", AI 없음"]


func _make_host_row(seat: int) -> Control:
	var state: LobbyModel.SeatState = service.model.state_of(seat)
	var card: Dictionary = _make_seat_card(seat, _seat_title(seat, state), seat == service.my_seat())
	var actions: VBoxContainer = card["actions"]
	match state:
		LobbyModel.SeatState.OPEN, LobbyModel.SeatState.INVITED:
			var fill := _button("AI 봇으로 채우기", service.set_bot.bind(seat, true), 14, Color("495a85"))
			fill.name = "FillBot%d" % seat
			actions.add_child(fill)
		LobbyModel.SeatState.HUMAN:
			if seat != LobbyModel.HOST_SEAT:
				actions.add_child(_button("내보내기", service.kick.bind(seat), 13, Color("7a2a2a")))
		LobbyModel.SeatState.BOT:
			actions.add_child(_button("비우기", service.set_bot.bind(seat, false), 13, Color("495a85")))
	return card["root"]


## 파티 편성 칸처럼 생긴 좌석 카드 한 장 (원본의 대기 화면 느낌). 이름표 라벨의 이름은 SeatTitle<좌석>이고 글은 _seat_title()이다.
func _make_seat_card(seat: int, title_text: String, is_me: bool) -> Dictionary:
	var state: LobbyModel.SeatState = service.model.state_of(seat)
	var empty: bool = state == LobbyModel.SeatState.OPEN or state == LobbyModel.SeatState.INVITED
	var avatar_id: StringName = &"default"
	if state == LobbyModel.SeatState.BOT:
		avatar_id = AvatarCatalog.bot_avatar(seat)
	elif service.model.avatar_of(seat) != "":
		avatar_id = AvatarCatalog.sanitize(service.model.avatar_of(seat))
	var card: Dictionary = HubKit.seat_card(seat, SEAT_COLORS[seat - 1], empty, avatar_id)
	var title: Label = card["name"]
	title.name = "SeatTitle%d" % seat
	title.text = title_text
	title.add_theme_font_size_override("font_size", 15)
	var state_label: Label = card["state"]
	state_label.text = "나" if is_me else ("AI" if state == LobbyModel.SeatState.BOT else ("준비 완료" if state == LobbyModel.SeatState.HUMAN else ""))
	(card["crown"] as Control).visible = seat == LobbyModel.HOST_SEAT and state == LobbyModel.SeatState.HUMAN
	return card


func _new_seat_box() -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	return box


func _seat_title(seat: int, state: LobbyModel.SeatState) -> String:
	match state:
		LobbyModel.SeatState.OPEN: return "빈 자리"
		LobbyModel.SeatState.INVITED: return "입장 대기 중..."
		LobbyModel.SeatState.BOT: return "AI 봇"
	if seat == LobbyModel.HOST_SEAT:
		return "방장  %s" % service.model.name_of(seat)
	return "입장 완료!  %s" % service.model.name_of(seat)


func _rebuild_guest() -> void:
	if _guest_box == null:
		return
	for child: Node in _guest_box.get_children():
		_guest_box.remove_child(child)
		child.queue_free()
	_join_input = null
	_join_button = null
	if _guest_connected:
		_guest_box.add_child(_label("입장 완료! 방장이 게임을 시작하기를 기다리는 중...", 18, Color("2b8a3e")))
		var cards := _new_seat_box()
		_guest_box.add_child(cards)
		for seat: int in range(1, LobbyModel.SEAT_COUNT + 1):
			var seat_state: LobbyModel.SeatState = service.model.state_of(seat)
			cards.add_child(_make_seat_card(seat, _seat_title(seat, seat_state), seat == service.my_seat())["root"])
		return
	var prompt := _label("방 코드", 26, LobbyTheme.TEAL)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guest_box.add_child(prompt)
	var hint := _label("친구에게 받은 5자리 코드를 입력하면 바로 합류합니다.", 15, Color("3d6b5c"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guest_box.add_child(hint)
	_join_input = LobbyTheme.input_field("_ _ _ _ _", 40, RoomCode.LENGTH)
	_join_input.name = "RoomCodeInput"
	_join_input.custom_minimum_size = Vector2(0, 70)
	_join_input.text = _guest_room_text
	_join_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_join_input.editable = not _guest_busy
	_join_input.text_changed.connect(_on_room_input_changed)
	_join_input.text_submitted.connect(func(_text: String) -> void: join_with_room_code())
	_guest_box.add_child(_join_input)
	_join_button = LobbyTheme.big_button("입장하기", join_with_room_code, 40)
	_join_button.name = "JoinRoom"
	_join_button.disabled = _guest_busy
	_guest_box.add_child(_join_button)
	var or_label := _label("방이 없다면", 15, Color("5a8070"))
	or_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_guest_box.add_child(or_label)
	var host_button := LobbyTheme.big_button("새 방 만들기", start_hosting, 26, LobbyTheme.BLUE)
	host_button.name = "HostCard"
	host_button.disabled = _guest_busy
	_guest_box.add_child(host_button)


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


func _set_status(text: String, is_error: bool) -> void:
	if _status != null:
		_status.text = text
		_status.add_theme_color_override("font_color", Color("d6336c") if is_error else Color("c47f00"))


func leave_room() -> void:
	service.leave()
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


func _on_join_progress(message: String) -> void:
	_set_status(message, false)


func _on_join_failed(message: String) -> void:
	_guest_busy = false
	if mode == Mode.QUICK:
		_rebuild()
		_set_status(message, true)
		return
	# 방 코드 입장 실패: 입력해 둔 코드는 남긴 채 로비(코드 입력) 화면으로 돌려보내고 안내 팝업을 띄운다.
	var typed: String = _guest_room_text
	_show_choose()
	_guest_room_text = typed
	if _join_input != null:
		_join_input.text = typed
	_set_status(message, true)
	show_join_failed_popup(message)


## 입장 실패 안내 팝업 ([확인]으로 닫는다).
func show_join_failed_popup(message: String) -> void:
	var old: Node = get_node_or_null("JoinFailedPopup")
	if old != null:
		remove_child(old)
		old.queue_free()
	var parts: Dictionary = LobbyTheme.popup(self, 520.0)
	var overlay: Control = parts["overlay"]
	overlay.name = "JoinFailedPopup"
	var box: VBoxContainer = parts["box"]
	var title := LobbyTheme.label("입장 실패", 24, Color("d6336c"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var body := LobbyTheme.label(message, 16)
	body.name = "Message"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.custom_minimum_size = Vector2(460, 0)
	box.add_child(body)
	var ok := LobbyTheme.small_button("확인", overlay.queue_free, &"teal", 16)
	ok.name = "Confirm"
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(ok)


func _on_link_failed(seat: int, message: String) -> void:
	if seat == 0:
		_set_status(message, true)
	_rebuild()


func _on_joined() -> void:
	if mode == Mode.QUICK:
		_refresh_quick()
		return
	mode = Mode.GUEST
	_guest_connected = true
	_guest_busy = false
	_set_status("", false)
	_rebuild()


func _on_left_room(reason: String) -> void:
	_show_choose()
	var message := _label(reason, 14, Color("d6336c"))
	_panel_box.add_child(message)


# ---------------------------------------------------------------------------
# 위젯 도우미
# ---------------------------------------------------------------------------

## 좌석 줄에 붙는 작은 아바타 (사람은 고른 아바타, 컴퓨터는 좌석별 고정 아바타, 빈 자리는 기본).
func _avatar_thumb(seat: int) -> AvatarSlot:
	var thumb := AvatarSlot.new()
	thumb.prefer_icon = true
	thumb.setup(seat, SEAT_COLORS[seat - 1], Vector2(34, 34))
	var seat_state: LobbyModel.SeatState = service.model.state_of(seat)
	var chosen: String = service.model.avatar_of(seat)
	if seat_state == LobbyModel.SeatState.BOT:
		thumb.set_character(AvatarCatalog.bot_avatar(seat))
	elif chosen != "":
		thumb.set_character(AvatarCatalog.sanitize(chosen))
	return thumb


func _pill_style(seat: int) -> StyleBoxFlat:
	return LobbyTheme.style(Color("f7fffb"), SEAT_COLORS[seat - 1].lightened(0.1), 3, 22, 0, 8)


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
	var tone: StringName = &"gray"
	for entry: Array in [["2b8a3e", &"teal"], ["1c6dd0", &"blue"], ["495a85", &"blue"], ["7a2a2a", &"pink"]]:
		if base == Color(entry[0]):
			tone = entry[1]
	if size_px >= 20:
		var fill: Color = {&"teal": LobbyTheme.TEAL, &"blue": LobbyTheme.BLUE, &"pink": LobbyTheme.PINK, &"gray": Color("6b8f82")}[tone]
		return LobbyTheme.big_button(text, callback, size_px, fill)
	return LobbyTheme.small_button(text, callback, tone, size_px)
