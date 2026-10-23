# File: res://core_engine/augments/augment_registry.gd
# Class: class_name AugmentRegistry
# Role: 증강 드래프트 전체 풀(기물 지급 (세부 기물별) / 판정 도구 교체 12 / 특수 승리 교칙 8 / 카드 패키지 1 / 초증강 12)과 선택지 3개를 4대 카테고리가 섞이도록 뽑는 생성기
class_name AugmentRegistry
extends RefCounted

static var _cache: Array[AugmentDef] = []

## 교체 대상 판정 도구. 기본 주사위(D6)를 제외한 확정 12종이다.
const SWAPPABLE_TOOLS: Array[StringName] = [&"YUT", &"HOLDEM", &"LIFE_ROULETTE", &"CHINCHIRO", &"SLOT_777", &"REVOLVER", &"DICE_HWATU", &"DICE_MAHJONG", &"DICE_TAROT", &"DICE_YACHT", &"DICE_BLACKJACK", &"DICE_PINBALL"]


## 기본 가중치 (augments_table.csv weight가 우선). 계열이 뽑힐 확률은 계열 평균 가중치에 비례한다.
const PAWN_WEIGHT: int = 50
const TOOL_WEIGHT: int = 50
const LAW_WEIGHT: int = 5
const SUPER_WEIGHT: int = 10
const CARD_WEIGHT: int = 50
const UTIL_WEIGHT: int = 85


static func all() -> Array[AugmentDef]:
	if _cache.is_empty():
		# 기물 지급: 세부 기물 하나하나가 별도 선택지다 (윷말 1종 / 체스·장기·모노폴리 4종씩 / 바둑 흑·백 2종).
		for kind: GameEnums.PawnKind in PawnCatalog.EVOLVABLE_SETS:
			for units: Array in PawnCatalog.unit_groups(kind):
				var typed_units: Array[int] = []
				for unit: Variant in units:
					typed_units.append(int(unit))
				var sub_name: String = PawnCatalog.unit_label(kind, typed_units[0])
				var evolution := AugmentDef.new(StringName("EVO_%d_%d" % [kind, typed_units[0]]), GameEnums.AugmentCategory.PAWN_EVOLUTION, "기물 지급: %s" % sub_name, kind, typed_units)
				evolution.weight = PAWN_WEIGHT
				_cache.append(evolution)
		for tool_id: StringName in SWAPPABLE_TOOLS:
			var swap := AugmentDef.new(StringName("TOOL_%s" % tool_id), GameEnums.AugmentCategory.TOOL_SWAP, "판정 도구 교체: %s" % ToolRegistry.create(tool_id).display_name, tool_id)
			swap.weight = TOOL_WEIGHT
			_cache.append(swap)
		for law_id: String in LawRegistry.ALL_IDS:
			var law := AugmentDef.new(StringName("AUG_%s" % law_id), GameEnums.AugmentCategory.LAW_ENACT, "특수 승리: %s" % LawRegistry.create(law_id).law_name, law_id)
			law.tier = "HOLO"  # 가장 드문 계열: 크리스탈 무지개빛 테두리
			law.weight = LAW_WEIGHT  # 특수 승리는 드물게
			law.min_round = 3
			_cache.append(law)
		var package := AugmentDef.new(&"CARD_PACKAGE", GameEnums.AugmentCategory.CARD_PACKAGE, "생떼 카드 패키지")
		package.weight = CARD_WEIGHT
		_cache.append(package)
		for effect: StringName in SuperAugments.ALL_IDS:
			var chaos := AugmentDef.new(effect, GameEnums.AugmentCategory.SUPER_GAMBLE, SuperAugments.display_name(effect), effect)
			chaos.tier = "PRISMA"  # 초증강의 기본 테두리 (표에서 바꿀 수 있다)
			chaos.weight = SUPER_WEIGHT
			_cache.append(chaos)
		for effect: StringName in UtilityAugments.ALL_IDS:
			var utility := AugmentDef.new(effect, GameEnums.AugmentCategory.UTILITY, UtilityAugments.display_name(effect), effect)
			utility.weight = UTIL_WEIGHT
			utility.min_round = 2
			_cache.append(utility)
		_apply_table(_cache)
	return _cache


## 캐시를 비워 다음 all()에서 augments_table.csv(와 override_table로 주입한 행)를 다시 입힌다.
static func reload() -> void:
	_cache = []


