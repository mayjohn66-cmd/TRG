# File: res://scenes/roll_pad.gd
# Class: class_name RollPad
# Role: 보드 아래쪽(17·18번 타일 위)에 놓이는 직접 조작 굴림 패드. 인생게임 룰렛은 원판을 잡고 돌려 던지고, 러시안 룰렛은 리볼버의 방아쇠를 당긴다. 조작과 연출만 담당하며 눈금은 엔진 결과를 그대로 보여 준다
class_name RollPad
extends Control

## 룰렛을 놓았다. power는 0~1 (돌린 속도).
signal spin_released(power: float)
## 방아쇠를 당겼다.
signal trigger_pulled
## 룰렛/리볼버 연출이 끝났다.
signal finished

enum Kind { NONE, ROULETTE, REVOLVER }

const WHEEL_SIZE: float = 140.0
## 이 속도(rad/s) 이상으로 돌려야 던진 것으로 친다. 이보다 느리게 놓으면 안내만 뜬다.
const MIN_FLING_SPEED: float = 3.0
const MAX_FLING_SPEED: float = 20.0
const TAP_MAX_TRAVEL: float = 8.0
const TAP_MAX_SECONDS: float = 0.35
const SPIN_MIN_SECONDS: float = 1.1
const SPIN_MAX_SECONDS: float = 2.2

var kind: Kind = Kind.NONE
var enabled: bool = true
## 연출을 건너뛴다 (헤드리스 테스트).
var instant: bool = false
var active: bool = false
var last_face: int = 0

var _wheel: RollPresenter.WheelView = null
var _face_label: Label = null
var _hint_label: Label = null
var _gun: GunView = null

var _dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_time: float = 0.0
var _last_angle: float = 0.0
var _last_move_msec: int = 0
var _velocity: float = 0.0
var _travel: float = 0.0
var _tween: Tween = null


## 리볼버 옆모습: 총열·약실(6발)·손잡이·방아쇠를 그린다. chambers[i]가 true면 빈 총을 당겨 비운 약실이다.
class GunView extends Control:
	var chambers: Array[bool] = [false, false, false, false, false, false]
	var cylinder_angle: float = 0.0
	var flash: Color = Color(0, 0, 0, 0)
	var trigger_down: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(190, 120)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var steel: Color = Color("868e96")
		var dark: Color = Color("495057")
		# 총열
		draw_rect(Rect2(Vector2(8, 22), Vector2(120, 22)), steel, true)
		draw_rect(Rect2(Vector2(8, 22), Vector2(120, 22)), dark, false, 2.0)
		draw_rect(Rect2(Vector2(2, 18), Vector2(10, 8)), dark, true)
		# 몸통과 손잡이
		draw_rect(Rect2(Vector2(110, 20), Vector2(70, 40)), steel, true)
		draw_rect(Rect2(Vector2(110, 20), Vector2(70, 40)), dark, false, 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(138, 58), Vector2(182, 58), Vector2(172, 112), Vector2(128, 112)]), Color("5c3b1e"))
		# 방아쇠 (당기면 안쪽으로 눌린다)
		draw_rect(Rect2(Vector2(124 + trigger_down * 6.0, 60), Vector2(10, 22)), Color("e03131"), true)
		# 약실 (6발)
		var center: Vector2 = Vector2(96, 40)
		draw_circle(center, 30.0, dark)
		draw_circle(center, 27.0, Color("adb5bd"))
		for index: int in 6:
			var angle: float = cylinder_angle + TAU * float(index) / 6.0 - PI / 2.0
			var spot: Vector2 = center + Vector2(cos(angle), sin(angle)) * 16.0
			draw_circle(spot, 7.0, Color("212529") if not chambers[index] else Color("e9ecef"))
			if chambers[index]:
				draw_line(spot - Vector2(4, 4), spot + Vector2(4, 4), Color("868e96"), 2.0)
				draw_line(spot - Vector2(4, -4), spot + Vector2(4, -4), Color("868e96"), 2.0)
		draw_circle(center, 5.0, dark)
		if flash.a > 0.0:
			draw_circle(Vector2(6, 33), 18.0 * flash.a + 6.0, flash)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(200, 170)
	custom_minimum_size = size
	_wheel = RollPresenter.WheelView.new()
	_wheel.custom_minimum_size = Vector2(WHEEL_SIZE, WHEEL_SIZE)
	_wheel.size = Vector2(WHEEL_SIZE, WHEEL_SIZE)
	_wheel.position = Vector2((size.x - WHEEL_SIZE) / 2.0, 6.0)
	_wheel.pivot_offset = _wheel.size / 2.0
	_wheel.visible = false
	add_child(_wheel)
	_face_label = Label.new()
	_face_label.add_theme_font_size_override("font_size", 38)
	_face_label.add_theme_color_override("font_color", Color("ffd43b"))
	_face_label.add_theme_constant_override("outline_size", 8)
	_face_label.add_theme_color_override("font_outline_color", Color("0d1018"))
	_face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_face_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_face_label.size = Vector2(70, 50)
	_face_label.position = _wheel.position + (_wheel.size - _face_label.size) / 2.0
	_face_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face_label.visible = false
	add_child(_face_label)
	_gun = GunView.new()
	_gun.position = Vector2((size.x - 190.0) / 2.0, 26.0)
	_gun.visible = false
	add_child(_gun)
	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 13)
	_hint_label.add_theme_color_override("font_color", Color("fff3bf"))
	_hint_label.add_theme_constant_override("outline_size", 4)
	_hint_label.add_theme_color_override("font_outline_color", Color("0d1018"))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.size = Vector2(size.x, 20)
	_hint_label.position = Vector2(0, size.y - 22.0)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_label)
	set_kind(Kind.NONE)


