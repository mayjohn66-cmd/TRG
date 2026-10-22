# File: res://scenes/start_menu.gd
# Class: class_name StartMenu
# Role: 게임 시작 전 메뉴(밝은 민트/청록 테마). 1단계 타이틀 + 교주의 이름 -> 2단계 큼직한 모드 카드 3장([놀이터] AI 대결 / [친선 줘팸터] 방 코드 친선전 / [익명 줘팸터] 빠른 랜덤 매칭) -> 훈련은 AI 인원 선택 후 메인 보드로, 나머지는 로비 씬으로 넘어간다
class_name StartMenu
extends Control

const BOARD_SCENE: String = "res://scenes/main_board.tscn"
const LOBBY_SCENE: String = "res://scenes/lobby.tscn"
const MIN_AI: int = 1
const MAX_AI: int = 3

## 테스트에서 씬 전환을 막기 위한 스위치.
var change_scene_enabled: bool = true
## 1 타이틀(이름) / 2 모드 선택 / 3 훈련 설정 / 4 아바타 설정
var step: int = 1
var ai_count: int = MAX_AI

var _top: Dictionary = {}
var _bottom: Dictionary = {}
var _name_page: VBoxContainer = null
var _mode_page: Control = null
var _hub_profile: Dictionary = {}
var _hub_tip: Dictionary = {}
var _tip_index: int = 0
var _train_page: VBoxContainer = null
var _avatar_page: VBoxContainer = null
var _avatar_button: Button = null
var _avatar_preview: AvatarSlot = null
var _avatar_name: Label = null
var _avatar_tiles: Dictionary = {}
const HUB_AVATAR_HEIGHT: float = 520.0
var _name_edit: LineEdit = null
var _error_label: Label = null
var _confirm_button: Button = null
var _hello_label: Label = null
var _ai_button: Button = null
var _multi_button: Button = null
var _quick_button: Button = null
var _back_button: Button = null
var _train_label: Label = null
var _train_start: Button = null
## 놀이터 난이도 토글 (순한맛 · 보통맛 · 마라맛).
var _difficulty_buttons: Dictionary = {}
var _difficulty_note: Label = null
const DIFFICULTY_TONES: Dictionary = {&"mild": &"teal", &"normal": &"blue", &"spicy": &"pink"}
const DIFFICULTY_NOTES: Dictionary = {
	&"mild": "입문·힐링: 컴퓨터가 내 말을 자주 봐주고, 나를 노리는 공격 카드도 덜 써요",
	&"normal": "기본: 컴퓨터가 1등을 먼저 견제하고, 방금 잡힌 사람은 잠깐 봐줘요",
	&"spicy": "하드코어: 봐주기 없이 최적의 킬각·카드·특수 승리를 노려요",
}
var _mobile: MobileSupport = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	LobbyTheme.add_background(self, true)
	_top = LobbyTheme.add_top_bar(self, "", _on_back_pressed, "규칙", _show_rules)
	_back_button = _top["back"]
	_bottom = LobbyTheme.add_bottom_bar(self, "", "설정", _show_settings)
	_hello_label = _bottom["name"]
	var fan_notice := Label.new()
	fan_notice.name = "FanNotice"
	fan_notice.text = "v%s · 비공식 팬 제작 게임 · 원작 제작사와 무관한 비영리 무료 배포물입니다" % GameSession.version()
	fan_notice.add_theme_font_size_override("font_size", 13)
	fan_notice.add_theme_color_override("font_color", Color(0.17, 0.35, 0.12, 0.85))
	fan_notice.add_theme_color_override("font_outline_color", Color("fff6df"))
	fan_notice.add_theme_constant_override("outline_size", 3)
	fan_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fan_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fan_notice.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	fan_notice.offset_top = -LobbyTheme.BAR_HEIGHT - 26.0
	fan_notice.offset_bottom = -LobbyTheme.BAR_HEIGHT - 4.0
	add_child(fan_notice)
	var area := CenterContainer.new()
	area.set_anchors_preset(Control.PRESET_FULL_RECT)
	area.offset_top = LobbyTheme.BAR_HEIGHT
	area.offset_bottom = -LobbyTheme.BAR_HEIGHT
	add_child(area)
	var stack := VBoxContainer.new()
	area.add_child(stack)
	_build_name_page(stack)
	_build_mode_page()
	_build_train_page(stack)
	_build_avatar_page(stack)
	GameSession.load_settings()
	Sfx.unlock()  # 저장된 음량을 적용하고 첫 버튼 클릭 전에 플레이어 풀을 준비한다.
	Sfx.bgm_play.call_deferred(Sfx.LOBBY_TRACK)
	var saved: String = GameSession.load_saved()
	if saved != "":
		_name_edit.text = saved
	# 게임이나 로비에서 돌아온 경우(이미 이름을 정했다)에는 모드 선택부터 보여 준다.
	if GameSession.nickname != "":
		_name_edit.text = GameSession.nickname
		_hello_label.text = "%s 교주님" % GameSession.nickname
		_show_step(2)
	else:
		_show_step(1)  # 모바일에서 키보드가 불쑥 뜨지 않도록 입력칸은 눌러야 입력된다
	_mobile = MobileSupport.new()
	add_child(_mobile)


