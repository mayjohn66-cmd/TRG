## Optional artwork shared by draft cards, augment history and the tool HUD.
class_name AugmentArt
extends RefCounted

const ROOT: String = "res://content_trickcal/illustrations/"
const CIRCLE_SHADER: Shader = preload("res://scenes/augment_circle.gdshader")
const PAWN_FILES: Dictionary = {
	GameEnums.PawnKind.CHESS: "PAWN_CHESS",
	GameEnums.PawnKind.JANGGI: "PAWN_JANGGI",
	GameEnums.PawnKind.YUT: "PAWN_YUT",
	GameEnums.PawnKind.MONOPOLY: "PAWN_MONO",
	GameEnums.PawnKind.GO: "PAWN_BADUK",
	GameEnums.PawnKind.SHOGI: "PAWN_SHOGI",
}
const TOOL_FILES: Dictionary = {
	&"D6": "DICE_D6", &"YUT": "DICE_YUT", &"LIFE_ROULETTE": "DICE_ROULETTE",
	&"HOLDEM": "DICE_POKER", &"SLOT_777": "DICE_SLOT", &"REVOLVER": "DICE_RUSSIAN",
	&"CHINCHIRO": "DICE_CHINCHIRO", &"DICE_HWATU": "DICE_HWATU",
	&"DICE_MAHJONG": "DICE_MAHJONG", &"DICE_TAROT": "DICE_TAROT",
	&"DICE_YACHT": "DICE_YACHT", &"DICE_BLACKJACK": "DICE_BLACKJACK", &"DICE_PINBALL": "DICE_PINBALL",
}


static func candidates(definition: AugmentDef) -> Array[String]:
	var paths: Array[String] = []
	match definition.category:
		GameEnums.AugmentCategory.PAWN_EVOLUTION:
			if not definition.units.is_empty():
				var subtype: int = PawnCatalog.sub_type_of(definition.payload, definition.units[0])
				paths.append(ROOT + "pawns/%s.png" % GameEnums.PawnSubType.keys()[subtype])
				if definition.payload == GameEnums.PawnKind.YUT:
					paths.append(ROOT + "pawns/YUT.png")
			paths.append(ROOT + "augments/%s.png" % definition.augment_id)
			paths.append(ROOT + "augments/pawns/%s.png" % PAWN_FILES.get(definition.payload, "PAWN_BASIC"))
			paths.append(ROOT + "pawns/%s.png" % PAWN_FILES.get(definition.payload, "PAWN_BASIC"))
		GameEnums.AugmentCategory.TOOL_SWAP:
			paths.assign(tool_candidates(definition.payload))
		GameEnums.AugmentCategory.LAW_ENACT:
			paths.append(ROOT + "laws/%s.png" % definition.payload)
			paths.append(ROOT + "augments/%s.png" % definition.augment_id)
			paths.append(ROOT + "augments/AUG_LAW.png")
		_:
			paths.append(ROOT + "augments/%s.png" % definition.augment_id)
			paths.append(ROOT + "augments/AUG_CARD_PACK.png")
	return paths


static func tool_candidates(tool_id: StringName) -> Array[String]:
	var paths: Array[String] = [ROOT + "dice/%s.png" % tool_id]
	var representative: String = ROOT + "dice/%s.png" % TOOL_FILES.get(tool_id, tool_id)
	if not paths.has(representative):
		paths.append(representative)
	return paths


## Check imported resources so optional artwork also works in exported PCKs.
## Do not cache misses: newly imported art becomes visible on the next refresh.
static func load_first(paths: Array[String]) -> Texture2D:
	for path: String in paths:
		if ResourceLoader.exists(path, "Texture2D"):
			var texture: Texture2D = load(path) as Texture2D
			if texture != null:
				return texture
	return null


static func make_texture(texture: Texture2D, diameter: float) -> TextureRect:
	var art := TextureRect.new()
	art.name = "EmblemArt"
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.size = Vector2.ONE * diameter
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var circle := ShaderMaterial.new()
	circle.shader = CIRCLE_SHADER
	art.material = circle
	return art
