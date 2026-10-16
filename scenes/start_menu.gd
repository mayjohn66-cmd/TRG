# File: res://scenes/start_menu.gd
# Class: class_name StartMenu
# Role: 게임 시작 전 메뉴. 1단계 닉네임 설정 -> 2단계 [컴퓨터 대전] / [멀티플레이] 선택. 컴퓨터 대전은 메인 보드 씬으로, 멀티플레이는 로비 씬으로 넘어간다
class_name StartMenu
extends Control

const BOARD_SCENE: String = "res://scenes/main_board.tscn"
const LOBBY_SCENE: String = "res://scenes/lobby.tscn"
const COLOR_BG: Color = Color("0d1018")
const COLOR_GOLD: Color = Color("ffd43b")

## 테스트에서 씬 전환을 막기 위한 스위치.
var change_scene_enabled: bool = true
var step: int = 1

var _title: Label = null
var _name_page: VBoxContainer = null
var _mode_page: VBoxContainer = null
var _name_edit: LineEdit = null
var _error_label: Label = null
var _confirm_button: Button = null
var _hello_label: Label = null
var _ai_button: Button = null
var _multi_button: Button = null
var _back_button: Button = null
var _mobile: MobileSupport = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = COLOR_BG
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override("panel", _style(Color("1a2030"), Color("39435c"), 3, 22, 24, 28))
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)
	_title = _label("에르핀의 억지 레이스", 34, COLOR_GOLD)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title)
	var subtitle := _label("보드게임 대격돌", 16, Color("adb5bd"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	_build_name_page(column)
	_build_mode_page(column)
	GameSession.load_settings()
	var saved: String = GameSession.load_saved()
	if saved != "":
		_name_edit.text = saved
	_show_step(1)
	_name_edit.grab_focus()
	_mobile = MobileSupport.new()
	add_child(_mobile)


func _build_name_page(parent: VBoxContainer) -> void:
	_name_page = VBoxContainer.new()
	_name_page.add_theme_constant_override("separation", 12)
	parent.add_child(_name_page)
	var prompt := _label("닉네임을 정해 주세요", 20, Color("f1f3f5"))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_page.add_child(prompt)
	_name_edit = LineEdit.new()
	_name_edit.max_length = GameSession.MAX_NICKNAME_LENGTH
	_name_edit.placeholder_text = "닉네임 (최대 %d자)" % GameSession.MAX_NICKNAME_LENGTH
	_name_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_edit.custom_minimum_size = Vector2(0, 48)
	_name_edit.add_theme_font_size_override("font_size", 22)
	_name_edit.text_submitted.connect(func(_text: String) -> void: confirm_nickname())
	_name_edit.text_changed.connect(func(_text: String) -> void: _error_label.text = "")
	_name_page.add_child(_name_edit)
	_error_label = _label("", 14, Color("ff8787"))
	_error_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_page.add_child(_error_label)
	_confirm_button = _button("확인", confirm_nickname, 20, Color("2b8a3e"))
	_name_page.add_child(_confirm_button)


func _build_mode_page(parent: VBoxContainer) -> void:
	_mode_page = VBoxContainer.new()
	_mode_page.add_theme_constant_override("separation", 12)
	parent.add_child(_mode_page)
	_hello_label = _label("", 20, Color("f1f3f5"))
	_hello_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_page.add_child(_hello_label)
	_ai_button = _button("컴퓨터 대전  (1P vs 3AI 봇)", start_ai_game, 22, Color("2b8a3e"))
	_mode_page.add_child(_ai_button)
	_multi_button = _button("멀티플레이  (빠른 매칭 / 방 코드)", open_lobby, 22, Color("1c6dd0"))
	_multi_button.tooltip_text = "빠른 랜덤 매칭 또는 5자리 방 코드로 연결합니다 (전용 서버 없이 WebRTC 직접 연결)."
	_mode_page.add_child(_multi_button)
	_back_button = _button("닉네임 변경", func() -> void: _show_step(1), 14, Color("4a3a66"))
	_mode_page.add_child(_back_button)


func _show_step(value: int) -> void:
	step = value
	_name_page.visible = value == 1
	_mode_page.visible = value == 2
	if value == 1 and _name_edit != null:
		_name_edit.grab_focus()


## 닉네임을 검사해 저장하고 모드 선택 화면으로 넘어간다. 통과했으면 true.
func confirm_nickname() -> bool:
	var problem: String = GameSession.validate_nickname(_name_edit.text)
	if problem != "":
		_error_label.text = problem
		return false
	GameSession.set_nickname(_name_edit.text)
	_hello_label.text = "%s 님, 환영합니다!" % GameSession.nickname
	_show_step(2)
	return true


## [컴퓨터 대전]: 1P(나) vs 3AI 봇으로 메인 보드를 연다.
func start_ai_game() -> void:
	GameSession.mode = GameSession.MODE_AI
	if change_scene_enabled:
		get_tree().change_scene_to_file(BOARD_SCENE)


## [멀티플레이]: 로비 화면으로 간다.
func open_lobby() -> void:
	GameSession.mode = GameSession.MODE_MULTIPLAYER
	if change_scene_enabled:
		get_tree().change_scene_to_file(LOBBY_SCENE)


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
	button.custom_minimum_size = Vector2(0, 56 if size_px >= 20 else 38)
	button.add_theme_font_size_override("font_size", size_px)
	button.add_theme_stylebox_override("normal", _style(base, base.lightened(0.3), 2, 12, 4, 8))
	button.add_theme_stylebox_override("hover", _style(base.lightened(0.15), COLOR_GOLD, 2, 12, 6, 8))
	button.add_theme_stylebox_override("pressed", _style(base.darkened(0.2), COLOR_GOLD, 2, 12, 0, 8))
	button.add_theme_stylebox_override("disabled", _style(base.darkened(0.5), base.darkened(0.2), 2, 12, 0, 8))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	if callback.is_valid():
		button.pressed.connect(callback)
	return button
