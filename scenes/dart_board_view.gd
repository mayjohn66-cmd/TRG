## 불스아이 다트 보드 (v1.1): 돌아가는 다트판 그림. 두 가지로 쓴다.
## 조준(aiming=true): 판이 돌고, 12시 방향 조준선 위를 조준점이 중심↔바깥으로 오간다. [던지기] 순간의 current_aim()을 굴림 행동에 싣는다.
## 결과(begin + apply_time): 판이 멈추고 다트가 날아와 엔진이 정한 자리에 꽂힌다.
class_name DartBoardView
extends Control

const SIZE := Vector2(300, 300)
## 판이 한 바퀴 도는 시간 / 조준점이 중심→끝→중심을 오가는 시간 (초).
const SPIN_PERIOD: float = 2.4
const AIM_PERIOD: float = 1.3
## 결과 연출: 다트가 날아오는 시간 / 끝.
const FLIGHT_TIME: float = 0.45
const TOTAL_TIME: float = 1.5
const DARK := Color("1f1f24")
const LIGHT := Color("f1e3c3")
const RED := Color("e03131")
const GREEN := Color("2f9e44")

var aiming: bool = false
var settled: bool = false
var _spin: float = 0.0
var _aim_radius: float = 0.0
var _clock: float = 0.0
var _hit_radius: float = -1.0
var _hit_angle: float = 0.0
var _t: float = 0.0
var _bull: bool = false
var _font: Font = null


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## 조준 화면을 켜고 끈다.
func set_aiming(on: bool) -> void:
	aiming = on
	_hit_radius = -1.0
	set_process(on)
	queue_redraw()


## 지금 던지면 맞을 자리: [중심에서의 거리 0~1, 판 기준 각도 0~1].
func current_aim() -> Array:
	return [_aim_radius, fposmod(-_spin, 1.0)]


func _process(delta: float) -> void:
	if not aiming:
		return
	_clock += delta
	_spin = fposmod(_clock / SPIN_PERIOD, 1.0)
	_aim_radius = 0.5 - 0.5 * cos(_clock / AIM_PERIOD * TAU)  # 0(중심) ~ 1(끝)을 부드럽게 오간다
	queue_redraw()


## 결과 연출 시작: 판을 멈추고 엔진이 정한 자리에 다트를 꽂는다.
func begin(details: Dictionary) -> void:
	set_aiming(false)
	_spin = 0.0
	_hit_radius = float(details.get("radius", 0.5))
	_hit_angle = float(details.get("angle", 0.0))
	_bull = bool(details.get("bull", false))
	settled = false
	_t = 0.0
	queue_redraw()


func apply_time(t: float) -> void:
	_t = t
	if t >= FLIGHT_TIME:
		settled = true
	queue_redraw()


static func caption(details: Dictionary, steps: int) -> String:
	return ToolDarts.hit_text(details, steps)


func _board_point(radius: float, angle: float) -> Vector2:
	var center: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.46
	var theta: float = (angle + _spin) * TAU - PI * 0.5  # 0 = 12시, 시계 방향
	return center + Vector2(cos(theta), sin(theta)) * radius * r


func _draw() -> void:
	if _font == null:
		_font = get_theme_default_font()
	var center: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.46
	draw_circle(center, r * 1.06, Color("101010"))
	var wedges: int = ToolDarts.WEDGES.size()
	for index: int in wedges:
		var a0: float = (float(index) / wedges + _spin) * TAU - PI * 0.5
		var a1: float = (float(index + 1) / wedges + _spin) * TAU - PI * 0.5
		var base: Color = DARK if index % 2 == 0 else LIGHT
		var ring_color: Color = RED if index % 2 == 0 else GREEN
		_wedge(center, 0.0, 1.0 * r, a0, a1, base)
		_wedge(center, 0.45 * r, 0.56 * r, a0, a1, ring_color)  # 트리플
		_wedge(center, 0.84 * r, 1.0 * r, a0, a1, ring_color)  # 더블
		var mid: float = (a0 + a1) * 0.5
		var label_at: Vector2 = center + Vector2(cos(mid), sin(mid)) * r * 0.70 + Vector2(-6, 7)
		draw_string_outline(_font, label_at, str(ToolDarts.WEDGES[index]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color.BLACK)
		draw_string(_font, label_at, str(ToolDarts.WEDGES[index]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	draw_circle(center, 0.08 * r, RED)
	draw_circle(center, 0.04 * r, GREEN)
	if aiming:
		# 12시 방향 조준선 + 오가는 조준점
		var top: Vector2 = center + Vector2(0, -r * 1.04)
		draw_line(center, top, Color(1, 1, 0.6, 0.35), 2.0, true)
		var aim_point: Vector2 = center + Vector2(0, -r * _aim_radius)
		draw_arc(aim_point, 14.0, 0.0, TAU, 24, Color("ffe066"), 3.0, true)
		draw_line(aim_point + Vector2(-20, 0), aim_point + Vector2(20, 0), Color("ffe066"), 2.0)
		draw_line(aim_point + Vector2(0, -20), aim_point + Vector2(0, 20), Color("ffe066"), 2.0)
	if _hit_radius >= 0.0:
		var spot: Vector2 = _board_point(_hit_radius, _hit_angle)
		var fly: float = clampf(_t / FLIGHT_TIME, 0.0, 1.0)
		var from: Vector2 = Vector2(size.x * 1.2, -size.y * 0.3)
		var dart: Vector2 = from.lerp(spot, 1.0 - pow(1.0 - fly, 3.0))
		var tail: Vector2 = dart + (from - spot).normalized() * 46.0
		draw_line(dart, tail, Color("dee2e6"), 4.0, true)
		draw_colored_polygon(PackedVector2Array([tail, tail + Vector2(14, -10), tail + Vector2(18, 8)]), Color("ff922b"))
		draw_circle(dart, 4.0, Color("adb5bd"))
		if fly >= 1.0:
			var ring: float = clampf((_t - FLIGHT_TIME) / 0.3, 0.0, 1.0)
			draw_arc(spot, lerpf(6.0, 30.0, ring), 0.0, TAU, 24, Color(1, 0.9, 0.3, 1.0 - ring), 3.0, true)
			if _bull:
				draw_arc(center, r * lerpf(0.1, 1.1, ring), 0.0, TAU, 48, Color(1, 0.85, 0.2, 1.0 - ring), 5.0, true)


func _wedge(center: Vector2, inner: float, outer: float, a0: float, a1: float, color: Color) -> void:
	var points := PackedVector2Array()
	var steps: int = 6
	for i: int in steps + 1:
		var a: float = lerpf(a0, a1, float(i) / steps)
		points.append(center + Vector2(cos(a), sin(a)) * outer)
	for i: int in range(steps, -1, -1):
		var a: float = lerpf(a0, a1, float(i) / steps)
		points.append(center + Vector2(cos(a), sin(a)) * inner)
	if inner <= 0.0:
		points = PackedVector2Array([center]) + points.slice(0, steps + 1)
	draw_colored_polygon(points, color)
