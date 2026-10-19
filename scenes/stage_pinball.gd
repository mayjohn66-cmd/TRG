# File: res://scenes/stage_pinball.gd
# Class: class_name PinballStage
# Role: 클래식 구슬 핀볼의 중앙 오픈 스테이지. 오른쪽 스프링 발사대, 상단 아치 레일, 지그재그 못(Peg), 하단 숫자 구멍 7칸 [2][4][6][★10][5][3][1]을 그린다. 발사 버튼을 꾹 누르는 동안 스프링이 당겨지고(set_pull), 놓으면 구슬이 레일을 타고 올라가 못에 튕기며 내려와 엔진이 정한 구멍에 들어간다. 연출만 담당한다
class_name PinballStage
extends Control

const STAGE_SIZE: Vector2 = Vector2(340.0, 400.0)
const FIELD_LEFT: float = 26.0
const FIELD_RIGHT: float = 258.0
const LANE_X: float = 294.0
const ARCH_CENTER: Vector2 = Vector2(172.0, 172.0)
const ARCH_RADIUS: float = 124.0
const PEG_ROWS: int = 6
const PEG_TOP: float = 206.0
const PEG_GAP: float = 22.0
const HOLE_Y: float = 356.0
const FALL_SECONDS: float = 1.0
const ARCH_SECONDS: float = 0.5

var pull: float = 0.0
var active: bool = false
var instant: bool = false
var last_hole: int = -1
var _ball: Vector2 = Vector2(LANE_X, 350.0)
var _ball_in_play: bool = false
var _highlight: int = -1


func _init() -> void:
	custom_minimum_size = STAGE_SIZE
	size = STAGE_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## 발사대 스프링을 당긴 정도 (0~1). 발사 버튼을 꾹 누르는 동안 파워 게이지 값이 들어온다.
func set_pull(value: float) -> void:
	pull = clampf(value, 0.0, 1.0)
	if not active:
		_ball = Vector2(LANE_X, 350.0 + pull * 20.0)
	queue_redraw()


## 새 차례에 처음 모습으로 돌린다.
func reset() -> void:
	active = false
	_ball_in_play = false
	_highlight = -1
	last_hole = -1
	pull = 0.0
	_ball = Vector2(LANE_X, 350.0)
	queue_redraw()


func hole_center(hole: int) -> Vector2:
	var width: float = (FIELD_RIGHT - FIELD_LEFT) / float(ToolPinball.HOLES.size())
	return Vector2(FIELD_LEFT + width * (float(hole) + 0.5), HOLE_Y + 14.0)


## 엔진 결과(RollResult.to_dict())를 구슬 낙하 연출로 보여 준다. power(0~1)는 발사 세기: 셀수록 빨리 솟구친다. 구슬은 언제나 엔진이 정한 구멍에 들어간다.
func play(result: Dictionary, power: float = 0.5) -> void:
	var details: Dictionary = result["details"]
	var hole: int = int(details["hole"])
	var bounces: Array = details["bounces"]
	var target: Vector2 = hole_center(hole)
	if instant or not is_inside_tree():
		_ball = target
		_ball_in_play = true
		_highlight = hole
		last_hole = hole
		pull = 0.0
		queue_redraw()
		return
	active = true
	_highlight = -1
	_ball_in_play = true
	pull = 0.0
	# 1) 발사대에서 레일을 타고 위로 솟구친다 (세게 쏠수록 빠르다)
	var rise_seconds: float = lerpf(0.85, 0.45, clampf(power, 0.0, 1.0))
	await _move(Vector2(LANE_X, 350.0), Vector2(LANE_X, ARCH_CENTER.y), rise_seconds, 0.0, true)
	# 2) 상단 아치를 돌아 왼쪽 위로
	var arch: Tween = create_tween()
	arch.tween_method(_arch_step, 0.0, 1.0, ARCH_SECONDS).set_trans(Tween.TRANS_SINE)
	await arch.finished
	if not is_inside_tree():
		return
	# 3) 못에 통! 통! 통! 튕기며 내려와 구멍에 들어간다 (약 1초)
	var points: Array[Vector2] = _fall_points(target, bounces)
	var per_segment: float = FALL_SECONDS / float(points.size())
	var from: Vector2 = _ball
	for index: int in points.size():
		var last: bool = index == points.size() - 1
		await _move(from, points[index], per_segment, 0.0 if last else 7.0, false)
		if not is_inside_tree():
			return
		if not last:
			Sfx.play(&"hop", -9.0, 0.08, 1.5 + 0.06 * float(index))
		from = points[index]
	_highlight = hole
	last_hole = hole
	Sfx.play(&"good", -6.0, 0.0)
	queue_redraw()
	await get_tree().create_timer(0.35).timeout
	active = false


## 아치 시작점(오른쪽)에서 위를 돌아 왼쪽까지 반원을 그린다.
func _arch_step(t: float) -> void:
	var angle: float = -PI * t
	_ball = ARCH_CENTER + Vector2(cos(angle), sin(angle)) * ARCH_RADIUS
	queue_redraw()


## 구슬 한 구간 이동. lift는 위로 튀는 높이(못에 튕기는 느낌).
func _move(from: Vector2, to: Vector2, seconds: float, lift: float, ease_out: bool) -> void:
	var tween: Tween = create_tween()
	var step: Callable = func(t: float) -> void:
		_ball = from.lerp(to, t) + Vector2(0.0, -lift * sin(PI * t))
		queue_redraw()
	var motion: MethodTweener = tween.tween_method(step, 0.0, 1.0, maxf(seconds, 0.01))
	if ease_out:
		motion.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await tween.finished


