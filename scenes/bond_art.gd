## Painted source art shared by the bond's reveal and persistent cuff.
extends RefCounted

const LINK = preload("res://content_trickcal/illustrations/effects/bond/link_painted.png")
const CUFF = preload("res://content_trickcal/illustrations/effects/bond/cuff_painted.png")
const LOCK = preload("res://content_trickcal/illustrations/effects/bond/lock_painted.png")
# Normalized source regions remain correct when Godot imports smaller mipmapped art.
const LINK_REGION := Rect2(134.0/1619,109.0/971,1352.0/1619,746.0/971)
const CUFF_REGION := Rect2(72.0/1536,177.0/1024,1404.0/1536,683.0/1024)
const LOCK_REGION := Rect2(202.0/1168,165.0/1347,763.0/1168,1033.0/1347)
static var _light: GradientTexture2D

static func _paint(canvas: Node2D, texture: Texture2D, normalized: Rect2, at: Vector2, size: Vector2, angle: float, color: Color) -> void:
	var region := Rect2(normalized.position*texture.get_size(),normalized.size*texture.get_size())
	canvas.draw_set_transform(at+Vector2(0,1.1),angle)
	canvas.draw_texture_rect_region(texture,Rect2(-size*0.5,size),region,Color(0.15,0.07,0.10,color.a*0.5))
	canvas.draw_set_transform(at,angle)
	canvas.draw_texture_rect_region(texture,Rect2(-size*0.5,size),region,color)
	canvas.draw_set_transform(Vector2.ZERO)

static func link(canvas: Node2D, at: Vector2, forward: Vector2, face_on: bool, alpha: float, gold: bool = false) -> void:
	var size := Vector2(17.0,9.4 if face_on else 3.3)
	var color := Color(1.0,1.0,0.86,alpha) if gold else Color(1,1,1,alpha)
	_paint(canvas,LINK,LINK_REGION,at,size,forward.angle(),color)

static func cuff(canvas: Node2D, at: Vector2, size: Vector2, alpha: float, gold: bool = false) -> void:
	_paint(canvas,CUFF,CUFF_REGION,at,size,0,Color(1,1,0.86 if gold else 1.0,alpha))

static func lock(canvas: Node2D, at: Vector2, size: Vector2, alpha: float) -> void:
	_paint(canvas,LOCK,LOCK_REGION,at,size,0,Color(1,1,1,alpha))

static func light(canvas: Node2D, at: Vector2, radius: float, tint: Color) -> void:
	if _light==null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0,0.22,0.6,1])
		gradient.colors = PackedColorArray([Color(1,1,1,0.95),Color(1,1,1,0.6),Color(1,1,1,0.12),Color(1,1,1,0)])
		_light = GradientTexture2D.new()
		_light.width = 64
		_light.height = 64
		_light.gradient = gradient
		_light.fill = GradientTexture2D.FILL_RADIAL
		_light.fill_from = Vector2(0.5,0.5)
		_light.fill_to = Vector2(1,0.5)
	canvas.draw_texture_rect(_light,Rect2(at-Vector2.ONE*radius,Vector2.ONE*radius*2),false,tint)
