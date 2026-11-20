class_name TestAugmentArt
extends TestCase

const EXPECTED_TOOLS: Dictionary = {
	&"YUT": "DICE_YUT", &"HOLDEM": "DICE_POKER", &"LIFE_ROULETTE": "DICE_ROULETTE",
	&"CHINCHIRO": "DICE_CHINCHIRO", &"SLOT_777": "DICE_SLOT", &"REVOLVER": "REVOLVER",
	&"DICE_HWATU": "DICE_HWATU", &"DICE_MAHJONG": "DICE_MAHJONG", &"DICE_TAROT": "DICE_TAROT",
	&"DICE_YACHT": "DICE_YACHT", &"DICE_BLACKJACK": "DICE_BLACKJACK", &"DICE_PINBALL": "DICE_PINBALL",
	&"DICE_STOCK": "DICE_STOCK_V02", &"DICE_DARTS": "DICE_DARTS_V02", &"DICE_OMIKUJI": "DICE_OMIKUJI_V02", &"DICE_ICECREAM": "DICE_ICECREAM_V02", &"DICE_COOKIE": "DICE_COOKIE_V02", &"DICE_CAPSULE": "DICE_CAPSULE_V02",
}


func test_all_draft_icons_resolve_to_the_described_target() -> void:
	var paths: Dictionary = {}
	for definition: AugmentDef in AugmentRegistry.all():
		var relative: String = ""
		match definition.category:
			GameEnums.AugmentCategory.PAWN_EVOLUTION:
				var subtype: int = PawnCatalog.sub_type_of(definition.payload, definition.units[0])
				relative = "pawns/%s.png" % GameEnums.PawnSubType.keys()[subtype]
				if subtype == GameEnums.PawnSubType.MOB_KYUI:
					relative = "pawns/MOB_KYUI_V01.png"
				if subtype == GameEnums.PawnSubType.ODD_MELON:
					relative = "pawns/ODD_MELON_V01.png"
				if definition.payload == GameEnums.PawnKind.YUT:
					relative = "pawns/YUT.png"
				if definition.payload in [GameEnums.PawnKind.TRPG, GameEnums.PawnKind.COLLECTIBLE]:
					relative = "augments/pawns/%s_V02.png" % GameEnums.PawnSubType.keys()[subtype]
			GameEnums.AugmentCategory.TOOL_SWAP:
				check(EXPECTED_TOOLS.has(definition.payload), "known tool: " + str(definition.payload))
				relative = "dice/%s.png" % EXPECTED_TOOLS.get(definition.payload, "MISSING")
			GameEnums.AugmentCategory.LAW_ENACT:
				relative = "laws/%s.png" % definition.payload
			GameEnums.AugmentCategory.SUPER_GAMBLE:
				relative = "augments/%s.png" % definition.augment_id
			_:
				relative = "augments/%s.png" % definition.augment_id  # 카드 패키지 3종·범용 보급 13종
		if definition.augment_id in [&"AUG_UTIL_DRIFT", &"AUG_UTIL_BOUNTY"]:
			relative = "augments/%s_V02.png" % definition.augment_id
		var texture: Texture2D = AugmentArt.load_first(AugmentArt.candidates(definition))
		check(texture != null, str(definition.augment_id) + " has illustration")
		if texture == null:
			continue
		check_eq(texture.resource_path, AugmentArt.ROOT + relative, str(definition.augment_id) + " target image, not an unrelated category fallback")
		check(not paths.has(texture.resource_path), str(definition.augment_id) + " distinct icon")
		paths[texture.resource_path] = true
	check_eq(AugmentRegistry.all().size(), 93, "28 pawns + 16 tools + 9 laws + 3 card packages + 16 super + 15 utility")
	check_eq(paths.size(), 93, "every draft effect has its own icon")
	print("AUGMENT_ART_COVERAGE ", paths.size(), "/93")


func test_shop_law_uses_the_icon_for_the_active_board() -> void:
	var original_tiles: int = BoardSpec.tile_count
	var original_convenience: bool = BoardSpec.convenience
	var original_witch: bool = BoardSpec.witch
	var definition: AugmentDef = AugmentRegistry.get_def(&"AUG_LAW_02")
	BoardSpec.apply(32, true)
	var city: Texture2D = AugmentArt.load_first(AugmentArt.candidates(definition))
	check(city != null and city.resource_path.ends_with("/LAW_02_MONATIUM.png"), "Monatium uses the convenience-store emblem")
	BoardSpec.apply(32, false, true)
	var witch: Texture2D = AugmentArt.load_first(AugmentArt.candidates(definition))
	check(witch != null and witch.resource_path.ends_with("/LAW_02_BAD_CARROT.png"), "Bad Carrot uses the witch and carrot emblem")
	check(AugmentArt.load_first(AugmentArt.law_candidates("LAW_02")) == witch, "rulebook and law effect use the same witch emblem")
	BoardSpec.apply(32)
	var classic: Texture2D = AugmentArt.load_first(AugmentArt.candidates(definition))
	check(classic != null and classic.resource_path.ends_with("/LAW_02.png"), "switching back restores the bakery ticket")
	BoardSpec.apply(original_tiles, original_convenience, original_witch)
