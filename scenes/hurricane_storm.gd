## 방해령 허리케인 포스!! 승리 연출의 폭풍 (1.1): 보드 한가운데에서 거대한 허리케인이 몰아친다.
## 하늘이 어두워지고 → 소용돌이 바람이 번지며 번개가 번쩍 → 절정의 흰 섬광(보드 위 기물이 모두 날아간다) → 폭풍이 걷힌다.
## 시계 하나(set_time)로 모든 것이 그려져 배속·건너뛰기에서도 어긋나지 않는다. 무작위가 필요한 곳(잔해·번개)은 번호로 정하는 가짜 난수라 시뮬레이션·RNG를 건드리지 않는다.
class_name HurricaneStorm
extends Control

## 박자: wind(바람 시작) · bolt(번개) · climax(절정) · cleared(폭풍이 걷힘, 기물이 돌아온다)
signal beat(kind: StringName)
signal completed

## 기본 길이(초). 실제 길이는 play()의 pace를 곱한다.
const DURATION: float = 3.1
const BOLT_TIMES: Array[float] = [0.75, 1.25, 1.7]
const CLIMAX_AT: float = 1.45
const CLEAR_AT: float = 2.4
const ARMS: int = 7
const ARM_POINTS: int = 26
const DEBRIS: int = 70

## 폭풍의 눈 (이 컨트롤 좌표계, 보통 화면 좌표).
var center: Vector2 = Vector2(683, 335)
var active: bool = false
var _time: float = 0.0
var _time_view: float = 0.0
var _pace: float = 1.0
var _fired: Dictionary = {}


func _init() -> void:
	name = "HurricaneStorm"
	mouse_filter = Control.MOUSE_FILTER_STOP  # 연출 중 보드 입력을 막고, 누르면 건너뛴다
	set_process(false)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_process(active)  # 엔진이 _ready에서 _process를 다시 켜므로 play() 전에는 시계를 끈다


func play(pace: float = 1.0) -> void:
	_pace = maxf(pace, 0.1)
	_time = 0.0
	_fired.clear()
	active = true
	visible = true
	set_process(true)
	set_time(0.0)


func skip() -> void:
	if not active:
		return
	for kind: StringName in [&"climax", &"cleared"]:
		_fire(kind, kind)
	_finish()


func _gui_input(event: InputEvent) -> void:
	if active and event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		accept_event()
		skip()


func _process(delta: float) -> void:
	_time += delta
	var t: float = _time / _pace
	set_time(minf(t, DURATION))
	if t >= DURATION:
		_finish()


func _finish() -> void:
	active = false
	set_process(false)
	visible = false
	completed.emit()


func _fire(key: Variant, kind: StringName) -> void:
	if _fired.has(key):
		return
	_fired[key] = true
	beat.emit(kind)


## 한 시계로 그린다 (t: 0~DURATION초, 배율 전).
func set_time(t: float) -> void:
	_time_view = t
	if t >= 0.0:
		_fire("wind", &"wind")
	for index: int in BOLT_TIMES.size():
		if t >= BOLT_TIMES[index]:
			_fire("bolt%d" % index, &"bolt")
	if t >= CLIMAX_AT:
		_fire("climax", &"climax")
	if t >= CLEAR_AT:
		_fire("cleared", &"cleared")
	queue_redraw()


## 번호 하나로 0~1 값을 정하는 가짜 난수 (시뮬레이션 RNG를 쓰지 않는다).
static func _hash(index: int, salt: int) -> float:
	return fposmod(sin(float(index * 127 + salt * 311) * 12.9898) * 43758.5453, 1.0)


static func _ramp(t: float, start: float, end: float) -> float:
	return clampf((t - start) / maxf(end - start, 0.001), 0.0, 1.0)


static func _ease_out(x: float) -> float:
	return 1.0 - pow(1.0 - x, 3.0)


