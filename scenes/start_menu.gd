# File: res://scenes/start_menu.gd
# Class: class_name StartMenu
# Role: 게임 시작 전 메뉴(밝은 민트/청록 테마). 1단계 타이틀 + 교주의 이름 -> 2단계 큼직한 모드 카드 3장([훈련] AI 대결 / [비밀 결투] 친선 방 / [진지 승부] 빠른 랜덤 매칭) -> 훈련은 AI 인원 선택 후 메인 보드로, 나머지는 로비 씬으로 넘어간다
class_name StartMenu
extends Control

const BOARD_SCENE: String = "res://scenes/main_board.tscn"
const LOBBY_SCENE: String = "res://scenes/lobby.tscn"
const MIN_AI: int = 1
const MAX_AI: int = 3

## 테스트에서 씬 전환을 막기 위한 스위치.
var change_scene_enabled: bool = true
## 1 타이틀(이름) / 2 모드 선택 / 3 훈련 설정
var step: int = 1
var ai_count: int = MAX_AI

var _top: Dictionary = {}
var _bottom: Dictionary = {}
var _name_page: VBoxContainer = null
var _mode_page: VBoxContainer = null
var _train_page: VBoxContainer = null
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
	set_anchors_preset(Control.PRESET_FULL_RECT)
	LobbyTheme.add_background(self, true)
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
	_build_mode_page(stack)
	_build_train_page(stack)
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
	var small := LobbyTheme.label("에르핀의", 30, LobbyTheme.TEAL_DARK)
	small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_page.add_child(small)
	var logo := LobbyTheme.label("억지 레이스", 76, Color("ffd34e"))
	logo.name = "Logo"
	logo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo.add_theme_color_override("font_outline_color", LobbyTheme.TEAL_DARK)
	logo.add_theme_constant_override("outline_size", 14)
	logo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.3))
	logo.add_theme_constant_override("shadow_offset_y", 4)
	_name_page.add_child(logo)
	var subtitle := LobbyTheme.label("보드게임 대격돌", 22, LobbyTheme.TEAL)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_page.add_child(subtitle)
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


func _build_mode_page(parent: VBoxContainer) -> void:
	_mode_page = VBoxContainer.new()
	_mode_page.add_theme_constant_override("separation", 12)
	parent.add_child(_mode_page)
	_ai_button = LobbyTheme.card("TrainingCard", "훈련", "컴퓨터 1~3명", "혼자서 연습 (AI와 대결)", &"blue", open_training)
	_mode_page.add_child(_ai_button)
	_multi_button = LobbyTheme.card("SecretCard", "비밀 결투", "방 코드 5자리", "친구와 친선 대결", &"green", open_lobby)
	_mode_page.add_child(_multi_button)
	_quick_button = LobbyTheme.card("QuickCard", "진지 승부", "15초 안에 자동 매칭", "랜덤 상대와 바로 대결 (빈자리는 AI)", &"pink", open_quick_match)
	_mode_page.add_child(_quick_button)


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
	_train_page.visible = value == 3
	_back_button.visible = value > 1
	(_top["title"] as Label).text = "훈련" if value == 3 else ""
	if value == 1 and _name_edit != null:
		_name_edit.grab_focus()


func _on_back_pressed() -> void:
	_show_step(maxi(step - 1, 1))
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


## [훈련]: AI 인원을 고르는 화면으로 간다.
func open_training() -> void:
	_show_step(3)


func change_ai_count(delta: int) -> void:
	ai_count = clampi(ai_count + delta, MIN_AI, MAX_AI)
	_refresh_train_label()


func _refresh_train_label() -> void:
	_train_label.text = "AI 상대 %d명" % ai_count
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


## [진지 승부]: 로비 씬에서 곧바로 빠른 랜덤 매칭을 시작한다.
func open_quick_match() -> void:
	GameSession.mode = GameSession.MODE_MULTIPLAYER
	GameSession.lobby_intent = &"quick"
	if change_scene_enabled:
		get_tree().change_scene_to_file(LOBBY_SCENE)
