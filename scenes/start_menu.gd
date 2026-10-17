# File: res://scenes/start_menu.gd
# Class: class_name StartMenu
# Role: 게임 시작 전 메뉴(밝은 민트/청록 테마). 1단계 타이틀 + 교주의 이름 -> 2단계 큼직한 모드 카드 3장([훈련] AI 대결 / [비밀 결투] 친선 방 / [랜덤 결투] 빠른 랜덤 매칭) -> 훈련은 AI 인원 선택 후 메인 보드로, 나머지는 로비 씬으로 넘어간다
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
var _hub_start_label: Label = null
var _tip_index: int = 0
var _mascots: Array[Control] = []
var _train_page: VBoxContainer = null
var _avatar_page: VBoxContainer = null
var _avatar_button: Button = null
var _avatar_preview: AvatarSlot = null
var _avatar_name: Label = null
var _avatar_tiles: Dictionary = {}
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
var _mobile: MobileSupport = null


func _ready() -> void:
	Sfx.apply_settings()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	LobbyTheme.add_background(self, true)
	add_child(HubKit.FestivalDecor.new())
	_top = LobbyTheme.add_top_bar(self, "", _on_back_pressed, "규칙", _show_rules)
	_back_button = _top["back"]
	_bottom = LobbyTheme.add_bottom_bar(self, "", "설정", _show_settings)
	_hello_label = _bottom["name"]
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
	var saved: String = GameSession.load_saved()
	if saved != "":
		_name_edit.text = saved
	# 게임이나 로비에서 돌아온 경우(이미 이름을 정했다)에는 모드 선택부터 보여 준다.
	if GameSession.nickname != "":
		_name_edit.text = GameSession.nickname
		_hello_label.text = "%s 교주님" % GameSession.nickname
		_show_step(2)
	else:
		_show_step(1)
		_name_edit.grab_focus()
	_mobile = MobileSupport.new()
	_mobile.button_position = Vector2(1070, 2)
	add_child(_mobile)


func _build_name_page(parent: VBoxContainer) -> void:
	_name_page = VBoxContainer.new()
	_name_page.custom_minimum_size = Vector2(520, 0)
	_name_page.add_theme_constant_override("separation", 10)
	parent.add_child(_name_page)
	_name_page.add_child(HubKit.logo("에르핀의", "억지 레이스", "보드게임 대격돌"))
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


