# File: res://scenes/emote_face.gd
# Class: class_name EmoteFace
# Role: 감정 표현(이모트) 얼굴 아이콘을 코드로 그린다 (게임 글꼴에 이모지가 없어 웹에서 깨지므로). face: joy(기쁨) / flustered(당황) / sad(슬픔)
class_name EmoteFace
extends Control

const INK: Color = Color("3b2a18")
const SKIN: Color = Color("ffd43b")
const SKIN_EDGE: Color = Color("e67700")
const TEAR: Color = Color("74c0fc")

var face: StringName = &"joy"


func _init(kind: StringName = &"joy", extent: float = 40.0) -> void:
	face = kind
	custom_minimum_size = Vector2(extent, extent)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r: float = minf(size.x, size.y) * 0.5 - 2.0
	var c: Vector2 = size / 2.0
	var fill: Color = SKIN
	match face:
		&"flustered": fill = Color("ffe8a3")
		&"sad": fill = Color("c5d6e8")
	draw_circle(c, r, SKIN_EDGE)
	draw_circle(c, r - 2.5, fill)
	var eye_y: float = c.y - r * 0.18
	var ex: float = r * 0.36
	var w: float = maxf(r * 0.1, 2.0)
	match face:
		&"joy":
			# 웃는 눈(^ ^) + 크게 벌린 입 + 볼터치
			for side: float in [-1.0, 1.0]:
				draw_polyline(PackedVector2Array([Vector2(c.x + side * ex - r * 0.16, eye_y + r * 0.04), Vector2(c.x + side * ex, eye_y - r * 0.14), Vector2(c.x + side * ex + r * 0.16, eye_y + r * 0.04)]), INK, w, true)
				draw_circle(Vector2(c.x + side * r * 0.6, c.y + r * 0.2), r * 0.13, Color(1, 0.45, 0.55, 0.6))
			var mouth := PackedVector2Array()
			for i: int in 9:
				var a: float = PI * float(i) / 8.0
				mouth.append(c + Vector2(cos(a) * r * 0.44, r * 0.1 + sin(a) * r * 0.46))
			draw_colored_polygon(mouth, Color("862e2e"))
		&"flustered":
			# 동그랗게 뜬 눈 + 꼬불꼬불한 입 + 식은땀
			for side: float in [-1.0, 1.0]:
				draw_circle(Vector2(c.x + side * ex, eye_y), r * 0.17, Color.WHITE)
				draw_arc(Vector2(c.x + side * ex, eye_y), r * 0.17, 0.0, TAU, 16, INK, w * 0.6, true)
				draw_circle(Vector2(c.x + side * ex, eye_y), r * 0.07, INK)
			var wave := PackedVector2Array()
			for i: int in 9:
				var t: float = float(i) / 8.0
				wave.append(c + Vector2(lerpf(-r * 0.36, r * 0.36, t), r * 0.42 + sin(t * TAU * 1.5) * r * 0.07))
			draw_polyline(wave, INK, w, true)
			var drop: Vector2 = c + Vector2(r * 0.72, -r * 0.5)
			draw_colored_polygon(PackedVector2Array([drop + Vector2(0, -r * 0.3), drop + Vector2(r * 0.14, 0), drop + Vector2(-r * 0.14, 0)]), TEAR)
			draw_circle(drop, r * 0.14, TEAR)
		&"sad":
			# 처진 눈썹 + 감은 눈에서 흐르는 눈물 + 처진 입
			for side: float in [-1.0, 1.0]:
				draw_line(Vector2(c.x + side * (ex - r * 0.16), eye_y - r * 0.32), Vector2(c.x + side * (ex + r * 0.16), eye_y - r * 0.2), INK, w * 0.8, true)
				draw_line(Vector2(c.x + side * (ex - r * 0.14), eye_y), Vector2(c.x + side * (ex + r * 0.14), eye_y), INK, w, true)
				draw_rect(Rect2(Vector2(c.x + side * ex - r * 0.07, eye_y + r * 0.04), Vector2(r * 0.14, r * 0.6)), TEAR)
			draw_arc(c + Vector2(0, r * 0.66), r * 0.3, PI + 0.4, TAU - 0.4, 12, INK, w, true)