## 왼쪽 위에서 시작해 목표 구멍까지 가면서 좌우로 튕기는 지점들 (엔진이 정한 bounces로 모든 화면에서 똑같다). 마지막은 구멍 안.
func _fall_points(target: Vector2, bounces: Array) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var start_x: float = ARCH_CENTER.x - ARCH_RADIUS
	for row: int in PEG_ROWS:
		var progress: float = float(row + 1) / float(PEG_ROWS + 1)
		var direction: float = 1.0 if int(bounces[row % bounces.size()]) == 1 else -1.0
		var swing: float = 16.0 * (1.0 - progress)
		var x: float = clampf(lerpf(start_x, target.x, progress) + direction * swing, FIELD_LEFT + 8.0, FIELD_RIGHT - 8.0)
		points.append(Vector2(x, PEG_TOP + PEG_GAP * float(row) - 8.0))
	points.append(target)
	return points


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	# 몸체와 상단 아치
	var body := StyleBoxFlat.new()
	body.bg_color = Color("f1d9a3")
	body.border_color = Color("8a5a2b")
	body.set_border_width_all(8)
	body.corner_radius_top_left = 160
	body.corner_radius_top_right = 160
	body.corner_radius_bottom_left = 26
	body.corner_radius_bottom_right = 26
	body.shadow_color = Color(0, 0, 0, 0.4)
	body.shadow_size = 12
	draw_style_box(body, Rect2(Vector2(8.0, 6.0), Vector2(STAGE_SIZE.x - 16.0, STAGE_SIZE.y - 12.0)))
	var field := StyleBoxFlat.new()
	field.bg_color = Color("6fbf8e")
	field.set_corner_radius_all(18)
	field.corner_radius_top_left = 110
	draw_style_box(field, Rect2(Vector2(FIELD_LEFT - 8.0, 62.0), Vector2(FIELD_RIGHT - FIELD_LEFT + 16.0, 328.0)))
	# 발사 레일과 아치 레일
	draw_arc(ARCH_CENTER, ARCH_RADIUS + 12.0, -PI, 0.0, 40, Color("b08b4f"), 5.0)
	draw_line(Vector2(LANE_X - 18.0, ARCH_CENTER.y), Vector2(LANE_X - 18.0, 372.0), Color("b08b4f"), 5.0)
	draw_line(Vector2(LANE_X + 18.0, ARCH_CENTER.y), Vector2(LANE_X + 18.0, 392.0), Color("b08b4f"), 5.0)
	# 못
	for row: int in PEG_ROWS:
		var columns: int = 6 if row % 2 == 0 else 5
		var offset: float = 0.0 if row % 2 == 0 else 20.0
		for column: int in columns:
			var peg := Vector2(FIELD_LEFT + 10.0 + offset + 40.0 * float(column), PEG_TOP + PEG_GAP * float(row))
			draw_circle(peg, 5.5, Color("e9ecef"))
			draw_arc(peg, 5.5, 0.0, TAU, 12, Color("495057"), 1.5)
	# 하단 숫자 구멍 7칸
	var hole_width: float = (FIELD_RIGHT - FIELD_LEFT) / float(ToolPinball.HOLES.size())
	for hole: int in ToolPinball.HOLES.size():
		var rect := Rect2(Vector2(FIELD_LEFT + hole_width * float(hole) + 2.0, HOLE_Y), Vector2(hole_width - 4.0, 36.0))
		var star: bool = ToolPinball.HOLES[hole] == 10
		var lit: bool = hole == _highlight
		var slot := StyleBoxFlat.new()
		slot.bg_color = Color("ffd43b") if lit else (Color("7a2e8f") if star else Color("1c2433"))
		slot.border_color = Color("fff3bf") if lit or star else Color("495057")
		slot.set_border_width_all(3)
		slot.set_corner_radius_all(8)
		draw_style_box(slot, rect)
		var text: String = "★10" if star else str(ToolPinball.HOLES[hole])
		draw_string(font, rect.position + Vector2(0.0, 24.0), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 12 if star else 20, Color("231600") if lit else Color("f8f9fa"))
	# 스프링 발사대 (당길수록 줄어든다)
	var spring_top: float = 370.0 + pull * 18.0
	var spring_bottom: float = 392.0
	var zig: int = 6
	for i: int in zig:
		var y0: float = lerpf(spring_top, spring_bottom, float(i) / float(zig))
		var y1: float = lerpf(spring_top, spring_bottom, float(i + 1) / float(zig))
		draw_line(Vector2(LANE_X - 11.0 if i % 2 == 0 else LANE_X + 11.0, y0), Vector2(LANE_X + 11.0 if i % 2 == 0 else LANE_X - 11.0, y1), Color("868e96"), 3.0)
	draw_rect(Rect2(Vector2(LANE_X - 14.0, spring_top - 8.0), Vector2(28.0, 8.0)), Color("e03131"))
	# 구슬
	if _ball_in_play or not active:
		draw_circle(_ball + Vector2(1.5, 2.5), 10.0, Color(0, 0, 0, 0.25))
		draw_circle(_ball, 10.0, Color("adb5bd"))
		draw_circle(_ball + Vector2(-3.0, -3.5), 4.0, Color("f8f9fa"))
