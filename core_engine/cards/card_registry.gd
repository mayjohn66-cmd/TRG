# File: res://core_engine/cards/card_registry.gd
# Class: class_name CardRegistry
# Role: 카드 ID -> BaseCard 구현 조회와 기본 덱 구성
class_name CardRegistry
extends RefCounted

static var _cache: Dictionary = {}

## v4.0 카드 32종: 방어 7 · 즉발 13 · 함정 6 · 코너 함정 4 · 소환 2. 값은 기본 덱 장수 (cards_table.csv param_2가 우선).
const DECK_COMPOSITION: Dictionary = {
	&"CNT_01": 1, &"CNT_02": 2, &"CNT_03": 2, &"CNT_04": 2, &"CNT_05": 1, &"CNT_06": 1, &"CNT_07": 1,
	&"ACT_02": 2, &"ACT_03": 2, &"ACT_04": 2, &"ACT_06": 2, &"ACT_07": 2, &"ACT_08": 2, &"ACT_09": 2,
	&"ACT_10": 2, &"ACT_11": 1, &"ACT_12": 1, &"ACT_13": 2, &"ACT_14": 1, &"ACT_15": 2,
	&"TRP_02": 2, &"TRP_03": 2, &"TRP_05": 2, &"TRP_06": 2, &"TRP_07": 2, &"TRP_08": 1,
	&"TRP_C01": 1, &"TRP_C02": 1, &"TRP_C03": 1, &"TRP_C04": 1,
	&"SUM_01": 1, &"SUM_02": 1,
}


static func get_card(card_id: StringName) -> BaseCard:
	if _cache.has(card_id):
		var cached: BaseCard = _cache[card_id]
		cached.display_name = GameData.text("cards", card_id, "name", cached.display_name)
		return cached
	var card: BaseCard = null
	match card_id:
		&"CNT_01", &"CNT_02", &"CNT_03", &"CNT_04", &"CNT_05", &"CNT_06", &"CNT_07": card = CardCounter.new(card_id)
		&"ACT_02": card = CardBang.new()
		&"ACT_03": card = CardUnoPlusFour.new()
		&"ACT_04": card = CardRocketBooster.new()
		&"ACT_06": card = CardObjection.new()
		&"ACT_07": card = CardTower.new()
		&"ACT_08": card = CardWheelOfFortune.new()
		&"ACT_09": card = CardDuel.new()
		&"ACT_10": card = CardCrowbar.new()
		&"ACT_11", &"ACT_12", &"ACT_14", &"ACT_15": card = CardStatus.new(card_id)
		&"ACT_13": card = CardDoor.new()
		&"TRP_02": card = CardTrapPit.new()
		&"TRP_03": card = CardMine.new()
		&"TRP_05": card = CardDomino.new()
		&"TRP_06", &"TRP_07", &"TRP_08", &"TRP_C02", &"TRP_C03", &"TRP_C04": card = CardTrap.new(card_id)
		&"TRP_C01": card = CardIsland.new()
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


## cards_table.csv type 열의 카드 종류.
const CARD_TYPES: Array[String] = ["COUNTER", "INSTANT", "TRAP", "TRAP_CORNER", "SUMMON"]


## 이 카드의 종류 (cards_table.csv type, 표에 없으면 ID 머리글자로 추정).
static func type_of(card_id: StringName) -> String:
	var code: String = GameData.text("cards", card_id, "type").strip_edges().to_upper()
	if CARD_TYPES.has(code):
		return code
	var id: String = String(card_id)
	if id.begins_with("CNT_"): return "COUNTER"
	if id.begins_with("TRP_C"): return "TRAP_CORNER"
	if id.begins_with("TRP_"): return "TRAP"
	if id.begins_with("SUM_"): return "SUMMON"
	return "INSTANT"


## 켜진 카드 중 이 종류인 카드 ID들 (방어 보급·공병 보급 패키지 풀).
static func ids_of_type(type_code: String) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card_id: StringName in all_ids():
		if type_of(card_id) == type_code:
			ids.append(card_id)
	return ids


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
