# File: res://core_engine/augments/augment_def.gd
# Class: class_name AugmentDef
# Role: 라운드 시작 증강 드래프트의 선택지 하나. 기물 진화 / 판정 도구 교체 / 교칙 제정 / 생떼 카드 패키지 중 하나의 효과를 정의하고 적용한다
class_name AugmentDef
extends RefCounted

var augment_id: StringName = &""
var category: GameEnums.AugmentCategory = GameEnums.AugmentCategory.CARD_PACKAGE
var display_name: String = ""
## 진화한 세트(PawnKind) / 판정 도구 ID / 교칙 ID 중 카테고리에 맞는 값.
var payload: Variant = null
## 기물 지급 증강에서 이 선택지가 주는 세부 기물의 호기 번호들 (같은 병종이 여러 호기일 수 있다: 바둑 흑돌 = 1·3호기).
var units: Array[int] = []

# --- augments_table.csv가 덮어쓰는 값 (표에 행이 없으면 기본값 그대로) -----------------------------------
## FALSE면 드래프트 풀에서 제외된다.
var enabled: bool = true
## NORMAL / GOLD / PRISMA / HOLO: 선택 카드 테두리 연출 (HOLO = 법전(교칙 제정) 전용, 가장 희귀한 크리스탈 무지개빛).
var tier: String = "NORMAL"
## 드래프트 등장 가중치(기본 100). 같은 계열 안에서 후보를 고르는 비율과, 계열이 뽑히는 비율에 쓰인다.
var weight: int = 100
## 이 라운드부터 등장한다.
var min_round: int = 1
## 선택 카드 제목·계열 표시·설명·족보 요약 (비어 있으면 코드의 기본 문구).
var title: String = ""
var subtitle: String = ""
var desc: String = ""
var spec_preview: String = ""
var param_1: String = ""
var param_2: String = ""
var target_ref: String = ""
var icon_file: String = ""


func _init(id: StringName, augment_category: GameEnums.AugmentCategory, name: String, value: Variant = null, unit_list: Array[int] = []) -> void:
	augment_id = id
	category = augment_category
	display_name = name
	payload = value
	units = unit_list


static func category_name(value: GameEnums.AugmentCategory) -> String:
	match value:
		GameEnums.AugmentCategory.PAWN_EVOLUTION: return "기물 진화"
		GameEnums.AugmentCategory.TOOL_SWAP: return "판정 도구 교체"
		GameEnums.AugmentCategory.LAW_ENACT: return "교칙 제정"
		GameEnums.AugmentCategory.SUPER_GAMBLE: return "초증강 : 하이리스크 하이리턴"
		GameEnums.AugmentCategory.UTILITY: return "범용 보급"
	return "생떼 카드 패키지"


## 이 선택지가 줄 수 있는, 아직 받지 않은 호기 번호들.
func _free_units_for(state: GameState, player_id: int) -> Array[int]:
	var free: Array[int] = state.free_units(player_id, payload)
	var result: Array[int] = []
	for unit: int in units:
		if free.has(unit):
			result.append(unit)
	return result


## 이 플레이어에게 지금 제시할 수 있는 선택지인가.
func is_available(state: GameState, player_id: int) -> bool:
	if not enabled or state.round_number < min_round:
		return false
	match category:
		GameEnums.AugmentCategory.PAWN_EVOLUTION:
			# 이미 그 세부 기물을 가지고 있으면(받을 호기가 남아 있지 않으면) 받을 수 없다.
			return not state.basic_pawns_of(player_id).is_empty() and not _free_units_for(state, player_id).is_empty()
		GameEnums.AugmentCategory.TOOL_SWAP:
			return (state.tools[player_id] as BaseJudgmentTool).tool_id != payload and GameData.enabled("dice", payload)
		GameEnums.AugmentCategory.LAW_ENACT:
			return not state.rulebook.has_law(payload)
		GameEnums.AugmentCategory.SUPER_GAMBLE:
			return SuperAugments.is_available(payload, state, player_id)
		GameEnums.AugmentCategory.UTILITY:
			return UtilityAugments.is_available(payload, state, player_id)
		GameEnums.AugmentCategory.CARD_PACKAGE:
			# 손패가 가득 차 있으면 받을 수 없어 선택해도 적용되지 않는다 (드래프트가 멈추는 것을 막는다).
			if (state.hands[player_id] as Array).size() >= GameEnums.MAX_HAND_SIZE:
				return false
			for pool: Array[StringName] in card_pools():
				if pool.is_empty():
					return false
			return true
	return true


