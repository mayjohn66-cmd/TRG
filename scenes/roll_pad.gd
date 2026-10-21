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
signal preparation_finished

enum Kind { NONE, ROULETTE, REVOLVER }

const ONE_CLICK_POWER: float = 0.75  ## 원판을 한 번 눌렀을 때의 연출 세기
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
## 보드가 패드를 키운 배수 (set_text_scale). 글자 라벨은 이 배수로 크게 그리고 1/배수로 줄인다.
var text_scale: float = 1.0
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
var preparing: bool = false
var _prepare_time: float = 0.0
var _prepared_key: String = ""


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
	_face_label.add_theme_color_override("font_color", Color("ffd43b"))
	_face_label.add_theme_color_override("font_outline_color", Color("0d1018"))
	_face_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_face_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_place_label(_face_label, Vector2(0,118), Vector2(200, 28), 21, 8)
	_face_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face_label.visible = false
	add_child(_face_label)
	_gun = ToyFlagGun3D.new()
	_gun.custom_minimum_size = Vector2(280,168)
	_gun.size = Vector2(280,168)
	_gun.position = Vector2((size.x - 280.0) / 2.0, 4.0)
	_gun.visible = false
	add_child(_gun)
	_hint_label = Label.new()
	_hint_label.add_theme_color_override("font_color", Color("fff3bf"))
	_hint_label.add_theme_font_override("font", preload("res://assets/fonts/game_small_font.tres"))  # 작은 안내 글자는 또렷한 고딕
	_hint_label.add_theme_color_override("font_outline_color", Color("0d1018"))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_place_label(_hint_label, Vector2(0, size.y - 22.0), Vector2(size.x, 20), 13, 4)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_label)
	set_kind(Kind.NONE)


## 어떤 패드를 보여 줄지 정한다 (NONE이면 숨김: 일반 굴리기 버튼이 대신 보인다).
func set_kind(value: Kind) -> void:
	if kind != value:
		cancel_spin()
		_prepared_key = ""
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
			_place_label(_hint_label, Vector2(0,size.y-22.0), Vector2(size.x,20), 13, 4)
		Kind.REVOLVER: _hint_label.text = ""  # 발사·정지 두 버튼이 안내를 대신한다
		_: _hint_label.text = ""


## 보드는 이 패드를 Control scale로 키워(최대 1.9배) 보여 준다. 글자를 작게 그린 뒤 키우면 흐릿하고 뭉개지므로
## 글자 라벨만 반대로 1/배수로 줄이고, 그 배수만큼 큰 글자(외곽선 포함)로 그려 화면 픽셀에 맞춘다.
func set_text_scale(value: float) -> void:
	text_scale = maxf(value, 0.01)
	for label: Label in [_face_label, _hint_label]:
		if label != null and label.has_meta("layout"):
			var layout: Array = label.get_meta("layout")
			_place_label(label, layout[0], layout[1], layout[2], layout[3])


## 결과 숫자를 가운데를 축으로 k배 통통 키운다 (라벨은 1/배수로 줄여 둔 상태라 위치를 직접 맞춘다).
func _pulse_face(k: float) -> void:
	if _face_label == null or not _face_label.has_meta("layout"):
		return
	var layout: Array = _face_label.get_meta("layout")
	var logical: Vector2 = layout[1]
	_face_label.scale = Vector2.ONE * k / text_scale
	_face_label.position = (layout[0] as Vector2) + logical / 2.0 - logical * k / 2.0


## 라벨을 패드 좌표 position에 logical_size 크기로 놓는다 (글자 크기 px · 외곽선 outline은 배수 1 기준).
func _place_label(label: Label, at: Vector2, logical_size: Vector2, px: int, outline: int) -> void:
	label.set_meta("layout", [at, logical_size, px, outline])
	label.position = at
	label.size = logical_size * text_scale
	label.pivot_offset = Vector2.ZERO
	label.scale = Vector2.ONE / text_scale
	label.add_theme_font_size_override("font_size", roundi(px * text_scale))
	label.add_theme_constant_override("outline_size", roundi(outline * text_scale))


func set_enabled(value: bool) -> void:
	enabled = value
	modulate = Color.WHITE if value or active else Color(0.55, 0.55, 0.6, 0.85)


## Clear only the public safe-click progress; no loaded chamber is displayed.
func reset_revolver() -> void:
	if _gun != null:
		_gun.reset_state()


## Cosmetic loading never reads or consumes the engine's hidden chamber/RNG.
func ensure_revolver_prepared(key: String, pending: bool) -> void:
	if _prepared_key==key:
		return
	_prepared_key = key
	_gun.reset_state()
	if instant or pending:
		_gun.show_side()
		return
	preparing = true
	active = true
	_prepare_time = 0.0
	modulate = Color.WHITE
	_gun.begin_preparation()
	_hint_label.text = ""  # 준비·발사 여부 안내 글자는 띄우지 않는다 (발사·정지 버튼과 총 연출이 대신한다)
	_place_label(_hint_label, Vector2(-30,134), Vector2(260,22), 11, 4)


func _gui_input(event: InputEvent) -> void:
	if kind == Kind.NONE or not enabled or active:
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if kind == Kind.REVOLVER:
		if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			trigger_pulled.emit()
		return
	# 원클릭: 원판을 한 번 누르면 바로 시원하게 돈다 (돌리는 속도를 잴 필요가 없다).
	var center: Vector2 = _wheel.position + _wheel.size / 2.0
	if button != null and button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
		if button.position.distance_to(center) > WHEEL_SIZE / 2.0 + 14.0:
			return
		accept_event()
		spin_released.emit(ONE_CLICK_POWER)


func _show_face_under_needle() -> void:
	_face_label.text = str(_wheel.displayed_value())


## Same 3D motion as remote rolls; dragging chooses direction and visual power.
func play_spin(face: int, power: float) -> void:
	cancel_spin()
	last_face = face
	_pulse_face(1.0)
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
	if preparing:
		_prepare_time += delta
		_gun.apply_preparation(_prepare_time)
		if _prepare_time>=ToyFlagGun3D.PREP_TIME:
			preparing = false
			active = false
			_gun.stop_rendering()
			preparation_finished.emit()
		return
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
		_pulse_face(1.0+0.20*sin(phase*PI)*(1.0-phase))
	if _spin_time >= RouletteSpin3D.TOTAL_TIME:
		_spinning = false
		active = false
		_wheel.stop_rendering()
		_pulse_face(1.0)
		finished.emit()


## Resume any awaiting board handler when a new game/tool cancels the spin.
func cancel_spin() -> void:
	var was_preparing: bool = preparing
	preparing = false
	_dragging = false
	if _wheel != null:
		_wheel.stop_rendering()
	if _gun != null:
		if _firing or was_preparing:
			_gun.reset_state()
			_gun.hide()
		_gun.stop_rendering()
	if not _spinning and not _firing and not was_preparing:
		return
	_spinning = false
	_firing = false
	active = false
	_pulse_face(1.0)
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
