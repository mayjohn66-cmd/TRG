# File: res://scenes/cauldron_brew_view.gd
# Class: class_name CauldronBrewView
# Role: 벨라티엔 왕국 마녀의 가마솥 연출 그림 (임시 2D 그림). 보라 가마솥이 물약 색으로 보글보글 끓다가 펑 하고 물약 병이 솟아오른다.
#       연출만 담당한다: 시간(t, 초)을 받아 그린다. 나쁜 물약이면 연기가 검게 피어오른다.
class_name CauldronBrewView
extends Control

const BREW_TIME: float = 1.25  # 이때 물약 병이 솟는다
var potion_color: Color = Color("7fd18b")
var good: bool = true
var t: float = 0.0
## 연출 속도 배율 (보드의 _motion_pace): 이름·효과 글자가 뜨는 시간과 맞춘다.
var pace: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func play(color: Color, is_good: bool, motion_pace: float = 1.0) -> void:
	pace = maxf(motion_pace, 0.01)
	potion_color = color
	good = is_good
	t = 0.0
	set_process(true)


func _process(delta: float) -> void:
	t += delta / pace
	queue_redraw()


func _draw() -> void:
	var c: Vector2 = Vector2(size.x * 0.5, size.y * 0.66)
	var w: float = minf(size.x * 0.62, 300.0)
	var pot := Color("3e2366")
	var rim := Color("6b4a8f")
	# 불꽃 (갈색 장작 + 주황 불)
	draw_rect(Rect2(c + Vector2(-w * 0.32, w * 0.36), Vector2(w * 0.64, w * 0.08)), Color("7a5232"))
	for i: int in 5:
		var fx: float = c.x - w * 0.24 + i * w * 0.12
		var flick: float = 0.75 + 0.25 * sin(t * 14.0 + i * 1.7)
		draw_colored_polygon(PackedVector2Array([Vector2(fx - w * 0.05, c.y + w * 0.37), Vector2(fx + w * 0.05, c.y + w * 0.37), Vector2(fx, c.y + w * (0.37 - 0.16 * flick))]), Color("ff922b"))
	# 솥 몸통
	draw_circle(c, w * 0.42, pot)
	draw_rect(Rect2(c + Vector2(-w * 0.52, -w * 0.30), Vector2(w * 1.04, w * 0.14)), rim)
	# 물약 수면 (끓을수록 차오름)
	var level: float = clampf(t / BREW_TIME, 0.0, 1.0)
	var surface := Rect2(c + Vector2(-w * 0.44, -w * 0.30), Vector2(w * 0.88, w * 0.07))
	draw_rect(surface, potion_color.darkened(0.25 * (1.0 - level)))
	# 거품
	for i: int in 9:
		var phase: float = fmod(t * (0.9 + 0.13 * i) + i * 0.37, 1.0)
		var bx: float = c.x - w * 0.36 + fmod(i * 0.29, 1.0) * w * 0.72
		var by: float = c.y - w * 0.30 - phase * w * (0.25 + 0.35 * level)
		var br: float = w * (0.02 + 0.03 * fmod(i * 0.53, 1.0)) * (1.0 - phase * 0.4)
		draw_circle(Vector2(bx, by), br, Color(potion_color.lightened(0.2), 1.0 - phase))
	# 나쁜 물약: 검은 연기
	if not good and t > BREW_TIME * 0.6:
		for i: int in 6:
			var age: float = fmod(t * 0.8 + i * 0.17, 1.0)
			draw_circle(c + Vector2((i - 2.5) * w * 0.08, -w * (0.4 + age * 0.6)), w * (0.05 + age * 0.08), Color(0.12, 0.08, 0.16, 0.55 * (1.0 - age)))
	# 물약 병이 솟아오른다
	if t >= BREW_TIME:
		var rise: float = clampf((t - BREW_TIME) / 0.35, 0.0, 1.0)
		var eased: float = 1.0 - pow(1.0 - rise, 3.0)
		var bottle_c: Vector2 = c + Vector2(0, -w * (0.3 + 0.55 * eased))
		var r: float = w * 0.13
		draw_circle(bottle_c, r * 1.15, Color(1, 1, 1, 0.25 * eased))  # 빛
		draw_circle(bottle_c, r, potion_color)
		draw_arc(bottle_c, r, 0.0, TAU, 32, Color("2a173f"), 4.0, true)
		draw_rect(Rect2(bottle_c + Vector2(-r * 0.32, -r * 1.55), Vector2(r * 0.64, r * 0.62)), Color("e9ddf7"))
		draw_rect(Rect2(bottle_c + Vector2(-r * 0.4, -r * 1.75), Vector2(r * 0.8, r * 0.26)), Color("8a5a34"))
