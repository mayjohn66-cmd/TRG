## Shared painted background. Illustration and live text remain separate.
class_name AugmentCardSkin
extends RefCounted

const BASE: Texture2D = preload("res://assets/ui/trickcal/augment/card_base.png")
const TINT: Shader = preload("res://scenes/augment_card_tint.gdshader")

static func make_background(color: Color, card_size: Vector2) -> TextureRect:
	var background := TextureRect.new()
	background.name = "AugmentBackground"
	background.position = Vector2(4, 4)
	background.size = card_size - Vector2(8, 8)
	background.texture = BASE
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tint := ShaderMaterial.new()
	tint.shader = TINT
	tint.set_shader_parameter("category_tint", color)
	background.material = tint
	return background
