# File: res://scenes/marquee_label.gd
# Class: class_name MarqueeLabel
# Role: 크기가 고정된 한 줄 글 상자. 글이 상자에 들어가면 그대로 두고, 길면(언어에 따라 번역이 길어지는 등) 잠깐 멈췄다가
#       전광판처럼 한 방향으로 계속 순환하며 흐른다 (글 뒤에 간격을 두고 같은 글이 이어 붙어 따라오므로 되감기 없이 이어진다).
#       한 바퀴 돌아 처음 모습이 되면 다시 잠깐 멈춘다. 글자 크기와 상자 크기는 글 길이와 상관없이 그대로다
#       (글이 길다고 상자가 커지거나 글자가 작아지지 않는다). 안쪽 Label은 자동 번역을 거치므로 언어를 바꾸면 길이를 다시 잰다.
class_name MarqueeLabel
extends Control

## 흐르는 속도(초당 px)와 한 바퀴마다 처음 모습에서 멈추는 시간.
const SPEED: float = 45.0
const HOLD: float = 1.4
## 글 끝과 이어 붙는 글 머리 사이의 간격(px).
const GAP: float = 48.0

## 글 (원문 한국어, 화면에서 번역된다).
@export var text: String = "":
	set(value):
		text = value
		if _label != null:
			_label.text = value
			_restart()

var _label: Label = null
## 순환용으로 글 뒤에 이어 붙는 같은 글 (흐를 때만 보인다).
var _tail: Label = null
var _offset: float = 0.0
var _overflow: float = 0.0
## 한 바퀴 거리 = 글 폭 + 간격.
var _cycle: float = 0.0
var _phase: int = 0  ## 0 처음 모습에서 멈춤, 1 흐름
## 0보다 크면 흐르기 전에 먼저 글자를 이 크기까지 줄여 상자에 맞춘다 (그래도 길면 흐른다). 0이면 글자 크기는 그대로.
var shrink_min_px: int = 0
var _base_px: int = 0
var _timer: float = 0.0
var _align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT


## 상자 하나를 만든다. box: 고정 크기 (높이 0이면 글자 높이에 맞춘다).
## label_name: 안쪽 Label의 이름 (화면·테스트가 이름으로 찾는 글자 노드). 상자 자체는 "<이름>Box".
static func create(content: String, font_size: int, color: Color, box: Vector2, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, label_name: String = "Text") -> MarqueeLabel:
	var marquee := MarqueeLabel.new()
	marquee.name = label_name + "Box"
	marquee._label.name = label_name
	marquee._align = align
	marquee._label.add_theme_font_size_override("font_size", font_size)
	marquee._base_px = font_size
	marquee._label.add_theme_color_override("font_color", color)
	marquee.text = content
	var height: float = box.y if box.y > 0.0 else marquee._label.get_minimum_size().y
	marquee.custom_minimum_size = Vector2(box.x, height)
	return marquee


func _init() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = Label.new()
	_label.name = "Text"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(_label)
	_tail = Label.new()
	_tail.name = "TailCopy"
	_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tail.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tail.autowrap_mode = TextServer.AUTOWRAP_OFF
	_tail.visible = false
	add_child(_tail)


## 흐르게 하는 대신 글자를 min_px까지 줄여 상자에 맞추게 한다 (짧은 제목·숫자 칸처럼 흐르면 읽기 어려운 곳).
func shrink_to_fit(min_px: int) -> MarqueeLabel:
	shrink_min_px = min_px
	_restart.call_deferred()
	return self


## 지금 쓰는 글자 크기.
func font_px() -> int:
	return _label.get_theme_font_size("font_size")


## 안쪽 글자 라벨 (글꼴·외곽선 등 꾸밈을 바꿀 때).
func label() -> Label:
	return _label


## 지금 글이 상자보다 길어 흐르고 있는가.
func scrolling() -> bool:
	return _overflow > 0.5


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_TRANSLATION_CHANGED or what == NOTIFICATION_THEME_CHANGED:
		_restart.call_deferred()
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process(is_visible_in_tree())  # 숨은 페이지의 흐르는 글은 멈춘다 (보이면 이어서 흐른다)


func _restart() -> void:
	if _label == null or not is_inside_tree():
		return
	if shrink_min_px > 0 and _base_px > 0:
		# 상자에 들어갈 때까지 글자를 줄인다 (원래 크기에서 다시 잰다: 언어를 바꿔 글이 짧아지면 다시 커진다)
		var shown: String = _label.atr(_label.text)
		var font: Font = _label.get_theme_font("font")
		var px: int = FontSizes.snap(_base_px)
		while px > shrink_min_px and font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > size.x:
			px = FontSizes.next_down(px)  # 표준 크기로만 줄인다 (크기마다 글리프를 굽는다)
		_label.add_theme_font_size_override("font_size", px)
	_label.reset_size()
	var width: float = _label.get_minimum_size().x
	_label.size = Vector2(maxf(width, size.x), size.y)
	_overflow = maxf(width - size.x, 0.0)
	_cycle = width + GAP
	_label.horizontal_alignment = _align if _overflow <= 0.5 else HORIZONTAL_ALIGNMENT_LEFT
	_phase = 0
	_timer = 0.0
	_offset = 0.0
	_label.position = Vector2.ZERO
	_tail.visible = _overflow > 0.5
	if _tail.visible:
		_sync_tail()
		_tail.size = Vector2(width, size.y)
		_tail.position = Vector2(_cycle, 0)


## 이어 붙는 글을 본 글과 똑같이 꾸민다 (글·글꼴·크기·색·외곽선은 나중에 바뀔 수 있다).
func _sync_tail() -> void:
	_tail.text = _label.text
	_tail.auto_translate_mode = _label.auto_translate_mode
	_tail.add_theme_font_override("font", _label.get_theme_font("font"))
	_tail.add_theme_font_size_override("font_size", _label.get_theme_font_size("font_size"))
	_tail.add_theme_color_override("font_color", _label.get_theme_color("font_color"))
	_tail.add_theme_color_override("font_outline_color", _label.get_theme_color("font_outline_color"))
	_tail.add_theme_constant_override("outline_size", _label.get_theme_constant("outline_size"))


func _ready() -> void:
	set_process(is_visible_in_tree())
	_restart()


func _process(delta: float) -> void:
	if _overflow <= 0.5:
		return
	_timer += delta
	match _phase:
		0:
			if _timer >= HOLD:
				_phase = 1
				_timer = 0.0
				_sync_tail()
		1:
			_offset += SPEED * delta
			if _offset >= _cycle:
				# 한 바퀴: 이어 붙은 글이 처음 자리에 왔다 = 처음 모습과 같다. 그대로 이어서 처음으로 돌리고 잠깐 멈춘다
				_offset = 0.0
				_phase = 0
				_timer = 0.0
	_label.position.x = -_offset
	_tail.position.x = _cycle - _offset