func _draw() -> void:
	var t: float = _time_view
	var view: Vector2 = size if size.x > 2.0 else get_viewport_rect().size
	var dark: float = _ramp(t, 0.0, 0.5) * (1.0 - _ramp(t, CLEAR_AT, DURATION))
	draw_rect(Rect2(Vector2.ZERO, view), Color(0.05, 0.07, 0.15, 0.62 * dark))
	var grow: float = _ease_out(_ramp(t, 0.1, CLIMAX_AT))
	var fade: float = 1.0 - _ramp(t, CLEAR_AT - 0.1, DURATION)
	var reach: float = lerpf(60.0, maxf(view.x, view.y) * 0.62, grow)
	var spin: float = t * 5.2 + grow * 3.0
	# 폭풍의 눈 주변의 어두운 원 + 바깥으로 번지는 구름 고리
	draw_circle(center, reach * 0.45, Color(0.02, 0.03, 0.08, 0.35 * dark))
	for ring: int in 3:
		draw_arc(center, reach * (0.55 + 0.22 * float(ring)), 0.0, TAU, 64, Color(0.75, 0.85, 1.0, (0.10 - 0.025 * float(ring)) * fade * grow), 10.0 - 2.0 * float(ring), true)
	# 소용돌이 바람 줄기: 일곱 가닥이 안에서 밖으로 휘감아 돈다 (굵기는 바깥으로 갈수록 가늘다)
	for arm: int in ARMS:
		var base: float = TAU * float(arm) / float(ARMS) + spin
		var points := PackedVector2Array()
		for k: int in ARM_POINTS:
			var u: float = float(k) / float(ARM_POINTS - 1)
			var radius: float = reach * u
			var angle: float = base + u * 3.6 + sin(t * 3.0 + float(arm)) * 0.12
			points.append(center + Vector2.from_angle(angle) * radius)
		var a: float = (0.55 - 0.04 * float(arm % 3)) * fade * grow
		draw_polyline(points, Color(0.86, 0.93, 1.0, a), 7.0, true)
		draw_polyline(points, Color(1.0, 1.0, 1.0, a * 0.8), 2.5, true)
	# 잔해: 나뭇잎·종이 조각이 소용돌이를 타고 바깥으로 날아간다
	for i: int in DEBRIS:
		var life: float = fposmod(t * (0.55 + 0.4 * _hash(i, 1)) + _hash(i, 2), 1.0)
		var radius: float = reach * (0.12 + 0.95 * life)
		var angle: float = spin * (1.0 + 0.5 * _hash(i, 3)) + TAU * _hash(i, 4) + life * 4.0
		var at: Vector2 = center + Vector2.from_angle(angle) * radius
		var size_px: float = 4.0 + 9.0 * _hash(i, 5)
		var tint: Color = Color("ffe14d") if i % 5 == 0 else (Color("8ce99a") if i % 5 == 1 else (Color("f8f9fa") if i % 5 == 2 else Color("ffa8a8")))
		var flutter: float = angle * 2.0
		var quad := PackedVector2Array([at + Vector2.from_angle(flutter) * size_px, at + Vector2.from_angle(flutter + 2.1) * size_px * 0.6,
			at + Vector2.from_angle(flutter + PI) * size_px, at + Vector2.from_angle(flutter + 4.2) * size_px * 0.6])
		draw_colored_polygon(quad, Color(tint, clampf(grow * 1.4, 0.0, 1.0) * fade * (1.0 - life * 0.5)))
	# 번개: 하늘에서 눈으로 갈라져 꽂힌다
	for index: int in BOLT_TIMES.size():
		var since: float = t - BOLT_TIMES[index]
		if since < 0.0 or since > 0.16:
			continue
		var k: float = 1.0 - since / 0.16
		var x: float = view.x * (0.25 + 0.5 * _hash(index, 7))
		var bolt := PackedVector2Array()
		for step: int in 9:
			var u: float = float(step) / 8.0
			var target: Vector2 = Vector2(lerpf(x, center.x, u), lerpf(-20.0, center.y, u))
			bolt.append(target + Vector2((_hash(index * 10 + step, 8) - 0.5) * 70.0 * (1.0 - u * 0.4), 0.0))
		draw_polyline(bolt, Color(0.75, 0.85, 1.0, 0.8 * k), 14.0, true)
		draw_polyline(bolt, Color(1, 1, 1, k), 5.0, true)
		draw_rect(Rect2(Vector2.ZERO, view), Color(1, 1, 1, 0.22 * k))
	# 절정: 흰 섬광이 크게 터지고 서서히 걷힌다
	var flash: float = 1.0 - _ramp(t, CLIMAX_AT, CLIMAX_AT + 0.45)
	if t >= CLIMAX_AT and flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, view), Color(1, 1, 1, 0.85 * flash))
		draw_circle(center, reach * 0.3 * (1.0 + (1.0 - flash)), Color(1, 1, 1, 0.5 * flash))
