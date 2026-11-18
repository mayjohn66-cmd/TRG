## 포츈쿠키 연출 (임시 2D 그림): 쿠키가 통통 떨어져 흔들리다가 쩍 갈라지고, 안에서 종이가 나와 펼쳐지며 몇 칸 전진할지 보여 준다.
## 규칙 엔진이 이미 정한 결과를 그릴 뿐이다. 최종 그림이 오면 _draw_cookie_half / _draw_paper만 바꾸면 된다.
class_name FortuneCookieView
extends Control

const SIZE := Vector2(420, 300)
const DROP_END := 0.40
const WOBBLE_END := 1.00
const CRACK_AT := 1.02
const UNFOLD_AT := 1.45
const REVEAL_AT := 1.95
const TOTAL_TIME := 2.60
const INK := Color("5a3a1a")
const GOLD := Color("e8b25a")
const GOLD_DARK := Color("b9812f")
const GOLD_LIGHT := Color("f6d38d")
const PAPER := Color("fffaf0")
const RED := Color("c2342f")
const FONT: Font = preload("res://assets/fonts/game_ui_font.tres")

var settled := false
var _t := 0.0
var _message := ""
var _steps := 3
var _lucky := 7
var _jackpot := false


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func begin(details: Dictionary, _kept: int = 0) -> void:
	_message = str(details.get("message", ""))
	_steps = int(details.get("steps", 3))
	_lucky = int(details.get("lucky", 7))
	_jackpot = bool(details.get("jackpot", false))
	apply_time(0.0)


func set_steps(steps: int) -> void:
	_steps = steps


static func caption(details: Dictionary, steps: int) -> String:
	return ToolFortuneCookie.caption(details, steps)


func apply_time(t: float) -> void:
	_t = t
	settled = t >= REVEAL_AT
	queue_redraw()