## augments_table.csv를 입힌다: 코드에 있는 증강은 행의 값으로 덮어쓰고, 코드에 없는 id의 행은 category·target_ref가 맞으면 새 증강으로 추가한다.
## 새 행으로 만들 수 있는 것: DICE(target_ref=판정 도구 ID), LAW(target_ref=교칙 ID), CARD(카드 패키지, param_1=카드 수). PAWN·CHAOS는 로직이 필요해 새로 만들 수 없다.
static func _apply_table(defs: Array[AugmentDef]) -> void:
	var rows: Dictionary = GameData.table("augments")
	for def: AugmentDef in defs:
		if rows.has(str(def.augment_id)):
			def.apply_row(rows[str(def.augment_id)])
	for id: String in rows:
		var data: Dictionary = rows[id]
		if id.begins_with("RULE_") or defs.any(func(def: AugmentDef) -> bool: return str(def.augment_id) == id):
			continue
		var category_code: String = str(data.get("category", "")).strip_edges().to_upper()
		var target: String = str(data.get("target_ref", "")).strip_edges()
		var made: AugmentDef = null
		match category_code:
			"DICE":
				if ToolRegistry.ALL_IDS.has(StringName(target)):
					made = AugmentDef.new(StringName(id), GameEnums.AugmentCategory.TOOL_SWAP, id, StringName(target))
			"LAW":
				if LawRegistry.ALL_IDS.has(target):
					made = AugmentDef.new(StringName(id), GameEnums.AugmentCategory.LAW_ENACT, id, target)
			"CARD":
				made = AugmentDef.new(StringName(id), GameEnums.AugmentCategory.CARD_PACKAGE, id)
				made.target_ref = target
		if made == null:
			push_warning("augments_table.csv: '%s' 행을 만들 수 없습니다 (category=%s, target_ref=%s)" % [id, category_code, target])
			continue
		made.apply_row(data)
		if made.title != "":
			made.display_name = made.title  # 표에서 새로 만든 증강은 표의 제목을 이름으로 쓴다
		defs.append(made)


static func get_def(augment_id: StringName) -> AugmentDef:
	for def: AugmentDef in all():
		if def.augment_id == augment_id:
			return def
	push_error("AugmentRegistry: 알 수 없는 증강 ID '%s'" % augment_id)
	return null


## 초반 드래프트는 계열을 좁혀 정보량을 줄인다 (단계별 증강 등장): 몇 번째 드래프트 → 그때 제시하는 계열.
## 1번째(1라운드)는 기물 진화만(자기 말에 먼저 애착이 가게), 2번째(4라운드)는 판정 도구·카드·기물 진화. 3번째(7라운드)부터는 제한 없이
## 법전·초증강까지 섞인다 (법전·초증강 행의 min_round도 7). 그 계열에 받을 수 있는 증강이 모자라면 다른 계열로 채운다.
const DRAFT_FOCUS: Dictionary = {
	1: [GameEnums.AugmentCategory.PAWN_EVOLUTION],
	2: [GameEnums.AugmentCategory.TOOL_SWAP, GameEnums.AugmentCategory.CARD_PACKAGE, GameEnums.AugmentCategory.PAWN_EVOLUTION],
}


## 이 라운드가 몇 번째 드래프트인가 (1라운드 = 1번째). 드래프트 라운드가 아니어도 직전 드래프트 번호.
static func draft_number(round_number: int) -> int:
	return maxi(round_number - 1, 0) / GameEnums.DRAFT_INTERVAL + 1


## 이번 드래프트에 제시할 계열 (빈 배열이면 제한 없음).
static func draft_focus(round_number: int) -> Array:
	return DRAFT_FOCUS.get(draft_number(round_number), [])


