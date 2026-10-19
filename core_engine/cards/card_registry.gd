# File: res://core_engine/cards/card_registry.gd
# Class: class_name CardRegistry
# Role: 카드 ID -> BaseCard 구현 조회와 기본 덱 구성
class_name CardRegistry
extends RefCounted

static var _cache: Dictionary = {}

const DECK_COMPOSITION: Dictionary = {
	&"ACT_01": 2,
	&"ACT_02": 2,
	&"ACT_03": 2,
	&"ACT_04": 2,
	&"ACT_05": 2,
	&"ACT_06": 3,
	&"TRP_01": 2,
	&"TRP_02": 2,
	&"TRP_03": 2,
	&"TRP_04": 2,
	&"TRP_05": 2,
	&"ACT_07": 2,
	&"ACT_08": 2,
	&"ACT_09": 2,
	&"SUM_01": 2,
	&"SUM_02": 1,
}


static func get_card(card_id: StringName) -> BaseCard:
	if _cache.has(card_id):
		var cached: BaseCard = _cache[card_id]
		cached.display_name = GameData.text("cards", card_id, "name", cached.display_name)
		return cached
	var card: BaseCard = null
	match card_id:
		&"ACT_01": card = CardUnoReverse.new()
		&"ACT_02": card = CardBang.new()
		&"ACT_03": card = CardUnoPlusFour.new()
		&"ACT_04": card = CardRocketBooster.new()
		&"ACT_05": card = CardBitesTheDust.new()
		&"ACT_06": card = CardObjection.new()
		&"TRP_01": card = CardMirrorForce.new()
		&"TRP_02": card = CardTrapPit.new()
		&"TRP_03": card = CardMine.new()
		&"TRP_04": card = CardIsland.new()
		&"TRP_05": card = CardDomino.new()
		&"ACT_07": card = CardTower.new()
		&"ACT_08": card = CardWheelOfFortune.new()
		&"ACT_09": card = CardDuel.new()
		&"SUM_01": card = CardBandit.new()
		&"SUM_02": card = CardGhost.new()
	if card == null:
		push_error("CardRegistry: 알 수 없는 카드 ID '%s'" % card_id)
		return null
	_cache[card_id] = card
	card.display_name = GameData.text("cards", card_id, "name", card.display_name)  # cards_table.csv의 name
	return card


## 이 카드가 덱과 카드 패키지 풀에 들어가는가 (cards_table.csv enabled).
static func is_enabled(card_id: StringName) -> bool:
	return GameData.enabled("cards", card_id)


## 카드 한 종류의 덱 장수: cards_table.csv param_2가 있으면 그것, 없으면 코드 기본값. 꺼진 카드는 0장.
static func deck_copies(card_id: StringName) -> int:
	if not is_enabled(card_id):
		return 0
	return maxi(GameData.param("cards", card_id, 2, int(DECK_COMPOSITION.get(card_id, 0))), 0)


## 카드의 수치(param_1). 표에 없거나 비어 있으면 default.
static func param(card_id: StringName, default: int) -> int:
	return GameData.param("cards", card_id, 1, default)


## 구현된 모든 카드 ID (증강 '생떼 카드 패키지'가 무작위로 뽑는 풀).
static func all_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for card_id: StringName in DECK_COMPOSITION.keys():
		if is_enabled(card_id):
			ids.append(card_id)
	return ids


static func default_deck() -> Array[StringName]:
	var deck: Array[StringName] = []
	for card_id: StringName in DECK_COMPOSITION:
		for i: int in deck_copies(card_id):
			deck.append(card_id)
	return deck
