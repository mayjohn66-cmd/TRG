## Painted storefront and original Minimi_Erpin frames; no avatar redrawing.
extends RefCounted

const SHOP = preload("res://content_trickcal/illustrations/effects/bakery/bakery_storefront.png")
const FLOUR = preload("res://content_trickcal/illustrations/effects/bakery/flour_puff.png")
const MOVE = preload("res://content_trickcal/illustrations/effects/bakery/erpin_move.png")
const IDLE = preload("res://content_trickcal/illustrations/effects/bakery/erpin_idle.png")
const MOVE_CELL := Vector2(212,308)
const MOVE_SIZE := Vector2(208,304)
const MOVE_ORIGIN := Vector2(91.5,275)

static func erpin(canvas: Node2D, foot: Vector2, clock: float, height: float, alpha: float, running: bool, facing: float, lean: float = 0.0) -> void:
	var texture: Texture2D = MOVE if running else IDLE
	var region := Rect2(Vector2.ZERO,texture.get_size())
	var origin := Vector2(218,404)
	var factor := height/380.0
	if running:
		var frame := int(maxf(0,clock)*30.0)%14
		region = Rect2(Vector2(frame%7,frame/7)*MOVE_CELL+Vector2(2,2),MOVE_SIZE)
		origin = MOVE_ORIGIN
		factor *= 2.0
	# The source faces left. Mirroring the source canvas preserves its foot pivot.
	canvas.draw_set_transform(foot,lean,Vector2(-facing*factor,factor))
	canvas.draw_texture_rect_region(texture,Rect2(-origin,region.size),region,Color(1,1,1,alpha))
	canvas.draw_set_transform(Vector2.ZERO)

static func storefront(canvas: Node2D, foot: Vector2, width: float, alpha: float, angle: float) -> void:
	canvas.draw_set_transform(foot,angle)
	canvas.draw_texture_rect(SHOP,Rect2(Vector2(-width/2,-width),Vector2.ONE*width),false,Color(1,1,1,alpha))
	canvas.draw_set_transform(Vector2.ZERO)

static func flour(canvas: Node2D, at: Vector2, radius: float, alpha: float, angle: float) -> void:
	canvas.draw_set_transform(at,angle)
	canvas.draw_texture_rect(FLOUR,Rect2(Vector2.ONE*-radius,Vector2.ONE*radius*2),false,Color(1,1,1,alpha))
	canvas.draw_set_transform(Vector2.ZERO)
