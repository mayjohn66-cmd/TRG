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


static func table_line(id: StringName) -> String:
	return "• %s" % TABLES.get(id, "눈금표: 나온 눈금만큼 전진")
