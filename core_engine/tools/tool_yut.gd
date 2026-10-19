# File: res://core_engine/tools/tool_yut.gd
# Class: class_name ToolYut
# Role: 전통 박달나무 윷 - [특도(+2칸+한 번 더), 도, 개, 걸, 윷, 모] 균등 추첨. 특도(옛 빽도 면)·윷·모는 재굴림
class_name ToolYut
extends BaseJudgmentTool

## 물리 윷의 배(특도) 면을 가리키는 면 번호 (이동은 SPECIAL_STEPS칸이다).
const SPECIAL_FACE: int = -1
const SPECIAL_STEPS: int = 2
const FACES: Array[int] = [-1, 1, 2, 3, 4, 5]


func _init() -> void:
	tool_id = &"YUT"
	display_name = "전통 박달나무 윷"


func roll(rng: RandomNumberGenerator) -> RollResult:
	var face: int = FACES[rng.randi_range(0, FACES.size() - 1)]
	var special: bool = face == SPECIAL_FACE
	var result: RollResult = RollResult.make(tool_id, SPECIAL_STEPS if special else face, {"face": face, "special": special})
	result.reroll = special or face >= 4
	return result
