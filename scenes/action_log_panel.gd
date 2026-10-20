# File: res://scenes/action_log_panel.gd
# Class: class_name ActionLogPanel
# Role: 인게임 액션 히스토리 로그. 누가 무엇을 했는지(굴림·카드·방어·함정·처치·필살기·증강·법전) 한 줄씩 쌓는다.
#       평소(미니)에는 최근 MINI_LINES줄만 작게, 펼치면([📜 로그] 버튼·L 키) 전체 내역을 스크롤로 본다.
#       메모리 보호: 최대 MAX_LOG_LINES줄만 보관하고 넘치면 가장 오래된 줄부터 버린다 (링 버퍼)
class_name ActionLogPanel
extends PanelContainer

signal expanded_changed(expanded: bool)

const MAX_LOG_LINES: int = 100
const MINI_LINES: int = 4
const MINI_SIZE: Vector2 = Vector2(300.0, 150.0)
const EXPANDED_SIZE: Vector2 = Vector2(460.0, 470.0)

var expanded: bool = false
## 미니 모드에서 패널이 놓일 왼쪽 위 (확장하면 위로 커져 보드 쪽을 가리지 않는다).
var mini_position: Vector2 = Vector2.ZERO

var _lines: Array[String] = []
var _title: Label = null
var _toggle: Button = null
var _text: RichTextLabel = null
var _scroll: ScrollContainer = null
var _mini_style: StyleBoxFlat = null
var _expanded_style: StyleBoxFlat = null


func _init() -> void:
	name = "ActionLogPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_mini_style = _panel_style(0.72)
	_expanded_style = _panel_style(0.94)
	add_theme_stylebox_override("panel", _mini_style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	_title = Label.new()
	_title.text = "최근 기록"
	_title.add_theme_font_size_override("font_size", 13)
	_title.add_theme_color_override("font_color", Color("ffd43b"))
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_toggle = Button.new()
	_toggle.text = "📜 로그 펼치기"
	_toggle.tooltip_text = "지금까지의 전체 기록을 펼쳐 봅니다 (단축키 L)"
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.add_theme_font_size_override("font_size", 12)
	_toggle.pressed.connect(toggle)
	header.add_child(_toggle)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_scroll)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.fit_content = true
	_text.scroll_active = false
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_PASS
	_text.add_theme_font_size_override("normal_font_size", 12)
	_text.add_theme_font_size_override("bold_font_size", 12)
	_scroll.add_child(_text)
	_apply_mode()


func _panel_style(alpha: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.065, 0.11, alpha)
	style.border_color = Color(1.0, 0.83, 0.23, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	return style


## 한 줄을 기록한다 (BBCode 가능). 100줄을 넘으면 가장 오래된 줄을 버린다.
func add_entry(bbcode: String) -> void:
	if bbcode.strip_edges().is_empty():
		return
	_lines.append(bbcode)
	while _lines.size() > MAX_LOG_LINES:
		_lines.pop_front()
	_render()


func clear_entries() -> void:
	_lines.clear()
	_render()


func line_count() -> int:
	return _lines.size()


func lines() -> Array[String]:
	return _lines.duplicate()


## 미니 화면에 보이는 줄 수 (펼치면 전부).
func visible_line_count() -> int:
	return _lines.size() if expanded else mini(_lines.size(), MINI_LINES)


func toggle() -> void:
	set_expanded(not expanded)


func set_expanded(value: bool) -> void:
	if expanded == value:
		return
	expanded = value
	_apply_mode()
	expanded_changed.emit(expanded)


func place(at: Vector2) -> void:
	mini_position = at
	_apply_mode()


func _apply_mode() -> void:
	add_theme_stylebox_override("panel", _expanded_style if expanded else _mini_style)
	_toggle.text = "📜 로그 접기" if expanded else "📜 로그 펼치기"
	_title.text = "액션 로그 (최근 %d줄)" % MAX_LOG_LINES if expanded else "최근 기록"
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if expanded else ScrollContainer.SCROLL_MODE_SHOW_NEVER
	z_index = 70 if expanded else 0
	var panel_size: Vector2 = EXPANDED_SIZE if expanded else MINI_SIZE
	custom_minimum_size = panel_size
	size = panel_size
	# 펼치면 아래쪽 끝은 그대로 두고 위로 커진다 (아래쪽 프로필 카드를 가리지 않게)
	position = Vector2(mini_position.x, maxf(mini_position.y + MINI_SIZE.y - panel_size.y, 8.0)) if expanded else mini_position
	_render()


## 줄 배열에서 화면 글자를 다시 만든다: 미니는 최근 몇 줄만, 펼치면 전부 (줄 수가 100줄로 묶여 있어 다시 그려도 가볍다).
func _render() -> void:
	if _text == null:
		return
	if _lines.is_empty():
		_text.text = "[color=#868e96]아직 기록이 없습니다[/color]"
	else:
		_text.text = "\n".join(PackedStringArray(_lines.slice(_lines.size() - visible_line_count())))
	if is_inside_tree():
		_scroll_to_bottom.call_deferred()  # 미니든 펼침이든 가장 최근 줄이 보이게


func _scroll_to_bottom() -> void:
	if _scroll == null or not is_inside_tree():
		return
	await get_tree().process_frame  # 글자 높이가 정해진 다음 프레임에 맨 아래로
	if is_instance_valid(_scroll):
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)
