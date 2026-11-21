## Native-image cutouts shared by the matching-pose ink transition.
extends RefCounted
const SHADER = preload("res://scenes/cutscene_ink_morph.gdshader")
static var _dice: Array[Texture2D] = []
static var _pawn: Texture2D
static func dice() -> Array[Texture2D]:
	if _dice.is_empty():
		var sheet := TextureCache.fetch("res://assets/fx/law_fx/victory_prints/dice_faces_v03.webp")
		for i: int in 3:
			var cell := AtlasTexture.new();cell.atlas=sheet
			cell.region=Rect2(float(i)*sheet.get_width()/3.0,0,sheet.get_width()/3.0,sheet.get_height())
			var crop := AtlasTexture.new();crop.atlas=sheet
			var bounds := PawnArt.visible_region(cell.get_image())
			crop.region=Rect2(cell.region.position+Vector2(bounds.position),Vector2(bounds.size))
			_dice.append(crop)
	return _dice
static func fallen_pawn() -> Texture2D:
	if _pawn==null:
		var sheet := TextureCache.fetch("res://assets/fx/law_fx/victory_prints/fallen_pawn_v03.webp")
		var crop := AtlasTexture.new();crop.atlas=sheet;crop.region=PaintedFx.region(sheet);_pawn=crop
	return _pawn
static func material(reverse: bool = false, surface: bool = false, quarter: bool = false) -> ShaderMaterial:
	var result := ShaderMaterial.new();result.shader=SHADER
	result.set_shader_parameter("erase",reverse);result.set_shader_parameter("whole_surface",surface);result.set_shader_parameter("quarter_turn",quarter)
	return result
static func picture(texture: Texture2D) -> TextureRect:
	var result := TextureRect.new();result.texture=texture
	result.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;result.stretch_mode=TextureRect.STRETCH_SCALE
	result.mouse_filter=Control.MOUSE_FILTER_IGNORE;result.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	return result
