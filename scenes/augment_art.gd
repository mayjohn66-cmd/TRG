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


## augments_table.csv·dice_table.csv의 icon_file이 기본 후보와 다른 파일이면 가장 먼저 찾는다 (res:// 전체 경로 또는 illustrations/ 아래 상대 경로, 확장자 생략 가능).
## 기본 후보와 같은 파일이면 순서를 바꾸지 않는다 (표에 현재 쓰는 파일명이 채워져 있어도 동작이 같다).
static func _with_table_icon(paths: Array[String], icon_file: String, extra_folder: String) -> Array[String]:
	if icon_file == "":
		return paths
	var file: String = icon_file if icon_file.get_extension() != "" else icon_file + ".png"
	var wanted: Array[String] = []
	if file.begins_with("res://"):
		wanted.append(file)
	else:
		wanted.append(ROOT + file)
		wanted.append(ROOT + extra_folder + file)
	for candidate: String in wanted:
		if paths.has(candidate):
			return paths
	var result: Array[String] = wanted.duplicate()
	result.append_array(paths)
	return result


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
		GameEnums.AugmentCategory.SUPER_GAMBLE:
			paths.append(ROOT + "augments/%s.png" % definition.augment_id)
		_:
			paths.append(ROOT + "augments/%s.png" % definition.augment_id)
			paths.append(ROOT + "augments/AUG_CARD_PACK.png")
	return _with_table_icon(paths, definition.icon_file, "augments/")


static func tool_candidates(tool_id: StringName) -> Array[String]:
	var paths: Array[String] = [ROOT + "dice/%s.png" % tool_id]
	var representative: String = ROOT + "dice/%s.png" % TOOL_FILES.get(tool_id, tool_id)
	if not paths.has(representative):
		paths.append(representative)
	var table_icon: String = GameData.text("dice", tool_id, "icon_file")  # dice_table.csv의 icon_file (illustrations/dice/ 아래)
	if table_icon != "" and not table_icon.begins_with("res://"):
		table_icon = "dice/" + table_icon
	return _with_table_icon(paths, table_icon, "dice/")


## Check imported resources so optional artwork also works in exported PCKs.
## Hits are kept in TextureCache; misses are not cached here, so newly imported art becomes visible on the next refresh.
static func load_first(paths: Array[String]) -> Texture2D:
	for path: String in paths:
		if ResourceLoader.exists(path, "Texture2D"):
			var texture: Texture2D = TextureCache.fetch(path)
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