## 어떤 패드를 보여 줄지 정한다 (NONE이면 숨김: 일반 굴리기 버튼이 대신 보인다).
func set_kind(value: Kind) -> void:
	kind = value
	visible = value != Kind.NONE
	if _wheel == null:
		return
	_wheel.visible = value == Kind.ROULETTE
	_face_label.visible = value == Kind.ROULETTE
	_gun.visible = value == Kind.REVOLVER
	match value:
		Kind.ROULETTE: _hint_label.text = "원판을 잡고 빙글 돌려 놓으세요"
		Kind.REVOLVER: _hint_label.text = "방아쇠를 당기세요"
		_: _hint_label.text = ""


func set_enabled(value: bool) -> void:
	enabled = value
	modulate = Color.WHITE if value else Color(0.55, 0.55, 0.6, 0.85)


## 리볼버 약실 표시를 새 판처럼 비운다 (턴이 끝났을 때).
func reset_revolver() -> void:
	if _gun == null:
		return
	for index: int in 6:
		_gun.chambers[index] = false
	_gun.cylinder_angle = 0.0
	_gun.queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if kind == Kind.NONE or not enabled or active:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if kind == Kind.REVOLVER:
		if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			trigger_pulled.emit()
		return
	var center: Vector2 = _wheel.position + _wheel.size / 2.0
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			if button.position.distance_to(center) > WHEEL_SIZE / 2.0 + 14.0:
				return
			accept_event()
			_dragging = true
			_press_pos = button.position
			_press_time = Time.get_ticks_msec() / 1000.0
			_last_angle = (button.position - center).angle()
			_last_move_msec = Time.get_ticks_msec()
			_velocity = 0.0
			_travel = 0.0
		elif _dragging:
			accept_event()
			_release_wheel(button.position)
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null and _dragging:
		accept_event()
		_drag_to(motion.position, center)


func _drag_to(pointer: Vector2, center: Vector2) -> void:
	var angle: float = (pointer - center).angle()
	var delta: float = wrapf(angle - _last_angle, -PI, PI)
	var now: int = Time.get_ticks_msec()
	var seconds: float = maxf(float(now - _last_move_msec) / 1000.0, 0.001)
	_velocity = lerpf(_velocity, delta / seconds, 0.5)
	_last_angle = angle
	_last_move_msec = now
	_travel += pointer.distance_to(_press_pos) if _travel == 0.0 else 0.0
	_wheel.angle -= delta
	_wheel.queue_redraw()
	_show_face_under_needle()


