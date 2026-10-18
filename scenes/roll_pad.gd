# File: res://scenes/roll_pad.gd
# Class: class_name RollPad
# Role: 보드 한가운데 오픈 스테이지에 놓이는 직접 조작 굴림 패드. 인생게임 룰렛은 원판을 잡고 돌려 던지고, 러시안 룰렛은 리볼버의 방아쇠를 당긴다. 조작과 연출만 담당하며 눈금은 엔진 결과를 그대로 보여 준다
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

var kind: Kind = Kind.NONE
var enabled: bool = true
## 연출을 건너뛴다 (헤드리스 테스트).
var instant: bool = false
var active: bool = false
var last_face: int = 0

var _wheel: RouletteSpin3D = null
var _face_label: Label = null
var _hint_label: Label = null
var _gun: ToyFlagGun3D = null

var _dragging: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _press_time: float = 0.0
var _last_angle: float = 0.0
var _last_move_msec: int = 0
var _velocity: float = 0.0
var _travel: float = 0.0
var _spinning: bool = false
var _spin_time: float = 0.0
var _firing: bool = false
var _trigger_time: float = 0.0
var _trigger_caption: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size = Vector2(200, 170)
	custom_minimum_size = size
	_wheel = RouletteSpin3D.new()
	_wheel.custom_minimum_size = Vector2(WHEEL_SIZE, WHEEL_SIZE)
	_wheel.size = Vector2(WHEEL_SIZE, WHEEL_SIZE)
	_wheel.position = Vector2((size.x - WHEEL_SIZE) / 2.0, 6.0)
	_wheel.pivot_offset = _wheel.size / 2.0
	_wheel.visible = false
	add_child(_wheel)
	_face_label = Label.new()
	_face_label.add_theme_font_size_override("font_size", 21)
	_face_label.add_theme_color_override("font_color", Color("ffd43b"))
	_face_label.add_theme_constant_override("outline_size", 8)
	_face_label.add_theme_color_override("font_outline_color", Color("0d1018"))
	_face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_face_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_face_label.size = Vector2(200, 28)
	_face_label.position = Vector2(0,118)
	_face_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face_label.visible = false
	add_child(_face_label)
	_gun = ToyFlagGun3D.new()
	_gun.custom_minimum_size = Vector2(190,120)
	_gun.size = Vector2(190,120)
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
	if kind != value:
		cancel_spin()
	kind = value
	visible = value != Kind.NONE
	if _wheel == null:
		return
	if value != Kind.ROULETTE:
		_wheel.stop_rendering()
	elif _wheel.render_view != null:
		_wheel.render_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	_wheel.visible = value == Kind.ROULETTE
	_face_label.visible = value == Kind.ROULETTE
	_gun.visible = value == Kind.REVOLVER
	if value == Kind.REVOLVER:
		_gun.render_view.render_target_update_mode = SubViewport.UPDATE_ONCE
	else:
		_gun.stop_rendering()
	match value:
		Kind.ROULETTE:
			_hint_label.text = "원판을 잡고 빙글 돌려 놓으세요"
			_hint_label.position = Vector2(0,size.y-22.0)
			_hint_label.size = Vector2(size.x,20)
			_hint_label.add_theme_font_size_override("font_size",13)
		Kind.REVOLVER: _hint_label.text = ""  # 발사·정지 두 버튼이 안내를 대신한다
		_: _hint_label.text = ""


func set_enabled(value: bool) -> void:
	enabled = value
	modulate = Color.WHITE if value or active else Color(0.55, 0.55, 0.6, 0.85)


## Clear only the public safe-click progress; no loaded chamber is displayed.
func reset_revolver() -> void:
	if _gun != null:
		_gun.reset_state()


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
	_wheel.set_idle_angle(_wheel.angle-delta)
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
	_face_label.text = str(_wheel.displayed_value())


## Same 3D motion as remote rolls; dragging chooses direction and visual power.
func play_spin(face: int, power: float) -> void:
	cancel_spin()
	last_face = face
	_face_label.scale = Vector2.ONE
	if instant or not is_inside_tree():
		_wheel.set_idle_angle((face-1)*RouletteSpin3D.STEP)
		_wheel.stop_rendering()
		_face_label.text = str(face)
		return
	_spinning = true
	active = true
	modulate = Color.WHITE
	_spin_time = 0.0
	_face_label.text = ""
	_hint_label.text = "빙글빙글…"
	_wheel.begin(face,power,_wheel.angle,-1.0 if _velocity>0.0 else 1.0)
	await finished


func _process(delta: float) -> void:
	if _firing:
		_trigger_time += delta
		_gun.apply_time(_trigger_time)
		if _gun.settled:
			_hint_label.text = _trigger_caption
		if _trigger_time >= ToyFlagGun3D.total_time(_gun.fired_result):
			_firing = false
			active = false
			_gun.stop_rendering()
			finished.emit()
		return
	if not _spinning:
		return
	_spin_time += delta
	_wheel.apply_time(_spin_time)
	if _wheel.settled:
		_face_label.text = str(last_face)
		_hint_label.text = "%d칸 전진%s" % [last_face," · 한 번 더!" if last_face==ToolLifeRoulette.JACKPOT_FACE else ""]
		var phase: float = clampf((_spin_time-RouletteSpin3D.RESULT_TIME)/0.18,0,1)
		_face_label.pivot_offset = _face_label.size/2.0
		_face_label.scale = Vector2.ONE*(1.0+0.20*sin(phase*PI)*(1.0-phase))
	if _spin_time >= RouletteSpin3D.TOTAL_TIME:
		_spinning = false
		active = false
		_wheel.stop_rendering()
		_face_label.scale = Vector2.ONE
		finished.emit()


## Resume any awaiting board handler when a new game/tool cancels the spin.
func cancel_spin() -> void:
	_dragging = false
	if _wheel != null:
		_wheel.stop_rendering()
	if _gun != null:
		if _firing:
			_gun.reset_state()
			_gun.hide()
		_gun.stop_rendering()
	if not _spinning and not _firing:
		return
	_spinning = false
	_firing = false
	active = false
	_face_label.scale = Vector2.ONE
	finished.emit()


## Fire the public outcome as a party toy, or click the next empty chamber.
func play_trigger(fired: bool, accumulated: int, lost: int = 0, can_continue: bool = true) -> void:
	cancel_spin()
	_trigger_caption = ToyFlagGun3D.result_caption(fired,accumulated,lost,can_continue)
	_gun.show()
	_gun.begin(fired,accumulated,lost)
	if instant or not is_inside_tree():
		_gun.apply_time(ToyFlagGun3D.total_time(fired))
		_gun.stop_rendering()
		return
	active = true
	_firing = true
	modulate = Color.WHITE
	_trigger_time = 0.0
	_hint_label.text = ""
	_hint_label.add_theme_font_size_override("font_size",11)
	_hint_label.position = Vector2(-30,134)
	_hint_label.size = Vector2(260,22)
	await finished
