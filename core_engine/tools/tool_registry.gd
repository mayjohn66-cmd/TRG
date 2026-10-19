# File: res://core_engine/tools/tool_registry.gd
# Class: class_name ToolRegistry
# Role: 판정 도구 ID -> 인스턴스 팩토리. 확정된 13종(친치로·화투·마작·타로·야추·블랙잭·핀볼 포함) 목록을 제공한다.
class_name ToolRegistry
extends RefCounted

const ALL_IDS: Array[StringName] = [
	&"D6", &"YUT", &"LIFE_ROULETTE", &"HOLDEM", &"CHINCHIRO", &"SLOT_777", &"REVOLVER",
	&"DICE_HWATU", &"DICE_MAHJONG", &"DICE_TAROT", &"DICE_YACHT", &"DICE_BLACKJACK", &"DICE_PINBALL",
]


static func create(id: StringName) -> BaseJudgmentTool:
	var tool: BaseJudgmentTool = _create_default(id)
	if tool != null:
		tool.display_name = GameData.text("dice", id, "name", tool.display_name)  # dice_table.csv의 name
	return tool


static func _create_default(id: StringName) -> BaseJudgmentTool:
	match id:
		&"D6": return ToolDiceD6.new()
		&"YUT": return ToolYut.new()
		&"LIFE_ROULETTE": return ToolLifeRoulette.new()
		&"HOLDEM": return ToolHoldem.new()
		&"CHINCHIRO": return ToolChinchiro.new()
		&"SLOT_777": return ToolSlot777.new()
		&"REVOLVER": return ToolRussianRoulette.new()
		&"DICE_HWATU": return ToolHwatu.new()
		&"DICE_MAHJONG": return ToolMahjong.new()
		&"DICE_TAROT": return ToolTarot.new()
		&"DICE_YACHT": return ToolYacht.new()
		&"DICE_BLACKJACK": return ToolBlackjack.new()
		&"DICE_PINBALL": return ToolPinball.new()
	push_error("ToolRegistry: 알 수 없는 도구 ID '%s'" % id)
	return null


## 증강 선택 카드에 보여 줄 눈금·족보별 이동 칸수 표 (한 줄). 어떤 주사위인지 모르고 고르지 않도록 모든 도구의 칸수를 구체적으로 적는다.
const TABLES: Dictionary = {
	&"D6": "눈금표: 1~6 (나온 눈금만큼 전진)",
	&"YUT": "눈금표: 특도(2칸+한번더) / 도(1) / 개(2) / 걸(3) / 윷(4칸+한번더) / 모(5칸+한번더)",
	&"LIFE_ROULETTE": "눈금표: 1~10 균등 (나온 숫자만큼) / ★7 당첨(7칸+한번더)",
	&"HOLDEM": "족보표: 노페어(1) / 원페어(3) / 투페어(5) / 트리플(7) / 스트레이트(10) / 플러시+(15칸)",
	&"CHINCHIRO": "눈금표: 4(2/6) / 5(2/6) / 6(1/6) / 삐끗(1/6) 이번 이동 0칸",
	&"SLOT_777": "족보표: 꽝(1) / 2일치(4) / 3일치(8) / ★777 잭팟(20칸!)",
	&"REVOLVER": "누적표: 방아쇠 1회 +3칸(최대 15) / 폭죽(6분의 1) 0칸·턴 종료 / 멈추면 누적 칸만큼",
	&"DICE_HWATU": "족보표: 망통(0칸·턴 종료) / 1~3끗(2) / 4~6끗(3) / 7~9끗(4) / 1~6땡(6) / 7~9땡(7) / 장땡·광땡(8칸)",
	&"DICE_MAHJONG": "족보표: 핑후(2) / 또이츠(3) / 슌쯔(5) / 커쯔(8) / ★역만(12칸+한번더)",
	&"DICE_TAROT": "족보표: 광대(헛발질 0 또는 +7) / 전차(6) / 수레바퀴(4+한번더) / 매달린 남자(1+다음 +8) / 세계(9칸)",
	&"DICE_YACHT": "족보표: 찬스(1~3) / 트리플(5) / 풀하·4연속(7) / 포카드·5연속(9) / ★야추(12칸+한번더)",
	&"DICE_BLACKJACK": "족보표: 11~20 스탠드 시 (합계-10)칸 / ★21 달성(11칸+한번더) / 22↑ 버스트(0칸)",
	&"DICE_PINBALL": "구멍표: [2][4][6][★10][5][3][1] 골인한 숫자만큼 (1~10칸)",
}


## 눈금·족보 표 문구: dice_table.csv의 spec_table이 있으면 그것, 없으면 코드 기본값.
static func spec_text(id: StringName) -> String:
	return GameData.text("dice", id, "spec_table", str(TABLES.get(id, "눈금표: 나온 눈금만큼 전진")))


static func table_line(id: StringName) -> String:
	return "• %s" % spec_text(id)


## 각 도구에서 가장 높은 결과(잭팟)의 기본 칸 수. dice_table.csv의 jackpot_step이 비어 있지 않으면 이 칸 수 결과를 그 값으로 바꾼다.
const NATURAL_JACKPOT: Dictionary = {
	&"YUT": 5, &"HOLDEM": 15, &"SLOT_777": 20, &"DICE_HWATU": 8, &"DICE_MAHJONG": 12,
	&"DICE_YACHT": 12, &"DICE_BLACKJACK": 11, &"DICE_PINBALL": 10,
}


## dice_table.csv의 min_step·max_step·jackpot_step을 한 번의 굴림 결과에 적용한다. 이동이 있는 확정 결과(칸 수 > 0)에만 작용하고, 표 값이 비어 있으면 아무것도 바꾸지 않는다.
static func adjust_result(result: RollResult) -> void:
	if result == null or result.ends_turn or result.can_continue or result.steps <= 0:
		return
	var id: StringName = result.tool_id
	var natural: int = result.steps
	var floor_steps: int = GameData.param("dice", id, 1, 0)
	var cap_steps: int = GameData.param("dice", id, 2, 0)
	if floor_steps > 0:
		result.steps = maxi(result.steps, floor_steps)
	if cap_steps > 0:
		result.steps = mini(result.steps, cap_steps)
	# 잭팟 칸 수는 max_step 상한과 상관없이 정확히 jackpot_step이 된다 (잭팟을 올리려고 max_step까지 같이 고치지 않아도 된다).
	var jackpot: int = GameData.param("dice", id, 3, 0)
	if jackpot > 0 and NATURAL_JACKPOT.has(id) and natural == int(NATURAL_JACKPOT[id]):
		result.steps = jackpot