## 적용 전에 플레이어가 기본 말 중 하나를 직접 골라야 하는가 (기본 말이 둘 이상일 때의 기물 진화).
func needs_pawn_choice(state: GameState, player_id: int) -> bool:
	return category == GameEnums.AugmentCategory.PAWN_EVOLUTION and state.basic_pawns_of(player_id).size() > 1


## 선택지에 보여 줄 설명 (플레이어 상태를 반영한다).
func describe(state: GameState, player_id: int) -> String:
	if desc.strip_edges() != "":
		return _table_text(state, player_id)
	return _default_text(state, player_id)


## CSV의 desc(+spec_preview)를 쓴다. {p1}·{p2}는 param_1·param_2 값으로 바뀐다. 판정 도구는 spec_preview가 비어 있으면 dice_table.csv의 spec_table을 붙인다.
func _table_text(state: GameState, _player_id: int) -> String:
	var text: String = desc.replace("{p1}", param_1).replace("{p2}", param_2)
	var spec: String = spec_preview.replace("{p1}", param_1).replace("{p2}", param_2)
	if spec.strip_edges() == "" and category == GameEnums.AugmentCategory.TOOL_SWAP:
		spec = "• " + ToolRegistry.spec_text(payload)
	if spec.strip_edges() != "":
		text += "\n" + spec
	if category == GameEnums.AugmentCategory.PAWN_EVOLUTION and not text.contains("※"):
		text += "\n※ 이미 가진 기물은 받을 수 없습니다"
	return text


func _default_text(state: GameState, player_id: int) -> String:
	match category:
		GameEnums.AugmentCategory.PAWN_EVOLUTION:
			var kind: GameEnums.PawnKind = payload
			var skill: StringName = PawnCatalog.skill_of(PawnCatalog.sub_type_of(kind, units[0]))
			var text: String = "◆ 기본 말 1개 → [%s] %s\n◆ 패시브: %s" % [PawnCatalog.display_set_name(kind), PawnCatalog.unit_label(kind, units[0]).split(":")[-1], PawnCatalog.ability_text(kind, units[0])]
			if skill != &"":
				text += "\n◆ [1회] %s: %s" % [PawnCatalog.skill_name(skill), PawnCatalog.skill_text(skill)]
			return text + "\n※ 이미 가진 기물은 받을 수 없습니다"
		GameEnums.AugmentCategory.TOOL_SWAP:
			return "◆ 내 판정 도구 즉시 교체\n%s" % ToolRegistry.table_line(payload)
		GameEnums.AugmentCategory.LAW_ENACT:
			var law: LawResource = LawRegistry.create(payload)
			return "◆ 승리 조건: %s\n◆ 라운드가 끝날 때 달성해 있으면 다음 순위로 졸업 (달성되면 법전에서 삭제)\n◆ 법전 4칸 (초과 시 가장 오래된 교칙 삭제)\n◆ 법전 슬롯에 마우스를 올리면 모두의 진행도" % law.description
		GameEnums.AugmentCategory.SUPER_GAMBLE:
			return SuperAugments.describe(payload)
		GameEnums.AugmentCategory.UTILITY:
			return UtilityAugments.describe(payload)
	return "◆ 무작위 생떼 카드 %d장 획득" % card_count()


## 증강을 적용한다. params["pawn_id"]로 진화할 기본 말을 지정할 수 있고, 생략하면 슬롯 번호가 가장 낮은 기본 말을 쓴다.
## 반환: {"ok": bool, "text": String}
func apply(state: GameState, player_id: int, params: Dictionary = {}) -> Dictionary:
	match category:
		GameEnums.AugmentCategory.PAWN_EVOLUTION: return _apply_evolution(state, player_id, params)
		GameEnums.AugmentCategory.TOOL_SWAP: return _apply_tool(state, player_id)
		GameEnums.AugmentCategory.LAW_ENACT: return _apply_law(state)
		GameEnums.AugmentCategory.SUPER_GAMBLE: return SuperAugments.apply(payload, state, player_id)
		GameEnums.AugmentCategory.UTILITY: return UtilityAugments.apply(payload, state, player_id)
	return _apply_cards(state, player_id)


func _apply_evolution(state: GameState, player_id: int, params: Dictionary) -> Dictionary:
	var pawn: PlayerPawn = null
	if params.has("pawn_id"):
		pawn = state.get_pawn(int(params["pawn_id"]))
		if pawn == null or pawn.owner_id != player_id or pawn.kind != GameEnums.PawnKind.BASIC:
			return {"ok": false, "text": "진화시킬 수 없는 말입니다"}
	else:
		var basics: Array[PlayerPawn] = state.basic_pawns_of(player_id)
		if basics.is_empty():
			return {"ok": false, "text": "진화시킬 기본 말이 없습니다"}
		pawn = basics[0]
	if not state.give_unit(pawn, payload, _free_units_for(state, player_id)):
		return {"ok": false, "text": "이미 가지고 있는 기물이라 받을 수 없습니다"}
	return {"ok": true, "text": "말 %d번이 [%s] 기물로 바뀌었습니다" % [pawn.slot, pawn.display_label()]}


