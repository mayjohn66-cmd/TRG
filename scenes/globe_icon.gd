# File: res://scenes/globe_icon.gd
# Class: class_name GlobeIcon
# Role: 언어 버튼의 지구본 아이콘 (게임 글꼴에 이모지가 없어 웹에서 깨지므로 코드로 그린다).
class_name GlobeIcon
extends Control

var color: Color = Color.WHITE


func _init(extent: float = 18.0, ink: Color = Color.WHITE) -> void:
	custom_minimum_size = Vector2(extent, extent)
	size = custom_minimum_size
	color = ink
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c: Vector2 = size / 2.0
	var r: float = minf(size.x, size.y) / 2.0 - 1.5
	var w: float = maxf(r * 0.16, 1.4)
	draw_arc(c, r, 0.0, TAU, 32, color, w, true)
	draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), color, w, true)
	draw_line(c + Vector2(0, -r), c + Vector2(0, r), color, w, true)
	# 경선(세로 타원)과 위도선 두 줄
	var meridian := PackedVector2Array()
	for i: int in 25:
		var a: float = TAU * float(i) / 24.0
		meridian.append(c + Vector2(cos(a) * r * 0.45, sin(a) * r))
	draw_polyline(meridian, color, w, true)
	for side: float in [-1.0, 1.0]:
		var y: float = side * r * 0.5
		var half: float = sqrt(maxf(r * r - y * y, 0.0))
		draw_line(c + Vector2(-half, y), c + Vector2(half, y), color, w * 0.8, true)
