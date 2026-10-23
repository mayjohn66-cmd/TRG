# File: res://scenes/marquee_label.gd
# Class: class_name MarqueeLabel
# Role: 크기가 고정된 한 줄 글 상자. 글이 상자에 들어가면 그대로 두고, 길면(언어에 따라 번역이 길어지는 등) 잠깐 멈췄다가
#       천천히 옆으로 흘러가며 끝까지 보여 주고, 다시 멈췄다가 처음으로 돌아온다. 글자 크기와 상자 크기는 글 길이와 상관없이 그대로다
#       (글이 길다고 상자가 커지거나 글자가 작아지지 않는다). 안쪽 Label은 자동 번역을 거치므로 언어를 바꾸면 길이를 다시 잰다.
class_name MarqueeLabel
extends Control

## 흐르는 속도(초당 px)와 양 끝에서 멈추는 시간.
const SPEED: float = 45.0
const HOLD: float = 1.4

## 글 (원문 한국어, 화면에서 번역된다).
@export var text: String = "":
	set(value):
		text = value
		if _label != null:
			_label.text = value
			_restart()

var _label: Label = null
var _offset: float = 0.0
var _overflow: float = 0.0
var _phase: int = 0  ## 0 처음에서 멈춤, 1 흐름, 2 끝에서 멈춤, 3 처음으로 돌아감
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


## 안쪽 글자 라벨 (글꼴·외곽선 등 꾸밈을 바꿀 때).
func label() -> Label:
	return _label


## 지금 글이 상자보다 길어 흐르고 있는가.
func scrolling() -> bool:
	return _overflow > 0.5


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_TRANSLATION_CHANGED or what == NOTIFICATION_THEME_CHANGED:
		_restart.call_deferred()


func _restart() -> void:
	if _label == null or not is_inside_tree():
		return
	_label.reset_size()
	var width: float = _label.get_minimum_size().x
	_label.size = Vector2(maxf(width, size.x), size.y)
	_overflow = maxf(width - size.x, 0.0)
	_label.horizontal_alignment = _align if _overflow <= 0.5 else HORIZONTAL_ALIGNMENT_LEFT
	_phase = 0
	_timer = 0.0
	_offset = 0.0
	_label.position = Vector2.ZERO


func _ready() -> void:
	_restart()


func _process(delta: float) -> void:
	if _overflow <= 0.5:
		return
	_timer += delta
	match _phase:
		0, 2:
			if _timer >= HOLD:
				_phase += 1
				_timer = 0.0
		1:
			_offset = minf(_offset + SPEED * delta, _overflow)
			if _offset >= _overflow:
				_phase = 2
				_timer = 0.0
		3:
			_offset = maxf(_offset - SPEED * 4.0 * delta, 0.0)
			if _offset <= 0.0:
				_phase = 0
				_timer = 0.0
	_label.position.x = -_offset
