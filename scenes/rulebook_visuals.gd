## Independent painted rulebook symbols and a neutral image skin; no gameplay data.
extends RefCounted

const SOURCES := {
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
	&"corner": preload("res://assets/board/decals/BOARD_CORNER.png"),
	&"halfway": preload("res://assets/board/decals/BOARD_HALF.png"),
	&"bread": preload("res://assets/board/decals/BOARD_BAKERY.png"),
	&"wardrobe": preload("res://assets/board/decals/BOARD_PORTAL.png"),
	&"boost": preload("res://assets/board/decals/BOARD_BOOST.png"),
	&"pawn_basics": preload("res://content_trickcal/illustrations/pawns/PAWN_DEFAULT.png"),
}
const REGIONS := {
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
	&"corner": Rect2(96.0/1254,304.0/1254,1103.0/1254,670.0/1254),
	&"halfway": Rect2(360.0/1254,244.0/1254,594.0/1254,783.0/1254),
	&"bread": Rect2(193.0/1254,406.0/1254,868.0/1254,489.0/1254),
	&"wardrobe": Rect2(294.0/1254,265.0/1254,666.0/1254,746.0/1254),
	&"boost": Rect2(172.0/1254,427.0/1254,915.0/1254,398.0/1254),
	&"pawn_basics": Rect2(334.0/1254,218.0/1254,586.0/1254,854.0/1254),
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