func _build_name_page(parent: VBoxContainer) -> void:
	_name_page = VBoxContainer.new()
	_name_page.custom_minimum_size = Vector2(520, 0)
	_name_page.add_theme_constant_override("separation", 10)
	parent.add_child(_name_page)
	_name_page.add_child(HubKit.logo("초증강", "엘리아스 마블", "HYPER AUGMENT ELIAS MARBLE"))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 26)
	_name_page.add_child(gap)
	_name_page.add_child(LobbyTheme.label("교주의 이름", 24, LobbyTheme.TEAL))
	_name_edit = LobbyTheme.input_field("닉네임 (최대 %d자)" % GameSession.MAX_NICKNAME_LENGTH, 26, GameSession.MAX_NICKNAME_LENGTH)
	_name_edit.custom_minimum_size = Vector2(0, 52)
	_name_edit.text_submitted.connect(func(_text: String) -> void: confirm_nickname())
	_name_edit.text_changed.connect(func(_text: String) -> void: _error_label.text = "")
	_name_page.add_child(_name_edit)
	_error_label = LobbyTheme.label("", 15, Color("d6336c"))
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_page.add_child(_error_label)
	_confirm_button = LobbyTheme.big_button("입장하기", confirm_nickname, 44)
	_confirm_button.name = "ConfirmButton"
	_name_page.add_child(_confirm_button)


