## Card identities come from the rule engine. Images are shared decorations;
## ranks, months and types remain exact live text rather than generated text.
class_name JudgmentCardArt
extends RefCounted

const ROOT: String = "res://assets/ui/trickcal/judgment_cards/"
const SUITS: Array[String] = ["CLUB", "DIAMOND", "HEART", "SPADE"]
const RANKS: Array[String] = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const TAROT: Dictionary = {
	&"fool": ["0", "광대"], &"chariot": ["VII", "전차"],
	&"wheel": ["X", "운명의 수레바퀴"], &"hanged": ["XII", "매달린 남자"], &"world": ["XXI", "세계"],
}
const TYPE_NAMES: Dictionary = {&"gwang":"광", &"yeol":"열끗", &"tti":"띠", &"pi":"피"}
static var _textures: Dictionary = {}


static func poker(card: int) -> Dictionary:
	var suit: int = card / 13
	return {"tool": &"HOLDEM", "id":card, "rank":RANKS[card % 13], "suit":suit,
		"art":"suits/SUIT_%s" % SUITS[suit], "back":"backs/POKER_BACK"}


static func hwatu(card: int) -> Dictionary:
	return {"tool": &"DICE_HWATU", "id":card, "month":ToolHwatu.month_of(card),
		"type":ToolHwatu.card_type(card), "art":"hwatu/HWATU_%02d" % ToolHwatu.month_of(card), "back":"backs/HWATU_BACK"}


static func tarot(fate: StringName = &"") -> Dictionary:
	return {"tool": &"DICE_TAROT", "fate":fate,
		"art":"tarot/TAROT_%s" % str(fate).to_upper() if TAROT.has(fate) else "", "back":"backs/TAROT_BACK"}


static func texture(asset: String) -> Texture2D:
	if asset.is_empty():
		return null
	if not _textures.has(asset):
		var path: String = ROOT + asset + ".png"
		_textures[asset] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[asset]


static func pip_positions(rank: int) -> Array[Vector2]:
	# Local normalized centres inside the playing card's middle field.
	var points: Array[Vector2] = []
	if rank == 1:
		return [Vector2(0.5, 0.5)]
	if rank <= 3:
		points = [Vector2(0.5, 0.22), Vector2(0.5, 0.78)]
		if rank == 3:
			points.append(Vector2(0.5, 0.5))
		return points
	var rows: Array = [0.22, 0.78] if rank <= 5 else ([0.22, 0.5, 0.78] if rank <= 8 else [0.17, 0.39, 0.61, 0.83])
	for y: float in rows:
		points.append(Vector2(0.28, y))
		points.append(Vector2(0.72, y))
	if rank == 5 or rank == 9:
		points.append(Vector2(0.5, 0.5))
	elif rank == 7:
		points.append(Vector2(0.5, 0.36))
	elif rank == 8 or rank == 10:
		points.append(Vector2(0.5, 0.32))
		points.append(Vector2(0.5, 0.68))
	return points
