# File: res://core_engine/tools/tool_yut.gd
# Class: class_name ToolYut
# Role: 전통 박달나무 윷 - [낙, 도, 개, 걸, 윷, 모] 균등 추첨. 낙(윷가락이 판 밖으로)은 0칸 + 턴 종료, 윷·모는 재굴림
class_name ToolYut
extends BaseJudgmentTool

## 윷가락이 판 밖으로 떨어진 낙(落)의 면 번호. 0칸 이동이고 턴이 끝난다.
const NAK_FACE: int = 0
const FACES: Array[int] = [0, 1, 2, 3, 4, 5]


func _init() -> void:
	tool_id = &"YUT"
	display_name = "전통 박달나무 윷"


func roll(rng: RandomNumberGenerator) -> RollResult:
	var face: int = FACES[rng.randi_range(0, FACES.size() - 1)]
	var nak: bool = face == NAK_FACE
	var result: RollResult = RollResult.make(tool_id, 0 if nak else face, {"face": face, "nak": nak})
	result.ends_turn = nak
	result.reroll = face >= 4
	return result
