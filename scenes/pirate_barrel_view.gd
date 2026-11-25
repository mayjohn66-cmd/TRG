## 해적 룰렛 연출 (임시 2D 그림): 통에 칼 하나가 미끄러져 꽂히고, 해적 구멍이면 해적이 빙글빙글 튀어 오른다.
## 이전에 꽂은 칼은 그대로 꽂혀 있다 (details.holes = 꽂은 구멍 순서, 마지막이 이번 칼).
class_name PirateBarrelView
extends Control

const SIZE := Vector2(420, 300)
const STAB_END := 0.42
const THUNK_END := 0.62
const POP_AT := 0.66
const SAFE_TOTAL := 1.05
const POP_TOTAL := 1.75
const WOOD := Color("c4803f")
const WOOD_DARK := Color("6e3e1c")
const HOLE := Color("462814")
const BLADE := Color("e4e8f0")
const HILTS: Array[Color] = [Color("e64646"), Color("468ce6"), Color("f2c83c"), Color("46b46e"), Color("b464dc"), Color("f08c3c"), Color("3cc8c8"), Color("e66ea0")]
## 구멍 8개의 자리 (통 앞면 두 줄, 통 왼쪽 위 기준 비율).
const HOLES: Array[Vector2] = [Vector2(0.16, 0.34), Vector2(0.39, 0.30), Vector2(0.61, 0.30), Vector2(0.84, 0.34), Vector2(0.16, 0.72), Vector2(0.39, 0.70), Vector2(0.61, 0.70), Vector2(0.84, 0.72)]
const BARREL := Rect2(120, 120, 180, 150)

var settled := false
var total_time := SAFE_TOTAL
var _holes: Array = []
var _popped := false
var _time := 0.0


func _init() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func begin(details: Dictionary) -> void:
	_holes = (details.get("holes", []) as Array).duplicate()
	_popped = bool(details.get("popped", false))
	total_time = POP_TOTAL if _popped else SAFE_TOTAL
	apply_time(0.0)


static func caption(details: Dictionary, steps: int, can_continue: bool = false) -> String:
	return ToolPirateRoulette.caption(details, steps, can_continue)


func apply_time(t: float) -> void:
	_time = t
	settled = t >= (POP_AT + 0.45 if _popped else THUNK_END)
	queue_redraw()


func _hole_at(index: int) -> Vector2:
	var spot: Vector2 = HOLES[clampi(index, 0, HOLES.size() - 1)]
	return BARREL.position + spot * BARREL.size


func _draw() -> void:
	var shake := 0.0
	if _time > STAB_END and _time < THUNK_END:
		shake = sin(_time * 90.0) * 3.0 * (1.0 - inverse_lerp(STAB_END, THUNK_END, _time))
	if _popped and _time >= POP_AT:
		shake += sin(_time * 70.0) * 4.0 * maxf(0.0, 1.0 - (_time - POP_AT) * 2.5)
	var offset := Vector2(shake, 0.0)
	_draw_pirate(offset)
	# 통
	var body := Rect2(BARREL.position + offset, BARREL.size)
	draw_style_box(_rounded(WOOD, WOOD_DARK, 28), body)
	for band: float in [0.15, 0.53, 0.9]:
		var y := body.position.y + body.size.y * band
		draw_line(Vector2(body.position.x + 6, y), Vector2(body.end.x - 6, y), WOOD_DARK, 7.0)
	for index: int in HOLES.size():
		var at := _hole_at(index) + offset
		draw_circle(at, 11.0, HOLE)
	# 꽂힌 칼: 이전 칼은 그대로, 마지막 칼은 밖에서 미끄러져 들어온다
	for order: int in _holes.size():
		var newest: bool = order == _holes.size() - 1
		var travel := 1.0 if not newest else smoothstep(0.0, STAB_END, _time)
		_draw_sword(int(_holes[order]), travel, offset, HILTS[order % HILTS.size()])


func _draw_sword(hole: int, travel: float, offset: Vector2, hilt: Color) -> void:
	var at := _hole_at(hole) + offset
	var side := -1.0 if HOLES[hole].x < 0.5 else 1.0
	var direction := Vector2(side, -0.35).normalized()
	var inside := at + direction * lerpf(150.0, 0.0, travel)
	var blade_end := inside + direction * 46.0
	draw_line(inside - direction * 6.0, blade_end, BLADE, 7.0)
	var guard := blade_end
	var normal := Vector2(-direction.y, direction.x)
	draw_line(guard - normal * 13.0, guard + normal * 13.0, hilt, 7.0)
	draw_line(guard, guard + direction * 24.0, hilt, 9.0)
	draw_circle(guard + direction * 26.0, 6.0, hilt.darkened(0.2))


func _draw_pirate(offset: Vector2) -> void:
	var head := Vector2(BARREL.get_center().x, BARREL.position.y - 18.0) + offset
	var spin := 0.0
	if _popped and _time >= POP_AT:
		var flight := clampf((_time - POP_AT) / (POP_TOTAL - POP_AT - 0.2), 0.0, 1.0)
		head += Vector2(sin(flight * PI) * 70.0, -sin(flight * PI * 0.5) * 72.0)  # 그림 칸 안에서 튀어 오른다
		spin = flight * TAU * 2.0  # 두 바퀴 돌고 똑바로 멈춘다
	draw_set_transform(head, spin, Vector2.ONE)
	draw_circle(Vector2.ZERO, 34.0, Color("ffd6b4"))
	draw_arc(Vector2.ZERO, 34.0, 0, TAU, 40, WOOD_DARK, 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-46, -18), Vector2(46, -18), Vector2(30, -52), Vector2(-30, -52)]), Color("282830"))
	draw_circle(Vector2(0, -38), 6.0, Color.WHITE)
	draw_circle(Vector2(-12, 2), 4.5, Color("281e1e"))
	draw_circle(Vector2(14, 0), 9.0, Color("1e1e1e"))
	draw_line(Vector2(2, -6), Vector2(32, -16), Color("1e1e1e"), 3.0)
	if _popped and _time >= POP_AT:
		draw_arc(Vector2(0, 16), 10.0, 0, TAU, 20, Color("782828"), 4.0)  # 놀란 입
	else:
		draw_arc(Vector2(0, 10), 13.0, 0.3, PI - 0.3, 12, Color("782828"), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _rounded(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(6)
	box.set_corner_radius_all(radius)
	return box

