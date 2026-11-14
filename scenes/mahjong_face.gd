## Deterministic tile faces composed from generated ink motifs and real CJK type.
## The game uses 30 kinds, without winds, red fives, flowers or bonus tiles.
class_name MahjongFace
extends Control

const ROOT: String = "res://assets/ui/trickcal/mahjong/"
const FONT: Font = preload("res://assets/fonts/mahjong/TRG-Mahjong-Glyphs.ttf")
const NUMERALS: Array[String] = ["一", "二", "三", "四", "五", "六", "七", "八", "九"]
const FACE_SIZE: Vector2i = Vector2i(256, 384)
const CREAM: Color = Color("fff5dc")
static var _art: Dictionary = {}
static var _regions: Dictionary = {}
var tile_id: int = 0
var back: bool = false


static func art(key: String) -> Texture2D:
	if not _art.has(key):
		var path: String = ROOT + key + ".png"
		_art[key] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _art[key]


## Load and measure ink before the slam timeline starts, not at contact time.
static func prepare(tile: int) -> void:
	if tile < 0:
		_region("BACK_LEAF")
		return
	for mark: Dictionary in marks(tile):
		_region(mark.art)


static func _region(key: String) -> Rect2:
	if not _regions.has(key):
		var picture: Texture2D = art(key)
		_regions[key] = PawnArt.visible_region(picture.get_image()) if picture != null else Rect2i()
	return Rect2(_regions[key])


static func model(tile: int) -> Dictionary:
	if tile >= ToolMahjong.HONOR_START:
		return {"id":tile, "suit":3, "rank":0, "glyph":["", "發", "中"][tile-27], "name":ToolMahjong.tile_name(tile)}
	return {"id":tile, "suit":tile/9, "rank":tile%9+1, "glyph":NUMERALS[tile%9] if tile<9 else "", "name":ToolMahjong.tile_name(tile)}


## Each entry is one visible ink mark; count never depends on image generation.
static func marks(tile: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var data: Dictionary = model(tile)
	if data.suit not in [1,2]:
		return result
	var rank: int = data.rank
	if data.suit == 2 and rank == 1:
		return [{"art":"BAMBOO_BIRD", "centre":Vector2(128,192), "size":Vector2(230,280), "angle":0.0}]
	var centres: Array[Vector2] = []
	if rank == 1:
		centres = [Vector2(128,192)]
	elif rank == 2:
		centres = [Vector2(128,104),Vector2(128,280)]
	elif rank == 3:
		if data.suit == 1:
			centres = [Vector2(68,100),Vector2(128,192),Vector2(188,284)]
		else:
			centres = [Vector2(128,98),Vector2(78,272),Vector2(178,272)]
	elif rank <= 5:
		centres = [Vector2(72,104),Vector2(184,104),Vector2(72,280),Vector2(184,280)]
		if rank == 5:
			centres.append(Vector2(128,192))
	elif rank <= 7:
		for y: float in [112.0,200.0,288.0]:
			centres.append(Vector2(72,y))
			centres.append(Vector2(184,y))
		if rank == 7:
			# Upper red mark, with six green marks below in the bamboo suit.
			for index: int in centres.size():
				centres[index].y = 155 + (centres[index].y-112)*0.80
			centres.append(Vector2(128,72))
	elif rank == 8:
		for y: float in [80.0,154.0,228.0,302.0]:
			centres.append(Vector2(74,y))
			centres.append(Vector2(182,y))
	else:
		for y: float in [100.0,192.0,284.0]:
			for x: float in [68.0,128.0,188.0]:
				centres.append(Vector2(x,y))
	for index: int in centres.size():
		var color: String = "GREEN"
		var span: Vector2
		if data.suit == 1:
			if rank == 1 or rank == 8:
				color = "BLUE"
			elif rank == 3:
				color = ["GREEN","RED","BLUE"][index]
			elif rank == 4:
				color = "BLUE" if index in [0,3] else "GREEN"
			elif rank == 5:
				color = "RED" if index == 4 else "BLUE"
			elif rank in [6,7]:
				color = "GREEN" if index < 2 or index == 6 else "RED"
			elif rank == 9:
				color = ["GREEN","RED","BLUE"][index/3]
			span = Vector2.ONE * (178.0 if rank == 1 else (74.0 if rank <= 5 else (54.0 if rank == 9 else 62.0)))
		else:
			if (rank in [5,7] and index == centres.size()-1) or (rank == 9 and index in [3,4,5]):
				color = "RED"
			span = Vector2(62,68 if rank in [7,8] else 80)
		result.append({"art":("DOT_" if data.suit == 1 else "BAMBOO_")+color, "centre":centres[index], "size":span, "angle":0.0})
	return result


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,Vector2(FACE_SIZE)), Color("4b9762") if back else CREAM)
	if back:
		_picture("BACK_LEAF",Rect2(36,100,184,184))
		return
	var data: Dictionary = model(tile_id)
	if data.suit == 0:
		_glyph(data.glyph, 112, 142, Color("274d43"))
		_glyph("萬", 118, 292, Color("bf4b4f"))
	elif data.suit == 3:
		if tile_id != 27: # Japanese white dragon intentionally has a blank face.
			_glyph(data.glyph,164,248,Color("2d8052") if tile_id == 28 else Color("bf4b4f"))
	else:
		for mark: Dictionary in marks(tile_id):
			_picture(mark.art,Rect2(mark.centre-mark.size*0.5,mark.size))


func _glyph(value: String, font_size: int, baseline: float, color: Color) -> void:
	var width: float = FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_string(FONT,Vector2((FACE_SIZE.x-width)*0.5,baseline),value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)


func _picture(key: String, rect: Rect2) -> void:
	var picture: Texture2D = art(key)
	if picture != null:
		var region: Rect2 = _region(key)
		var factor: float = minf(rect.size.x/region.size.x,rect.size.y/region.size.y)
		var fitted: Vector2 = region.size*factor
		draw_texture_rect_region(picture,Rect2(rect.get_center()-fitted*0.5,fitted),region)
