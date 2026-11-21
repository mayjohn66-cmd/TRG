## Shared painted background. Illustration and live text remain separate.
class_name AugmentCardSkin
extends RefCounted

const BASE: Texture2D = preload("res://assets/ui/trickcal/augment/card_base.png")
const TINT: Shader = preload("res://scenes/augment_card_tint.gdshader")

static func make_background(color: Color, card_size: Vector2, frame: StyleBoxFlat) -> TextureRect:
	var inset: float = float(frame.border_width_left)
	var inner_size: Vector2 = card_size - Vector2.ONE * inset * 2.0
	var background := TextureRect.new()
	background.name = "AugmentBackground"
	background.position = Vector2.ONE * inset
	background.size = inner_size
	background.texture = BASE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tint := ShaderMaterial.new()
	tint.shader = TINT
	tint.set_shader_parameter("category_tint", color)
	tint.set_shader_parameter("card_size", inner_size)
	tint.set_shader_parameter("corner_radius", maxf(1.0, float(frame.corner_radius_top_left) - inset))
	background.material = tint
	return background
