# File: res://scenes/emote_face.gd
# Class: class_name EmoteFace
# Role: 감정 표현(이모트) 얼굴 아이콘을 코드로 그린다 (게임 글꼴에 이모지가 없어 웹에서 깨지므로). face: nice / laugh / angry / shock / cry / please / fire / cool
class_name EmoteFace
extends Control

const INK: Color = Color("3b2a18")
const SKIN: Color = Color("ffd43b")
const SKIN_EDGE: Color = Color("e67700")

var face: StringName = &"nice"


func _init(kind: StringName = &"nice", extent: float = 40.0) -> void:
	face = kind
	custom_minimum_size = Vector2(extent, extent)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r: float = minf(size.x, size.y) * 0.5 - 2.0
	var c: Vector2 = size / 2.0
	var fill: Color = SKIN
	match face:
		&"angry": fill = Color("ff6b6b")
		&"fire": fill = Color("ffa94d")
		&"shock": fill = Color("a5d8ff")
	if face == &"fire":
		# 머리 위 불꽃
		var flame := PackedVector2Array([c + Vector2(-r * 0.7, -r * 0.5), c + Vector2(-r * 0.45, -r * 1.25), c + Vector2(-r * 0.1, -r * 0.8), c + Vector2(r * 0.15, -r * 1.35), c + Vector2(r * 0.45, -r * 0.85), c + Vector2(r * 0.7, -r * 1.15), c + Vector2(r * 0.75, -r * 0.4)])
		draw_colored_polygon(flame, Color("ff6b00"))
	draw_circle(c, r, SKIN_EDGE)
	draw_circle(c, r - 2.5, fill)
	var eye_y: float = c.y - r * 0.18
	var ex: float = r * 0.36
	var w: float = maxf(r * 0.1, 2.0)
	match face:
		&"nice", &"please":
			# 웃는 눈(^ ^)과 미소
			for side: float in [-1.0, 1.0]:
				draw_polyline(PackedVector2Array([Vector2(c.x + side * ex - r * 0.16, eye_y + r * 0.05), Vector2(c.x + side * ex, eye_y - r * 0.12), Vector2(c.x + side * ex + r * 0.16, eye_y + r * 0.05)]), INK, w, true)
			draw_arc(c + Vector2(0, r * 0.12), r * 0.42, 0.25, PI - 0.25, 12, INK, w, true)
			if face == &"please":
				for side: float in [-1.0, 1.0]:
					draw_circle(Vector2(c.x + side * r * 0.58, c.y + r * 0.2), r * 0.13, Color(1, 0.45, 0.55, 0.6))
		&"laugh":
			for side: float in [-1.0, 1.0]:
				draw_polyline(PackedVector2Array([Vector2(c.x + side * ex - r * 0.16, eye_y), Vector2(c.x + side * ex, eye_y - r * 0.14), Vector2(c.x + side * ex + r * 0.16, eye_y)]), INK, w, true)
				draw_circle(Vector2(c.x + side * r * 0.62, eye_y + r * 0.12), r * 0.11, Color("74c0fc"))
			var mouth := PackedVector2Array()
			for i: int in 9:
				var a: float = PI * float(i) / 8.0
				mouth.append(c + Vector2(cos(a) * r * 0.48, r * 0.08 + sin(a) * r * 0.5))
			draw_colored_polygon(mouth, Color("862e2e"))
		&"angry":
			for side: float in [-1.0, 1.0]:
				draw_line(Vector2(c.x + side * (ex + r * 0.2), eye_y - r * 0.28), Vector2(c.x + side * (ex - r * 0.18), eye_y - r * 0.1), INK, w * 1.2, true)
				draw_circle(Vector2(c.x + side * ex, eye_y + r * 0.04), r * 0.09, INK)
			draw_arc(c + Vector2(0, r * 0.62), r * 0.35, PI + 0.4, TAU - 0.4, 12, INK, w, true)
		&"shock":
			for side: float in [-1.0, 1.0]:
				draw_circle(Vector2(c.x + side * ex, eye_y), r * 0.16, Color.WHITE)
				draw_circle(Vector2(c.x + side * ex, eye_y), r * 0.08, INK)
			draw_circle(c + Vector2(0, r * 0.38), r * 0.2, Color("862e2e"))
		&"cry":
			for side: float in [-1.0, 1.0]:
				draw_line(Vector2(c.x + side * (ex - r * 0.14), eye_y), Vector2(c.x + side * (ex + r * 0.14), eye_y), INK, w, true)
				draw_rect(Rect2(Vector2(c.x + side * ex - r * 0.07, eye_y + r * 0.04), Vector2(r * 0.14, r * 0.6)), Color("74c0fc"))
			draw_arc(c + Vector2(0, r * 0.66), r * 0.3, PI + 0.4, TAU - 0.4, 12, INK, w, true)
		&"fire":
			for side: float in [-1.0, 1.0]:
				draw_line(Vector2(c.x + side * (ex + r * 0.18), eye_y - r * 0.22), Vector2(c.x + side * (ex - r * 0.16), eye_y - r * 0.12), INK, w, true)
				draw_circle(Vector2(c.x + side * ex, eye_y + r * 0.04), r * 0.09, INK)
			draw_arc(c + Vector2(0, r * 0.1), r * 0.42, 0.2, PI - 0.2, 12, INK, w * 1.2, true)
		&"cool":
			# 선글라스와 한쪽 입꼬리
			draw_rect(Rect2(Vector2(c.x - r * 0.72, eye_y - r * 0.16), Vector2(r * 0.62, r * 0.32)), INK)
			draw_rect(Rect2(Vector2(c.x + r * 0.1, eye_y - r * 0.16), Vector2(r * 0.62, r * 0.32)), INK)
			draw_line(Vector2(c.x - r * 0.12, eye_y - r * 0.08), Vector2(c.x + r * 0.12, eye_y - r * 0.08), INK, w, true)
			draw_line(c + Vector2(-r * 0.25, r * 0.42), c + Vector2(r * 0.35, r * 0.3), INK, w, true)