func _apply_tool(state: GameState, player_id: int) -> Dictionary:
	var tool: BaseJudgmentTool = ToolRegistry.create(payload)
	state.tools[player_id] = tool
	return {"ok": true, "text": "판정 도구가 [%s](으)로 바뀌었습니다" % tool.display_name}


func _apply_law(state: GameState) -> Dictionary:
	var law: LawResource = LawRegistry.create(payload)
	SpecialVictory.on_law_enacted(state, law)
	state.rulebook.enqueue_law(law)
	return {"ok": true, "text": "특수 승리 교칙 [%s] 제정: %s" % [law.law_name, law.description]}


func _apply_cards(state: GameState, player_id: int) -> Dictionary:
	var names: Array[String] = []
	var pools: Array = card_pools()
	var counts: Array[int] = card_counts()
	for index: int in pools.size():
		var pool: Array[StringName] = pools[index]
		if pool.is_empty():
			return {"ok": false, "text": "받을 수 있는 생떼 카드가 없습니다"}
		for i: int in counts[index]:
			var picked: StringName = pool[state.rng.randi_range(0, pool.size() - 1)]
			if state.give_card(player_id, picked):
				names.append(CardRegistry.get_card(picked).display_name)
	return {"ok": not names.is_empty(), "text": "생떼 카드 획득: %s" % ", ".join(names)}


## 카드 패키지가 주는 카드 수 (augments_table.csv param_1, 기본 2).
func card_count() -> int:
	return maxi(DataTable.to_int(param_1, 2), 0)


## 카드 패키지의 카드 풀들: target_ref가 카드 종류(COUNTER / TRAP / TRAP_CORNER / INSTANT / SUMMON)면 그 종류만,
## "TRAP_CORNER+TRAP"처럼 +로 이으면 풀이 여러 개이고 각각 param_1·param_2장씩 준다. 그 밖(CARD_PACKAGE 등)은 모든 카드.
func card_pools() -> Array:
	var pools: Array = []
	for type_code: String in _card_types():
		pools.append(CardRegistry.all_ids() if type_code == "" else CardRegistry.ids_of_type(type_code))
	return pools


## card_pools()와 같은 순서의 장수 (첫 풀 param_1, 둘째 풀 param_2, 비어 있으면 1장).
func card_counts() -> Array[int]:
	var types: Array[String] = _card_types()
	if types.size() == 1:
		return [card_count()] as Array[int]
	var counts: Array[int] = []
	for index: int in types.size():
		counts.append(maxi(DataTable.to_int([param_1, param_2][mini(index, 1)], 1), 0))
	return counts


func _card_types() -> Array[String]:
	var types: Array[String] = []
	for part: String in target_ref.to_upper().split("+", false):
		if CardRegistry.CARD_TYPES.has(part.strip_edges()):
			types.append(part.strip_edges())
	if types.is_empty():
		types.append("")
	return types


## 표의 한 행을 이 증강에 입힌다.
func apply_row(data: Dictionary) -> void:
	enabled = DataTable.to_bool(data.get("enabled", "TRUE"), true)
	tier = str(data.get("tier", "NORMAL")).strip_edges().to_upper()
	if not ["NORMAL", "GOLD", "PRISMA", "HOLO"].has(tier):
		tier = "NORMAL"
	weight = maxi(DataTable.to_int(data.get("weight", ""), 100), 0)
	min_round = maxi(DataTable.to_int(data.get("min_round", ""), 1), 1)
	param_1 = str(data.get("param_1", "")).strip_edges()
	param_2 = str(data.get("param_2", "")).strip_edges()
	# 문구 열은 현재 언어의 번역 열(title_en 등)을 먼저 쓰고, 비어 있으면 한국어 열 (L10n.pick)
	title = L10n.pick(data, "title").strip_edges().replace("{p1}", param_1).replace("{p2}", param_2)
	subtitle = L10n.pick(data, "subtitle").strip_edges()
	desc = L10n.pick(data, "desc")
	spec_preview = L10n.pick(data, "spec_preview")
	param_1 = str(data.get("param_1", "")).strip_edges()
	param_2 = str(data.get("param_2", "")).strip_edges()
	target_ref = str(data.get("target_ref", "")).strip_edges()
	icon_file = str(data.get("icon_file", "")).strip_edges()