## 모드 선택 화면 = 마을 허브(원본의 로비처럼): 왼쪽 위 프로필, 오른쪽 위 팁 띠와 둥근 버튼, 가운데 로고와 캐릭터들, 아래 둥근 초록 메뉴 줄과 큰 [바로 시작] 버튼.
func _build_mode_page() -> void:
	_mode_page = Control.new()
	_mode_page.name = "Hub"
	_mode_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_mode_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mode_page)
	_build_hub_mascots()
	# 위쪽 줄: 프로필 ........ 팁 띠 + 둥근 버튼
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_right = -18
	top.offset_top = 14
	top.add_theme_constant_override("separation", 12)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_page.add_child(top)
	_hub_profile = HubKit.profile_capsule(GameSession.display_nickname(), "교주님", AvatarCatalog.sanitize(GameSession.avatar_id), AvatarCatalog.color_of(AvatarCatalog.sanitize(GameSession.avatar_id)), open_avatar)
	top.add_child(_hub_profile["root"])
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
	var rename := LobbyTheme.small_button("이름 바꾸기", func() -> void: _on_back_pressed(), &"teal", 14)
	rename.name = "RenameButton"
	rename.position = Vector2(54, 114)
	_mode_page.add_child(rename)
	# 가운데 로고
	var logo := HubKit.logo("에르핀의", "억지 레이스", "보드게임 대격돌")
	logo.set_anchors_preset(Control.PRESET_CENTER_TOP)
	logo.anchor_left = 0.5
	logo.anchor_right = 0.5
	logo.offset_left = -300
	logo.offset_right = 300
	logo.offset_top = 112
	_mode_page.add_child(logo)
	# 아래쪽 메뉴 줄
	var nav := HBoxContainer.new()
	nav.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	nav.anchor_top = 1.0
	nav.anchor_bottom = 1.0
	nav.offset_left = 26
	nav.offset_top = -HubKit.NAV_SIZE.y - 16.0
	nav.offset_bottom = -16
	nav.add_theme_constant_override("separation", 16)
	nav.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mode_page.add_child(nav)
	_ai_button = HubKit.nav_button("TrainingCard", &"sword", "훈련", open_training, &"green")
	_ai_button.tooltip_text = "컴퓨터 1~3명과 혼자서 연습"
	nav.add_child(_ai_button)
	_quick_button = HubKit.nav_button("QuickCard", &"dice", "랜덤 결투", open_quick_match, &"pink")
	_quick_button.tooltip_text = "15초 안에 자동 매칭 (빈자리는 AI)"
	nav.add_child(_quick_button)
	_multi_button = HubKit.nav_button("SecretCard", &"key", "비밀 결투", open_lobby, &"blue")
	_multi_button.tooltip_text = "방 코드 5자리로 친구와 친선 대결"
	nav.add_child(_multi_button)
	_avatar_button = HubKit.nav_button("AvatarButton", &"face", "아바타", open_avatar, &"gold")
	nav.add_child(_avatar_button)
	# 오른쪽 아래의 큰 [바로 시작] 버튼 (원본의 [모험] 자리)
	var start := Button.new()
	start.name = "QuickStartAi"
	start.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	start.anchor_left = 1.0
	start.anchor_top = 1.0
	start.offset_left = -290
	start.offset_right = -22
	start.offset_top = -150
	start.offset_bottom = -24
	start.focus_mode = Control.FOCUS_NONE
	start.pivot_offset = Vector2(134, 63)
	var start_style := LobbyTheme.style(Color("ffd34e"), Color.WHITE, 5, 46, 8, 0, Color("c98a14"))
	start_style.border_width_bottom = 9
	start.add_theme_stylebox_override("normal", start_style)
	var start_hover: StyleBoxFlat = start_style.duplicate()
	start_hover.bg_color = Color("ffe07a")
	start.add_theme_stylebox_override("hover", start_hover)
	var start_pressed: StyleBoxFlat = start_style.duplicate()
	start_pressed.bg_color = Color("f0bd2e")
	start.add_theme_stylebox_override("pressed", start_pressed)
	start.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var start_column := VBoxContainer.new()
	start_column.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_column.alignment = BoxContainer.ALIGNMENT_CENTER
	start_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	start_column.add_theme_constant_override("separation", -2)
	start.add_child(start_column)
	var start_title := HubKit.outlined("바로 시작", 40, Color.WHITE, Color("8a5a0a"), 9)
	start_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_column.add_child(start_title)
	_hub_start_label = HubKit.outlined("", 17, Color("fff3bf"), Color("8a5a0a"), 5)
	_hub_start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	start_column.add_child(_hub_start_label)
	start.pressed.connect(start_ai_game)
	start.mouse_entered.connect(func() -> void: HubKit._bounce(start, 1.05))
	start.mouse_exited.connect(func() -> void: HubKit._bounce(start, 1.0))
	_mode_page.add_child(start)
	_refresh_hub()