## 손을 뗐다: 충분히 빠르게 돌렸거나 가볍게 톡 쳤으면 던진 것으로 친다.
func _release_wheel(pointer: Vector2) -> void:
	_dragging = false
	var held: float = Time.get_ticks_msec() / 1000.0 - _press_time
	var speed: float = absf(_velocity)
	# 손가락을 멈췄다 떼면 속도가 식은 것으로 본다 (마지막 움직임이 오래됐으면 0)
	if Time.get_ticks_msec() - _last_move_msec > 120:
		speed = 0.0
	var tapped: bool = pointer.distance_to(_press_pos) <= TAP_MAX_TRAVEL and held <= TAP_MAX_SECONDS
	if speed >= MIN_FLING_SPEED:
		spin_released.emit(clampf((speed - MIN_FLING_SPEED) / (MAX_FLING_SPEED - MIN_FLING_SPEED), 0.0, 1.0))
	elif tapped:
		spin_released.emit(0.5)
	else:
		_hint_label.text = "더 세게 돌려 주세요!"
		get_tree().create_timer(1.2).timeout.connect(func() -> void:
			if kind == Kind.ROULETTE and not active:
				_hint_label.text = "원판을 잡고 빙글 돌려 놓으세요")


func _show_face_under_needle() -> void:
	var step: float = TAU / 10.0
	var index: int = posmod(int(roundf(_wheel.angle / step)), 10)
	_face_label.text = str(index + 1)


## 엔진이 정한 눈금(face 1~10)으로 원판이 감속하며 멈춘다. power(0~1)가 클수록 오래·많이 돈다.
func play_spin(face: int, power: float) -> void:
	last_face = face
	if instant or not is_inside_tree():
		_wheel.angle = float(face - 1) * TAU / 10.0
		_wheel.queue_redraw()
		_face_label.text = str(face)
		return
	active = true
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var step: float = TAU / 10.0
	var start_index: float = _wheel.angle / step
	var extra: float = 20.0 + clampf(power, 0.0, 1.0) * 30.0
	var target_index: float = ceilf(start_index + extra)
	while posmod(int(target_index), 10) != posmod(face - 1, 10):
		target_index += 1.0
	var seconds: float = lerpf(SPIN_MIN_SECONDS, SPIN_MAX_SECONDS, clampf(power, 0.0, 1.0))
	_tween = create_tween()
	_tween.tween_method(func(value: float) -> void:
		_wheel.angle = value * step
		_wheel.queue_redraw()
		_show_face_under_needle(), start_index, target_index, seconds).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	await _tween.finished
	_face_label.text = str(face)
	_face_label.pivot_offset = _face_label.size / 2.0
	var punch: Tween = create_tween()
	_face_label.scale = Vector2(1.5, 1.5)
	punch.tween_property(_face_label, "scale", Vector2.ONE, 0.2)
	await punch.finished
	active = false
	finished.emit()


## 리볼버 연출: 빈 총이면 약실이 한 칸 돌고 철컥, 실탄이면 총구에서 번쩍 한다.
func play_trigger(fired: bool, accumulated: int) -> void:
	if instant or not is_inside_tree():
		if fired:
			reset_revolver()
		return
	active = true
	var pull: Tween = create_tween()
	pull.tween_property(_gun, "trigger_down", 1.0, 0.08)
	pull.tween_property(_gun, "trigger_down", 0.0, 0.12)
	pull.parallel().tween_method(func(_v: float) -> void: _gun.queue_redraw(), 0.0, 1.0, 0.2)
	await pull.finished
	if fired:
		_gun.flash = Color("ff6b6b")
		_gun.queue_redraw()
		var boom: Tween = create_tween()
		boom.tween_method(func(value: float) -> void:
			_gun.flash.a = value
			_gun.queue_redraw(), 1.0, 0.0, 0.5)
		await boom.finished
		reset_revolver()
	else:
		var index: int = clampi(accumulated / ToolRussianRoulette.STEPS_PER_EMPTY - 1, 0, 5)
		_gun.chambers[index] = true
		var spin: Tween = create_tween()
		spin.tween_method(func(value: float) -> void:
			_gun.cylinder_angle = value
			_gun.queue_redraw(), _gun.cylinder_angle, _gun.cylinder_angle + TAU / 6.0, 0.18)
		await spin.finished
	active = false
	finished.emit()
