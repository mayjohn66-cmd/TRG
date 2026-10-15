# File: res://scenes/event_announcer.gd
# Class: class_name EventAnnouncer
# Role: 자동으로 일어나는 일(법 제정·카드 사용·설치물 발동 등)을 보드 한가운데에 큼직한 카드로 한 건씩 보여 주는 대기열 연출기. 연출만 담당하며 클릭하면 건너뛴다
class_name EventAnnouncer
extends PanelContainer

## 대기열이 모두 비었다 (마지막 알림이 끝났다).
signal drained

const FADE_IN: float = 0.12
const FADE_OUT: float = 0.18
const MAX_QUEUE: int = 6

## true면 알림을 모두 건너뛴다 (헤드리스 테스트·ui_smoke 자동 진행).
var instant: bool = false
## 화면 중앙 좌표 (패널은 이 점에 가운데 정렬된다).
var center: Vector2 = Vector2(683, 330)
## 지금 알림이 떠 있거나 대기 중이다. 입력 잠금 판정에 쓴다.
var active: bool = false
## 지금까지 띄운 알림 헤드라인 (테스트 확인용).
var history: Array[String] = []

var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _t: float = 0.0
var _root: VBoxContainer = null


func _init() -> void:
	visible = false
	z_index = 40
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


## 알림 한 건을 대기열에 넣는다. extra는 헤드라인 아래에 붙일 임의의 Control(카드 프레임·법전 목록 등)이다.
func announce(tag: String, headline: String, body: String, color: Color, extra: Control = null, duration: float = 1.5) -> void:
	history.append(headline)
	if instant:
		if extra != null:
			extra.free()
		return
	if _queue.size() >= MAX_QUEUE:
		var dropped: Dictionary = _queue.pop_front()
		if dropped["extra"] != null:
			(dropped["extra"] as Control).free()
	_queue.append({"tag": tag, "headline": headline, "body": body, "color": color, "extra": extra, "duration": duration})
	active = true
	if _current.is_empty():
		_start_next()


## 대기 중인 알림까지 모두 지운다 (새 게임·테스트).
func cancel() -> void:
	for entry: Dictionary in _queue:
		if entry["extra"] != null:
			(entry["extra"] as Control).free()
	_queue.clear()
	_current = {}
	_clear()
	visible = false
	var was_active: bool = active
	active = false
	if was_active:
		drained.emit()


func skip_current() -> void:
	if _current.is_empty():
		return
	_t = maxf(_t, float(_current["duration"]))


func _start_next() -> void:
	_clear()
	if _queue.is_empty():
		_current = {}
		visible = false
		active = false
		drained.emit()
		return
	_current = _queue.pop_front()
	_t = 0.0
	var color: Color = _current["color"]
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101626")
	style.border_color = color
	style.set_border_width_all(4)
	style.set_corner_radius_all(18)
	style.set_content_margin_all(16)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 24
	add_theme_stylebox_override("panel", style)
	_root = VBoxContainer.new()
	_root.add_theme_constant_override("separation", 6)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.add_child(_label(str(_current["tag"]), 13, color.lightened(0.2)))
	_root.add_child(_label(str(_current["headline"]), 26, Color("f8f9fa")))
	if str(_current["body"]) != "":
		var body: Label = _label(str(_current["body"]), 14, Color("ced4da"))
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(380, 0)
		_root.add_child(body)
	if _current["extra"] != null:
		_root.add_child(_current["extra"] as Control)
	_root.add_child(_label("(클릭하면 넘어갑니다)", 10, Color("6c757d")))
	modulate = Color(1, 1, 1, 0)
	visible = true
	reset_size()
	_place()
	call_deferred("_place")


func _place() -> void:
	reset_size()
	position = center - size / 2.0
	pivot_offset = size / 2.0


func _label(text: String, size_px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _clear() -> void:
	if _root != null:
		remove_child(_root)
		_root.queue_free()
		_root = null


func _process(delta: float) -> void:
	if _current.is_empty():
		return
	_t += delta
	var duration: float = float(_current["duration"])
	var alpha: float = 1.0
	if _t < FADE_IN:
		alpha = _t / FADE_IN
	elif _t > duration - FADE_OUT:
		alpha = clampf((duration - _t) / FADE_OUT, 0.0, 1.0)
	modulate = Color(1, 1, 1, alpha)
	# 등장할 때 살짝 커지며 튀어나온다 (0.88배 -> 1.0배).
	var pop: float = clampf(_t / (FADE_IN * 2.0), 0.0, 1.0)
	scale = Vector2.ONE * lerpf(0.88, 1.0, 1.0 - pow(1.0 - pop, 3.0))
	if _t >= duration:
		_start_next()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		skip_current()
