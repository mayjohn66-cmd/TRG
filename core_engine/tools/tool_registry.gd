# File: res://core_engine/tools/tool_registry.gd
# Class: class_name ToolRegistry
# Role: 판정 도구 ID -> 인스턴스 팩토리. 확정된 7종 목록을 제공한다.
class_name ToolRegistry
extends RefCounted

const ALL_IDS: Array[StringName] = [
	&"D6", &"YUT", &"LIFE_ROULETTE", &"HOLDEM", &"HALLI_GALLI", &"SLOT_777", &"REVOLVER",
]


static func create(id: StringName) -> BaseJudgmentTool:
	match id:
		&"D6": return ToolDiceD6.new()
		&"YUT": return ToolYut.new()
		&"LIFE_ROULETTE": return ToolLifeRoulette.new()
		&"HOLDEM": return ToolHoldem.new()
		&"HALLI_GALLI": return ToolHalliGalli.new()
		&"SLOT_777": return ToolSlot777.new()
		&"REVOLVER": return ToolRussianRoulette.new()
	push_error("ToolRegistry: 알 수 없는 도구 ID '%s'" % id)
	return null
