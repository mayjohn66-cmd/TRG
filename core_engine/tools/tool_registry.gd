# File: res://core_engine/tools/tool_registry.gd
# Class: class_name ToolRegistry
# Role: 판정 도구 ID -> 인스턴스 팩토리. 확정된 10종(친치로·화투·마작·타로 포함) 목록을 제공한다.
class_name ToolRegistry
extends RefCounted

const ALL_IDS: Array[StringName] = [
	&"D6", &"YUT", &"LIFE_ROULETTE", &"HOLDEM", &"CHINCHIRO", &"SLOT_777", &"REVOLVER",
	&"DICE_HWATU", &"DICE_MAHJONG", &"DICE_TAROT",
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
	push_error("ToolRegistry: 알 수 없는 도구 ID '%s'" % id)
	return null
