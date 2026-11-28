## Independent painted rulebook symbols and a neutral image skin; no gameplay data.
extends RefCounted

const SOURCES := {
	&"board": preload("res://assets/ui/trickcal/rulebook/v04/board.png"),
	&"capture": preload("res://assets/ui/trickcal/rulebook/v04/capture.png"),
	&"hidden_trap": preload("res://assets/ui/trickcal/rulebook/v04/hidden_trap.png"),
	&"pawn_ability": preload("res://assets/ui/trickcal/rulebook/v04/pawn_ability.png"),
	&"start": preload("res://assets/ui/trickcal/rulebook/v02/finish.png"),
	&"turn": preload("res://assets/ui/trickcal/rulebook/v02/resolve.png"),
	&"tool_swap": preload("res://assets/ui/trickcal/rulebook/v02/roll.png"),
	&"card_law": preload("res://assets/ui/trickcal/rulebook/v02/lawbook.png"),
	&"disc": preload("res://assets/ui/trickcal/rulebook/v03/disc_round.png"),
	&"finish": preload("res://assets/ui/trickcal/rulebook/v02/finish.png"),
	&"play_card": preload("res://assets/ui/trickcal/rulebook/v02/play_card.png"),
	&"roll": preload("res://assets/ui/trickcal/rulebook/v02/roll.png"),
	&"choose_pawn": preload("res://assets/ui/trickcal/rulebook/v02/choose_pawn.png"),
	&"resolve": preload("res://assets/ui/trickcal/rulebook/v02/resolve.png"),
	&"bonus": preload("res://assets/ui/trickcal/rulebook/v02/bonus.png"),
	&"augment_round": preload("res://assets/ui/trickcal/rulebook/v02/augment_round.png"),
	&"tempo": preload("res://assets/ui/trickcal/rulebook/v02/tempo.png"),
	&"attack": preload("res://assets/ui/trickcal/rulebook/v02/attack.png"),
	&"defense": preload("res://assets/ui/trickcal/rulebook/v02/defense.png"),
	&"trap_card": preload("res://assets/ui/trickcal/rulebook/v02/trap_card.png"),
	&"lawbook": preload("res://assets/ui/trickcal/rulebook/v02/lawbook.png"),
	&"supply": preload("res://assets/ui/trickcal/rulebook/v02/supply.png"),
	&"super": preload("res://assets/ui/trickcal/rulebook/v02/super.png"),
	&"panel": preload("res://assets/ui/trickcal/rulebook/v03/panel_round.png"),
	&"paper": preload("res://assets/ui/trickcal/rulebook/v02/paper.png"),
	&"ribbon": preload("res://assets/ui/trickcal/rulebook/v02/ribbon.png"),
	&"corner": preload("res://assets/ui/trickcal/rulebook/v04/corner.png"),
	&"halfway": preload("res://assets/ui/trickcal/rulebook/v04/halfway.png"),
	&"bread": preload("res://assets/ui/trickcal/rulebook/v04/bread.png"),
	&"wardrobe": preload("res://assets/ui/trickcal/rulebook/v04/wardrobe.png"),
	&"store": preload("res://assets/ui/trickcal/rulebook/v04/store.png"),
	&"vending": preload("res://assets/ui/trickcal/rulebook/v04/vending.png"),
	&"witch_shop": preload("res://assets/ui/trickcal/rulebook/v04/witch_shop.png"),
	&"cauldron": preload("res://assets/ui/trickcal/rulebook/v04/cauldron.png"),
	&"spirit": preload("res://assets/ui/trickcal/rulebook/v04/spirit.png"),
	&"boost": preload("res://assets/ui/trickcal/rulebook/v04/boost.png"),
	&"pawn_basics": preload("res://assets/ui/trickcal/rulebook/v04/pawn_basics.png"),
}
const REGIONS := {
	&"board": Rect2(0.11004785,0.13556619,0.75598086,0.75598086),
	&"capture": Rect2(0.12440191,0.17543860,0.73843700,0.67304625),
	&"hidden_trap": Rect2(0.13556619,0.09409888,0.69856459,0.84370016),
	&"pawn_ability": Rect2(0.14673046,0.10366826,0.70813397,0.81499203),
	&"start": Rect2(162.0/1254,170.0/1254,931.0/1254,920.0/1254),
	&"turn": Rect2(151.0/1254,134.0/1254,952.0/1254,979.0/1254),
	&"tool_swap": Rect2(164.0/1254,159.0/1254,939.0/1254,984.0/1254),
	&"card_law": Rect2(166.0/1254,134.0/1254,939.0/1254,1007.0/1254),
	&"disc": Rect2(113.0/1254,126.0/1254,1026.0/1254,1029.0/1254),
	&"finish": Rect2(162.0/1254,170.0/1254,931.0/1254,920.0/1254),
	&"play_card": Rect2(167.0/1254,170.0/1254,920.0/1254,930.0/1254),
	&"roll": Rect2(164.0/1254,159.0/1254,939.0/1254,984.0/1254),
	&"choose_pawn": Rect2(91.0/1254,117.0/1254,1068.0/1254,985.0/1254),
	&"resolve": Rect2(151.0/1254,134.0/1254,952.0/1254,979.0/1254),
	&"bonus": Rect2(139.0/1254,225.0/1254,983.0/1254,826.0/1254),
	&"augment_round": Rect2(70.0/1254,172.0/1254,1114.0/1254,872.0/1254),
	&"tempo": Rect2(119.0/1254,195.0/1254,1020.0/1254,869.0/1254),
	&"attack": Rect2(183.0/1254,182.0/1254,908.0/1254,917.0/1254),
	&"defense": Rect2(50.0/1254,184.0/1254,1144.0/1254,909.0/1254),
	&"trap_card": Rect2(204.0/1254,157.0/1254,877.0/1254,925.0/1254),
	&"lawbook": Rect2(166.0/1254,134.0/1254,939.0/1254,1007.0/1254),
	&"supply": Rect2(141.0/1254,250.0/1254,972.0/1254,737.0/1254),
	&"super": Rect2(177.0/1254,85.0/1254,938.0/1254,1075.0/1254),
	&"panel": Rect2(81.0/1254,99.0/1254,1092.0/1254,1057.0/1254),
	&"paper": Rect2(123.0/1254,141.0/1254,1008.0/1254,988.0/1254),
	&"ribbon": Rect2(31.0/1942,218.0/809,1879.0/1942,344.0/809),
	&"corner": Rect2(0.13237640,0.15470494,0.71451356,0.73684211),
	&"halfway": Rect2(0.17543860,0.11323764,0.64114833,0.80382775),
	&"bread": Rect2(0.11961722,0.20095694,0.76395534,0.70494418),
	&"wardrobe": Rect2(0.19298246,0.12759171,0.61084530,0.77511962),
	&"store": Rect2(0.11164274,0.14832536,0.77033493,0.76236045),
	&"vending": Rect2(0.16746411,0.11961722,0.64752791,0.81977671),
	&"witch_shop": Rect2(0.14673046,0.11483254,0.68899522,0.80223285),
	&"cauldron": Rect2(0.10047847,0.10207337,0.79585327,0.82296651),
	&"spirit": Rect2(0.10207337,0.09728868,0.77990431,0.79585327),
	&"boost": Rect2(0.11483254,0.13875598,0.75119617,0.74641148),
	&"pawn_basics": Rect2(0.21531100,0.09090909,0.54385965,0.85167464),
}
static var _atlases: Dictionary = {}
static var _panels: Dictionary = {}

