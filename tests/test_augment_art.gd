class_name TestAugmentArt
extends TestCase

const EXPECTED_TOOLS: Dictionary = {
	&"YUT": "DICE_YUT", &"HOLDEM": "DICE_POKER", &"LIFE_ROULETTE": "DICE_ROULETTE",
	&"CHINCHIRO": "DICE_CHINCHIRO", &"SLOT_777": "DICE_SLOT", &"REVOLVER": "REVOLVER",
	&"DICE_HWATU": "DICE_HWATU", &"DICE_MAHJONG": "DICE_MAHJONG", &"DICE_TAROT": "DICE_TAROT",
	&"DICE_YACHT": "DICE_YACHT", &"DICE_BLACKJACK": "DICE_BLACKJACK", &"DICE_PINBALL": "DICE_PINBALL",
}


func test_all_draft_icons_resolve_to_the_described_target() -> void:
	var paths: Dictionary = {}
	for definition: AugmentDef in AugmentRegistry.all():
		var relative: String = ""
		match definition.category:
			GameEnums.AugmentCategory.PAWN_EVOLUTION:
				var subtype: int = PawnCatalog.sub_type_of(definition.payload, definition.units[0])
				relative = "pawns/%s.png" % GameEnums.PawnSubType.keys()[subtype]
				if definition.payload == GameEnums.PawnKind.YUT:
					relative = "pawns/YUT.png"
			GameEnums.AugmentCategory.TOOL_SWAP:
				check(EXPECTED_TOOLS.has(definition.payload), "known tool: " + str(definition.payload))
				relative = "dice/%s.png" % EXPECTED_TOOLS.get(definition.payload, "MISSING")
			GameEnums.AugmentCategory.LAW_ENACT:
				relative = "laws/%s.png" % definition.payload
			GameEnums.AugmentCategory.SUPER_GAMBLE:
				relative = "augments/%s.png" % definition.augment_id
			_:
				relative = "augments/CARD_PACKAGE.png"
		var texture: Texture2D = AugmentArt.load_first(AugmentArt.candidates(definition))
		check(texture != null, str(definition.augment_id) + " has illustration")
		if texture == null:
			continue
		check_eq(texture.resource_path, AugmentArt.ROOT + relative, str(definition.augment_id) + " target image, not an unrelated category fallback")
		check(not paths.has(texture.resource_path), str(definition.augment_id) + " distinct icon")
		paths[texture.resource_path] = true
	check_eq(AugmentRegistry.all().size(), 50, "19 pawns + 12 tools + 8 laws + card package + 10 super")
	check_eq(paths.size(), 50, "every draft effect has its own icon")
	print("AUGMENT_ART_COVERAGE ", paths.size(), "/50")
