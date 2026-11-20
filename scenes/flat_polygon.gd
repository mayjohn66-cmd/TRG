class_name FlatPolygon
extends Node2D
## 단색 다각형 노드: Polygon2D 대체용.
## Godot 4.7.1의 Polygon2D는 같은 꼭짓점 수로 다시 그릴 때 인덱스 버퍼를 GL_ARRAY_BUFFER로
## 묶어 갱신한다(mesh_surface_update_index_region). WebGL은 이를 거부해
## "bindBuffer: element array buffers can not be bound to a different target" 오류가 쌓인다.
## draw_colored_polygon은 메시 갱신 경로를 쓰지 않으므로 웹에서도 안전하다.

@export var polygon: PackedVector2Array = PackedVector2Array():
	set(value):
		polygon = value
		queue_redraw()

@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _draw() -> void:
	if polygon.size() >= 3:
		draw_colored_polygon(polygon, color)