## 모드 선택 화면 = 마을 허브: 왼쪽에 내 아바타 + 닉네임 + [아바타 설정], 오른쪽에서 어디로 대결할지 고른다 (놀이터 / 친선 줘팸터 / 익명 줘팸터).
func _build_mode_page() -> void:
	_mode_page = Control.new()
	_mode_page.name = "Hub"
	_mode_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mode_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mode_page)
	# 위쪽 줄: 팁 띠 + 둥근 규칙/설정 버튼
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_right = -18
	top.offset_top = 14
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_page.add_child(top)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(fill)
	_hub_tip = HubKit.tip_bar(GameTips.TIPS[0], _next_tip)
	(_hub_tip["root"] as Control).size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(_hub_tip["root"])
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	buttons.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(buttons)
	buttons.add_child(HubKit.round_button("HubRules", &"book", _show_rules, 56.0))
	buttons.add_child(HubKit.round_button("HubSettings", &"gear", _show_settings, 56.0))
	# 왼쪽: 큼직한 전신 아바타 + 닉네임 + 아바타 설정 (타이틀은 오른쪽 아래)
	var left := VBoxContainer.new()
	left.name = "ProfileCapsule"
	left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left.offset_left = 40
	left.offset_top = 74
	left.offset_right = 600
	left.add_theme_constant_override("separation", 8)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_page.add_child(left)
	var avatar_holder := CenterContainer.new()
	avatar_holder.name = "AvatarHolder"
	avatar_holder.custom_minimum_size = Vector2(0, HUB_AVATAR_HEIGHT)
	left.add_child(avatar_holder)
	var id: StringName = AvatarCatalog.sanitize(GameSession.avatar_id)
	var avatar: Control = HubKit.avatar_full(id, AvatarCatalog.color_of(id), HUB_AVATAR_HEIGHT)
	avatar_holder.add_child(avatar)
	var plate_row := CenterContainer.new()
	left.add_child(plate_row)
	var plate := PanelContainer.new()
	plate.custom_minimum_size = Vector2(300, 0)
	plate.add_theme_stylebox_override("panel", HubArt.skin(&"mode_green", 42, 4.0))
	plate_row.add_child(plate)
	var name_label := HubKit.outlined(GameSession.display_nickname(), 28, Color.WHITE, Color("17591f"), 6)
	name_label.name = "ProfileName"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	plate.add_child(name_label)
	var buttons_row := HBoxContainer.new()
	buttons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_row.add_theme_constant_override("separation", 10)
	left.add_child(buttons_row)
	_avatar_button = LobbyTheme.cream_button("아바타 설정", open_avatar, 22)
	_avatar_button.name = "AvatarButton"
	_avatar_button.custom_minimum_size = Vector2(200, 50)
	buttons_row.add_child(_avatar_button)
	var rename := LobbyTheme.small_button("이름 바꾸기", func() -> void: _on_back_pressed(), &"teal", 14)
	rename.name = "RenameButton"
	rename.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons_row.add_child(rename)
	_hub_profile = {"name": name_label, "avatar": avatar, "holder": avatar_holder}
	# 웹: 내 아바타의 대기 애니메이션 묶음을 먼저 받고, 도착하면 허브의 전신 아바타를 움직이는 그림으로 바꾼다
	AvatarPacks.request(id, true)
	AvatarPacks.when_ready(self, func(ready_id: StringName) -> void:
		if ready_id == AvatarCatalog.sanitize(GameSession.avatar_id):
			_refresh_hub())
	# 오른쪽: 대결 장소 고르기
	var right := VBoxContainer.new()
	right.name = "ModeColumn"
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.anchor_left = 1.0
	right.anchor_right = 1.0
	right.offset_left = -690
	right.offset_right = -28
	right.offset_top = 96
	right.add_theme_constant_override("separation", 16)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_page.add_child(right)
	var heading := HubKit.outlined("어디로 대결하러 갈까요?", 28, Color.WHITE, Color("2c7a1f"), 8)
	right.add_child(heading)
	_ai_button = HubKit.mode_card("TrainingCard", &"sword", "놀이터", "컴퓨터 1~3명 · 혼자서 연습", open_training, &"green")
	right.add_child(_ai_button)
	_multi_button = HubKit.mode_card("SecretCard", &"key", "친선 줘팸터", "방 코드 5자리 · 친구와 친선 대결", open_lobby, &"blue")
	right.add_child(_multi_button)
	_quick_button = HubKit.mode_card("QuickCard", &"dice", "익명 줘팸터", "15초 자동 매칭 · 모르는 상대와 바로 대결", open_quick_match, &"pink")
	right.add_child(_quick_button)
	# 타이틀은 하단 중앙에 작게 두고, 영문 부제 자리에는 비영리 무료 배포물이라고 적는다 (안내 문구 바로 위)
	var logo := HubKit.logo("초증강", "엘리아스 마블", "비영리 무료 배포물", 230.0)
	logo.name = "HubLogoCorner"
	(logo.get_node("LogoSubtitle") as Label).add_theme_font_size_override("font_size", 15)
	logo.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	logo.anchor_left = 0.5
	logo.anchor_right = 0.5
	logo.offset_left = -115.0
	logo.offset_right = 115.0
	logo.offset_top = -LobbyTheme.BAR_HEIGHT - 30.0 - 134.0
	logo.offset_bottom = -LobbyTheme.BAR_HEIGHT - 30.0
	_mode_page.add_child(logo)
	_refresh_hub()


## 허브의 이름·아바타를 현재 값으로 맞춘다.
func _refresh_hub() -> void:
	if _hub_profile.is_empty():
		return
	(_hub_profile["name"] as Label).text = GameSession.display_nickname()
	var id: StringName = AvatarCatalog.sanitize(GameSession.avatar_id)
	var holder: Control = _hub_profile["holder"]
	(_hub_profile["avatar"] as Control).queue_free()
	var fresh: Control = HubKit.avatar_full(id, AvatarCatalog.color_of(id), HUB_AVATAR_HEIGHT)
	holder.add_child(fresh)
	_hub_profile["avatar"] = fresh


