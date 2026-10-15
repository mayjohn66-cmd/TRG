# File: res://core_engine/tools/tool_chinchiro.gd
# Class: class_name ToolChinchiro
# Role: 지하노역장 친치로(사기 주사위) - [4, 4, 5, 5, 6, -6] 균등 추첨: 5/6 확률로 4~6칸 고눈금 전진, 1/6 확률로 주사위가 접시 밖으로 튀는 '삐끗'이 터져 -6칸 강제 후퇴
class_name ToolChinchiro
extends BaseJudgmentTool

const FACES: Array[int] = [4, 4, 5, 5, 6, -6]
const OOPS_FACE: int = -6


func _init() -> void:
	tool_id = &"CHINCHIRO"
	display_name = "지하노역장 친치로"


func roll(rng: RandomNumberGenerator) -> RollResult:
	var face: int = FACES[rng.randi_range(0, FACES.size() - 1)]
	return RollResult.make(tool_id, face, {"face": face, "oops": face == OOPS_FACE})
