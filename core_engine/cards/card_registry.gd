# File: res://core_engine/cards/card_registry.gd
# Class: class_name CardRegistry
# Role: 카드 ID -> BaseCard 구현 조회와 기본 덱 구성
class_name CardRegistry
extends RefCounted

static var _cache: Dictionary = {}

const DECK_COMPOSITION: Dictionary = {
	&"ACT_01": 2,
	&"ACT_04": 2,
	&"ACT_05": 2,
	&"ACT_06": 3,
	&"TRP_01": 3,
}


static func get_card(card_id: StringName) -> BaseCard:
	if _cache.has(card_id):
		return _cache[card_id]
	var card: BaseCard = null
	match card_id:
		&"ACT_01": card = CardUnoReverse.new()
		&"ACT_04": card = CardBackdoGoal.new()
		&"ACT_05": card = CardBitesTheDust.new()
		&"ACT_06": card = CardObjection.new()
		&"TRP_01": card = CardMirrorForce.new()
	if card == null:
		push_error("CardRegistry: 알 수 없는 카드 ID '%s'" % card_id)
		return null
	_cache[card_id] = card
	return card


static func default_deck() -> Array[StringName]:
	var deck: Array[StringName] = []
	for card_id: StringName in DECK_COMPOSITION:
		for i: int in int(DECK_COMPOSITION[card_id]):
			deck.append(card_id)
	return deck
