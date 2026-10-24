# File: res://core_engine/tools/tool_chinchiro.gd
# Class: class_name ToolChinchiro
# Role: 지하노역장 친치로(사기 주사위) - [4, 4, 5, 5, 6, 삐끗] 균등 추첨: 5/6 확률로 4~6칸 고눈금 전진, 1/6 확률로 주사위가 접시 밖으로 튀는 '삐끗'이 터져 이번 이동은 0칸 (후퇴는 없다)
class_name ToolChinchiro
extends BaseJudgmentTool

## 물리 주사위의 삐끗 면 번호 (이동은 0칸).
const OOPS_FACE: int = -6
const FACES: Array[int] = [4, 4, 5, 5, 6, -6]


func _init() -> void:
	tool_id = &"CHINCHIRO"
	display_name = "지하노역장 친치로"


func roll(rng: RandomNumberGenerator) -> RollResult:
	var face: int = FACES[rng.randi_range(0, FACES.size() - 1)]
	var oops: bool = face == OOPS_FACE
	return RollResult.make(tool_id, 0 if oops else face, {"face": face, "oops": oops})
