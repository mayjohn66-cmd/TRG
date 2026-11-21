# File: res://tests/scripted_tool.gd
# Class: class_name ScriptedTool
# Role: 테스트용 판정 도구. 미리 넣어 둔 결과를 순서대로 돌려줘 TurnManager 흐름을 결정적으로 검증한다
class_name ScriptedTool
extends BaseJudgmentTool

var queue: Array[RollResult] = []


func _init(results: Array = []) -> void:
	tool_id = &"SCRIPTED"
	for value: Variant in results:
		if value is RollResult:
			queue.append(value)
		else:
			queue.append(RollResult.make(tool_id, int(value)))


func roll(_rng: RandomNumberGenerator) -> RollResult:
	return queue.pop_front()


static func reroll_of(steps: int) -> RollResult:
	var result: RollResult = RollResult.make(&"SCRIPTED", steps)
	result.reroll = true
	return result