## 팁 띠의 [>>]: 다음 게임 팁으로 넘긴다.
func _next_tip() -> void:
	_tip_index = (_tip_index + 1) % GameTips.TIPS.size()
	(_hub_tip["label"] as Label).text = GameTips.TIPS[_tip_index]


func _build_train_page(parent: VBoxContainer) -> void:
	_train_page = VBoxContainer.new()
	_train_page.custom_minimum_size = Vector2(560, 0)
	_train_page.add_theme_constant_override("separation", 26)
	parent.add_child(_train_page)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", LobbyTheme.style(LobbyTheme.BLUE_PALE, LobbyTheme.BLUE, 5, 34, 6, 16))
	_train_page.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	var minus := LobbyTheme.small_button("-", change_ai_count.bind(-1), &"blue", 34)
	minus.name = "AiMinus"
	minus.custom_minimum_size = Vector2(64, 64)
	row.add_child(minus)
	_train_label = LobbyTheme.label("", 52, LobbyTheme.BLUE)
	_train_label.name = "AiCount"
	_train_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_train_label.custom_minimum_size = Vector2(330, 0)
	row.add_child(_train_label)
	var plus := LobbyTheme.small_button("+", change_ai_count.bind(1), &"blue", 34)
	plus.name = "AiPlus"
	plus.custom_minimum_size = Vector2(64, 64)
	row.add_child(plus)
	var note := LobbyTheme.label("컴퓨터와 겨룹니다. 제한 시간 없이 천천히 연습하세요.", 18, LobbyTheme.BLUE)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_train_page.add_child(note)
	# 난이도 3단 토글 (기본 보통맛, 고른 값은 다음 접속에도 남는다)
	var levels := HBoxContainer.new()
	levels.name = "DifficultyRow"
	levels.add_theme_constant_override("separation", 10)
	levels.alignment = BoxContainer.ALIGNMENT_CENTER
	_train_page.add_child(levels)
	for level: StringName in BotTemper.ALL:
		var button := LobbyTheme.small_button(BotTemper.label(level), set_difficulty.bind(level), DIFFICULTY_TONES[level], 24)
		button.name = "Difficulty_%s" % level
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(170, 56)
		levels.add_child(button)
		_difficulty_buttons[level] = button
	_difficulty_note = LobbyTheme.label("", 17, LobbyTheme.BLUE)
	_difficulty_note.name = "DifficultyNote"
	_difficulty_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_train_page.add_child(_difficulty_note)
	_refresh_difficulty()
	_train_start = LobbyTheme.cream_button("게임 시작", start_ai_game, 40)
	_train_start.name = "StartTraining"
	_train_page.add_child(_train_start)
	_refresh_train_label()


func _show_step(value: int) -> void:
	step = value
	_name_page.visible = value == 1
	_mode_page.visible = value == 2
	# 허브(2단계)는 자기 화면에 규칙·설정 버튼이 있어 청록 띠를 숨긴다 (뒤로가기·규칙·설정 버튼 자체는 그대로 살아 있다).
	(_top["bar"] as Control).visible = value != 2
	(_bottom["bar"] as Control).visible = value != 2
	if value == 2:
		_refresh_hub()
	_train_page.visible = value == 3
	_avatar_page.visible = value == 4
	_back_button.visible = value > 1
	(_top["title"] as Label).text = {3: "놀이터", 4: "아바타"}.get(value, "")


func _on_back_pressed() -> void:
	_show_step(2 if step == 4 else maxi(step - 1, 1))
	if step == 1:
		_name_edit.text = GameSession.nickname if GameSession.nickname != "" else _name_edit.text


func _show_rules() -> void:
	LobbyTheme.show_rules(self)


func _show_settings() -> void:
	LobbyTheme.show_settings(self)


## 닉네임을 검사해 저장하고 모드 선택 화면으로 넘어간다. 통과했으면 true.
func confirm_nickname() -> bool:
	var problem: String = GameSession.validate_nickname(_name_edit.text)
	if problem != "":
		_error_label.text = problem
		return false
	GameSession.set_nickname(_name_edit.text)
	_hello_label.text = "%s 교주님" % GameSession.nickname
	_show_step(2)
	MatchTelemetry.report_lobby_entry(self)  # 통계: 게임을 켜서 실제로 들어온 사람 (이번 접속에 한 번)
	return true


