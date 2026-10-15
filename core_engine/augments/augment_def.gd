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


func _init(id: StringName, augment_category: GameEnums.AugmentCategory, name: String, value: Variant = null) -> void:
	augment_id = id
	category = augment_category
	display_name = name
	payload = value


static func category_name(value: GameEnums.AugmentCategory) -> String:
	match value:
		GameEnums.AugmentCategory.PAWN_EVOLUTION: return "기물 진화"
		GameEnums.AugmentCategory.TOOL_SWAP: return "판정 도구 교체"
		GameEnums.AugmentCategory.LAW_ENACT: return "교칙 제정"
	return "생떼 카드 패키지"


## 이 플레이어에게 지금 제시할 수 있는 선택지인가.
func is_available(state: GameState, player_id: int) -> bool:
	match category:
		GameEnums.AugmentCategory.PAWN_EVOLUTION:
			return not state.basic_pawns_of(player_id).is_empty() and state.set_count(player_id, payload) < GameEnums.PAWNS_PER_PLAYER
		GameEnums.AugmentCategory.TOOL_SWAP:
			return (state.tools[player_id] as BaseJudgmentTool).tool_id != payload
		GameEnums.AugmentCategory.LAW_ENACT:
			return not state.rulebook.has_law(payload)
	return true


## 적용 전에 플레이어가 기본 말 중 하나를 직접 골라야 하는가 (기본 말이 둘 이상일 때의 기물 진화).
func needs_pawn_choice(state: GameState, player_id: int) -> bool:
	return category == GameEnums.AugmentCategory.PAWN_EVOLUTION and state.basic_pawns_of(player_id).size() > 1


## 선택지에 보여 줄 설명 (플레이어 상태를 반영한다).
func describe(state: GameState, player_id: int) -> String:
	match category:
		GameEnums.AugmentCategory.PAWN_EVOLUTION:
			var names: Array[String] = []
			for unit: int in state.free_units(player_id, payload):
				var sub_name: String = PawnCatalog.unit_label(payload, unit).split(":")[-1]
				if not names.has(sub_name):
					names.append(sub_name)
			return "기본 말 1개를 [%s] 기물 중 무작위 1종으로 영구 진화 - 남은 후보: %s (현재 %d/4)" % [PawnCatalog.display_set_name(payload), "/".join(names), state.set_count(player_id, payload)]
		GameEnums.AugmentCategory.TOOL_SWAP:
			return "내 판정 도구를 [%s](으)로 교체" % ToolRegistry.create(payload).display_name
		GameEnums.AugmentCategory.LAW_ENACT:
			var law: LawResource = LawRegistry.create(payload)
			return "%s\n중앙 법전에 즉시 등록 (가득 차면 가장 오래된 교칙이 밀려남)" % law.description
	return "무작위 생떼 카드 2장을 손패에 획득"


## 증강을 적용한다. params["pawn_id"]로 진화할 기본 말을 지정할 수 있고, 생략하면 슬롯 번호가 가장 낮은 기본 말을 쓴다.
## 반환: {"ok": bool, "text": String}
func apply(state: GameState, player_id: int, params: Dictionary = {}) -> Dictionary:
	match category:
		GameEnums.AugmentCategory.PAWN_EVOLUTION: return _apply_evolution(state, player_id, params)
		GameEnums.AugmentCategory.TOOL_SWAP: return _apply_tool(state, player_id)
		GameEnums.AugmentCategory.LAW_ENACT: return _apply_law(state)
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
	if not state.evolve_pawn_random(pawn, payload):
		return {"ok": false, "text": "이 세트는 더 진화할 수 없습니다"}
	return {"ok": true, "text": "말 %d번이 [%s]로 진화했습니다" % [pawn.slot, pawn.display_label()]}


func _apply_tool(state: GameState, player_id: int) -> Dictionary:
	var tool: BaseJudgmentTool = ToolRegistry.create(payload)
	if tool is ToolHalliGalli:
		tool.on_turn_begin(state.rng)
	state.tools[player_id] = tool
	return {"ok": true, "text": "판정 도구가 [%s](으)로 바뀌었습니다" % tool.display_name}


func _apply_law(state: GameState) -> Dictionary:
	var law: LawResource = LawRegistry.create(payload)
	state.rulebook.enqueue_law(law)
	return {"ok": true, "text": "교칙 [%s] %s 제정" % [law.law_id, law.law_name]}


func _apply_cards(state: GameState, player_id: int) -> Dictionary:
	var pool: Array[StringName] = CardRegistry.all_ids()
	var names: Array[String] = []
	for i: int in 2:
		var picked: StringName = pool[state.rng.randi_range(0, pool.size() - 1)]
		if state.give_card(player_id, picked):
			names.append(CardRegistry.get_card(picked).display_name)
	return {"ok": not names.is_empty(), "text": "생떼 카드 획득: %s" % ", ".join(names)}
