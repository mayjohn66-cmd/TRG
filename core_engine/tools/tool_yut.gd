# File: res://core_engine/tools/tool_yut.gd
# Class: class_name ToolYut
# Role: 전통 박달나무 윷 - [-1(빽도), 1, 2, 3, 4, 5] 균등 추첨, 4·5가 나오면 재굴림
class_name ToolYut
extends BaseJudgmentTool

const FACES: Array[int] = [-1, 1, 2, 3, 4, 5]


func _init() -> void:
	tool_id = &"YUT"
	display_name = "전통 박달나무 윷"


func roll(rng: RandomNumberGenerator) -> RollResult:
	var face: int = FACES[rng.randi_range(0, FACES.size() - 1)]
	var result: RollResult = RollResult.make(tool_id, face, {"face": face})
	result.reroll = face >= 4
	return result