## 아바타 설정 화면: 큰 미리보기 + 고를 수 있는 아바타 격자.
func _build_avatar_page(parent: VBoxContainer) -> void:
	_avatar_page = VBoxContainer.new()
	_avatar_page.custom_minimum_size = Vector2(900, 0)
	_avatar_page.add_theme_constant_override("separation", 20)
	parent.add_child(_avatar_page)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 32)
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	_avatar_page.add_child(body)
	# 왼쪽: 미리보기 + 감정 시험 버튼
	# 배경 그림 위에서도 이름·안내 문구가 읽히도록 오른쪽 격자와 같은 민트 카드 위에 올린다
	var left_panel := PanelContainer.new()
	left_panel.name = "AvatarPreviewPanel"
	left_panel.add_theme_stylebox_override("panel", LobbyTheme.style(Color(LobbyTheme.MINT, 0.9), LobbyTheme.MINT_EDGE, 3, 26, 8, 16))
	left_panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	body.add_child(left_panel)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(280, 0)
	left_panel.add_child(left)
	_avatar_preview = AvatarSlot.new()
	_avatar_preview.name = "AvatarPreview"
	_avatar_preview.catalog_tint = true
	_avatar_preview.hq_idle = true
	_avatar_preview.setup(1, Color("e8590c"), Vector2(240, 240))
	_avatar_preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	left.add_child(_avatar_preview)
	_avatar_name = LobbyTheme.label("", 26, LobbyTheme.TEAL_DARK)
	_avatar_name.name = "AvatarName"
	_avatar_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left.add_child(_avatar_name)
	var emotions := HBoxContainer.new()
	emotions.add_theme_constant_override("separation", 6)
	emotions.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_child(emotions)
	for entry: Array in [["웃음", AvatarSlot.Emotion.HAPPY], ["분노", AvatarSlot.Emotion.ANGRY], ["놀람", AvatarSlot.Emotion.SURPRISED], ["환호", AvatarSlot.Emotion.CHEER]]:
		var emotion_button := LobbyTheme.small_button(entry[0], func() -> void: _avatar_preview.react(entry[1], 1.2), &"blue", 14)
		emotions.add_child(emotion_button)
	var hint := LobbyTheme.label("게임 중 말이 잡히거나 완주하면 이렇게 반응합니다.", 13, LobbyTheme.INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(hint)
	# 오른쪽: 고를 수 있는 아바타 격자
	var grid_panel := PanelContainer.new()
	grid_panel.add_theme_stylebox_override("panel", LobbyTheme.style(Color(LobbyTheme.MINT, 0.9), LobbyTheme.MINT_EDGE, 3, 26, 8, 16))
	body.add_child(grid_panel)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid_panel.add_child(grid)
	for id: StringName in AvatarCatalog.ids():
		var tile := Button.new()
		tile.name = "Tile_%s" % String(id)
		tile.custom_minimum_size = Vector2(104, 104)
		tile.focus_mode = Control.FOCUS_NONE
		tile.pressed.connect(select_avatar.bind(id))
		var thumb := AvatarSlot.new()
		thumb.catalog_tint = true
		thumb.prefer_icon = true
		thumb.icon_border = false
		thumb.outline = false  # 칸(버튼) 테두리 하나만: 그림에 테두리를 또 두르면 두 겹 틈처럼 보인다
		thumb.placeholder_text = AvatarCatalog.name_of(id).trim_prefix("아바타 ")
		thumb.setup(1, AvatarCatalog.color_of(id), Vector2(88, 88))
		thumb.set_character(id)
		thumb.position = Vector2(8, 8)
		tile.add_child(thumb)
		grid.add_child(tile)
		_avatar_tiles[id] = tile
	var done := LobbyTheme.cream_button("선택 완료", func() -> void: _show_step(2), 34)
	done.name = "AvatarDone"
	done.custom_minimum_size = Vector2(0, 66)
	_avatar_page.add_child(done)
	_refresh_avatar_page()


func _refresh_avatar_page() -> void:
	var current: StringName = AvatarCatalog.sanitize(GameSession.avatar_id)
	_avatar_preview.placeholder_text = AvatarCatalog.name_of(current).trim_prefix("아바타 ")
	_avatar_preview.set_character(current)
	_avatar_name.text = AvatarCatalog.name_of(current)
	for id: StringName in _avatar_tiles.keys():
		var tile: Button = _avatar_tiles[id]
		var selected: bool = id == current
		# 고른 칸은 금빛 테두리와 은은한 빛, 나머지는 흰 바탕에 옅은 테두리 (아이콘 자체에는 테두리가 없다).
		var gold: Color = Color("f2b01e")
		tile.add_theme_stylebox_override("normal", LobbyTheme.style(Color("fff6d6") if selected else Color.WHITE, gold if selected else LobbyTheme.MINT_EDGE, 5 if selected else 2, 22, 12 if selected else 0, 0, Color(gold, 0.55)))
		tile.add_theme_stylebox_override("hover", LobbyTheme.style(Color("fff6d6") if selected else Color("f4fffa"), gold if selected else LobbyTheme.TEAL, 5 if selected else 3, 22, 12 if selected else 4, 0, Color(gold, 0.55) if selected else Color(0, 0, 0, 0.15)))
		tile.add_theme_stylebox_override("pressed", LobbyTheme.style(Color("fff6d6"), gold, 5, 22, 6, 0, Color(gold, 0.55)))
		tile.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## 아바타를 고른다 (저장되어 훈련·방·게임에서 내 아바타로 쓰인다).
func select_avatar(id: StringName) -> void:
	GameSession.avatar_id = AvatarCatalog.sanitize(id)
	AvatarPacks.request(GameSession.avatar_id, true)
	GameSession.save_settings()
	_refresh_avatar_page()
	_avatar_preview.react(AvatarSlot.Emotion.HAPPY, 1.0)
	Sfx.play_voice(AvatarCatalog.select_voice_path(GameSession.avatar_id))  # 고른 캐릭터의 선택 대사


## [아바타 설정]: 아바타 선택 화면으로 간다.
func open_avatar() -> void:
	_refresh_avatar_page()
	_show_step(4)


## [놀이터]: AI 인원을 고르는 화면으로 간다.
func open_training() -> void:
	_show_step(3)


## 놀이터 난이도를 고른다 (BotTemper.MILD / NORMAL / SPICY).
func set_difficulty(level: StringName) -> void:
	GameSession.set_bot_difficulty(level)
	_refresh_difficulty()


func _refresh_difficulty() -> void:
	var current: StringName = GameSession.bot_difficulty()
	for level: Variant in _difficulty_buttons:
		var button: Button = _difficulty_buttons[level]
		button.set_pressed_no_signal(level == current)
		button.modulate = Color.WHITE if level == current else Color(1, 1, 1, 0.55)
	if _difficulty_note != null:
		_difficulty_note.text = str(DIFFICULTY_NOTES.get(current, ""))


func change_ai_count(delta: int) -> void:
	ai_count = clampi(ai_count + delta, MIN_AI, MAX_AI)
	_refresh_train_label()


func _refresh_train_label() -> void:
	_train_label.text = "AI 상대 %d명" % ai_count
	_refresh_hub()
	(_train_page.find_child("AiMinus", true, false) as Button).disabled = ai_count <= MIN_AI
	(_train_page.find_child("AiPlus", true, false) as Button).disabled = ai_count >= MAX_AI


## [게임 시작](훈련): 나(P1) vs 컴퓨터 ai_count명으로 메인 보드를 연다.
func start_ai_game() -> void:
	GameSession.clear_net()
	GameSession.mode = GameSession.MODE_AI
	GameSession.ai_opponents = ai_count
	if change_scene_enabled:
		get_tree().change_scene_to_file(BOARD_SCENE)


## [친선 줘팸터]: 로비 씬에서 방 코드 입력 / 방 만들기.
func open_lobby() -> void:
	GameSession.mode = GameSession.MODE_MULTIPLAYER
	GameSession.lobby_intent = &"secret"
	if change_scene_enabled:
		get_tree().change_scene_to_file(LOBBY_SCENE)


## [익명 줘팸터]: 로비 씬에서 곧바로 빠른 랜덤 매칭을 시작한다.
func open_quick_match() -> void:
	GameSession.mode = GameSession.MODE_MULTIPLAYER
	GameSession.lobby_intent = &"quick"
	if change_scene_enabled:
		get_tree().change_scene_to_file(LOBBY_SCENE)