## 플레이어에게 보여 줄 선택지를 count개 뽑는다. 4대 카테고리를 무작위 순서로 한 번씩 돌며 가능한 증강을 하나씩 뽑으므로
## 선택지가 서로 다른 카테고리로 섞여 나온다. 가능한 카테고리가 부족하면 남은 증강에서 채운다.
static func generate_offers(state: GameState, player_id: int, count: int = GameEnums.DRAFT_OFFER_COUNT) -> Array[StringName]:
	var offers: Array[StringName] = []
	var by_category: Dictionary = {}
	var focus: Array = draft_focus(state.round_number)
	for def: AugmentDef in all():
		if def.is_available(state, player_id) and def.weight > 0 and (focus.is_empty() or focus.has(def.category)):
			if not by_category.has(def.category):
				by_category[def.category] = [] as Array[AugmentDef]
			(by_category[def.category] as Array).append(def)
	# 한 번의 드래프트는 계열이 겹치지 않게 뽑는다. 계열이 뽑힐 가능성은 그 계열 후보들의 평균 가중치에 비례하고(전부 기본 100이면 균등),
	# 초증강처럼 가중치가 낮은 계열은 그만큼 덜 나온다. 계열 안에서는 후보의 가중치 비율로 고른다.
	var categories: Array = by_category.keys()
	while offers.size() < count and not categories.is_empty():
		var weights: Array[float] = []
		for category: Variant in categories:
			var candidates_of: Array = by_category[category]
			var total: float = 0.0
			for def: Variant in candidates_of:
				total += effective_weight(def as AugmentDef, state, player_id)
			weights.append(total / float(candidates_of.size()))
		var chosen: int = _weighted_index(weights, state.rng)
		var picked_category: Variant = categories[chosen]
		categories.remove_at(chosen)
		var pool: Array = by_category[picked_category]
		var pool_weights: Array[float] = []
		for def: Variant in pool:
			pool_weights.append(effective_weight(def as AugmentDef, state, player_id))
		offers.append((pool[_weighted_index(pool_weights, state.rng)] as AugmentDef).augment_id)
	if offers.size() < count:
		# 모자라면 이번 드래프트 계열 안에서 먼저(가중치대로) 채우고, 그래도 모자라면 다른 계열에서 채운다
		var rest: Array[AugmentDef] = []
		var others: Array[AugmentDef] = []
		for def: AugmentDef in all():
			if def.weight > 0 and def.is_available(state, player_id) and not offers.has(def.augment_id):
				if focus.is_empty() or focus.has(def.category):
					rest.append(def)
				else:
					others.append(def)
		_shuffle(rest, state.rng)
		_shuffle(others, state.rng)
		rest.append_array(others)
		for def: AugmentDef in rest:
			if offers.size() >= count:
				break
			offers.append(def.augment_id)
	return offers


## 이미 기본 주사위(D6)가 아닌 특수 판정 도구를 가진 사람에게 판정 도구 교체 증강이 나올 가중치 배수 (도구를 의미 없이 계속 덮어쓰지 않게).
const OWNED_TOOL_SWAP_FACTOR: float = 0.2


## 드래프트에 쓰는 가중치: 표의 weight × 템포 업 배수 (템포 업 1단계 8라운드부터 법전·초증강 ×3).
## player_id를 주면 그 사람이 이미 특수 판정 도구를 가졌을 때 판정 도구 교체 증강을 OWNED_TOOL_SWAP_FACTOR배로 줄인다.
static func effective_weight(def: AugmentDef, state: GameState, player_id: int = -1) -> float:
	var weight: float = float(def.weight * TempoUp.weight_multiplier(state.round_number, def.category))
	if def.category == GameEnums.AugmentCategory.TOOL_SWAP and has_special_tool(state, player_id):
		weight *= OWNED_TOOL_SWAP_FACTOR
	return weight


## 기본 주사위(D6)가 아닌 판정 도구를 쓰고 있는가.
static func has_special_tool(state: GameState, player_id: int) -> bool:
	if player_id < 0 or not state.tools.has(player_id):
		return false
	var tool: BaseJudgmentTool = state.tools[player_id]
	return tool != null and tool.tool_id != &"D6"


## 가중치 배열에서 비율대로 한 칸을 고른다 (합이 0이면 균등). 호스트 RNG만 쓰므로 모든 참가자가 같은 결과를 얻는다.
static func _weighted_index(weights: Array[float], rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for weight: float in weights:
		total += weight
	if total <= 0.0:
		return rng.randi_range(0, weights.size() - 1)
	var roll: float = rng.randf() * total
	var acc: float = 0.0
	for index: int in weights.size():
		acc += weights[index]
		if roll < acc:
			return index
	return weights.size() - 1


## 리롤: 현재 제시된 선택지(current)에 없는 선택 가능 증강 중 하나를 무작위로 뽑는다. 후보가 없으면 빈 ID.
static func reroll_candidate(state: GameState, player_id: int, current: Array) -> StringName:
	var pool: Array[StringName] = []
	var outside: Array[StringName] = []
	var focus: Array = draft_focus(state.round_number)
	for def: AugmentDef in all():
		if def.weight > 0 and def.is_available(state, player_id) and not current.has(def.augment_id):
			if focus.is_empty() or focus.has(def.category):
				pool.append(def.augment_id)
			else:
				outside.append(def.augment_id)
	if pool.is_empty():
		pool = outside  # 이번 드래프트 계열이 바닥나면 다른 계열에서
	if pool.is_empty():
		return &""
	return pool[state.rng.randi_range(0, pool.size() - 1)]


static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i: int in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap
