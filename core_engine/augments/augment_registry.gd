# File: res://core_engine/augments/augment_registry.gd
# Class: class_name AugmentRegistry
# Role: 증강 드래프트 전체 풀(기물 진화 5 / 판정 도구 교체 6 / 교칙 제정 8 / 카드 패키지 1)과 선택지 3개를 4대 카테고리가 섞이도록 뽑는 생성기
class_name AugmentRegistry
extends RefCounted

static var _cache: Array[AugmentDef] = []

## 교체 대상 판정 도구. 기본 주사위(D6)를 제외한 확정 6종이다.
const SWAPPABLE_TOOLS: Array[StringName] = [&"YUT", &"HOLDEM", &"LIFE_ROULETTE", &"HALLI_GALLI", &"SLOT_777", &"REVOLVER"]


static func all() -> Array[AugmentDef]:
	if _cache.is_empty():
		for kind: GameEnums.PawnKind in PawnCatalog.EVOLVABLE_SETS:
			_cache.append(AugmentDef.new(StringName("EVO_%d" % kind), GameEnums.AugmentCategory.PAWN_EVOLUTION, "기물 진화: %s 세트" % PawnCatalog.display_set_name(kind), kind))
		for tool_id: StringName in SWAPPABLE_TOOLS:
			_cache.append(AugmentDef.new(StringName("TOOL_%s" % tool_id), GameEnums.AugmentCategory.TOOL_SWAP, "판정 도구 교체: %s" % ToolRegistry.create(tool_id).display_name, tool_id))
		for law_id: String in LawRegistry.ALL_IDS:
			_cache.append(AugmentDef.new(StringName("AUG_%s" % law_id), GameEnums.AugmentCategory.LAW_ENACT, "교칙 제정: %s" % LawRegistry.create(law_id).law_name, law_id))
		_cache.append(AugmentDef.new(&"CARD_PACKAGE", GameEnums.AugmentCategory.CARD_PACKAGE, "생떼 카드 패키지"))
	return _cache


static func get_def(augment_id: StringName) -> AugmentDef:
	for def: AugmentDef in all():
		if def.augment_id == augment_id:
			return def
	push_error("AugmentRegistry: 알 수 없는 증강 ID '%s'" % augment_id)
	return null


## 플레이어에게 보여 줄 선택지를 count개 뽑는다. 4대 카테고리를 무작위 순서로 한 번씩 돌며 가능한 증강을 하나씩 뽑으므로
## 선택지가 서로 다른 카테고리로 섞여 나온다. 가능한 카테고리가 부족하면 남은 증강에서 채운다.
static func generate_offers(state: GameState, player_id: int, count: int = GameEnums.DRAFT_OFFER_COUNT) -> Array[StringName]:
	var offers: Array[StringName] = []
	var by_category: Dictionary = {}
	for def: AugmentDef in all():
		if def.is_available(state, player_id):
			if not by_category.has(def.category):
				by_category[def.category] = [] as Array[AugmentDef]
			(by_category[def.category] as Array).append(def)
	var categories: Array = by_category.keys()
	_shuffle(categories, state.rng)
	for category: Variant in categories:
		if offers.size() >= count:
			break
		var candidates: Array = by_category[category]
		offers.append((candidates[state.rng.randi_range(0, candidates.size() - 1)] as AugmentDef).augment_id)
	if offers.size() < count:
		var rest: Array[AugmentDef] = []
		for def: AugmentDef in all():
			if def.is_available(state, player_id) and not offers.has(def.augment_id):
				rest.append(def)
		_shuffle(rest, state.rng)
		for def: AugmentDef in rest:
			if offers.size() >= count:
				break
			offers.append(def.augment_id)
	return offers


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i: int in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap
