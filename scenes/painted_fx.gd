## Texture-only accents shared by board, profile and duel presentations.
class_name PaintedFx
extends RefCounted

const FLAME: Texture2D = preload("res://assets/fx/priority/flame_plume_v01.png")
const LIGHTNING: Texture2D = preload("res://assets/fx/priority/lightning_v01.png")
const IMPACT: Texture2D = preload("res://assets/fx/priority/impact_wisp_v01.png")
const SMOKE: Texture2D = preload("res://assets/fx/atmosphere/steam_puff_v01.png")
const DUST: Texture2D = preload("res://assets/fx/atmosphere/ground_dust_v01.png")
const WAKE: Texture2D = preload("res://assets/fx/capture/pierce_trail_v01.png")
const RIPPLE: Texture2D = preload("res://assets/fx/common/shockwave_v01.png")
const FLECK: Texture2D = preload("res://assets/fx/common/spark_fleck_v01.png")
const ELECTRIC: Shader = preload("res://assets/fx/priority/electric_arc.gdshader")
# Measured white-hot source endpoints, independent of surrounding branch/glow padding.
const LIGHTNING_TOP := Vector2(0.49755859375, 0.06119791667)
const LIGHTNING_BOTTOM := Vector2(0.5166015625, 0.95963541667)
static var _regions: Dictionary = {}

static func region(texture: Texture2D) -> Rect2:
	var key := texture.get_instance_id()
	if not _regions.has(key):
		_regions[key] = Rect2(PawnArt.visible_region(texture.get_image()))
	return _regions[key]

static func sprite(texture: Texture2D) -> Sprite2D:
	var result := Sprite2D.new()
	result.texture = texture
	result.region_enabled = true
	result.region_filter_clip_enabled = true
	result.region_rect = region(texture)
	return result

static func stamp(canvas: CanvasItem, texture: Texture2D, at: Vector2, extent: Vector2, color: Color, angle: float = 0.0) -> void:
	if color.a <= 0.001 or extent.x <= 0 or extent.y <= 0: return
	canvas.draw_set_transform(at, angle)
	canvas.draw_texture_rect_region(texture, Rect2(-extent * 0.5, extent), region(texture), color)
	canvas.draw_set_transform(Vector2.ZERO)

static func flame(canvas: CanvasItem, base: Vector2, direction: Vector2, height: float, half_width: float, color: Color, phase: float) -> void:
	if height <= 0.3 or color.a <= 0.001: return
	var angle := direction.angle() + PI * 0.5 + sin(phase) * 0.07
	var extent := Vector2(half_width * 2.0 * (1.0 + sin(phase * 0.71) * 0.12), height)
	canvas.draw_set_transform(base, angle)
	canvas.draw_texture_rect_region(FLAME, Rect2(Vector2(-extent.x * 0.5, -extent.y), extent), region(FLAME), color)
	canvas.draw_set_transform(Vector2.ZERO)

static func streak(canvas: CanvasItem, from: Vector2, to: Vector2, width: float, color: Color) -> void:
	var length := from.distance_to(to)
	if length < 0.5: return
	stamp(canvas, WAKE, from.lerp(to, 0.5), Vector2(length, width), color, from.angle_to_point(to))

static func lightning(from: Vector2, to: Vector2, color: Color) -> Sprite2D:
	var result := sprite(LIGHTNING)
	var top := LIGHTNING.get_size() * LIGHTNING_TOP
	var bottom := LIGHTNING.get_size() * LIGHTNING_BOTTOM
	result.centered = false
	result.offset = result.region_rect.position - bottom
	result.position = to
	result.rotation = from.direction_to(to).angle() - top.direction_to(bottom).angle()
	result.scale = Vector2.ONE * from.distance_to(to) / top.distance_to(bottom)
	result.modulate = color
	var electric := ShaderMaterial.new()
	electric.shader = ELECTRIC
	result.material = electric
	return result
