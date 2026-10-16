## Shared, deterministic lobby backdrop. Geometry stays independent of menu input.
extends Control

const REFERENCE_SIZE: Vector2 = Vector2(1920, 1080)
const BASE: Color = Color("cde793")
const LOWER_CURVE: Color = Color("bfdb7c")
const LEAF: Color = Color("f9f9f31a") # 26 / 255 alpha, approximately 10%.
const LEAF_STROKE: float = 2.5
## Normalized center, length at reference resolution, rotation in degrees.
## All ornament contours stay outside the central 60% of the viewport.
const LEAVES: Array[Vector4] = [
	Vector4(0.055, 0.145, 96, -38),
	Vector4(0.155, 0.290, 76, 32),
	Vector4(0.075, 0.505, 108, -22),
	Vector4(0.155, 0.715, 88, 55),
	Vector4(0.040, 0.875, 76, -42),
	Vector4(0.945, 0.175, 100, -142),
	Vector4(0.845, 0.355, 80, 148),
	Vector4(0.930, 0.540, 108, -158),
	Vector4(0.850, 0.745, 88, 125),
	Vector4(0.965, 0.900, 76, -138),
]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BASE)
	var curve := PackedVector2Array()
	for i: int in range(97):
		var x: float = float(i) / 96.0
		var y: float = 0.84 + 0.04 * sin(TAU * x + 0.35)
		curve.append(Vector2(x * size.x, y * size.y))
	curve.append(size)
	curve.append(Vector2(0, size.y))
	draw_colored_polygon(curve, LOWER_CURVE)
	draw_polyline(curve.slice(0, 97), LOWER_CURVE, 1.5, true)
	# Uniform ornament scaling prevents stretching on wide/tall screens.
	var scale_factor: float = minf(size.x / REFERENCE_SIZE.x, size.y / REFERENCE_SIZE.y)
	for leaf: Vector4 in LEAVES:
		_draw_leaf(Vector2(leaf.x, leaf.y) * size, leaf.z * scale_factor, deg_to_rad(leaf.w), scale_factor)


func _draw_leaf(center: Vector2, length_px: float, angle: float, scale_factor: float) -> void:
	var contour := PackedVector2Array()
	for side: float in [1.0, -1.0]:
		for i: int in range(25):
			var t: float = float(i) / 24.0 if side > 0 else 1.0 - float(i) / 24.0
			var point := Vector2((t - 0.5) * length_px, side * sin(PI * t) * length_px * 0.28)
			contour.append(center + point.rotated(angle))
	contour.append(contour[0])
	draw_polyline(contour, LEAF, maxf(LEAF_STROKE * scale_factor, 1.0), true)
	draw_line(center + Vector2(-length_px * 0.36, 0).rotated(angle), center + Vector2(length_px * 0.36, 0).rotated(angle), LEAF, maxf(LEAF_STROKE * scale_factor, 1.0), true)