func _draw() -> void:
	var center := Vector2(SIZE.x * 0.5, 168.0)
	# 바닥 그림자
	draw_set_transform(center + Vector2(0, 88), 0.0, Vector2(1.0, 0.24))
	draw_circle(Vector2.ZERO, 96.0, Color(0.19, 0.10, 0.04, 0.22), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	var drop := ease(clampf(_t / DROP_END, 0.0, 1.0), 0.36)
	var bounce := absf(sin(clampf(_t / DROP_END, 0.0, 1.0) * PI * 1.5)) * (1.0 - clampf(_t / DROP_END, 0.0, 1.0)) * 26.0
	var wobble := clampf(inverse_lerp(DROP_END, WOBBLE_END, _t), 0.0, 1.0)
	var shake := sin(wobble * TAU * 4.0) * sin(wobble * PI) * 0.16
	var cracked := clampf((_t - CRACK_AT) / 0.34, 0.0, 1.0)
	var at := center + Vector2(0, -(1.0 - drop) * 120.0 - bounce)
	if _t < CRACK_AT:
		var squash := 1.0 + 0.05 * sin(wobble * TAU * 6.0) * wobble
		draw_set_transform(at, shake, Vector2(1.0 / squash, squash))
		_draw_cookie_half(0.0, 1.0)
		_draw_cookie_half(0.0, -1.0)
		draw_set_transform(Vector2.ZERO)
	else:
		var spread := ease(cracked, 0.4)
		draw_set_transform(at + Vector2(-52.0 * spread, 12.0 * spread), -0.6 * spread, Vector2.ONE)
		_draw_cookie_half(0.0, 1.0)
		draw_set_transform(at + Vector2(52.0 * spread, 12.0 * spread), 0.6 * spread, Vector2.ONE)
		_draw_cookie_half(0.0, -1.0)
		draw_set_transform(Vector2.ZERO)
		_draw_sparkles(at, cracked)
		_draw_paper(at)
	if settled:
		var glow := clampf((_t - REVEAL_AT) / 0.4, 0.0, 1.0)
		_draw_burst(Vector2(SIZE.x * 0.5, 120.0), glow)


## 쿠키 반쪽 (side 1 = 왼쪽, -1 = 오른쪽): 접힌 반달 쿠키의 한쪽 (가로로 넓은 타원의 반쪽 + 접힌 주름).
func _draw_cookie_half(_unused: float, side: float) -> void:
	var rx: float = 66.0
	var ry: float = 44.0
	var dir: float = -side  # 왼쪽 반쪽은 x가 음수
	var points := PackedVector2Array()
	for i: int in 25:
		var a: float = -PI * 0.5 + float(i) / 24.0 * PI
		points.append(Vector2(cos(a) * rx * dir, sin(a) * ry))
	var outline := PackedVector2Array(points)
	draw_colored_polygon(points, GOLD)
	draw_polyline(outline, GOLD_DARK, 3.0, true)
	draw_line(Vector2(0, -ry), Vector2(0, ry), GOLD_DARK, 2.0, true)
	# 접힌 쿠키의 주름(안쪽으로 파인 그림자)과 윗면 반짝임
	draw_arc(Vector2(dir * 10.0, 14.0), 30.0, 0.15 * PI, 0.85 * PI, 14, GOLD_DARK, 3.0, true)
	draw_arc(Vector2(dir * 30.0, -8.0), 22.0, PI * 1.05, PI * 1.55, 12, GOLD_LIGHT, 3.0, true)


func _draw_sparkles(at: Vector2, k: float) -> void:
	if k >= 1.0:
		return
	var light := Color("fff3bf")
	light.a = 1.0 - k
	for i: int in 8:
		var dir := Vector2.from_angle(i * TAU / 8.0 + 0.3)
		draw_line(at + dir * (30.0 + 40.0 * k), at + dir * (44.0 + 52.0 * k), light, 3.0, true)


## 종이: 쿠키 속에서 위로 올라와 펼쳐진다. 접힌 띠(가로로 좁음) -> 활짝 펼친 종이(글자가 보임).
func _draw_paper(at: Vector2) -> void:
	var rise := ease(clampf((_t - CRACK_AT - 0.1) / 0.4, 0.0, 1.0), 0.4)
	if rise <= 0.0:
		return
	var open := ease(clampf((_t - UNFOLD_AT) / 0.5, 0.0, 1.0), 0.4)
	var width := lerpf(34.0, 214.0, open)
	var height := lerpf(36.0, 150.0, open)
	var origin := at + Vector2(0, lerpf(0.0, -62.0, rise)) + Vector2(0, -height * 0.5 * open)
	var rect := Rect2(origin - Vector2(width * 0.5, height * 0.5), Vector2(width, height))
	draw_set_transform(origin, lerpf(0.0, -0.05, open), Vector2.ONE)
	rect = Rect2(-Vector2(width * 0.5, height * 0.5), Vector2(width, height))
	draw_rect(Rect2(rect.position + Vector2(3, 5), rect.size), Color(0.14, 0.08, 0.04, 0.25))
	draw_rect(rect, PAPER)
	draw_rect(rect, INK, false, 2.0)
	if open > 0.55:
		var alpha := clampf((open - 0.55) / 0.45, 0.0, 1.0)
		_text(L10n.t("행운의 종이"), Vector2(0, rect.position.y + 20.0), 13, Color(RED, alpha), width - 16.0)
		_text(L10n.t(_message), Vector2(0, rect.position.y + 46.0), 14, Color(INK, alpha), width - 20.0)
		_text(L10n.t("%d칸 전진!") % _steps, Vector2(0, rect.position.y + height * 0.62), 34 if not _jackpot else 38, Color(RED if not _jackpot else Color("d9480f"), alpha), width - 24.0)
		_text(L10n.t("행운의 숫자 %02d") % _lucky, Vector2(0, rect.position.y + height - 14.0), 11, Color(0.45, 0.32, 0.18, alpha), width - 16.0)
	draw_set_transform(Vector2.ZERO)


func _draw_burst(at: Vector2, k: float) -> void:
	if k >= 1.0:
		return
	var rays := 10 if _jackpot else 6
	var light := Color("ffd46b") if _jackpot else Color("ffe9a6")
	light.a = (1.0 - k) * 0.85
	for i: int in rays:
		var dir := Vector2.from_angle(i * TAU / rays - 0.3)
		var from := at + dir * Vector2(118.0 + 12.0 * k, 92.0 + 10.0 * k)
		draw_line(from, from + dir * (8.0 + 10.0 * (1.0 - k)), light, 3.0, true)


func _text(value: String, at: Vector2, px: int, color: Color, max_width: float = INF) -> void:
	var width := FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if width > max_width:
		px = maxi(1, floori(px * max_width / width))
		width = FONT.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var baseline := (FONT.get_ascent(px) - FONT.get_descent(px)) * 0.5
	draw_string(FONT, at + Vector2(-width * 0.5, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
