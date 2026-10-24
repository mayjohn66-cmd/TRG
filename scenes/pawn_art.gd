## Board tokens are transparent sprites; augment medallions live separately.
class_name PawnArt
extends RefCounted

const ROOT: String = "res://content_trickcal/illustrations/pawns/"
static var _regions: Dictionary = {}


static func candidates(pawn: PlayerPawn) -> Array[String]:
	var paths: Array[String] = []
	if pawn.kind == GameEnums.PawnKind.BASIC:
		return [ROOT + "PAWN_DEFAULT.png"]
	var subtype: String = GameEnums.PawnSubType.keys()[pawn.sub_type()]
	if pawn.is_promoted_shogi():
		paths.append(ROOT + subtype + "_NARI.png")
		paths.append(ROOT + "SHOGI_NARI.png")
	paths.append(ROOT + subtype + ".png")
	if pawn.kind == GameEnums.PawnKind.YUT:
		paths.append(ROOT + "YUT.png")
	if pawn.kind == GameEnums.PawnKind.SHOGI:
		paths.append(ROOT + "SHOGI_NORMAL.png")
	paths.append(ROOT + str(AugmentArt.PAWN_FILES.get(pawn.kind, "PAWN_DEFAULT")) + ".png")
	return paths


static func sprite(pawn: PlayerPawn) -> Dictionary:
	return load_sprite(candidates(pawn))


static func load_sprite(paths: Array[String]) -> Dictionary:
	var texture: Texture2D = AugmentArt.load_first(paths)
	if texture == null:
		return {}
	var path: String = texture.resource_path if texture.resource_path != "" else "id:%d" % texture.get_instance_id()  # TextureCache가 줄인 그림은 경로가 없다
	if not _regions.has(path):
		var image: Image = texture.get_image()
		if image == null:
			return {}
		_regions[path] = visible_region(image)
	var region: Rect2 = _regions[path]
	if region.size.x <= 0 or region.size.y <= 0:
		return {}
	return {"texture": texture, "region": region}


## Native cutouts can have 1/255 alpha specks far from the real silhouette.
## Measure visible pixels once, with 2 source-pixel AA padding; keep PNG intact.
static func visible_region(image: Image) -> Rect2i:
	var size: Vector2i = image.get_size()
	if image.detect_alpha() == Image.ALPHA_NONE:
		return Rect2i(Vector2i.ZERO,size)
	var minimum: Vector2i = size
	var maximum := Vector2i(-1,-1)
	for y: int in size.y:
		for x: int in size.x:
			if image.get_pixel(x,y).a >= 0.08:
				minimum = Vector2i(mini(minimum.x,x),mini(minimum.y,y))
				maximum = Vector2i(maxi(maximum.x,x),maxi(maximum.y,y))
	if maximum.x < 0:
		return Rect2i()
	return Rect2i(minimum,maximum-minimum+Vector2i.ONE).grow(2).intersection(Rect2i(Vector2i.ZERO,size))
