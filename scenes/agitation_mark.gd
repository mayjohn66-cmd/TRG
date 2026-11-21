extends Node2D

const ART: Texture2D = preload("res://assets/fx/priority/agitation_target.png")


func _draw() -> void:
	draw_mark(self, Vector2.ZERO, 10.5)


static func draw_mark(canvas: CanvasItem, center: Vector2, radius: float, opacity: float = 1.0) -> void:
	PaintedFx.stamp(canvas, ART, center, Vector2.ONE * radius * 2.0, Color(1.0, 1.0, 1.0, opacity))