static func has(role: StringName) -> bool:
	return SOURCES.has(role)

static func texture(role: StringName) -> Texture2D:
	if not _atlases.has(role):
		var source: Texture2D = SOURCES[role]
		var crop: Rect2 = REGIONS[role]
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = Rect2(crop.position*source.get_size(),crop.size*source.get_size())
		_atlases[role] = atlas
	return _atlases[role] as Texture2D

## Nine-slice display preparation preserves the selected source image unchanged.
static func panel(tint: Color, radius: int = 16, margin: int = 0) -> StyleBoxTexture:
	# Source corner arcs occupy about 24% of its cropped width. Match their displayed radius,
	# and preserve the complete quarter arcs inside the nine-slice margins.
	var height := clampi(roundi(float(radius) / 0.24), 12, 192)
	if not _panels.has(height):
		var source: AtlasTexture = texture(&"panel") as AtlasTexture
		var pixels := source.atlas.get_image()
		if pixels.is_compressed():
			pixels.decompress()
		pixels = pixels.get_region(Rect2i(source.region))
		pixels.resize(height,height,Image.INTERPOLATE_LANCZOS)
		_panels[height] = ImageTexture.create_from_image(pixels)
	var skin := StyleBoxTexture.new()
	skin.texture = _panels[height]
	skin.set_texture_margin_all(roundf(height * 0.24))
	skin.set_content_margin_all(margin)
	skin.modulate_color = tint
	return skin


## Circular pedestals use their own uncut image, avoiding collapsed nine-slice seams.
static func disc(tint: Color) -> StyleBoxTexture:
	var skin := StyleBoxTexture.new()
	skin.texture = texture(&"disc")
	skin.set_content_margin_all(0)
	skin.modulate_color = tint
	return skin