## 가운데 아래에 서 있는 캐릭터들: 내 아바타는 왼쪽에 크게, 컴퓨터들은 가운데·오른쪽에서 통통 숨 쉰다 (그림이 들어오면 그대로 대체된다).
func _build_hub_mascots() -> void:
	_mascots.clear()
	var me: StringName = AvatarCatalog.sanitize(GameSession.avatar_id)
	var specs: Array[Dictionary] = [
		{"id": me, "size": 250.0, "pos": Vector2(46, 300), "tag": "나"},
		{"id": AvatarCatalog.bot_avatar(2), "size": 190.0, "pos": Vector2(560, 380), "tag": "컴퓨터"},
		{"id": AvatarCatalog.bot_avatar(3, [me]), "size": 210.0, "pos": Vector2(790, 350), "tag": "컴퓨터"},
	]
	for index: int in specs.size():
		var spec: Dictionary = specs[index]
		var diameter: float = spec["size"]
		var holder := Control.new()
		holder.position = spec["pos"]
		holder.size = Vector2(diameter, diameter + 34.0)
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.modulate = Color(1, 1, 1, 0.97)
		var id: StringName = spec["id"]
		var avatar: Control = HubKit.avatar_disc(id, AvatarCatalog.color_of(id), diameter)
		holder.add_child(avatar)
		var tag := HubKit.outlined(spec["tag"], 20, Color.WHITE, Color("2c7a1f"), 6)
		tag.position = Vector2(0, diameter + 4.0)
		tag.size = Vector2(diameter, 28)
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		holder.add_child(tag)
		_mode_page.add_child(holder)
		_mascots.append(holder)
		var bob: Tween = holder.create_tween().set_loops()
		var rise: float = 7.0 + index * 2.0
		bob.tween_property(holder, "position:y", holder.position.y - rise, 1.1 + 0.25 * index).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(holder, "position:y", holder.position.y, 1.1 + 0.25 * index).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## 허브의 이름·직함·아바타·바로 시작 문구를 현재 값으로 맞춘다.
func _refresh_hub() -> void:
	if _hub_profile.is_empty():
		return
	(_hub_profile["name"] as Label).text = GameSession.display_nickname()
	var id: StringName = AvatarCatalog.sanitize(GameSession.avatar_id)
	var old_avatar: Control = _hub_profile["avatar"]
	var fresh: Control = HubKit.avatar_disc(id, AvatarCatalog.color_of(id), 76.0, Color("2fa63a"), 4)
	fresh.position = old_avatar.position
	old_avatar.get_parent().add_child(fresh)
	old_avatar.queue_free()
	_hub_profile["avatar"] = fresh
	_hub_start_label.text = "AI %d명과 대결" % ai_count


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
	(_top["title"] as Label).text = {3: "훈련", 4: "아바타"}.get(value, "")
	if value == 1 and _name_edit != null:
		_name_edit.grab_focus()


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
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(280, 0)
	body.add_child(left)
	_avatar_preview = AvatarSlot.new()
	_avatar_preview.name = "AvatarPreview"
	_avatar_preview.catalog_tint = true
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
		tile.add_theme_stylebox_override("normal", LobbyTheme.style(Color.WHITE if not selected else LobbyTheme.CREAM, LobbyTheme.CREAM_EDGE if selected else LobbyTheme.MINT_EDGE, 5 if selected else 2, 18, 0, 0))
		tile.add_theme_stylebox_override("hover", LobbyTheme.style(Color("f4fffa"), LobbyTheme.TEAL, 3, 18, 0, 0))
		tile.add_theme_stylebox_override("pressed", LobbyTheme.style(LobbyTheme.CREAM, LobbyTheme.CREAM_EDGE, 5, 18, 0, 0))
		tile.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


## 아바타를 고른다 (저장되어 훈련·방·게임에서 내 아바타로 쓰인다).
func select_avatar(id: StringName) -> void:
	GameSession.avatar_id = AvatarCatalog.sanitize(id)
	GameSession.save_settings()
	_refresh_avatar_page()
	_avatar_preview.react(AvatarSlot.Emotion.HAPPY, 1.0)


## [아바타 설정]: 아바타 선택 화면으로 간다.
func open_avatar() -> void:
	_refresh_avatar_page()
	_show_step(4)


## [훈련]: AI 인원을 고르는 화면으로 간다.
func open_training() -> void:
	_show_step(3)


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


## [비밀 결투]: 로비 씬에서 방 코드 입력 / 방 만들기.
func open_lobby() -> void:
	GameSession.mode = GameSession.MODE_MULTIPLAYER
	GameSession.lobby_intent = &"secret"
	if change_scene_enabled:
		get_tree().change_scene_to_file(LOBBY_SCENE)


## [랜덤 결투]: 로비 씬에서 곧바로 빠른 랜덤 매칭을 시작한다.
func open_quick_match() -> void:
	GameSession.mode = GameSession.MODE_MULTIPLAYER
	GameSession.lobby_intent = &"quick"
	if change_scene_enabled:
		get_tree().change_scene_to_file(LOBBY_SCENE)
