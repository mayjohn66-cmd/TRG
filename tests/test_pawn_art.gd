# Every playable subtype, promoted shogi face and neutral token must resolve to
# its own transparent illustration, never silently to a category/base fallback.
class_name TestPawnArt
extends TestCase


func test_all_catalog_states_have_distinct_illustrations() -> void:
	var sources: Dictionary = {}
	var basic := PlayerPawn.new()
	_check_art(PawnArt.sprite(basic), "PAWN_DEFAULT.png", sources)
	var subtypes: Dictionary = {}
	for kind: GameEnums.PawnKind in PawnCatalog.SUB_TYPES.keys():
		var units: Array = PawnCatalog.SUB_TYPES[kind]
		for index: int in units.size():
			var pawn := PlayerPawn.new()
			pawn.kind = kind
			pawn.unit_no = index + 1
			var subtype: GameEnums.PawnSubType = pawn.sub_type()
			if subtypes.has(subtype):
				continue
			subtypes[subtype] = true
			var key: String = GameEnums.PawnSubType.keys()[subtype]
			_check_art(PawnArt.sprite(pawn), "YUT.png" if kind == GameEnums.PawnKind.YUT else key + ".png", sources)
			if kind == GameEnums.PawnKind.SHOGI:
				pawn.promoted = true
				_check_art(PawnArt.sprite(pawn), key + "_NARI.png", sources)
	check_eq(subtypes.size(), GameEnums.PawnSubType.size() - 1, "all non-basic catalog subtypes covered")
	for behavior: GameEnums.NpcBehavior in GameEnums.NpcBehavior.values():
		var token := PawnToken.new()
		token.configure_npc(behavior)
		_check_art(token.artwork, "NPC_ROBBER.png" if behavior == GameEnums.NpcBehavior.CHASE_NEAREST else "NPC_GHOST.png", sources)
		token.free()
	check_eq(sources.size(), 32, "26 normal + 4 promoted + 2 NPC illustrations")
	print("PAWN_ART_COVERAGE ", sources.size(), "/32")


func _check_art(art: Dictionary, filename: String, sources: Dictionary) -> void:
	check(not art.is_empty(), filename + " has illustration")
	if art.is_empty():
		return
	var texture: Texture2D = art.texture
	check_eq(texture.resource_path, PawnArt.ROOT + filename, filename + " exact state image")
	check(not sources.has(texture.resource_path), filename + " is not shared with another state")
	sources[texture.resource_path] = true
	check(texture.get_width() <= 256 and texture.get_height() <= 256, filename + " runtime size limit")
	var image: Image = texture.get_image()
	check(image != null and not image.is_empty(), filename + " decodes")
	if image == null or image.is_empty():
		return
	check(image.detect_alpha() != Image.ALPHA_NONE, filename + " transparent cutout")
	var region: Rect2 = art.region
	check(region.has_area() and Rect2(Vector2.ZERO, texture.get_size()).encloses(region), filename + " visible sprite inside atlas")
